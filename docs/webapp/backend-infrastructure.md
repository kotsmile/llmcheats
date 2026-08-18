---
title: Infrastructure layer — SQL, transactions, migrations
summary: Infra implements the service's ports with hand-written SQL, a shared transaction factory, and timestamp-prefixed migrations applied by a separate subcommand.
keywords: [infra, raw SQL, sqlx, row struct, jsonb, TxFactory, WithTx, FOR UPDATE, SKIP LOCKED, migrations, goose, index]
related:
  - webapp/backend-services.md
  - webapp/security-input-sql.md
  - webapp/performance.md
  - webapp/infrastructure.md
---

# Infrastructure layer — SQL, transactions, migrations

## Writing raw SQL by default

Hand-written SQL because the query is the artifact that gets reviewed: the
statement in the code is the statement that runs, so its plan, its lock
footprint and its column list are all readable at review time, and there is no
lazy-load or association walk that turns one reviewed call into N.

The costs are real — more typing, no free portability, hand-written row
mapping — and this reference pays them deliberately. A project that already
runs an ORM keeps it; what does not move is the parameter-binding invariant in
`webapp/security-input-sql.md`, which binds every dynamic value whatever writes
the SQL.

## Mapping rows to entities

Use `sqlx` (Go) with hand-written SQL. Row structs are private to the infra
package, tagged with `db:"..."`, and converted to/from entities explicitly:

```go
type userRow struct {
    ID           string         `db:"id"`
    Email        string         `db:"email"`
    PasswordHash sql.NullString `db:"password_hash"`
    Profile      []byte         `db:"profile"` // jsonb
    LastActiveAt sql.NullTime   `db:"last_active_at"`
}

func (r userRow) toEntity() (entity.User, error) { ... }
```

Rules:

- Query strings are `const`. Column lists are shared consts (`userCols`) so
  every query selects the same, reviewed set.
- JSONB columns are `[]byte` on the row, marshalled by hand. Gotcha: a nil
  `[]byte` for JSONB fails in some drivers, and `[]byte("null")` stores the
  **JSON `null` scalar**, not SQL `NULL` (`col IS NULL` stays false,
  `jsonb_typeof` returns `'null'`). Decide which "empty" each column means —
  JSON null via `[]byte("null")`, true SQL NULL via a nullable wrapper — and
  be consistent.
- The infra layer translates driver errors into domain vocabulary:
  `sql.ErrNoRows` → a canonical not-found error; the service re-emits its own
  domain sentinel with a better message.

## Implementing the transaction factory

One `TxFactory` abstraction in a shared library:

```go
func (f *TxFactory) WithTx(ctx context.Context, fn func(tx *sqlx.Tx) error) error {
    tx, err := f.beginTx(ctx) // retries BEGIN up to 3× on transient conn errors
    if err != nil {
        return err
    }
    if err := fn(tx); err != nil {
        if rbErr := tx.Rollback(); rbErr != nil && !errors.Is(rbErr, sql.ErrTxDone) {
            return errors.Join(err, fmt.Errorf("rollback: %w", rbErr))
        }
        return err
    }
    if err := tx.Commit(); err != nil {
        return fmt.Errorf("commit: %w", err)
    }
    return nil
}
```

Retrying `BEGIN` (and only `BEGIN` — it is side-effect-free) on
`driver.ErrBadConn` / `ECONNRESET` / `EPIPE` absorbs the moment a managed
Postgres pooler drops every pooled connection at once.

## Locking for read-modify-write

Read-modify-write against concurrent writers uses `SELECT ... FOR UPDATE`
inside the transaction (`FindUserByIDForUpdate`). A "claim exactly once"
operation (two approvals landing simultaneously) is a **conditional UPDATE**
whose affected-row count is the verdict.

## Writing migrations

- Plain SQL files, timestamp-prefixed, in a `migrations/` directory, managed
  by a migration tool that supports up-migrations in SQL (e.g. goose).
- Embedded into the binary (`//go:embed migrations/*.sql`) and applied by the
  **`migrate` subcommand** — never on `serve` boot. In an orchestrated
  deployment this runs as a pre-deploy job or init container
  (`webapp/infrastructure.md`).
- Migrations carry justification comments: why this index, what locks the DDL
  takes, what the operator should know. `CREATE INDEX CONCURRENTLY` goes in a
  no-transaction migration.
- **No index without a written reason** — but remember PostgreSQL does *not*
  index foreign-key columns automatically; a FK you join or cascade on almost
  always needs one.

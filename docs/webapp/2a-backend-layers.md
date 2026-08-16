# 2. Backend: Domain-Driven Design

The reference implementation below is Go. §2.9 maps every layer onto Python.

## 2.1 The four layers

Each business **domain** (user, order, billing, …) is one package tree with four
sub-packages:

```
internal/<domain>/
  entity/            ← domain model: types, value objects, invariants, sentinel errors
  service/           ← use cases: orchestration, transactions, port interfaces
  infra/             ← implementations of the service's ports (Postgres, Redis, adapters)
  transport/http/    ← HTTP handlers, DTOs, routing, auth guards
```

Dependency direction — this is the load-bearing rule of the whole architecture:

```
transport/http ──▶ service ──▶ entity
                      ▲
                   infra ─────▶ entity
```

- `entity` imports **nothing** from the other layers. Pure domain.
- `service` imports `entity` and declares — as Go interfaces — every external
  capability it needs (**ports**). It never imports `infra`.
- `infra` imports `service` (for the port interfaces it implements) and
  `entity` (for the types). **The consumer owns the interface; the
  implementation conforms to it**, never the other way around.
- `transport` imports `service` and `entity`. It contains all HTTP vocabulary
  (status codes, JSON tags, cookies) and nothing else does.
- `cmd/<app>/main.go` imports everything and is the **only wiring point**.

Every infra implementation carries a compile-time conformance assertion at the
top of the file:

```go
var _ service.Persistence = (*PostgresPersistence)(nil)
```

**Shared libraries** live outside the domains (e.g. `lib/` or `pkg/`): an HTTP
kit, a Postgres helper, a config loader, a typed-error package, crypto helpers.
They are a leaf layer — they import nothing from `internal/`. Clients for
external third-party APIs also live here (one package per vendor, each owning
its own `Config` struct), **not** in a domain's `infra/` — `infra/` is only for
implementations of that domain's own ports.

A small app (an internal console, a single-purpose service) keeps exactly the
same shape with one domain:

```
internal/request/
  entity/    request.go
  infra/     request_repo.go event_repo.go
  service/   service.go policy.go
  transport/http/  http.go
```

plus a handful of plain supporting packages beside it for things that are
neither entity nor infra (parsers of external artefacts, provisioning helpers).

## 2.2 Entity layer: invariants live here

The entity layer contains entity types, **value objects**, sentinel errors, and
pure state-transition methods. No I/O, no SQL, no HTTP vocabulary — name things
in domain terms (`OrderPlaced`, not `WebhookPayload`).

### Value objects

Every primitive that has rules gets a type with a validating constructor:

```go
type Email string

func EmailFromString(s string) (Email, error) {
    email := Email(s)
    if err := email.Validate(); err != nil {
        return Email(""), err
    }
    return email, nil
}

func (e Email) String() string { return string(e) }

func (e Email) Validate() error {
    var errs []string
    if e != "" && !emailRe.MatchString(string(e)) {
        errs = append(errs, "invalid email format")
    }
    return NewValidationError(errs) // returns nil for an empty slice
}
```

Two sub-rules that pay off later:

- **Value objects stay `comparable`** (no pointer/slice fields), so they can be
  map keys. If a role is a pair (base role + specialisation), make it a struct
  of two strings, not a formatted string.
- **Secrets redact themselves.** A `Password` type's `String()` returns
  `"**REDACTED**"` so it is safe to pass to any logger; the real bytes are
  behind an explicit `Inner()`.

### Invariants in constructors and mutators

The entity is never in an invalid state because the only ways to create or
change it check the rules:

```go
func NewUser(email Email, password Password) (User, error) {
    if err := email.Validate(); err != nil {
        return User{}, err
    }
    if err := password.Validate(); err != nil {
        return User{}, err
    }
    hash, err := password.Hash()
    if err != nil {
        return User{}, err
    }
    return User{ID: NewUserID(), Email: email, PasswordHash: hash, Role: RoleUser}, nil
}

func (u *User) VerifyEmail() error {
    if u.EmailVerified {
        return ErrEmailAlreadyVerified
    }
    u.EmailVerified = true
    u.UpdatedAt = time.Now()
    return nil
}
```

**Actor-based operations belong to the entity too.** When an operation's
legality depends on who performs it, the entity method takes the actor and
decides — the service just calls it:

```go
func (u *User) AdminDeactivate(actor *User) error {
    if err := actor.CheckPerm(PermUserDeactivate); err != nil {
        return err
    }
    if u.Role == RoleAdmin {
        return ErrCannotDeactivateAdmin
    }
    if !u.IsActivated {
        return ErrUserNotActive
    }
    u.IsActivated = false
    u.ClearAssignments()
    return nil
}
```

This is what "invariant entities" means in practice: business rules are methods
on the data they protect, testable without a database, impossible to bypass
from a handler.

### Sentinel errors

One `var (...)` block per entity file. Each sentinel carries a **generic
user-facing message** plus internal detail attached separately (see §2.6):

```go
var (
    ErrWrongPassword         = NewUnauthorizedError("wrong email or password").WithDebug("wrong password")
    ErrCannotDeactivateAdmin = NewForbiddenError("forbidden").WithDebug("cannot deactivate admin")
    ErrRecoveryCodeExpired   = NewBadRequestError("recovery code expired").
                                   WithReason("recovery_code_expired") // machine-readable, for client i18n
)
```

## 2.3 Service layer: use cases and ports

Structure of a service package:

- `service.go` — the `Service` struct, **all port interfaces**, the DI
  constructor, optional `Run(ctx)` background loop.
- Sibling files split **by access scope or use-case family**, not by entity:
  `auth.go` (public flows), `account.go` (self-service), `admin.go`,
  `staff.go`, `system.go` (internal helpers).
- One `Service` struct per domain. No per-use-case command/handler classes —
  that's ceremony this scale does not need.

### Ports are declared where they are consumed

```go
// service/service.go
type Persistence interface {
    FindUserByEmail(ctx context.Context, email entity.Email, tx *sqlx.Tx) (entity.User, error)
    FindUserByIDForUpdate(ctx context.Context, id entity.UserID, tx *sqlx.Tx) (entity.User, error)
    SaveUser(ctx context.Context, user entity.User, tx *sqlx.Tx) error
}

type Mailer interface {
    SendRecoveryCodeEmail(ctx context.Context, to entity.Email, code string) error
}
```

Hand-written interfaces, one per collaborator kind. Note the **explicit
`tx *sqlx.Tx` trailing parameter** on persistence methods: the transaction is
passed openly, never smuggled through `context`. `nil` means "no transaction,
use the pool".

### Dependency injection: constructors, by hand

No DI framework. `main.go` builds infra, passes it into `NewService`, passes
services into `NewHandlers`:

```go
func NewService(
    cfg config.UserServiceConfig,
    persistence Persistence,
    mailer Mailer,
    txFactory *pgx.TxFactory,
    logger *zap.Logger,
) *Service
```

Keep dependencies minimal: pass `signingSecret string`, not the whole config
struct, when one field is all the service needs.

### Transaction boundaries: mutate → commit → side effects

The service owns the transaction; infra only receives it:

```go
func (s *Service) DeleteMe(ctx context.Context, userID entity.UserID) error {
    if err := s.txFactory.WithTx(ctx, func(tx *sqlx.Tx) error {
        if _, err := s.persistence.FindUserByID(ctx, userID, tx); err != nil {
            return err
        }
        return s.persistence.DeleteUser(ctx, userID, tx)
    }); err != nil {
        return fmt.Errorf("delete user: %w", err)
    }

    // Post-commit, best-effort: external systems are NEVER called inside the tx.
    if err := s.sessions.RevokeAll(ctx, userID); err != nil {
        s.logger.Warn("revoke sessions after account deletion failed", zap.Error(err))
    }
    return nil
}
```

The ordering rule: **never call an external system inside a database
transaction**. Mutate, commit, then trigger side effects; a failed side effect
is a warning log, not a rollback (design the side effect to be retryable or
reconciled instead).

Detached work that must outlive the request uses `context.WithoutCancel(ctx)`
plus either a panic-recovering `SafeGo` helper or a **bounded** worker pool
that returns "busy" at capacity — never a bare `go func()`.

### Cross-domain dependencies

Domain A must not import domain B. When A needs a capability of B, A declares a
tiny interface in its own service package, and `main.go` wires B's service into
it **after construction** via a setter:

```go
// in user/service — user knows nothing about the notification domain
type WelcomeNotifier interface {
    NotifyWelcome(ctx context.Context, userID entity.UserID) error
}
func (s *Service) SetWelcomeNotifier(n WelcomeNotifier) { s.welcomeNotifier = n }
```

Such ports are optional (`if s.welcomeNotifier != nil`) so a build with a
feature disabled degrades instead of crashing. Because the compiler can no
longer catch a forgotten setter, each service exposes a runtime check that
`main.go` calls before serving:

```go
func (s *Service) ValidateWiring() error {
    var missing []string
    if s.welcomeNotifier == nil {
        missing = append(missing, "WelcomeNotifier")
    }
    if len(missing) > 0 {
        return fmt.Errorf("user service: unwired ports: %s", strings.Join(missing, ", "))
    }
    return nil
}
```

Treat this pattern as a **scaling workaround** for a large multi-domain binary,
not a default: with two or three domains, plain constructor parameters are
simpler.

## 2.4 Infrastructure layer

### Database access: raw SQL, no ORM

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

### Transactions

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

Read-modify-write against concurrent writers uses `SELECT ... FOR UPDATE`
inside the transaction (`FindUserByIDForUpdate`). A "claim exactly once"
operation (two approvals landing simultaneously) is a **conditional UPDATE**
whose affected-row count is the verdict.

### Migrations

- Plain SQL files, timestamp-prefixed, in a `migrations/` directory, managed
  by a migration tool that supports up-migrations in SQL (e.g. goose).
- Embedded into the binary (`//go:embed migrations/*.sql`) and applied by the
  **`migrate` subcommand** — never on `serve` boot. In an orchestrated
  deployment this runs as a pre-deploy job or init container (§7.4).
- Migrations carry justification comments: why this index, what locks the DDL
  takes, what the operator should know. `CREATE INDEX CONCURRENTLY` goes in a
  no-transaction migration.
- **No index without a written reason** — but remember PostgreSQL does *not*
  index foreign-key columns automatically; a FK you join or cascade on almost
  always needs one.

---
title: Database tests
summary: Unit tests never require a database; DB tests exist only where the SQL itself is the risk, gated by an env var or a build tag and isolated at setup.
keywords: [database test, Postgres, env-gated, t.Skip, truncate, build tag, dbtest, throwaway schema, search_path, fixtures, migrations]
related:
  - webapp/testing-strategy.md
  - webapp/backend-infrastructure.md
  - webapp/testing-ci.md
---

# Database tests

## When a database test is worth it

Unit tests never require a database. DB tests exist only where the SQL itself
is the risk — a `SELECT *` that drifts against a new column, a single
`ON CONFLICT` clause, a comparison operator that could invert — and each states
that reason in its comment.

## Gating DB tests by environment variable

```go
func testDB(t *testing.T) *sqlx.DB {
    t.Helper()
    dsn := os.Getenv("APP_TEST_PG")
    if dsn == "" {
        t.Skip("APP_TEST_PG is not set — skipping the database tests")
    }
    db, err := sqlx.Connect("postgres", dsn)
    require.NoError(t, err)
    t.Cleanup(func() { _ = db.Close() })
    _, err = db.Exec(`delete from workflows`) // FK cascades take the children
    require.NoError(t, err)
    return db
}
```

Isolation is a `DELETE` from the root table at **setup** (not teardown — a
failed test leaves its state for inspection). Fixtures are Go helper
constructors, not SQL files. The database must have migrations applied.

## Fencing DB tests behind a build tag

For a repo whose default `go test` must not even compile the DB tests:
`//go:build dbtest`, create an isolated schema, apply the exact DDL from the
named migration, `SET search_path`, drop the schema on cleanup.

If CI has no Postgres service, these tests self-skip — decide explicitly
whether that gap is acceptable, and write it down.

# 4. Testing

## 4.1 Philosophy

- **A test protects a behavior or an invariant, never the shape of the
  implementation.** Assert what a caller depends on — the decision returned, the
  row persisted, the status code, the event emitted — not the private helper that
  produced it. A test that has to be rewritten every time its subject is
  refactored was testing the shape, and it will be deleted the first time it is
  inconvenient.
- **Write them in this order**, and stop where the cost of the failure stops
  justifying the test:
  1. **a test that reproduces a discovered bug** — written first, failing before
     the fix, and kept afterwards. This is a gate in the fast flow (§5 F3,
     `devflow/3-fast-flow.md`) and it does not collapse under any flow, however
     small (§10.5, `devflow/6-asap-flow.md`). Its one exception is §4.7's, and it
     is about where the defect lives, never about how urgent the work is;
  2. business and domain invariants — entity and service;
  3. contracts something else depends on: an endpoint's authorization matrix, a
     published request/response shape, a pinned role-name constant;
  4. critical integration paths — auth, money, migrations, the SQL that is
     itself the risk (§4.4);
  5. everything else, only where a failure would actually cost something —
     business logic gets the density, transport gets a thinner
     authorization-matrix layer, glue gets none.
- **Do not add a test because code changed.** A trivial refactor, plain wiring,
  and behavior already covered by a test one level up get nothing. New behavior
  gets a test when the behavior is worth protecting; a spike or a throwaway
  script does not, and then you *say* you skipped it.
- **Critical paths, justified individually.** Every non-trivial test carries a
  doc comment answering *why does this exist* — the invariant it guards, the
  way the code can silently regress, or the incident that motivated it
  ("guards the invariant: chaining decorators must copy `reason`, otherwise it
  is silently dropped"). A test that cannot state its reason is ballast.
- **Name tests as sentences** where it helps:
  `TestUpsertStoresTheAccessListsAndNeverNull`,
  `TestTheGateAcceptsTheThreeRolesAndOnlyThem`.
- **AAA with comments**: `// Arrange`, `// Act`, `// Assert` sections in every
  test, both backend and frontend.

## 4.2 Go unit tests

Table-driven where cases share a shape; testify (`require`/`assert`) or plain
stdlib — pick one per package and stay consistent:

```go
func TestAPIKeyAuth(t *testing.T) {
    tests := []struct {
        name       string
        configured string
        provided   string
        wantStatus int
    }{
        {"valid key passes", "secret-key", "secret-key", http.StatusOK},
        {"wrong key rejected", "secret-key", "wrong", http.StatusUnauthorized},
        {"missing header rejected", "secret-key", "", http.StatusUnauthorized},
        {"empty configured key rejects everything", "", "", http.StatusUnauthorized},
    }
    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            // Arrange
            handler := APIKeyAuth(tt.configured)(okHandler)
            req := httptest.NewRequest(http.MethodGet, "/x", nil)
            if tt.provided != "" { req.Header.Set("X-API-Key", tt.provided) }
            rec := httptest.NewRecorder()
            // Act
            handler.ServeHTTP(rec, req)
            // Assert
            require.Equal(t, tt.wantStatus, rec.Code)
        })
    }
}
```

**A config test is mandatory**: parse the committed dev config file in a test —
otherwise a broken committed config is discovered by the next person trying to
run the service. Pair it with a test that secrets arrive via placeholders
(`t.Setenv`), proving the no-`os.Getenv` contract.

## 4.3 Fakes, not mocks

**No mocking frameworks.** Hand-written fakes are shorter, readable, and fail
in ways you designed. A project that already runs a mocking framework keeps it;
what does not move is the property below — a renamed or re-signed port must fail
the suite rather than be auto-answered. The reason is the failure mode, not the line count: a
generated or `MagicMock`-style double answers a method that no longer exists, so
a renamed or re-signed port keeps a green suite while production breaks. The
price is real and is the point — change a port and every fake stops compiling,
which is the signal a mock framework swallows. Three idioms:

**Nil-embedded interface — unexpected calls panic:**

```go
// A method these tests do not need panics rather than silently answering zero —
// the right direction for a store a route was not supposed to reach.
type fakeWorkflows struct {
    service.WorkflowStore // embedded nil interface
    items []entity.Workflow
}
func (f *fakeWorkflows) List(ctx context.Context) ([]entity.Workflow, error) {
    return f.items, nil
}
```

**Call-recording fake with a mutex** — for asserting a hook fired:

```go
type fakeNotifier struct {
    mu    sync.Mutex
    calls []entity.UserID
    err   error
}
func (f *fakeNotifier) NotifyWelcome(_ context.Context, id entity.UserID) error {
    f.mu.Lock(); defer f.mu.Unlock()
    f.calls = append(f.calls, id)
    return f.err
}
```

**In-memory implementation of a whole port** — mirrors the real semantics
(version chains, label resolution) for service-level tests.

Use real dependencies where they are pure and local: the real router, the real
middleware in dev mode, real constructors. The universal logger stub is
`zap.NewNop()`.

## 4.4 Database tests

Unit tests never require a database. DB tests exist only where the SQL itself
is the risk — a `SELECT *` that drifts against a new column, a single
`ON CONFLICT` clause, a comparison operator that could invert — and each states
that reason in its comment. Two gating patterns:

**Env-gated skip + truncate-per-test:**

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

**Build-tag fence + throwaway schema** (for a repo whose default `go test`
must not even compile the DB tests): `//go:build dbtest`, create an isolated
schema, apply the exact DDL from the named migration, `SET search_path`, drop
the schema on cleanup.

If CI has no Postgres service, these tests self-skip — decide explicitly
whether that gap is acceptable, and write it down.

## 4.5 HTTP handler tests

Test the transport layer by **building the real router with real middleware
and fake stores**, then driving requests through `ServeHTTP`:

```go
func newTestRouter(t *testing.T, user string, roles ...string) http.Handler {
    t.Helper()
    svc := service.New(service.Config{}, zap.NewNop(), &fakeStore{items: fixtures()})
    auth := authmw.DevAuthenticator(user, roles) // pass-through auth carrying the identity
    return Router(svc, auth, zap.NewNop())
}

func do(t *testing.T, h http.Handler, method, url, body string) *httptest.ResponseRecorder {
    req := httptest.NewRequest(method, url, strings.NewReader(body))
    rec := httptest.NewRecorder()
    h.ServeHTTP(rec, req)
    return rec
}
```

What to assert at this layer: **the authorization matrix** (which roles get
200 vs 403 on which routes), route-construction sanity (`TestRouterBuilds` —
building the router at all asserts no duplicate patterns), and pinned contract
constants (role name strings are a contract with the identity provider — pin
them). Body-level assertions belong in service tests.

Make handlers testable by giving the auth middleware a **dev mode** that
injects a configured identity without a real IdP — the same mode a local dev
build runs in.

## 4.6 End-to-end tests

A small, real-HTTP e2e suite run against the fully composed stack
(docker compose: Postgres, Redis, object store, migrate job, API, e2e runner):

- Tests drive the **public API client** (the generated one), not internal
  functions; one deliberate backdoor into the DB is allowed for what has no API
  (e.g. marking an email verified when there is no mail server).
- Unique fixtures by construction (`user-<timestamp>@e2e.test`), no cleanup.
- Cover the golden paths: signup/signin/refresh/logout, the core object
  lifecycle, one websocket flow if you have one.
- Keep it out of the default unit-test sweep; run it as its own make target /
  CI job with the compose stack.

## 4.7 Frontend tests

Be honest about the trade-off the reference codebase makes: **the SPAs rely on
`tsc -b` + ESLint as their check**, and unit tests exist only for **pure
logic** — date/window rules, parsers, mappers, schedule computations — using
the zero-dependency Node built-in runner (Node ≥ 22.6 strips types from `.ts`
imports natively):

```ts
import assert from "node:assert/strict";
import { test } from "node:test";
import { bookingWindowAt } from "./bookingWindowRules.ts";

const at = (h: number, m = 0) => new Date(2026, 0, 15, h, m);

test("evening booking window is open 19:00–03:00 and closed the rest of the day", () => {
  // Assert — the window wraps midnight
  assert.equal(bookingWindowAt(at(19)).isOpen, true);
  assert.equal(bookingWindowAt(at(2, 59)).isOpen, true);
  assert.equal(bookingWindowAt(at(18, 59)).isOpen, false);
  assert.equal(bookingWindowAt(at(3)).isOpen, false);
});
```

The discipline that makes this defensible: keep logic **out of components** —
in pure `lib/` and `model/` modules — so the testable surface is testable
without a DOM. If you add component tests, add them for genuinely stateful
composites (a multi-step form), with Testing Library; do not snapshot-test
markup.

That discipline is also how §4.1's reproduction test gets paid on the frontend,
so state it rather than improvising it: a bug in a screen is usually a bug in a
rule that should not have been inside a component, so pull the rule into
`lib/`/`model/` and let the failing test land there. Only when nothing is left
to extract — the defect is in markup, wiring, or a library call — is there no
unit to write, and then the fix reports the flow walked in the browser and what
it showed before and after. That is a narrower carve-out than it looks: it never
covers a rule, a computation, or a state transition.

## 4.8 CI

- Per-project check jobs gated on changed paths; a shared-library change
  re-runs its dependents' checks.
- Backend check: `go vet ./...` + `go test ./...` (plus build). Run single
  tests locally with `-race`; consider `-race` in CI when the suite affords it.
- Frontend check: `tsc -b` + ESLint (+ whatever unit tests exist).
- Also-run safety nets that aren't unit tests: config-parses tests,
  generated-file staleness checks (`--check` modes), rendered-manifest diffs.
- Checks on merge requests are **blocking** by default; make a check advisory
  only as a conscious, documented exception.

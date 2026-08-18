---
title: Unit tests and hand-written fakes
summary: Table-driven Go tests, a mandatory config-parses test, and hand-written fakes instead of mock frameworks so a renamed port breaks the build.
keywords: [unit test, table-driven, testify, httptest, config test, t.Setenv, fakes, mocks, nil-embedded interface, call recording, in-memory port, zap.NewNop]
related:
  - webapp/testing-strategy.md
  - webapp/testing-database.md
  - webapp/backend-config-lifecycle.md
  - webapp/backend-services.md
---

# Unit tests and hand-written fakes

## Writing Go unit tests

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

## Testing the committed config

**A config test is mandatory**: parse the committed dev config file in a test —
otherwise a broken committed config is discovered by the next person trying to
run the service. Pair it with a test that secrets arrive via placeholders
(`t.Setenv`), proving the no-`os.Getenv` contract
(`webapp/backend-config-lifecycle.md`).

## Writing fakes instead of mocks

**No mocking frameworks.** Hand-written fakes are shorter, readable, and fail
in ways you designed. A project that already runs a mocking framework keeps it;
what does not move is the property below — a renamed or re-signed port must
fail the suite rather than be auto-answered.

The reason is the failure mode, not the line count: a generated or
`MagicMock`-style double answers a method that no longer exists, so a renamed
or re-signed port keeps a green suite while production breaks. The price is
real and is the point — change a port and every fake stops compiling, which is
the signal a mock framework swallows.

## Three fake idioms

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

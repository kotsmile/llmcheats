---
title: HTTP handler tests and end-to-end tests
summary: Handler tests drive the real router with real middleware and fake stores to assert the authorization matrix; a small e2e suite drives the public client against the composed stack.
keywords: [handler test, router, ServeHTTP, httptest, dev authenticator, authorization matrix, contract constants, e2e, docker compose, golden path, fixtures]
related:
  - webapp/testing-unit-fakes.md
  - webapp/backend-transport.md
  - webapp/security-authorization.md
  - webapp/testing-ci.md
---

# HTTP handler tests and end-to-end tests

## Testing handlers through the real router

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

Make handlers testable by giving the auth middleware a **dev mode** that
injects a configured identity without a real IdP — the same mode a local dev
build runs in.

## What to assert at the transport layer

- **The authorization matrix**: which roles get 200 vs 403 on which routes.
- Route-construction sanity (`TestRouterBuilds` — building the router at all
  asserts no duplicate patterns).
- Pinned contract constants: role name strings are a contract with the identity
  provider — pin them.

Body-level assertions belong in service tests.

## Running end-to-end tests against the composed stack

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

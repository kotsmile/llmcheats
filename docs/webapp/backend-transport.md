---
title: Transport layer — handlers, DTOs, middleware, guards
summary: Handlers return values through a generic JSON adapter, one hardened reader validates every request body, and middleware order and route guards are fixed and documented.
keywords: [handler, HTTP, JSON envelope, DTO, ReadJSON, validation, 415, 413, middleware order, chi, timeout, auth guard, status mapping, field filtering]
related:
  - webapp/backend-errors.md
  - webapp/backend-services.md
  - webapp/security-http-hardening.md
  - webapp/security-authorization.md
  - webapp/performance.md
---

# Transport layer — handlers, DTOs, middleware, guards

## Returning values from handlers

Handlers are `func(w, r) (ResponseDTO, error)` — they never touch the
`ResponseWriter` for the success path. A generic adapter lifts them:

```go
func JSONFunc[V any](h func(http.ResponseWriter, *http.Request) (V, error)) http.HandlerFunc {
    return func(w http.ResponseWriter, r *http.Request) {
        v, err := h(w, r)
        if err != nil {
            WriteAppError(r, w, err)
            return
        }
        WriteJSON(w, http.StatusOK, v)
    }
}
```

## Fixing the response envelopes

Envelopes are fixed for the whole API:

```go
type APIData[T any] struct {                 // success
    Data T      `json:"data"`
    Code int    `json:"code"`
}
type APIError struct {                       // error — flat, not nested
    Error      string `json:"error"`
    Code       int    `json:"code"`
    Reason     string `json:"reason,omitempty"`      // machine-readable
    RetryAfter int    `json:"retry_after,omitempty"`
}
type Paginated[T any] struct {
    Items  []T `json:"items"`
    Total  int `json:"total"`
    Limit  int `json:"limit"`
    Offset int `json:"offset"`
}
```

## Reading and validating request bodies

DTOs live in the transport package with `json` + `validate` tags (and OpenAPI
annotations if you generate a spec). All request parsing goes through one
hardened helper:

```go
const defaultMaxBodySize = 1 << 20 // 1MB

func ReadJSON(w http.ResponseWriter, r *http.Request, dst any) error {
    if ct, _, _ := mime.ParseMediaType(r.Header.Get("Content-Type")); ct != "application/json" {
        return ErrUnsupportedMediaType // 415 — a load-bearing CSRF leg (webapp/security-http-hardening.md)
    }
    r.Body = http.MaxBytesReader(w, r.Body, defaultMaxBodySize) // w lets the server drop the conn
    dec := json.NewDecoder(r.Body)
    dec.DisallowUnknownFields()
    if err := dec.Decode(dst); err != nil {
        var tooBig *http.MaxBytesError
        if errors.As(err, &tooBig) { return ErrBodyTooLarge } // 413, not a generic 400
        return ErrBadJSON.WithError(err)
    }
    if err := dec.Decode(&struct{}{}); err != io.EOF { return ErrTrailingJSON }
    if err := validator.Struct(dst); err != nil { return ErrValidation.WithError(err) }
    return nil
}
```

Media-type check (415), size cap (oversize is 413, not 400), unknown-field
rejection, trailing-garbage rejection, struct-tag validation — in that order,
in one place. After `ReadJSON`, the handler converts DTO fields into value
objects (`entity.EmailFromString(req.Email)`), which is the second validation
gate.

**One handler = one service call.** A handler parses, converts, calls one
service method, converts the result to a DTO. If a use case needs two steps,
that is one service method, not two calls from the handler.

## Ordering router middleware

Router: chi (or any mux with route patterns and per-route middleware). Order
matters and is documented:

```
Recover                          (outermost: catch panics, log stack, return 500)
  SecureHeaders                  (X-Frame-Options, nosniff, HSTS, Referrer-Policy, COOP)
    router:
      CORS                       (only if a second origin is configured)
      RequestLogging             (method, route pattern, status, duration)
      Metrics                    (RED metrics by route pattern)
      Group A: RedactSecrets + Timeout(10s)   ← the default for all request/response routes
        per-route: Auth(handler, guards...)
      Group B: Timeout(45–60s)                ← named slow routes (uploads, AI calls), each justified
      parent router (NO timeout)              ← websockets, streaming downloads (a timeout
                                                handler buffers responses and breaks streaming)
```

The **10-second default deadline** is a budget, not a suggestion: the timeout
middleware cancels `r.Context()`, so downstream DB and HTTP calls observe it.
Every route that needs more gets an explicitly justified carve-out group — the
full budget hierarchy is in `webapp/performance.md`.

## Authenticating and guarding routes

Auth is **per-route**, not global. The middleware extracts the credential
(cookie first, then `Authorization: Bearer` — `webapp/security-authentication.md`),
validates it, and injects claims into the request context. Route access is
expressed as composable **guards**:

```go
type Guard interface {
    Guard(claims entity.Claims) bool
    String() string // for logs: which guard denied
}

r.Get("/admin/users", auth.Auth(h.ListUsers, ut.AdminGuard))
r.Post("/orders", auth.Auth(h.CreateOrder, ut.UserGuard))
```

Guards (route-level, coarse: "is this class of user allowed here") are a
**different layer** from permissions (`entity.Perm.Check(role)`,
operation-level, checked inside entity/service methods). Both exist; neither
substitutes for the other — see `webapp/security-authorization.md`.

## Mapping errors to HTTP status

Two valid styles — pick one per codebase:

**Style A — status-carrying errors** (best for large APIs): a typed application
error carries its HTTP status; the single `WriteAppError` function maps it
(`webapp/backend-errors.md`).

**Style B — plain sentinels + transport switch** (lighter, good for small
services): entity defines `ErrNotFound`, `ErrForbidden`, `ErrValidation`,
`ErrConflict` with `errors.New`, and the transport layer maps:

```go
switch {
case errors.Is(err, entity.ErrNotFound):  writeErr(w, http.StatusNotFound, err.Error())
case errors.Is(err, entity.ErrInvalid):   writeErr(w, http.StatusBadRequest, err.Error())
case errors.Is(err, entity.ErrForbidden): writeErr(w, http.StatusForbidden, err.Error())
default:                                  writeErr(w, http.StatusInternalServerError, "internal error")
}
```

Either way: **an unrecognised error becomes an opaque 500** — internal error
strings never reach the client.

## Filtering response fields by viewer role

When one endpoint serves several viewer roles, tag response DTO fields with the
roles that may see them and filter by reflection before writing:

```go
type UserResponse struct {
    ID    string `json:"id" access:"*"`
    Email string `json:"email" access:"self,admin,support"`
    Notes string `json:"notes" access:"admin"`
}
// Filter[T](value, Viewer{Role, ID}) zeroes fields the viewer may not see.
```

This keeps "what the admin sees" and "what the user sees" in one struct, one
endpoint, one reviewable place. Cache the reflection metadata (`sync.Map`).

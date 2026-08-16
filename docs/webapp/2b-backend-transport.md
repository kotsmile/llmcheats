# 2. Backend: Domain-Driven Design — transport, errors, config, lifecycle

## 2.5 Transport layer

### Handlers return values, not writes

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

### Request DTOs and validation

DTOs live in the transport package with `json` + `validate` tags (and OpenAPI
annotations if you generate a spec). All request parsing goes through one
hardened helper:

```go
const defaultMaxBodySize = 1 << 20 // 1MB

func ReadJSON(w http.ResponseWriter, r *http.Request, dst any) error {
    if ct, _, _ := mime.ParseMediaType(r.Header.Get("Content-Type")); ct != "application/json" {
        return ErrUnsupportedMediaType // 415 — a load-bearing CSRF leg (webapp/5-security.md §5.7)
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
in one place. After `ReadJSON`, the handler
converts DTO fields into value objects (`entity.EmailFromString(req.Email)`),
which is the second validation gate.

**One handler = one service call.** A handler parses, converts, calls one
service method, converts the result to a DTO. If a use case needs two steps,
that's one service method, not two calls from the handler.

### Router and middleware order

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
Every route that needs more gets an explicitly justified carve-out group.

### Authentication middleware and guards

Auth is **per-route**, not global. The middleware extracts the credential
(cookie first, then `Authorization: Bearer` — see §5.1,
`webapp/5-security.md`), validates it, and injects claims into the request
context. Route access is expressed as composable **guards**:

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
substitutes for the other. See §5.2 in `webapp/5-security.md`.

### Error → status mapping happens once

Two valid styles — pick one per codebase:

**Style A — status-carrying errors** (best for large APIs): a typed application
error carries its HTTP status; the single `WriteAppError` function maps it (see
§2.6).

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

### Field-level response filtering

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

## 2.6 Error handling: the status-carrying AppError

One immutable error type in a shared library:

```go
type AppError struct {
    code       int    // HTTP status, carried by the error itself
    msg        string // user-facing, safe to return
    cause      error  // wrapped underlying error
    debug      string // internal detail, exposed only to staff/debug sessions
    loc        string // file:line where the error was created
    reason     string // machine-readable code ("recovery_code_expired") for client i18n
    retryAfter int
}
```

Design points that make it work:

- **Constructors per status**: `NewBadRequestError`, `NewUnauthorizedError`,
  `NewForbiddenError`, `NewNotFoundError`, `NewConflictError`,
  `NewTooManyRequestsError` (+ `...f` variants).
  `NewValidationError([]string)` joins messages into one 400 and returns `nil`
  for an empty slice, so `Validate()` methods can return it unconditionally.
- **Fluent decorators return copies** — `WithError`, `WithDebug`, `WithReason`,
  `WithRetryAfter`. Because they copy, package-level sentinels can be decorated
  at a call site without mutating the shared value.
- **`errors.Is` works across copies**: `Is` compares code + message.
- **Nil-safe accessors**: a nil `*AppError` reports code 500 — no panic paths.
- **Caller-location capture**: the constructor records the first stack frame
  outside the error package, so logs point at the app call site.
- Distinguish "is this the canonical not-found sentinel" from "is this any
  404" with two helpers — domain-specific 404s stay distinguishable.

Propagation across layers:

- entity/service: `return ErrUserNotFound` (sentinels), or wrap context with
  `fmt.Errorf("load profile: %w", err)` — `errors.As` still finds the AppError.
- infra: translate driver errors to canonical ones (`sql.ErrNoRows` → not-found).
- transport: does nothing — the JSON adapter → `WriteAppError` is the only
  mapping point. It also picks the log level: 401/403 at Info, other 4xx at
  Warn, 5xx at Error — routine denials must not bury real faults.
- `panic` only for unrecoverable init (`MustNew` at startup), never for
  business errors. The `Recover` middleware is the backstop, not a control-flow
  mechanism.

Lint the convention: ban legacy error packages and `fmt.Print*` with your
linter config; enforce import grouping; keep `go vet` (or `govet enable-all`)
green.

## 2.7 Configuration

Layered YAML with generics-based parsing:

```go
cfg, err := configx.ParseAndValidate[config.Config]("config.yml,secrets.yml")
```

1. Split the comma-separated file list; later files override earlier (deep
   merge) — `config.yml` holds the committed defaults, an optional overlay
   holds environment specifics.
2. In each file's **raw text**, resolve `${VAR}` placeholders from the
   environment. **An unset placeholder is fatal**, not an empty string —
   `${VAR:-default}` is the explicit opt-out.
3. Apply defaults: every config struct may implement `Default()`; defaults run
   before unmarshal so YAML always wins.
4. Validate with struct tags (`validate:"required,oneof=dev prod"`); parsing
   fails loudly on the first invalid field.

Sharp edges to document for your team:

- Placeholders resolve in raw text, so one inside a YAML *comment* resolves too.
- Quote every placeholder (`'${DB_PASSWORD}'`) or a JSON-shaped credential
  parses as a YAML mapping.
- The committed dev config must contain **no** placeholders — assert it with a
  test that parses the committed file (this test also guarantees `serve` works
  on a fresh clone).
- **The config is never logged**, in full or in part: it holds credentials,
  and a service that prints its configuration at startup puts them in the log
  aggregator. Additionally expose `cfg.Secrets() []string` — the list of
  secret values — and feed it to a response-redaction middleware (§5.5,
  `webapp/5-security.md`).

## 2.8 Startup and shutdown

`main()` calls `run() error`; `run` is the whole lifecycle:

```go
func run() error {
    ctx, stop := signal.NotifyContext(context.Background(), syscall.SIGINT, syscall.SIGTERM)
    defer stop()

    cfg, err := config.Parse(*configPath)
    if err != nil { return err }
    logger := logx.MustNew(cfg.Server.LogLevel)

    db, err := pgx.NewDB(cfg.Postgres)      // + PingContext; defer Close
    if err != nil { return err }

    eg, ctx := errgroup.WithContext(ctx)
    txFactory := pgx.NewTxFactory(db)

    // Per domain, bottom-up: infra → service → handlers.
    userPersistence := userinfra.NewPostgresPersistence(db, logger)
    userService := userservice.NewService(cfg.User, userPersistence, txFactory, logger)
    userHandlers := usertransport.NewHandlers(userService, logger)

    // Cross-domain wiring, then the wiring gate:
    userService.SetWelcomeNotifier(notificationService)
    if err := userService.ValidateWiring(); err != nil { return err }

    handler := httpx.Recover(httpx.SecureHeaders(buildRouter(userHandlers /*...*/)))
    server := &http.Server{
        Addr: cfg.Server.Address, Handler: handler,
        // ReadTimeout stays 0: it bounds the ENTIRE body and would kill slow
        // uploads. Slowloris is ReadHeaderTimeout's job; upload routes set
        // their own body deadlines (webapp/6-performance.md §6.2).
        ReadHeaderTimeout: 15 * time.Second,
        WriteTimeout:      75 * time.Second, // ≥ longest route carve-out (webapp/6-performance.md §6.2)
        IdleTimeout:       60 * time.Second,
    }

    eg.Go(func() error { return userService.Run(ctx) }) // background workers
    eg.Go(func() error {
        if err := server.ListenAndServe(); !errors.Is(err, http.ErrServerClosed) {
            return err // ErrServerClosed is the normal shutdown signal, not a failure
        }
        return nil
    })
    eg.Go(func() error {
        <-ctx.Done()
        // WithoutCancel: the parent is already cancelled; the drain needs its own deadline.
        sctx, cancel := context.WithTimeout(context.WithoutCancel(ctx), 75*time.Second)
        defer cancel()
        return server.Shutdown(sctx)
    })

    if err := eg.Wait(); err != nil && !errors.Is(err, context.Canceled) {
        return err
    }
    return nil
}
```

Rules baked into that shape:

- `signal.NotifyContext` is the root context; **errgroup is the process
  supervisor** — every long-lived goroutine belongs to it, and workers return
  `nil` on cancellation so a normal SIGTERM isn't an error.
- The **drain window equals `WriteTimeout`** — a shorter drain drops exactly
  the requests your slow-route carve-outs promised to allow.
- Metrics are a **separate listener** (`:9090`) with no public route (§5.7,
  `webapp/5-security.md`).

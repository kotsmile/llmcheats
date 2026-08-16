# Web Application Engineering Guide

A reference for building production web applications: a **Go (or Python) backend**
exposing a JSON API, and a **React single-page application** in front of it. Every
pattern in this document is distilled from a running production system — a
multi-domain production API, several small internal consoles, and the SPAs on
top of them. Nothing here is theoretical.

The document is written to be used as a **reference by both humans and LLMs**
when creating a new web application. Follow the structure; deviate only with a
written reason.

---

## Table of contents

1. [System shape](#1-system-shape)
2. [Backend: Domain-Driven Design](#2-backend-domain-driven-design)
3. [Frontend: React SPA](#3-frontend-react-spa)
4. [Testing](#4-testing)
5. [Security](#5-security)
6. [Performance](#6-performance)
7. [Infrastructure](#7-infrastructure)
8. [New-application checklist](#8-new-application-checklist)
9. [AI features](#9-ai-features)

---

# 1. System shape

The reference architecture is deliberately boring:

```
Browser ──▶ Reverse proxy (nginx / caddy / ingress)
              ├── /            → static SPA files (built by Vite)
              ├── /api/*       → backend service
              └── /auth/*      → backend service (auth endpoints, if cookie-based)

Backend ──▶ PostgreSQL   (system of record)
        ──▶ Redis        (counters, pub/sub, caches — optional)
        ──▶ Object store (S3-compatible, for files — optional)
        ──▶ OIDC provider (Keycloak or similar, for staff/console apps — optional)
```

**The one-origin rule.** The SPA and its API share an origin: the reverse proxy
serves the static files and proxies `/api` (and `/auth`) to the backend. The dev
server (Vite) proxies *the same paths* to a local backend. Consequences:

- Session cookies behave identically in dev and prod — no CORS, no
  third-party-cookie problems, no `Access-Control-Allow-Credentials` dance.
- CORS middleware exists only for the exceptional deployment where a second
  origin genuinely must call the API, and it is a strict allowlist, never `*`.

**One binary, subcommands.** The backend ships as a single binary with
subcommands: `serve` runs the HTTP service, `migrate` applies database
migrations and exits. Migrations never run implicitly on service boot
(see §7.4).

**Configuration is a file, secrets are env vars.** The process reads one YAML
config file passed via `--config`. Secrets reach it as `${VAR}` placeholders in
that file, resolved from the environment at parse time. The service itself never
calls `os.Getenv` for its own settings (see §2.7).

---

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
        return ErrUnsupportedMediaType // 415 — also a load-bearing CSRF leg, see §5.7
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
(cookie first, then `Authorization: Bearer` — see §5.1), validates it, and
injects claims into the request context. Route access is expressed as
composable **guards**:

```go
type Guard interface {
    Guard(claims entity.Claims) bool
    String() string // for logs: which guard denied
}

r.Get("/admin/users", auth.Auth(h.ListUsers, ut.AdminGuard))
r.Post("/orders", auth.Auth(h.CreateOrder, ut.UserGuard))
```

Guards (route-level, coarse: "is this class of user allowed here") are a
**different layer** from permissions (`entity.Perm.Check(role)`, operation-level,
checked inside entity/service methods). Both exist; neither substitutes for the
other. See §5.2.

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
- **The config is never logged**, in full or in part: it holds credentials, and
  a service that prints its configuration at startup puts them in the log
  aggregator. Additionally expose `cfg.Secrets() []string` — the list of secret
  values — and feed it to a response-redaction middleware (§5.5).

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
        // their own body deadlines (§6.2).
        ReadHeaderTimeout: 15 * time.Second,
        WriteTimeout:      75 * time.Second, // ≥ the longest route carve-out (§6.2)
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
- Metrics are a **separate listener** (`:9090`) with no public route (§5.7).

## 2.9 The same architecture in Python

The layers translate directly; only the idioms change. Reference stack:
**FastAPI + Pydantic v2 + SQLAlchemy Core (or asyncpg with raw SQL) + Alembic**.

| Concept (Go) | Python equivalent |
|---|---|
| `entity/` package | `entity.py` / `entities/` — frozen dataclasses or plain classes; invariants in `__post_init__`, classmethod constructors (`User.create(email, password)`), mutator methods that raise domain exceptions |
| Value objects | `NewType` + validating factory functions, or small frozen dataclasses; **not** Pydantic models (those belong to transport) |
| Sentinel errors | Exception hierarchy: `class DomainError(Exception)`, `class NotFoundError(DomainError)`, `class ForbiddenError(DomainError)` — with an optional `reason` attribute |
| Port interfaces in `service/` | `typing.Protocol` classes declared in the service module; repositories conform structurally |
| `var _ Port = (*Impl)(nil)` | a unit test asserting `isinstance(impl, PortProtocol)` (with `@runtime_checkable`), or just mypy |
| Constructor DI in `main.go` | explicit constructor wiring in `app.py` / a `build_app()` factory; FastAPI `Depends` only at the transport edge — never inside services |
| `TxFactory.WithTx` | `async with db.begin() as conn:` context manager owned by the service; repositories take the connection as a parameter |
| DTOs + `validate` tags | Pydantic request/response models in the router module — `model_config = ConfigDict(extra="forbid")` is the `DisallowUnknownFields` equivalent; body-size cap at the ASGI server or middleware |
| `JSONFunc` + `WriteAppError` | one exception handler: `app.add_exception_handler(DomainError, to_api_error)` mapping the exception class to a status and the flat `APIError` shape |
| goose migrations | Alembic, plain SQL in migration files where possible; applied by a `migrate` entrypoint/command, never at import time |
| errgroup + graceful shutdown | ASGI lifespan handlers + `asyncio.TaskGroup` for background workers; uvicorn/hypercorn handle SIGTERM draining — configure a drain timeout matching the slowest route |
| `${VAR}` config | one YAML file, same placeholder resolution rule, parsed into a Pydantic Settings-free plain model (avoid implicit env magic — keep the "config is a file, secrets are `${VAR}`" contract) |

The invariant rules do not change: entities validate themselves, services own
transactions and orchestration, repositories are dumb SQL executors conforming
to protocols, routers parse/convert/call-one-service-method/serialize. The
dependency direction is enforced by import-linter (contracts: `transport →
service → entity`, `infra → service, entity`).

---

# 3. Frontend: React SPA

## 3.1 Toolchain

- **Vite** + `@vitejs/plugin-react`, **TypeScript strict**, **Tailwind CSS 4**
  via `@tailwindcss/vite` (CSS-first config: `@theme` / `@source`; no
  `tailwind.config.js`, no `postcss.config.js`).
- `tsconfig`: `strict: true`, plus `noUnusedLocals`, `noUnusedParameters`,
  `noFallthroughCasesInSwitch`. `any` is prohibited — use `unknown` + type
  guards. No suppression comments (`@ts-ignore`, `eslint-disable`): fix the
  root cause.
- Path alias `@/*` → `src/*` (declared in both Vite and tsconfig, kept in sync).
- `build` script is `tsc -b && vite build` — the type check is part of the
  build, not a separate optional step.

**The dev proxy mirrors production paths:**

```ts
export default defineConfig({
  plugins: [react(), tailwindcss()],
  resolve: { alias: { "@": fileURLToPath(new URL("./src", import.meta.url)) } },
  server: {
    proxy: {
      "/api": "http://localhost:8080",
      "/auth": "http://localhost:8080",
    },
  },
});
```

Whatever the production reverse proxy forwards, the dev server forwards the
same — so cookies, redirects and relative URLs behave identically.

**Runtime config over build-time config.** Ship a `public/config.js` containing
`window.__RUNTIME_CONFIG__ = { apiBaseUrl: "" }` and let the deployment overlay
it (a mounted file, a templated asset). Resolution order:

```ts
export const env = {
  apiBaseUrl:
    window.__RUNTIME_CONFIG__?.apiBaseUrl   // deployment-provided — wins
    || import.meta.env.VITE_API_BASE_URL     // build-time fallback (dev)
    || "/api",                               // default: same-origin
};
```

One build artefact then serves every environment.

## 3.2 Feature-Sliced Design (FSD)

Layers, top to bottom — **import only from the same or a lower layer, always
through a slice's public `index.ts`**:

```
src/
  app/        providers (router, query client), global styles, error boundary,
              the API-client side-effect module
  pages/      route-level components; thin — compose widgets/features
  widgets/    self-contained page sections (sidebar, header)
  features/   user-facing capabilities: the real screen bodies — tabs, modals,
              forms — each slice holding its own ui/ + model/ + api/
  entities/   domain types and pure mappers (API row → view row); no components,
              no queries
  shared/     ui/ (design-system primitives), api/ (client), lib/ (utils),
              config/, model/ (app-wide stores)
```

**Scale the layer set to the app.** A large product app uses all six. A small
console legitimately flattens to `app / features / widgets / shared` — screens
live in `widgets/`, API types in `shared/api/types.ts`, and one
`features/queries.ts` holds every query/mutation hook. Do not manufacture empty
layers.

Other conventions: files under ~300 lines; alphabetically sorted imports;
components in `shared/ui/<Component>/` folders with an `index.ts` each and a
barrel `shared/ui/index.ts`.

## 3.3 Routing and guards

Use **React Router v7** (declarative `<Routes>`) for a multi-page app.
Every page is lazy:

```tsx
const AdminPage = lazy(() => import("@/pages/admin"));
// one top-level <Suspense fallback={<Spinner/>}> around <Routes>
```

The auth guard is a wrapper component with an **explicit check order** —
initializing → authenticated → authorized → account-state:

```tsx
function ProtectedRoute({ children, allowedRoles }: Props) {
  const { profile, isInitialized } = useAuth();
  const location = useLocation();

  if (!isInitialized) return <Spinner />;                                    // 1
  if (!profile) return <Navigate to="/signin" state={{ from: location }} replace />; // 2
  if (!allowedRoles.includes(profile.role)) return <Navigate to="/" replace />;      // 3
  if (profile.activated === false) return <InactiveAccountOverlay />;        // 4
  return children;
}
```

Define role lists as named constants — never repeat a role array inline at
each route.

For a tiny console, a hand-rolled router is acceptable and instructive: a
discriminated-union `Route` type + `parseRoute(pathname, search)` /
`routePath(route)`, `useState<Route>` + a `popstate` listener. Two rules from
that pattern generalize to every SPA:

- **The URL is the source of screen state**: every screen's filled-in state
  rides in the query string so any screen is a pasteable link.
- `history.pushState` for navigations, `replaceState` for form-field edits —
  the back button must leave the form, not undo it a keystroke at a time.

Client-side guards are **UX, not security**: the server decides authorization
on every request; a 403 from the "who am I" endpoint renders a dedicated
no-access screen instead of the shell.

## 3.4 Data layer

### API client

Two proven options:

**Generated client (product apps).** Generate a typed fetch client from the
backend's OpenAPI spec (e.g. `@hey-api/openapi-ts`) — read the spec from the
backend's own build output so it cannot drift. Generated code is never
hand-edited. Wrap `fetch` once for auth/refresh (see §3.6).

**Hand-written client (small apps).** ~40 lines is enough:

```ts
export class ApiError extends Error {
  constructor(readonly status: number, message: string) {
    super(message);
    this.name = "ApiError";
  }
}

async function request<T>(url: string, init?: RequestInit): Promise<T> {
  const res = await fetch(url, {
    ...init,
    // Plain-object headers only: spreading a Headers instance yields {}.
    // For FormData uploads use a separate helper — this JSON Content-Type
    // would break the multipart boundary.
    headers: { Accept: "application/json", "Content-Type": "application/json", ...init?.headers },
  });
  // Skip endpoints where 401 is a normal answer (the sign-in call itself),
  // or the login page would redirect to itself.
  if (res.status === 401 && !url.startsWith("/auth/")) {
    const back = window.location.pathname + window.location.search;
    window.location.href = `/login?return=${encodeURIComponent(back)}`;
    throw new ApiError(401, "unauthorized");
  }
  if (res.status === 204) return undefined as T;
  const body = await res.text();
  if (!res.ok) throw new ApiError(res.status, parseError(body) ?? `${url}: ${res.status}`);
  return (body ? JSON.parse(body) : undefined) as T;
}

export const api = {
  me: () => request<Profile>("/api/me"),
  search: (q: string, signal?: AbortSignal) =>       // abortable — the caller is a keystroke
    request<Suggestions>(`/api/search?q=${encodeURIComponent(q)}`, { signal }),
};
```

Always `encodeURIComponent` path/query parameters. Pass `AbortSignal` through
for type-ahead endpoints.

### TanStack Query

Server state lives in **TanStack Query**, never in a client-state store.

**Query keys are centralized.** Use a query-key factory
(`@lukemorales/query-key-factory`) in one module; hooks spread the key object:

```ts
export const staffKeys = createQueryKeys("staff", {
  clients: null,
  userDetail: (userId: string) => [userId],
});
export const queryKeys = mergeQueryKeys(staffKeys, orderKeys /* ... */);

export const useStaffClientsQuery = () =>
  useQuery({
    ...queryKeys.staff.clients,
    queryFn: async () => {
      const { data, error } = await getStaffClients();
      if (error) throw error;
      return data?.data;
    },
  });
```

(For a small app a hand-rolled `keys` object of `as const` tuples is fine —
the point is *one* place that owns key shapes.)

**Mutations invalidate by key**, and after a state-changing decision invalidate
**coarsely by prefix** — the screen that shows the result is usually not the
one the button was on:

```ts
onSuccess: (_data, variables) => {
  // TanStack Query v5: the argument is a FILTERS OBJECT. Always pass
  // { queryKey: [...] } explicitly — passing a bare key array (or a factory
  // object without unwrapping .queryKey) can silently match everything.
  queryClient.invalidateQueries({ queryKey: queryKeys.chat.messages(variables.chatId).queryKey });
  queryClient.invalidateQueries({ queryKey: queryKeys.chat.list.queryKey });
},
```

**Client defaults** — pick per data volatility:

```ts
new QueryClient({
  defaultOptions: { queries: { refetchOnWindowFocus: false, retry: 1 } },
});
```

`staleTime: Infinity` for immutable metadata; ~1 min for normal lists;
per-hook overrides where it matters.

**An audited or side-effectful read is a mutation, not a query.** If a "read"
writes an audit row (revealing a secret, opening a sealed record), model it as
`useMutation` on a POST — React Query must never re-fire it on refocus,
remount, or revalidation, and the result must never enter the query cache.

### One-hook-per-file

In a shared data package: one file per hook (`useStaffClientsQuery.ts`,
`useSendMessageMutation.ts`), grouped in domain folders with barrel exports.
Components never call the API client directly — always through a hook.

## 3.5 Client state: Zustand

Client-only state (theme, current selection, auth status) lives in **Zustand**;
anything fetched from the server does not.

```ts
interface ProfileState {
  profile: Profile | null;
  isSignedOut: boolean;
  setProfile: (profile: Profile | null) => void;
  markSignedOut: () => void;
}

export const useProfileStore = create<ProfileState>()(
  devtools(
    (set) => ({
      profile: null,
      isSignedOut: false,
      setProfile: (profile) => set({ profile, isSignedOut: false }),
      markSignedOut: () => set({ profile: null, isSignedOut: true }),
    }),
    { name: "profile" }
  )
);
```

- Consume with **selectors, one field per call**: `useProfileStore((s) => s.profile)`.
- Persistence via the `persist` middleware for preferences (theme, language).
- **Library stores use the factory pattern**: a shared package must not own a
  module-level singleton — export `createXStore({ deps })` built on vanilla
  `createStore` + `useStore`, re-attaching `getState`/`subscribe` on the
  returned hook so non-React code (the API client's `onUnauthorized` callback)
  can read and act on the store.

## 3.6 Authentication in the SPA

Two models, by audience:

### Cookie session (recommended for browser apps)

The SPA holds **no tokens**. Sign-in sets an HttpOnly, Secure, SameSite=Lax
cookie; every request rides it automatically (same origin). A grep of the
codebase for `localStorage` should find only UI preferences — theme, language,
panel widths — never credentials.

**The 401-refresh flow** is the one subtle piece. Wrap `fetch` once:

1. On 401 (excluding an explicit skip-list of endpoints where 401 is a normal
   answer), call the refresh endpoint.
2. **Collapse concurrent 401s onto one in-flight refresh promise** — an SPA
   firing five requests at once must cost one refresh, not five.
3. The refresh verdict is **three-way**, and the distinction is load-bearing:

```ts
type RefreshResult =
  | { status: "ok" }          // retry the original request
  | { status: "invalid" }     // server said 401/403 → session is dead → sign-out flow
  | { status: "transient" };  // network error / 5xx / timeout → surface the 401, do NOT log out
```

A flaky network must never destroy a valid session. Only an authoritative
"invalid" from the server clears local auth state.

Sign-out order: mark signed out in the store → cancel in-flight queries →
`queryClient.clear()` → fire-and-forget the logout request.

### OIDC via the backend (staff/console apps)

The SPA never talks to the identity provider and never holds a token. The
backend terminates OIDC (§5.1) and sets its own session cookie; the frontend
contributes:

- a `/login` page rendered **before the app shell mounts** (the shell's first
  act is an authenticated call — exactly the one that just bounced);
- sign-in as a plain link to `/auth/login?return=…`, sign-out as a link to
  `/auth/logout`;
- on 401 from the API: redirect to the app's own `/login` page, **not**
  straight into the IdP — an uninterruptible bounce can only ever offer the SSO
  door, and the day the IdP is down is the day you need the other one;
- an open-redirect guard on the `return` parameter:

```ts
function returnPath(): string {
  const raw = new URLSearchParams(window.location.search).get("return") ?? "/";
  return raw.startsWith("/") && !raw.startsWith("//") ? raw : "/";
}
```

## 3.7 Styling and design tokens

- **Tailwind 4, CSS-first.** The app's CSS entry is two imports: `tailwindcss`
  and the design-token theme.
- **Semantic tokens only.** Colors are `--color-background`, `--color-card`,
  `--color-primary`, `--color-destructive`… defined in `@theme` (light) and
  overridden under `.dark`. **Never hardcode hex values or raw palette scales
  in app code.**
- If tokens are shared across platforms, build them from a token source (JSON +
  Style Dictionary) emitting the Tailwind theme, dark/light variable sets, and
  typed JS tokens.
- Theme switching is a `dark`/`light` class on `<html>`, applied by an inline
  pre-React script in `index.html` (reads the persisted preference — no flash
  of wrong theme) and mirrored by a persisted store. In Tailwind 4 the `dark:`
  variant follows `prefers-color-scheme` by default — class-based theming
  needs one line in the CSS entry:
  `@custom-variant dark (&:where(.dark, .dark *));`
- A **small purpose-named type scale** beats a large generic one:
  `--text-row` (list rows, inputs), `--text-meta` (panel titles, qualifiers),
  `--text-caption` (chips, group headings). Name sizes for what they label.
- **Build the component library, not per-app components**: Button, Input,
  Modal, Card, Skeleton, EmptyState… If a primitive is missing, add it to the
  shared library, not to the app.
- If you compose classes with a `cn()` helper, know what yours does: a plain
  join does **not** resolve Tailwind conflicts (that's `tailwind-merge`);
  express overrides as a ternary emitting one class.

## 3.8 Forms

For apps with few forms, `useState` + a typed setter + an errors record is
sufficient and dependency-free:

```tsx
const [form, setForm] = useState<CreateOrderForm>(initialForm);
const [errors, setErrors] = useState<Partial<Record<keyof CreateOrderForm, string>>>({});

const setField = <K extends keyof CreateOrderForm>(key: K, value: CreateOrderForm[K]) => {
  setForm((prev) => ({ ...prev, [key]: value }));
  if (errors[key]) setErrors((prev) => ({ ...prev, [key]: undefined })); // clear on edit
};
```

Validate on submit against named constants (`TITLE_MAX_LENGTH`), mirror the
backend's limits. For form-heavy apps, `react-hook-form` + `zod` is the
standard upgrade path. Either way the backend re-validates everything — client
validation is UX only.

## 3.9 React 19 conventions

- **No manual `useMemo` / `useCallback` / `memo`.** With the React Compiler
  enabled they are noise (React 19 alone does *not* auto-memoize — enable the
  compiler if you want that). Without it, memoization is a measured
  optimization, never a habit: default to none, and when a profiler shows a
  real hot spot, fix the data shape first. Referential stability for effect
  dependencies is a correctness question — restructure the dependency rather
  than memoizing around it.
- `<StrictMode>`, `createRoot`, `React.lazy` + `Suspense` for route splitting,
  a class `ErrorBoundary` at the app root.
- The API-client configuration module is imported **for side effects, first, in
  `main.tsx`** — the client must be configured before the first query fires.
- Server state in TanStack Query, client state in Zustand, and nothing
  duplicated between them.

---

# 4. Testing

## 4.1 Philosophy

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
- Business logic (entity + service) gets the density; transport gets a thinner
  authorization-matrix layer; glue gets none.

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
in ways you designed. Three idioms:

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

---

# 5. Security

## 5.1 Authentication

### First-party JWT (product apps: end-user browser + mobile)

- The API issues its own access + refresh tokens (HMAC-signed JWT is fine for
  a single-service issuer).
- **Browser: HttpOnly cookies. Mobile/CLI: `Authorization: Bearer`.** The
  middleware extracts **cookie first, then header** — one code path, both
  clients.
- The refresh cookie is scoped with `Path=/api/user/refresh` — the path **as
  the browser sends it** (proxy prefix included) — so it rides only to the one
  endpoint that needs it.
- Refresh tokens are **single-use**, tracked by JTI in Redis; account deletion
  and password change revoke all JTIs.
- `AuthOptional` (for public-or-private resources) **fails closed** on a
  present-but-invalid token: only a credential-less request proceeds
  anonymously.

### OIDC via the backend (staff/console apps)

The backend terminates OIDC against the IdP (e.g. Keycloak) and issues its own
session cookie. Hard-won rules:

- **The session cookie is encrypted (AEAD), not merely signed** — it carries
  the refresh token. AES-256-GCM, random nonce per seal, key derived from
  configured secret. HttpOnly + Secure + SameSite=Lax.
- **Version the cookie layout.** Refuse an older version rather than decode it
  with missing fields — a cookie with no roles field would otherwise decode as
  "this user has no roles", indistinguishable from a real answer.
- **Freshness model**: claims copied into the cookie are trusted until the
  access token's expiry, then a refresh grant re-asks the IdP. Distinguish
  three outcomes: grant refused → session dead, back to login; IdP unreachable
  → serve stale claims until absolute expiry with a short retry backoff;
  success → reseal. Collapse concurrent refreshes with singleflight (keyed on
  a digest of the refresh token, on a `WithoutCancel` context so one client's
  hangup doesn't fail the coalesced waiters).
- **Token verification**: JWKS via OIDC discovery; check signature, issuer,
  expiry. If your IdP doesn't reliably populate `aud` for API access tokens,
  verify the authorized-party claim (`azp`) against an explicit client
  allowlist instead — the check moves, it must not disappear. Strip empty
  strings from the allowlist at construction so an unset env var can't become
  a wildcard.
- **OAuth flow hardening**: `state` in an HttpOnly cookie compared against the
  callback query; open-redirect guard on `return` paths (`startsWith("/") &&
  !startsWith("//")`) on both login and callback; logout revokes the refresh
  token at the IdP's end-session endpoint, best-effort, cookie cleared
  regardless.
- **Never fail open.** If auth configuration is missing, refuse to start in
  production. A dev pass-through authenticator (fixed identity + roles) is
  invaluable for tests and local work, but it must be impossible to reach in a
  production build path without an explicit, loud opt-in.

### Machine tokens (service-to-service, CLI)

Format `prefix_<public-id>_<secret>`: 8-byte id + 32-byte `crypto/rand`
secret. Store **plain SHA-256** of the secret — a slow KDF defends
small-keyspace passwords; a 256-bit random secret has nothing to iterate
against. What matters: plaintext never stored, comparison constant-time
(`subtle.ConstantTimeCompare`). Check order is cheapest-first and
fail-early: shape → stored hash → expiry → *only then* any upstream identity
resolution, so unauthenticated garbage never reaches your IdP.

## 5.2 Authorization

Layered, from coarse to fine:

1. **Route-level role gate** (middleware): "may this class of user enter this
   door at all". Answers **403, never a redirect** — redirecting an
   authenticated-but-unauthorized user to login is an infinite loop with a
   friendly face. Stack it inside the auth middleware so a misordered route
   denies everyone — the safe direction for a wiring mistake.
2. **Resource-level decision in the service**, against ownership/delegation
   data, in **one place** (`mustSee` / `mustAdminister` helpers). The service
   is what fetches — a route added tomorrow that forgets to ask returns
   nothing, not everything. Router-level "GET is read, POST is write" is not
   sufficient when a POST can be semantically a read (see audited reads).
3. **Operation-level permission checks in entities** (`actor.CheckPerm(...)`),
   for rules that depend on both actor and target state.
4. **Field-level response filtering** by viewer role (§2.5).

Patterns that generalize:

- **Roles as structured strings** `<system>:<selector>:<access>` — parse them
  into a typed `Actor` **once at the transport boundary**; keep derived fields
  unexported ("a field anybody could set is a field somebody eventually sets
  from a request"). The decision is an ordered comparison of access levels
  (`none < read < write`), taking the maximum over matching grants.
- **Group hierarchies: expand the caller's side, not the grant's.** If a grant
  on a parent group must cover subgroups, expand the *user's* group list into
  its ancestor paths, then match with exact string equality — which stays
  indexable in SQL (`subject = any($1)`), where a prefix-match would be
  neither indexable nor honest.
- **Authorization-relevant filters live in SQL**, not Go: an expired grant
  must not reach the decision at all — a filter the caller can forget is a
  filter somebody eventually forgets.
- For an approval/change-management system: keep the policy **in a reviewed
  file in version control, not a database table** the system itself can edit.
  Embed a default so a failed config mount can't silently degrade; refuse a
  policy that renders any request kind unapprovable; when a template
  placeholder has nothing to fill it, **drop the rule rather than widen it**.

## 5.3 Input validation

Defense in depth, three gates:

1. **Transport**: one `ReadJSON` chokepoint — body-size cap (1MB default),
   `DisallowUnknownFields`, single-JSON-value check, struct-tag validation
   (§2.5). Set a smaller cap where the domain justifies it.
2. **Entity**: value-object constructors re-validate domain rules.
3. **Any tool/automation input** (LLM function calls, webhook payloads): its
   own explicit parser with enum and bounds checks. Never trust structured
   input because a schema was published.

## 5.4 SQL injection

**100% parameterized queries — no exceptions, enforced by review and grep.**
No SQL built with string formatting anywhere in the codebase. The two idioms:

- Positional placeholders `$1..$n`; variable-length IN-lists stay
  parameterized via array binding: `where subject = any($1)` with
  `pq.Array(values)`.
- Named parameters bound from tagged structs for wide INSERT/UPDATE.

Query text is `const`. `LIKE`/`ILIKE` user input goes through an escape helper
for `%`/`_`.

## 5.5 Secrets

- **Delivery**: secret manager → deployment secret → env var → `${VAR}` in the
  config file. The app never fetches secrets itself and never reads env vars
  directly (§2.7).
- **Never log the config.** Also: expose the list of secret *values* to a
  response-redaction middleware that replaces any occurrence in a JSON
  response with `[REDACTED]` — with a minimum-length floor (~12 chars) so a
  dev default like `postgres` doesn't shred responses. Skip it for streaming
  routes.
- **Encryption at rest** for sensitive user content (private chat, health
  data): AES-256-GCM, random nonce per message stored beside the ciphertext,
  AEAD tag as tamper detection. One shared cipher instance for the domain so
  key rotation touches one place. Validate key length at startup
  (16/24/32 bytes), not first use.
- Secret-bearing responses set `Cache-Control: no-store, max-age=0`.
- On the client: revealed secret values live in component state and die with
  it — never in the query cache, never in any storage (§3.4).

## 5.6 Audit logging

For any system that manages access, money, or secrets:

- **Append-only by construction, not convention**: the repository type has no
  update and no delete method. "An audit log with an update path is one whose
  contents are an opinion." Retention is a scheduled age-based DELETE at the
  ops layer, not a code path the type exposes.
- **Audit reads, not just writes** — for sensitive material the question is
  "who looked at this", far more often than "who changed it".
- **Audit before disclosure, and a failed audit write fails the action**: the
  audit row is written before the sensitive payload is fetched; a disclosure
  nobody can attribute is worse than one that did not happen.
- Record **what** was touched (resource, keys, a structural diff of
  operations), never the payload values.
- Model audited reads as POST so a page refresh doesn't replay them.
- Cap and filter audit feeds **in SQL** so the limit counts rows the caller
  actually receives.
- Prefer auth mechanisms that put a **person's** name in the log even for CLI
  access (device-grant tokens over shared bot credentials).

## 5.7 HTTP hardening

Headers (one middleware, outermost after Recover):

```
X-Frame-Options: DENY
X-Content-Type-Options: nosniff
Strict-Transport-Security: max-age=31536000; includeSubDomains
Referrer-Policy: no-referrer        ← mandatory if any URL ever carries a token
Cross-Origin-Opener-Policy: same-origin
X-Permitted-Cross-Domain-Policies: none
```

Add a **Content-Security-Policy** for the SPA at the reverse proxy (the layer
that serves the HTML): `default-src 'self'` plus what the app genuinely needs.

**CORS**: only when a second origin is real; strict allowlist map; echo the
matched origin, never `*` with credentials.

**CSRF stance** for a cookie-authenticated SPA — structural, and every leg
matters:

- same origin (proxy), so no cross-origin XHR reaches the API with cookies;
- `SameSite=Lax` on every cookie;
- all state-changing routes are non-GET, and the backend **rejects any
  request whose `Content-Type` is not `application/json` (415, enforced in
  `ReadJSON` — §2.5)**. This leg only holds if it is enforced: without the
  415, a cross-site `<form enctype="text/plain">` posts without any preflight
  and can be shaped into valid JSON. With it, a cross-site sender must use
  JSON — which is not a "simple request", so it gets preflighted and blocked;
- checking `Origin` / `Sec-Fetch-Site` in middleware is a cheap additional
  leg worth adding;
- **therefore: never make a GET route state-changing.** `SameSite=Lax` still
  sends cookies on top-level cross-site GET navigations — a state-changing GET
  is your CSRF hole. Audit for it explicitly.
- `SameSite` is a cross-*site* control, not cross-origin: a sibling subdomain
  is same-site — never host untrusted content on one.
- Bearer-token clients (mobile, CLI) are outside CSRF entirely.

If any leg doesn't hold (cross-site deployment, form posts), add CSRF tokens.

**Rate limiting**: at minimum, targeted counters on abuse-prone auth paths —
login attempts per account, code attempts, email sends per hour, resend
cooldowns — atomic INCR+EXPIRE in Redis (Lua or pipeline). Keyed by
account/email (credential-stuffing resistance); volumetric per-IP limiting
belongs at the ingress/proxy layer. Return 429 with `retry_after`. A
break-glass local-admin door gets a per-address lockout.

**Panics**: `Recover` middleware logs the stack and returns a generic 500 —
the panic message never reaches the client. Debug detail in error responses
(cause, location) is gated on an explicit per-session debug flag for staff.

**`/metrics` and health endpoints** live on a separate listener/port with no
public route.

## 5.8 Frontend security

- **No tokens in JS-readable storage.** HttpOnly cookies only.
  `localStorage` is for theme and language.
- React's default escaping; **no `dangerouslySetInnerHTML`** (if you must
  render rich text, sanitize server-side and isolate the surface).
- `encodeURIComponent` every interpolated URL parameter.
- Client-side route guards are UX; the server is the authority (§3.3).
- For the API, keep JSON as JSON — HTML-escaping inside JSON is not an XSS
  control; the controls are `nosniff`, correct `Content-Type`, and CSP.
- Server-side field filtering (§2.5) is the real "don't ship data the viewer
  shouldn't see" control for data-heavy UIs.

---

# 6. Performance

## 6.1 Database

**Connection pool** — one shared helper with deliberate bounds:

```go
db.SetMaxOpenConns(cfg.MaxConns)
db.SetMaxIdleConns(cfg.MaxConns / 2)
db.SetConnMaxLifetime(30 * time.Minute)
db.SetConnMaxIdleTime(5 * time.Minute)
```

Bounded lifetime/idle-time matters behind managed poolers that recycle
connections; the `BEGIN` retry (§2.4) absorbs the recycling moment.

**Indexes**: composite, ordered to match the query — a feed reading
`order by at desc, id desc` gets `(resource, at desc, id desc)` (the
tiebreaker column belongs in the index too); a uniqueness rule
gets a unique index that also backs the upsert. Every index has a written
justification; FK columns you join on get one (Postgres won't).

**N+1 avoidance** — set-based queries are the default:

- "Everything this subject can see" is **one** query with
  `subject = any($1)` over the expanded subject list — never a query per group.
- Its counterpart: the single-resource authorization read is a deliberately
  narrow query on the exact composite index, not "list everything and filter".
- Join in SQL or fetch two sets and join in a map in Go — never loop-and-query.
- "Least-loaded assignee" is one `LEFT JOIN … GROUP BY … ORDER BY COUNT` —
  not a fan-out.

**Work queues in Postgres**: `FOR UPDATE SKIP LOCKED` for multi-replica job
claiming — every replica ticks, the claim query stops duplicate processing.
One job per claim keeps lock scopes small.

**Caps everywhere**: every list endpoint clamps `limit` server-side.

## 6.2 HTTP deadlines: the budget system

Deadlines are a **budget hierarchy**, each level justified:

| Level | Value | Why |
|---|---|---|
| Handler default | **10s** (timeout middleware, cancels `r.Context()`) | the request/response norm |
| Named slow routes | 45–60s per route-group carve-out | uploads, synchronous AI calls — each with a written reason |
| Streaming routes | none (outside the timeout group) | a buffering timeout handler breaks streaming. `WriteTimeout` still applies to any **non-hijacked** stream (SSE, long downloads) — extend the deadline per write with `http.NewResponseController(w).SetWriteDeadline`, or serve streams from a second `http.Server` with `WriteTimeout: 0`; hijacked websockets are exempt |
| `WriteTimeout` | ≥ longest carve-out (75s) | a socket deadline below a handler deadline closes the connection mid-handler and the proxy reports 502 |
| `ReadHeaderTimeout` / `IdleTimeout` | 15s / 60s | Slowloris and keep-alive hygiene. `ReadTimeout` stays **0** — it bounds header *plus entire body*, so 15s would kill the 45–60s uploads regardless of the handler carve-out; upload routes set per-request body deadlines via `http.NewResponseController(w).SetReadDeadline` |
| Shutdown drain | = `WriteTimeout` | a shorter drain drops the requests the carve-outs allow |
| Outbound calls | explicit `context.WithTimeout` ~10s + `io.LimitReader` on response bodies | no unbounded dependency |

The trap the budget prevents: a handler that finishes its externally slow work
just under the deadline, then opens a trailing transaction on an
already-cancelled context — failing with a 500 the client retries into
duplicates. Set the carve-out for the *whole* handler, not the slow call.

At minimum set `ReadHeaderTimeout` (Slowloris) on every server, including
internal ones — and give internal services real write/idle timeouts and
per-request deadlines too; "internal" is not a deadline exemption when it
calls cloud APIs that hang.

## 6.3 Concurrency

- **errgroup as process supervisor** (§2.8) and as a fan-out primitive for
  parallel independent work (calling three providers, composing panels).
- **Cross-replica distribution is the database** (`SKIP LOCKED`), not an
  in-process queue — replicas then need no coordination.
- `context.WithoutCancel` for work that must outlive its trigger: post-commit
  hooks, shutdown drains, coalesced refreshes — always with its own timeout.
- **singleflight** for stampede-prone lookups (session refresh, identity
  resolution): five concurrent requests must cost one upstream call.
- **Bounded in-process caches**: mutex + map, keyed by digest, entries expiring
  with the data they mirror, swept on write. A polling caller should cost one
  upstream round trip per TTL, not per request.
- Never a bare `go func()` in request paths: panic-recovering spawn helper or
  a bounded pool that reports "busy".

## 6.4 Caching

- **Redis** for: auth counters, single-use token registries, pub/sub across
  replicas, expensive-to-recompute catalogs.
- **Derive TTLs from upstream expiry**: cache a signed URL for **half** its
  validity window so eviction always precedes expiry, and treat a hit whose
  remaining validity is under a threshold as a miss ("never hand out a URL
  that may die mid-use"). Emit cache refresh reasons (`miss` / `near_expiry`)
  as metric labels.
- **Don't cache**: high-cardinality cheap queries (search results), and
  **never** revealed secrets — on either side of the wire.
- Frontend caching is TanStack Query's `staleTime` tiers (§3.4).

## 6.5 Frontend

- **Lazy-load every route** (product apps). A small internal console may ship
  one bundle but should split its *login* entry so the sign-in screen needs no
  session and fires no query.
- Pin one React version across the workspace (`resolutions`/`overrides`) and
  `dedupe` react/react-dom in Vite — duplicate React is a correctness bug that
  presents as a perf bug.
- `refetchOnWindowFocus: false`, `retry: 1` as defaults; `staleTime` by
  volatility; mutation → targeted invalidation, not refetch-all.
- No hand memoization (§3.9); if lists get large, virtualize; fix data shape
  before adding `memo`.

---

# 7. Infrastructure

The application must not care how it is run. **systemd on a VM, Docker
Compose, Kubernetes, a PaaS — all are equally valid runtimes**; choose by
team size and operational maturity, not fashion. Everything below is written
to hold under any of them.

## 7.1 The contract between app and runtime

Whatever runs the app provides exactly four things:

1. **Env vars** holding secrets (referenced as `${VAR}` in the config file).
2. **A config file** (baked default + optional mounted/overlaid environment file).
3. **A network** to Postgres/Redis/object store and an ingress for HTTP.
4. **SIGTERM with a grace period** ≥ the app's drain window.

The app in turn guarantees: it boots read-only (no writes outside its data
stores), listens on configured addresses, exposes `/health`, drains on
SIGTERM, and logs structured lines to stdout. That contract is the whole
portability story — it is why the same binary runs under systemd
(`EnvironmentFile=` + `ExecStart=app serve --config /etc/app/config.yml`),
Compose (env + mounted config), or Kubernetes (Secret → env, ConfigMap →
mount) without a code change.

## 7.2 Build and ship

- **Static binaries** (Go: `CGO_ENABLED=0`) run anywhere — alpine, debian,
  scratch, a bare VM.
- Multi-stage Dockerfiles: deps layer (dependency download, cached) → build
  layer → minimal runtime stage copying artefacts only. Build tooling never
  ships in the runtime image.
- One image per service; the migrate entrypoint is the same binary
  (subcommand), so shipping one artefact ships both.
- SPA: build once; environment specifics arrive at runtime via the overlaid
  `config.js` (§3.1) — **one artefact serves every environment**.
- Daemonless builders (kaniko/buildah) if CI runners are unprivileged;
  describe the image declaratively enough that swapping builders is a CI
  change, not a per-project change.

## 7.3 Reverse proxy topology

One proxy in front (§1): nginx/caddy as a systemd service, a Compose sidecar,
or an Ingress — same three rules everywhere:

- static SPA files with long-cache hashed assets and no-cache `index.html` +
  `config.js`;
- `/api` (and `/auth`) proxied to the backend; websocket upgrade where needed;
- CSP and any additional headers for the HTML at this layer.

TLS terminates here (certbot/ACME on a VM, cert-manager or LB certs on k8s).

## 7.4 Migrations in deployment

The migrate step runs **before** the new code serves, as its own step:

- systemd: `ExecStartPre=app migrate --config …` (or a deploy-script step)
- Compose: a one-shot `migrate` service the app `depends_on`
- Kubernetes: an init container or a pre-sync hook Job

The app never migrates on serve-boot: N replicas racing DDL is a failure mode
you simply delete by keeping the step separate. Consequence discipline:
migrations are **backward compatible one release back** (the old code runs
against the new schema during rollout) — expand → migrate → contract.

## 7.5 Secrets in deployment

The pattern is runtime-agnostic: **secret store → runtime secret → env var →
`${VAR}` in config**.

- systemd: `EnvironmentFile=/etc/app/secrets.env` (root-owned, 0600)
- Compose: env file or Docker secrets
- Kubernetes: Secret (ideally synced from a cloud secret manager by an
  operator such as External Secrets) → `envFrom`

One flat secret map per app+environment (`myapp-prod`). Never bake secrets
into images or commit them to the repo; changes to a secret are audited in
the secret store, not in git.

## 7.6 Observability

- **Structured JSON logs to stdout**; the runtime ships them (journald,
  logging driver, log agent). Request logs carry method, route *pattern* (not
  raw path — cardinality), status, duration, and a request/user correlation
  field. Log levels carry meaning: 401/403 Info, 4xx Warn, 5xx Error.
- **Prometheus metrics** on a separate private port: RED metrics per route
  pattern from middleware, plus domain gauges/counters owned by services.
  Any scraper (Prometheus, agent, cloud collector) works — the app only
  exposes the endpoint.
- **Health**: `/health` for liveness/monitoring, checked by systemd watchdog,
  compose healthcheck, or probes alike. Readiness (where supported) gates on
  dependencies.
- Dashboards/alerts as code in the repo, whatever the toolchain — click-ops
  drifts and dies.

## 7.7 CI/CD principles

- One pipeline per change: checks gated on changed paths; shared-library
  changes re-run dependents.
- **Releases are tags**; the version is stamped into the artefact at build
  time from the tag (`-ldflags "-X main.version=…"`). Artefacts are
  **immutable**: a re-upload of identical bytes is a no-op, different bytes
  under the same version are refused — a fix is a new tag.
- Deploy = update the desired version somewhere declarative (a values file in
  git for GitOps; a systemd unit env + restart via a deploy script; a compose
  file bump). GitOps (Argo CD/Flux) is an excellent pattern for k8s shops —
  the audit trail is git history — but a reviewed deploy script on a VM
  satisfies the same principle: **the deployed state is written down, diffable,
  and rolled back by reverting**.
- Production deploys gate on a manual approval; test deploys are automatic.
- CI secrets are protected variables scoped to protected branches/tags — MR
  pipelines from arbitrary branches never see them.
- Make MR check jobs interruptible (a re-push cancels the stale run); never
  make a deploy job interruptible.
- Measure before caching in CI: a package-manager store cache whose
  restore+archive costs more than the build it saves is a net loss —
  measure the archive step, cache coarse artefacts, or don't.

---

# 8. New-application checklist

**Backend**
- [ ] `cmd/<app>/main.go` with `run() error`, `serve`/`migrate` subcommands
- [ ] Domain packages: `entity/`, `service/`, `infra/`, `transport/http/`
- [ ] Value objects with validating constructors; invariants in entity methods
- [ ] Ports declared in `service`, implemented in `infra`, with `var _ Port = (*Impl)(nil)`
- [ ] `TxFactory.WithTx`; explicit `tx` params; mutate → commit → side effects
- [ ] Typed errors (status-carrying or sentinels+switch); unknown error → opaque 500
- [ ] `ReadJSON` hardening: media-type check (415), size cap (413), unknown fields, trailing garbage, struct validation
- [ ] Middleware order: Recover → SecureHeaders → logging/metrics → timeout groups → per-route auth
- [ ] 10s default deadline; carve-outs justified; streaming outside the timeout group
- [ ] `WriteTimeout` ≥ longest carve-out; drain window = `WriteTimeout`
- [ ] SQL: const query strings, parameterized only, array binding for IN-lists
- [ ] Migrations: SQL files, embedded, applied by `migrate` step pre-deploy, expand→contract
- [ ] Config: one YAML, `${VAR}` secrets, fatal on unset, `Default()` + validation, never logged
- [ ] Config-parses test + secrets-via-placeholders test
- [ ] Metrics on a separate listener; `/health`

**Frontend**
- [ ] Vite + TS strict + Tailwind 4; `tsc -b && vite build`
- [ ] Dev proxy mirrors production proxy paths
- [ ] `window.__RUNTIME_CONFIG__` runtime config
- [ ] FSD layers scaled to app size; imports through slice `index.ts`
- [ ] Lazy routes; guard component with init→authn→authz→state order
- [ ] TanStack Query + central query keys; mutations invalidate by key
- [ ] Audited/side-effectful reads as mutations; sensitive values never cached
- [ ] Zustand for client state only; selector-based consumption
- [ ] Cookie auth: no tokens in storage; three-way refresh verdict; single in-flight refresh
- [ ] Semantic design tokens; dark/light via `<html>` class + pre-React inline script
- [ ] No manual memoization; no `any`; no suppression comments

**Security**
- [ ] HttpOnly + Secure + SameSite=Lax on every cookie; refresh cookie path-scoped
- [ ] No state-changing GET routes (audit explicitly)
- [ ] Backend rejects non-JSON `Content-Type` on JSON routes (415 — the CSRF leg)
- [ ] Security headers middleware + CSP at the proxy
- [ ] AuthZ: route gates (403, no redirect) + service-level resource checks + entity perms
- [ ] Auth-path rate limiting (per-account counters, 429 + retry_after)
- [ ] Secrets: manager → env → `${VAR}`; response redaction; `no-store` on secret responses
- [ ] AES-GCM for sensitive data at rest; key length validated at startup
- [ ] Audit log append-only by construction; audit-before-disclosure where relevant
- [ ] Never fail open on missing auth config

**Testing**
- [ ] Each non-trivial test states its reason; AAA comments
- [ ] Hand-written fakes (nil-embedded interfaces); no mock frameworks
- [ ] DB tests env-gated/build-tagged, each justified ("worth a database because…")
- [ ] Handler tests: real router + dev-mode auth + fake stores; assert the authz matrix
- [ ] E2E: composed stack, public client, golden paths, own CI job
- [ ] Frontend logic in pure modules, tested with the platform's plain runner

**Infrastructure**
- [ ] Runtime-agnostic contract: env + config file + network + SIGTERM
- [ ] Static binary, multi-stage image, one artefact per service
- [ ] Migrations as a distinct pre-serve step in whatever runs it
- [ ] Structured logs to stdout; metrics scraped privately; health endpoints
- [ ] Releases are immutable tagged artefacts; deployed state is declarative and diffable

**AI (only if the product has LLM features — see §9)**
- [ ] Prompts live in code, reviewed; stable prefix ordered for caching
- [ ] LLM provider behind a service port; hand-written fakes for tests
- [ ] Tool executors validate arguments + authz like a public endpoint
- [ ] Conversations encrypted at rest, access audited, never plaintext in logs
- [ ] Level-1 deterministic tests blocking in CI; Level-2 scenario evals recorded
- [ ] LLM calls under justified deadline carve-outs; post-LLM writes survive cancellation

---

# 9. AI features

LLM functionality is a feature like any other: it lives inside the same
layered architecture, passes the same gates, and its inputs are as untrusted
as any other user input. What changes is where the risks concentrate.

**Where things live:**

- **Prompts are code.** System prompts, persona definitions, and routing
  instructions live in the AI domain's `service/` layer (e.g. `prompt.go` or
  a `prompt/` subpackage) — versioned, reviewed, diffable. Never in a
  database or an admin panel, where they drift unreviewed. Keep the static
  part first and stable: provider prompt caching keys on the prefix, and
  reordering it silently destroys the hit rate.
- **The LLM provider is a port**: declared as an interface in `service/`,
  implemented in `infra/` (one package per provider). Business logic is then
  testable with hand-written fakes (§4.3) — no network, deterministic
  responses, scriptable tool calls.
- **Tool/function-call executors are a transport layer for an untrusted
  client.** The model is a client: every argument is validated server-side
  (bounds, enums, authz for the acting user) exactly like a public endpoint
  (§5.3), and a tool call must never authorize more than the user could do
  directly. Retrieved or user-supplied content entering the context is data,
  not instructions — delimit it explicitly.
- **Conversation data is sensitive by default**: encrypted at rest (§5.5),
  access audited (§5.6), never plaintext in logs or traces.

**Deadlines and side effects:** a synchronous LLM round gets a justified
carve-out in the timeout budget (§6.2); streaming responses run outside the
timeout group. The trailing database write after a slow LLM call runs on a
context that survives cancellation (`context.WithoutCancel` + its own short
timeout, §6.3) — otherwise the write fails on the already-cancelled request
context and the client retries the whole generation into duplicates.

**Safety is layered**: deterministic pre-LLM input gates (pattern or
classifier checks that cannot be talked out of), prompt-level constraints,
and output-side checks where stakes demand them. Never rely on the prompt
alone for a hard constraint.

**Evaluation is two-level** (the AI layer's regression suite):

- **Level 1 — deterministic unit tests**, blocking in CI: safety filters,
  tool-argument parsers, prompt assembly (right blocks, right order), context
  budgeting.
- **Level 2 — a scenario corpus** (YAML, versioned next to the code) judged
  against a rubric per dimension — routing, persona boundaries, safety,
  tool-use triggers. Add a scenario for every production incident before
  fixing it. See the `ai-engineer` agent for the full methodology.

**Cost is an engineering budget**: tier models by task (cheap models for
classification and extraction, strong models for generation and judgment),
measure tokens/cost/latency per conversation with an LLM tracing tool, and
treat every token of system prompt as multiplied by daily request volume.

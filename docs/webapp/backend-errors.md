---
title: Error handling — the status-carrying AppError
summary: One immutable error type carries HTTP status, a safe message, internal debug detail and a machine-readable reason, and is mapped to a response in exactly one place.
keywords: [AppError, error handling, HTTP status, sentinel, errors.Is, WithDebug, WithReason, retry_after, panic, recover, log level, lint]
related:
  - webapp/backend-entities.md
  - webapp/backend-transport.md
  - webapp/security-http-hardening.md
---

# Error handling — the status-carrying AppError

## The status-carrying AppError

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

## Constructing and decorating errors

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

## Propagating errors across layers

- entity/service: `return ErrUserNotFound` (sentinels), or wrap context with
  `fmt.Errorf("load profile: %w", err)` — `errors.As` still finds the AppError.
- infra: translate driver errors to canonical ones (`sql.ErrNoRows` → not-found).
- transport: does nothing — the JSON adapter → `WriteAppError` is the only
  mapping point. It also picks the log level: 401/403 at Info, other 4xx at
  Warn, 5xx at Error — routine denials must not bury real faults.
- `panic` only for unrecoverable init (`MustNew` at startup), never for
  business errors. The `Recover` middleware is the backstop, not a control-flow
  mechanism.

## Linting the error convention

Ban legacy error packages and `fmt.Print*` with your linter config; enforce
import grouping; keep `go vet` (or `govet enable-all`) green.

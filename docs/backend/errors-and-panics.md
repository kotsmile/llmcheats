---
title: Error construction, sentinel errors and the panic policy
summary: How errors carry HTTP status and internal detail, where sentinel errors live, and which failures are deliberately swallowed.
theme: backend
keywords: [AppError, HTTP status, WithDebug, WithError, IsNotFound, sentinel error, var block, zero value, panic, MustNew, best-effort, error wrapping]
related:
  - backend/layered-architecture.md
  - backend/http-endpoints-and-middleware.md
---

## The error type

Return an application error type carrying an HTTP status code, built by a constructor per status:

```go
NewBadRequestError(msg)
NewForbiddenError(msg)
```

Chain context onto it:

```go
err.WithDebug("reason")   // internal detail — surfaced only to staff/test users
err.WithError(cause)      // wrap an underlying error
```

Check not-found through the library's predicate rather than comparing values.

## Always return a zero value with the error

```go
return entity.User{}, err
```

Never return a partially populated entity alongside an error.

## Sentinel errors

Group all sentinel errors in a **single `var ()` block per file**. Keep short ones on one line. Use a generic user-facing message and put the internal detail behind the debug channel:

```go
var (
	ErrAccountNotActivated   = NewForbiddenError("forbidden").WithDebug("account not activated")
	ErrInviteAlreadyAccepted = NewBadRequestError("invite already accepted")
)
```

Placement: a new sentinel goes in the file that owns the failing operation, inside that file's existing `var (...)` block. Do not open a second block.

## Translating persistence errors

In a service method:

- not-found → return a domain sentinel;
- everything else → `fmt.Errorf("...: %w", err)`.

## Panic policy

**Never panic for a business error.** Panic is reserved for unrecoverable initialization failures — the `MustNew` pattern at wiring time.

## Deliberately best-effort paths

Some failures are logged and swallowed because failing the caller would be worse than the missed side effect. These are documented at the callsite and must not be "fixed" into hard failures:

- Auto-allocation of a staff member on a state transition — must not fail the transaction when no eligible staff exists.
- Enqueuing follow-up background work after a profile save — the profile is already committed; a 5xx caused by a downstream hiccup breaks the user experience, and the worker picks the job up on its next tick.

The shape is always the same: the durable write is synchronous and idempotent, the immediate trigger is asynchronous and detached from the request context.

## After a mutation

Log and increment a metric:

```go
s.logger.Info(...)
s.metric.X.Inc()
```

## Do not log secrets

A redacting `String()` protects only the default path — the plaintext accessor does not. Log identifiers, never credential-bearing value objects.

---
title: HTTP handlers, middleware order and request deadlines
summary: The handler contract and response envelopes, the middleware chain, and the timeout group that streaming routes must stay out of.
theme: backend
keywords: [handler, JSONFunc, response envelope, APIData, APIError, middleware order, recover, secure headers, CORS, timeout group, WriteTimeout, TimeoutHandler, streaming, SSE, metrics cardinality]
related:
  - backend/layered-architecture.md
  - backend/authorization-model.md
  - backend/websocket-hub.md
  - backend/code-generation.md
---

## Handler contract

Handlers return `(ResponseType, error)` and are wrapped by a JSON helper that serializes both:

```go
r.Post("/path", JSONFunc(h.Handler))
r.Post("/path", Auth(JSONFunc(h.Handler), guard))
```

| Outcome | Envelope                              |
| ------- | ------------------------------------- |
| Success | `APIData[T]{Data: T, Code: "200"}`    |
| Error   | `APIError{Error: "msg", Code: "400"}` |

Debug mode — enabled for elevated roles via context — adds extended error info to the response.

## One handler = one service call

A handler must **not** orchestrate multiple service calls. If validation is a mandatory step before processing, combine it into a single service method: the service owns its invariants.

## Adding an endpoint

1. Define request/response structs in transport with json, validation and example tags.
2. Add the API-doc annotations (summary, tags, params, success, failure).
3. Implement the handler returning `(Response, error)`.
4. Register the route in `main`.
5. Regenerate the API documentation.

When a new sentinel error becomes user-facing, add a failure annotation to the handler that returns it.

## Middleware order

```
Recover
  → SecureHeaders
    → router (CORS → Logging → metrics)
      → per-group (RedactSecrets, Timeout)
        → Auth (per-route)
```

The API-docs UI is protected with basic auth.

## Request deadlines — the critical rule

The server's write timeout (15s) protects against slow clients but **not** against a hanging handler with a slow database: it is a deadline on socket write, not on `ServeHTTP`.

The main request-response group wraps its routes in a **10s** context timeout. Downstream database and outbound HTTP calls then observe `ctx.Done()` and fail with a deadline error.

Sibling groups raise the deadline for specific routes, each justified in a comment above its group:

| Group                                          | Deadline |
| ---------------------------------------------- | -------- |
| Main request-response                          | 10s      |
| Synchronous model inference, third-party fetch | 45s      |
| Long interactive replies                       | 60s      |

## Streaming routes live outside the group

**Register SSE, WebSocket and any hijacked connection on the parent router, outside the timeout group.** The standard timeout handler buffers the response and force-closes the upgrade when the deadline fires — fatal for a long-lived connection.

The handler must additionally clear the write deadline, or the server's own write timeout tears the stream.

When adding a legitimately long endpoint (>10s): either speed it up, or move it to a separate group with a custom timeout and a comment saying why.

## Auth context

The auth middleware injects the caller's id and role into the request context; transport-level accessors read them back. The debug flag is derived from the role and set on the context by the same middleware.

## Metrics

The metric prefix is attached by the registry at wiring time.

**Never add a per-user label** — cardinality explodes.

Existing label sets are load-bearing: dashboards and alerts hardcode the current values. Changing one needs discussion, not a refactor.

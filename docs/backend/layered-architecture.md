---
title: Layered domain architecture for the Go service
summary: The four-layer split every backend domain follows, how dependencies are injected, and the naming rules enforced in review.
theme: backend
keywords: [clean architecture, DDD, entity, service, infra, transport, ports, dependency injection, value object, transaction factory, comparable, service file scope, naming]
related:
  - backend/errors-and-panics.md
  - backend/http-endpoints-and-middleware.md
  - backend/go-shared-library-layout.md
---

## Stack

Go REST API on a lightweight router, clean architecture with domain-driven design. PostgreSQL through a thin SQL mapper (raw SQL, no ORM), Redis, structured logging.

## The four layers

Each domain directory is split:

```
entity/     → types and value objects
service/    → business logic + the interfaces it depends on
infra/      → implementations of those interfaces
transport/  → HTTP handlers
```

Shared utilities and third-party API clients live in a repo-level shared library directory, not inside a domain. Entry point and DI wiring is the service's `main`.

## Where a third-party client goes

HTTP clients for external services belong in the shared library, **not** in a domain's `infra/`. The `infra/` layer is only for implementations of that domain's own service interfaces (postgres, redis, in-memory).

Each client package defines its own `Config` struct alongside the client. Do not add third-party service configs to the central config struct.

## Interface-based DI

Services depend on interfaces **defined in the service package** and implemented in the infra package. Pin the implementation with a compile-time assertion:

```go
var _ service.Persistence = (*PostgresPersistence)(nil)
```

Grepping for `var _ ` in a domain lists its port implementations.

## Minimal dependencies

Services receive only what they need. Pass a specific value (`signingSecret string`) instead of an entire config struct when the service uses a subset of its fields.

## Optional ports use setters

Where two domains would otherwise import each other, the optional port is wired **after** the constructor:

```go
func (s *Service) SetCheckInEnsurer(e CheckInEnsurer)
func (s *Service) SetJobEnqueuer(e JobEnqueuer)
```

This breaks import cycles and allows graceful degradation: when a feature is disabled in config, its service is never built and the setter is never called.

**Every callsite must keep its `if s.X != nil` guard.** Tests run with partial DI, and a disabled-feature deployment is a real configuration.

## Value objects

Strong typing for domain concepts, each with a `FromString()` constructor that validates and a `String()` method.

- A value object used as a map key must stay **comparable** — every field a value type (`string`, not `*string`).
- A secret-bearing value object's `String()` returns a redacted constant; a separate accessor exposes the plaintext, used only on the hashing path.
- **No `Ptr` suffix on methods.** Return `*T` from the primary name (`SpecialistType() *string`), never a paired `Xxx() T` / `XxxPtr() *T`.

## Transactions

```go
txFactory.WithTx(ctx, func(tx *Tx) error { ... })
```

Pass `tx` down to persistence methods.

**Ordering rule for post-commit side effects: save → commit → trigger.** Never fire a pipeline, notification or enqueue inside the transaction — the consumer would race an unsaved row.

## Domain naming without transport terms

Entity and service types use domain language, not transport details. Prefer `ProviderUpdate` over `WebhookPayload`, `HandleProviderUpdate` over `HandleWebhook`. The words "webhook", "request" and "response" belong in the transport layer only.

## Service files are named by access scope

Not by feature:

| File | Scope |
| --- | --- |
| `service.go` | Service struct, port interfaces, sentinel errors, DI, metrics, wiring validation |
| `auth.go` | Authentication flows and public user-facing operations |
| `admin.go` | Elevated-permission operations only |
| role-named files | Operations scoped to one staff role |
| `profile.go`, `account.go` | Self-service |
| `system.go` | Internal helpers, system-driven mutations |

Do not create a new service file without an explicit need — a genuinely new scope, or an existing file exceeding ~300 lines. All methods are `func (s *Service) ...`; do not introduce a second struct.

## Naming

| Thing | Convention |
| --- | --- |
| Files | snake_case |
| Packages | lowercase single word with a domain prefix (`userservice`, `userentity`, `userinfra`) |
| Request/response DTOs | `PostSignUpEmailRequest`, `PostSignUpEmailResponse` |
| Import aliases | alias the domain package explicitly at the import site |

- **Variable names must match parameter semantics.** If a parameter is `supportID`, the fetched entity is `support`, not `actor`.
- **A string literal used in more than one place becomes an unexported `const`.**

## Formatting

- gofumpt + gci; line length 100.
- Import order: standard library, third-party, local. Enforced by gci.
- JSON tags snake_case, enforced by a linter. Request structs also carry validation and example tags.
- 70+ linters are enabled in the linter config.

## Logging

Structured logging, injected by constructor, with a named sub-logger per subsystem. Never log PII in plain text — an opaque user id is fine; message content needs care.

## Forbidden

`fmt.Print*`, and the third-party `errors.Wrap` / `errors.Cause`. Use standard errors and `%w`.

## Comments — default none

Code must be self-explanatory; good names beat comments. Write a comment ONLY for a non-obvious *why* — an invariant, a workaround, a subtle gotcha — and keep it to **1 line, 2 at the very most**.

Forbidden: multi-line explanatory blocks, paragraph doc-comments above every func/const/field, comments restating what the code does, and comments narrating a change or decision ("we do X because earlier Y…", "moved from Z", ADR-style prose).

This is not a preference — oversized comments are treated as a defect in review, and the rule applies to generated and agent-written code too.

Keep only: citations of external guidelines quoted inside prompts, build/generate directives, and API-doc annotations on handlers.

## Adding a domain

1. `entity/` — domain types and value objects.
2. `service/service.go` — port interfaces and the `Service` struct.
3. `infra/` — implementations.
4. `transport/` — handlers.
5. Wire in `main`: infra → service → handlers → routes.

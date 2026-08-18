---
title: Backend layers and dependency direction
summary: Each business domain is one package tree of entity, service, infra and transport, with dependencies pointing inward and main.go as the only wiring point.
keywords: [DDD, layers, entity, service, infra, transport, dependency direction, ports, package layout, shared libraries, main.go]
related:
  - webapp/backend-entities.md
  - webapp/backend-services.md
  - webapp/backend-infrastructure.md
  - webapp/backend-transport.md
  - webapp/backend-python.md
---

# Backend layers and dependency direction

The reference implementation is Go. `webapp/backend-python.md` maps every layer
onto Python.

## The four layers of a domain

Each business **domain** (user, order, billing, …) is one package tree with four
sub-packages:

```
internal/<domain>/
  entity/            ← domain model: types, value objects, invariants, sentinel errors
  service/           ← use cases: orchestration, transactions, port interfaces
  infra/             ← implementations of the service's ports (Postgres, Redis, adapters)
  transport/http/    ← HTTP handlers, DTOs, routing, auth guards
```

## Direction of dependencies

This is the load-bearing rule of the whole architecture:

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

## Asserting port conformance at compile time

Every infra implementation carries a compile-time conformance assertion at the
top of the file:

```go
var _ service.Persistence = (*PostgresPersistence)(nil)
```

## Placing shared libraries and vendor clients

**Shared libraries** live outside the domains (e.g. `lib/` or `pkg/`): an HTTP
kit, a Postgres helper, a config loader, a typed-error package, crypto helpers.
They are a leaf layer — they import nothing from `internal/`.

Clients for external third-party APIs also live here (one package per vendor,
each owning its own `Config` struct), **not** in a domain's `infra/` — `infra/`
is only for implementations of that domain's own ports.

## Scaling the layout down to one domain

A small app (an internal console, a single-purpose service) keeps exactly the
same shape with one domain:

```
internal/request/
  entity/    request.go
  infra/     request_repo.go event_repo.go
  service/   service.go policy.go
  transport/http/  http.go
```

Plus a handful of plain supporting packages beside it for things that are
neither entity nor infra (parsers of external artefacts, provisioning helpers).

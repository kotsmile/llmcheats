---
title: The same backend architecture in Python
summary: FastAPI, Pydantic v2, SQLAlchemy Core and Alembic express the same four layers, with Protocols as ports and import-linter enforcing the dependency direction.
keywords: [Python, FastAPI, Pydantic, SQLAlchemy, Alembic, Protocol, dataclass, dependency injection, Depends, import-linter, asyncio, TaskGroup]
related:
  - webapp/backend-layers.md
  - webapp/backend-entities.md
  - webapp/backend-services.md
  - webapp/backend-transport.md
---

# The same backend architecture in Python

## Mapping the Go layers onto Python

The layers translate directly; only the idioms change. Reference stack:
**FastAPI + Pydantic v2 + SQLAlchemy Core (or asyncpg with raw SQL) + Alembic**.

| Concept (Go)                  | Python equivalent                                                                                                                                                                                       |
| ----------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `entity/` package             | `entity.py` / `entities/` — frozen dataclasses or plain classes; invariants in `__post_init__`, classmethod constructors (`User.create(email, password)`), mutator methods that raise domain exceptions |
| Value objects                 | `NewType` + validating factory functions, or small frozen dataclasses; **not** Pydantic models (those belong to transport)                                                                              |
| Sentinel errors               | Exception hierarchy: `class DomainError(Exception)`, `class NotFoundError(DomainError)`, `class ForbiddenError(DomainError)` — with an optional `reason` attribute                                      |
| Port interfaces in `service/` | `typing.Protocol` classes declared in the service module; repositories conform structurally                                                                                                             |
| `var _ Port = (*Impl)(nil)`   | a unit test asserting `isinstance(impl, PortProtocol)` (with `@runtime_checkable`), or just mypy                                                                                                        |
| Constructor DI in `main.go`   | explicit constructor wiring in `app.py` / a `build_app()` factory; FastAPI `Depends` only at the transport edge — never inside services                                                                 |
| `TxFactory.WithTx`            | `async with db.begin() as conn:` context manager owned by the service; repositories take the connection as a parameter                                                                                  |
| DTOs + `validate` tags        | Pydantic request/response models in the router module — `model_config = ConfigDict(extra="forbid")` is the `DisallowUnknownFields` equivalent; body-size cap at the ASGI server or middleware           |
| `JSONFunc` + `WriteAppError`  | one exception handler: `app.add_exception_handler(DomainError, to_api_error)` mapping the exception class to a status and the flat `APIError` shape                                                     |
| goose migrations              | Alembic, plain SQL in migration files where possible; applied by a `migrate` entrypoint/command, never at import time                                                                                   |
| errgroup + graceful shutdown  | ASGI lifespan handlers + `asyncio.TaskGroup` for background workers; uvicorn/hypercorn handle SIGTERM draining — configure a drain timeout matching the slowest route                                   |
| `${VAR}` config               | one YAML file, same placeholder resolution rule, parsed into a Pydantic Settings-free plain model (avoid implicit env magic — keep the "config is a file, secrets are `${VAR}`" contract)               |

## What does not change in Python

Entities validate themselves, services own transactions and orchestration,
repositories are dumb SQL executors conforming to protocols, routers
parse/convert/call-one-service-method/serialize.

The dependency direction is enforced by import-linter (contracts:
`transport → service → entity`, `infra → service, entity`).

---
title: The shared Go library — what belongs there
summary: The categories of shared package, the naming convention for third-party clients, and the placement rule that keeps them out of domain infra.
theme: backend
keywords: [shared library, package naming, x suffix, external client, config struct, single module, http middleware, config loader, crypto, storage, provider abstraction]
related:
  - backend/layered-architecture.md
  - backend/configuration-loading.md
  - backend/llm-provider-abstraction.md
---

## Placement rule

The shared library holds cross-cutting utilities and **third-party API clients**. A client for an external service belongs there — never in a domain's `infra/`, which is reserved for implementations of that domain's own service interfaces.

Each client package defines its own `Config` struct alongside the client.

The shared library is part of the **same Go module** as the services that consume it — one module at the repo root, not one per service.

## Naming

A package wrapping a third-party service is named `<service>x`. The suffix marks it as an adapter rather than the vendor's own SDK, and keeps the import alias unambiguous.

## Categories

**Infrastructure and cross-cutting**

| Concern | Contents |
| --- | --- |
| errors | application error type with HTTP status, debug channel, not-found predicate |
| http | middleware and helpers: JSON handler wrapper, recover, secure headers, logging, timeout, basic auth, secret redaction, auth, cookies |
| config | typed parse-and-validate, placeholder resolution, defaulting |
| logging | structured logger setup and safe goroutine helpers |
| metrics | registry and HTTP middleware |
| validation | struct-tag validation |
| time, async | small helpers |
| postgres, redis | connection setup |
| object storage | S3-compatible blob access |
| mail | SMTP |
| git | repository operations for services that commit |

**Auth, crypto and secrets**

| Concern | Contents |
| --- | --- |
| OIDC | the auth layer for every internal service: session, access token, offline token, service-issued token, admin password; plus a directory lookup for user and group autosuggest |
| OAuth | third-party identity verifiers and JWKS handling |
| crypto | symmetric encryption, hashing, randomness |
| secret KV | key-value secret representation |
| vault | secret-provider abstraction with pluggable backends |

**Model serving**

| Concern | Contents |
| --- | --- |
| provider abstraction | provider-agnostic completion layer with a factory registry and per-vendor sub-packages |
| tracing | OpenTelemetry decoration of any provider |
| transaction engine | queue and protocol for long-running model work |
| tool protocol client | client with reconnect and schema handling for external tool servers |

**Domain-specific third-party clients**

Wearable aggregation, generative workout supply, nutrition datasets, food databases, image handling and classification, PDF handling, deep links, and link-format parsers each get their own `<service>x` package.

## Generated clients

Clients produced from a vendor's OpenAPI spec live in the same package as their hand-written wrapper, with the generator config checked in beside them. They are never edited by hand.

## Adding a package

1. Name it `<service>x` for a third-party client.
2. Put the `Config` struct next to the client.
3. Wire it at composition time and pass each consuming service **only the fields it needs**, not the whole config struct.

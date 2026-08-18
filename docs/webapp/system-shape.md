---
title: System shape
summary: The reference topology is a reverse proxy serving one origin in front of one backend binary, Postgres, and optional Redis/object store/OIDC.
keywords: [topology, reverse proxy, one origin, CORS, subcommands, serve, migrate, config file, env vars]
related:
  - webapp/infrastructure.md
  - webapp/backend-config-lifecycle.md
  - webapp/frontend-toolchain.md
---

# System shape

## Reference topology

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

The architecture is deliberately boring.

## Sharing one origin between SPA and API

The SPA and its API share an origin: the reverse proxy serves the static files
and proxies `/api` (and `/auth`) to the backend. The dev server proxies *the
same paths* to a local backend.

Consequences:

- Session cookies behave identically in dev and prod — no CORS, no
  third-party-cookie problems, no `Access-Control-Allow-Credentials` dance.
- CORS middleware exists only for the exceptional deployment where a second
  origin genuinely must call the API, and it is a strict allowlist, never `*`.

## Shipping one binary with subcommands

The backend ships as a single binary with subcommands: `serve` runs the HTTP
service, `migrate` applies database migrations and exits.

Migrations never run implicitly on service boot — see
`webapp/infrastructure.md`.

## Reading config from a file and secrets from the environment

The process reads one YAML config file passed via `--config`. Secrets reach it
as `${VAR}` placeholders in that file, resolved from the environment at parse
time. The service itself never calls `os.Getenv` for its own settings — see
`webapp/backend-config-lifecycle.md`.

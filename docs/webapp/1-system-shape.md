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

# llmcheats reference — index

Two references, split into per-topic files. `webapp/` says *how to build*;
`devflow/` says *in what order, with which gates*. Distilled from a running
production system — a multi-domain API, several internal consoles, and the
SPAs on top of them. Nothing here is theoretical.

**Read only the files your task needs.** Section numbers (§) are preserved
inside each file, so a reference like "§2.5" still resolves.

## webapp/ — how to build

| File | § | Read it when |
|---|---|---|
| `1-system-shape.md` | 1 | Standing up a new app; deciding process/deploy topology |
| `2a-backend-layers.md` | 2.1–2.4 | Backend domain work: the four layers, invariant entities, value objects, services, ports, transactions, raw SQL, migrations |
| `2b-backend-transport.md` | 2.5–2.8 | Endpoints, handlers, DTOs/validation, middleware, auth guards, error→status mapping, config, startup/shutdown |
| `2c-backend-python.md` | 2.9 | Same architecture in Python (FastAPI, SQLAlchemy Core, Alembic) |
| `3-frontend.md` | 3 | React SPA: Vite/TS/Tailwind, FSD, routing, TanStack Query, Zustand, auth, tokens, forms, React 19 |
| `4-testing.md` | 4 | Writing tests: fakes over mocks, DB/handler/e2e/frontend tests, CI |
| `5-security.md` | 5 | Auth (JWT/OIDC/machine tokens), authz, validation, SQLi, secrets, audit logging, HTTP hardening |
| `6-performance.md` | 6 | DB tuning, deadline budgets, concurrency, caching, frontend perf |
| `7-infrastructure.md` | 7 | Runtime contract, build/ship, proxy topology, migrations, secrets, observability, CI/CD |
| `8-checklist.md` | 8 | New-application checklist; its Security block doubles as a review checklist |
| `9-ai-features.md` | 9 | LLM features: prompts as code, provider as a port, tool executors, evals, cost |

## devflow/ — in what order

| File | § | Read it when |
|---|---|---|
| `1-principles-roles.md` | 1–2 | Need the never-skip list or who owns which stage |
| `2-full-flow.md` | 3–4 | Feature, migration, or behavior change: all 13 stages, gates, required artifacts |
| `3-fast-flow.md` | 5 | Bug or hotfix, including the infra-inspection-first rule |
| `4-never-skip.md` | 6–7 | Observability minimums; release-speed targets |
| `5-git.md` | 8–9 | Commit format, PR description blocks, gate→approval mapping, merge discipline; scaling the process down |
| `6-asap-flow.md` | 10 | Small urgent task delivered in one pass by one person/agent: what it may skip, the floor it may not, and when to hand back to the full or fast flow |

## Rules

Read the relevant file before acting — don't work from memory of it. Deviations
are allowed with a written reason; silent deviations are not.

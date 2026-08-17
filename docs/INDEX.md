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
| `7-flow-visibility.md` | 11 | A flow runs long, an agent goes quiet, or you cannot tell whether work is progressing: reporting cadence, counting gate rounds, background agents, reading agent state off disk, orchestrating at a depth the operator can see |
| `8-resuming.md` | 12 | Picking up work that was stopped, ran out of context, or is half-written: plans as files, the resume inventory, counting re-planning rounds, why an orchestrator never finishes the work itself |
| `9-agent-io.md` | 13 | A single agent pass takes too long: batching independent reads into one block, what is out of bounds to read (vendor source, live data), sizing the output to the scope, budgeting the pass |
| `10-flow-cost.md` | 14 | A flow costs more than it should: choosing the cheapest flow that clears the gates, tiering the model per stage, hand-backs as summaries, cache-stable prefixes, when parallel is worth it, the loops that burn stages |

## Rules

Read the relevant file before acting — don't work from memory of it.

Deviating from a **constraint, a security rule, or a triggered workflow gate**
needs a written reason; silently deviating from one is never allowed. An
ordinary implementation choice — naming, file layout, which of two equivalent
idioms — is not a deviation and needs no paragraph defending it. The line
between the two is in `devflow/1-principles-roles.md` §1.

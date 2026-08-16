---
name: webapp-guide
description: Reference guide for building production web applications (Go/Python backend + React SPA) and the development flow around them. Use when designing, implementing, reviewing, or operating a web application — architecture (DDD layers, FSD frontend), testing, security, performance, infrastructure, or the feature/hotfix delivery process.
---

# Web application guide

This skill points at two reference documents installed alongside it. Locate
them — check in order, use the first directory that exists:

1. `<project>/.claude/llmcheats/docs/` (project install)
2. `~/.claude/llmcheats/docs/` (global install)
3. `~/.codex/llmcheats/docs/` (codex install)

If none exist, say so explicitly and proceed on general best practice — do
not invent the documents' contents.

## The documents

**`WEBAPP_DOC.md`** — how to build:
- §1 System shape (one-origin SPA + API, single binary with subcommands)
- §2 Backend DDD: entity/service/infra/transport layers, invariant entities,
  ports, transactions, errors, config, startup/shutdown; §2.9 Python mapping
- §3 React SPA: Vite/TS/Tailwind, FSD, routing, TanStack Query, Zustand,
  auth, tokens/styling, forms, React 19 rules
- §4 Testing: philosophy, fakes over mocks, DB/handler/e2e/frontend tests, CI
- §5 Security: authn (JWT/OIDC/machine tokens), layered authz, validation,
  SQLi, secrets, audit logging, HTTP hardening, frontend security
- §6 Performance: DB, deadline budgets, concurrency, caching, frontend
- §7 Infrastructure: runtime-agnostic contract, build/ship, proxy topology,
  migrations, secrets, observability, CI/CD
- §8 New-application checklist
- §9 AI features: prompts as code, LLM provider as a port, tool executors as
  transport, two-level evaluation, deadlines, cost

**`DEVFLOW.md`** — in what order, with which gates:
- Principles and the never-skip list; roles
- Full flow (feature/migration): scope → design → architecture → security &
  devops design approvals → operator plan approval (when not watching live) →
  development → testing → implementation approvals → docs → product review →
  release
- Fast flow (bug/hotfix), including the infra-inspection-first rule
- Required artifacts after every feature/release
- Observability minimums and release-speed targets
- Git rules: commit format and hygiene, PR description blocks, gate-to-approval
  mapping, merge discipline

## How to use

Read the section relevant to the task before acting — don't work from memory
of it. When implementing, follow the §8 checklist. When running a delivery
process, follow DEVFLOW and its gates (the `dev-team` agent orchestrates this
if agents are installed). Deviations from the guide are allowed with a written
reason; silent deviations are not.

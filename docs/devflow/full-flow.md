---
title: Full flow — feature and migration delivery
summary: Thirteen stages from scope to release, each naming its owner, the gate that blocks progression, and the artifacts that must exist when it closes.
keywords: [full flow, stages, scope, product design, architecture, security audit, devops audit, plan approval, development, testing, documentation, product review, release, gate, artifact]
related:
  - devflow/skip-gates.md
  - devflow/roles.md
  - devflow/release-artifacts.md
  - devflow/fast-flow.md
  - devflow/flow-cost.md
---

# Full flow — feature and migration delivery

Every stage names its owner, its **gate** (what blocks progression), and its
**artifacts** (what must exist when the stage closes).

Before opening any of them, run the skip gates in `devflow/skip-gates.md`: a
stage this change does not reach closes unopened with its reason printed.

## Stage 1 — Scope (product designer)

- Problem statement: who hurts, how, and how we will know it stopped.
- Acceptance criteria — testable, enumerated.
- Priority and rough size (S/M/L — calibrate once, e.g. S ≤ a day, M ≤ a week,
  L larger); explicit non-goals.
- **Gate:** the team can restate the problem without mentioning the solution.
- **Artifact:** a short scope document (issue/ticket body is fine).

## Stage 2 — Product design (product designer)

- User flows, screen states (loading / empty / error / success), copy.
- Edge cases from the user's perspective (offline, permissions, concurrent edits).
- **Gate:** every acceptance criterion is reachable through the designed flow.
- **Artifact:** flow description / wireframes attached to the scope.

## Stage 3 — Architecture (architect)

- Implementation plan by layer (entity / service / infra / transport; FSD
  slices on the frontend) — files to create or touch.
- API contract: endpoints, DTOs, error reasons.
- Data: schema changes as an **expand → migrate → contract** plan
  (`webapp/infrastructure.md`), index justifications.
- Risks, alternatives considered, rollout & rollback story.
- **AI features:** when the feature touches an LLM, the AI engineer co-designs
  this stage — tool schemas, prompt placement, and the evaluation plan are part
  of the design document (`webapp/ai-features.md`), and the stage 4/5 gates
  review them with the rest.
- **Gate:** a developer who was not in the discussion could implement from the plan.
- **Artifact:** design document linked from the ticket — written to a path in
  the repo, not left as a message, so a resumed or re-delegated flow implements
  it instead of designing it again (`devflow/resuming.md`).

## Stage 4 — Security audit, design approval (security auditor)

- Reviews the *design*: authn/authz model for the new surface, data
  classification (does it touch client secrets / PII?), input sources, new
  attack surface.
- **Gate:** written approval, or findings that reshape the design **before**
  code exists — this is the cheap moment to fix an authz model.
- **Artifact:** approval note + threat notes for stage 11.

## Stage 5 — DevOps audit, design approval (devops)

- Infra impact: new services/queues/buckets, capacity, quota, cost.
- Deployability: migration ordering, config/secret changes, feature flags,
  rollback plan.
- Observability plan: which metrics/logs/alerts this feature must emit
  (`devflow/observability-minimum.md`).
- **Gate:** written approval; a feature with no rollback story does not proceed.
- **Artifact:** infra/rollout notes appended to the design doc.

## Stage 6 — Plan and operator approval (optional)

Applies only when a human operator is **not** watching the work live
(autonomous agents, delegated work, async teams). Skip it when the operator is
already in the loop — they see the plan as it forms.

- Before writing code, the developer posts a **high-level plan of one or two
  sentences** — what will be changed and where ("Add `POST
  /orders/{id}/cancel` through the order domain's four layers plus a
  `cancelled_at` column; frontend gets a cancel action on the order card."). No
  preamble, no option-listing — the architecture doc already holds the detail.
- **Who approves:** the operator when reachable. When the operator granted
  autonomy for the task, the **project manager approves on their behalf** —
  checking the plan against the agreed scope and recording the delegation. Work
  exceeding the agreed scope always goes back to the human, however long the
  wait. Silence is never approval for irreversible work.
- **Gate:** an ack from the operator or the project manager (or the step was
  explicitly skipped because the operator is watching).
- **Artifact:** the plan line + the ack (and who gave it), on the ticket/thread.

## Stage 7 — Development (developers)

- Implement per the plan and the `webapp/` guide. Deviations from the plan go
  back to the architect (a one-line message, not a meeting).
- Tests written alongside (unit + the DB/handler tests the plan called for),
  each stating its reason (`webapp/testing-strategy.md`).
- **Gate:** CI green (build, vet/lint, tests); self-review of the diff.
- **Artifact:** the merge request.

## Stage 8 — Testing (developers and testers)

- Automated: full test suite; e2e on the composed stack where it exists.
- Manual: walk the acceptance criteria on a test stand (or locally composed
  stack when there is no stand). Testers if you have them; the developer +
  product designer if you do not.
- Regression: the flows adjacent to the change.
- **AI features:** the deterministic Level-1 tests (safety filters, tool
  parsers, prompt assembly) are blocking; the Level-2 scenario evaluation runs
  and its verdict is recorded with the test notes (`webapp/ai-features.md`).
- **Gate:** every acceptance criterion demonstrably passes.
- **Artifact:** test notes on the ticket (what was run, on what, what failed).

## Stage 9 — Security audit, implementation approval (security auditor)

- Reviews the *diff*: the `webapp/security-*.md` files (the rationale) plus the
  Security block of `webapp/new-app-checklist.md` (the checklist form) against
  the actual code — authz on every new route, parameterized SQL, input
  validation, secret handling, no state-changing GETs, audit rows where the
  design demanded them.
- **Gate:** written approval; findings are fixed, not waived, unless the
  auditor explicitly accepts the risk in writing.

## Stage 10 — DevOps approval, release readiness (devops)

- Migrations reviewed (locks, backward compatibility one release back).
- Config/secret changes staged in the secret store; deploy artifact builds.
- Alerts/dashboards from stage 5 actually exist.
- **Gate:** written approval.

## Stage 11 — Documentation update (developer, security auditor, devops)

Documentation is part of the feature, updated **in the same change set or
immediately after**, by the role that owns each document
(`devflow/release-artifacts.md`).

- Developer: architecture docs, API docs, READMEs of touched components.
- Developer: **project memory** — the conventions and decisions this change
  established, written into `CLAUDE.md` / `AGENTS.md`
  (`devflow/project-memory.md`). Both tools load it unprompted next session,
  which is what lets the change after this one plan less.
- Security auditor: security notes / threat model deltas.
- DevOps: runbooks, infra description, deploy/operations instructions.
- **Gate:** the docs a newcomer would read no longer lie.

## Stage 12 — Product review (product designer)

- Walks the shipped (or stand-deployed) feature against the acceptance criteria
  from stage 1.
- **Gate:** explicit accept. A "mostly done" verdict spawns follow-up scope, it
  does not hold the release hostage.

## Stage 13 — Release (devops, if applicable)

- Deploy via the standard mechanism (CI job or the repo's deploy script — never
  by improvised hand commands).
- Verify: health checks, error rates, the feature's own metrics for the first
  minutes after rollout.
- **Artifact:** release record — version, when, by whom, and the one-command
  rollback.

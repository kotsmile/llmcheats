# Development Flow — full flow (feature / migration)

## 3. Full flow — new feature / migration

Every stage names its owner, its **gate** (what blocks progression), and its
**artifacts** (what must exist when the stage closes).

### 3.1 Scope — *product designer*
- Problem statement: who hurts, how, and how we'll know it stopped.
- Acceptance criteria — testable, enumerated.
- Priority and rough size (S/M/L — calibrate once, e.g. S ≤ a day, M ≤ a
  week, L larger); explicit non-goals.
- **Gate:** the team can restate the problem without mentioning the solution.
- **Artifact:** a short scope document (issue/ticket body is fine).

### 3.2 Product design — *product designer*
- User flows, screen states (loading / empty / error / success), copy.
- Edge cases from the user's perspective (offline, permissions, concurrent edits).
- **Gate:** every acceptance criterion is reachable through the designed flow.
- **Artifact:** flow description / wireframes attached to the scope.

### 3.3 Architecture — *architect*
- Implementation plan by layer (entity / service / infra / transport;
  FSD slices on the frontend) — files to create or touch.
- API contract: endpoints, DTOs, error reasons.
- Data: schema changes as an **expand → migrate → contract** plan
  (`webapp/7-infrastructure.md` §7.4), index justifications.
- Risks, alternatives considered, rollout & rollback story.
- **AI features:** when the feature touches an LLM, the AI engineer co-designs
  this stage — tool schemas, prompt placement, and the evaluation plan are
  part of the design document (`webapp/9-ai-features.md`), and the §3.4/§3.5 gates review
  them with the rest.
- **Gate:** a developer who wasn't in the discussion could implement from the plan.
- **Artifact:** design document (architecture plan) linked from the ticket —
  written to a path in the repo, not left as a message, so a resumed or
  re-delegated flow implements it instead of designing it again
  (`devflow/8-resuming.md`).

### 3.4 Security audit — design approval — *security auditor*
- Reviews the *design*: authn/authz model for the new surface, data
  classification (does it touch client secrets / PII?), input sources,
  new attack surface.
- **Gate:** written approval, or findings that reshape the design **before**
  code exists — this is the cheap moment to fix an authz model.
- **Artifact:** approval note + threat notes for §3.11.

### 3.5 DevOps audit — design approval — *devops*
- Infra impact: new services/queues/buckets, capacity, quota, cost.
- Deployability: migration ordering, config/secret changes, feature flags,
  rollback plan.
- Observability plan: which metrics/logs/alerts this feature must emit (§6,
  `devflow/4-never-skip.md`).
- **Gate:** written approval; a feature with no rollback story does not proceed.
- **Artifact:** infra/rollout notes appended to the design doc.

### 3.6 Plan & operator approval — *developer → operator or manager* (optional)

Applies only when a human operator is **not** watching the work live
(autonomous agents, delegated work, async teams). Skip it when the operator
is already in the loop — they see the plan as it forms.

- Before writing code, the developer posts a **high-level plan of one or two
  sentences** — what will be changed and where ("Add `POST /orders/{id}/cancel`
  through the order domain's four layers plus a `cancelled_at` column;
  frontend gets a cancel action on the order card."). No preamble, no
  option-listing — the architecture doc (§3.3) already holds the detail.
- **Who approves:** the operator when reachable. When the operator granted
  autonomy for the task, the **project manager approves on their behalf** —
  checking the plan against the agreed scope and recording the delegation.
  Work exceeding the agreed scope always goes back to the human, however
  long the wait. Silence is never approval for irreversible work.
- **Gate:** an ack from the operator or the project manager (or the step was
  explicitly skipped because the operator is watching).
- **Artifact:** the plan line + the ack (and who gave it), on the
  ticket/thread.

### 3.7 Development — *developers*
- Implement per the plan and the `webapp/` guide. Deviations from the plan go back to
  the architect (a one-line message, not a meeting).
- Tests written alongside (unit + the DB/handler tests the plan called for),
  each stating its reason (`webapp/4-testing.md` §4.1).
- **Gate:** CI green (build, vet/lint, tests); self-review of the diff.
- **Artifact:** the merge request.

### 3.8 Testing — *developers / testers*
- Automated: full test suite; e2e on the composed stack where it exists.
- Manual: walk the acceptance criteria on a test stand (or locally composed
  stack when there is no stand). Testers if you have them; the developer +
  product designer if you don't.
- Regression: the flows adjacent to the change.
- **AI features:** the deterministic Level-1 tests (safety filters, tool
  parsers, prompt assembly) are blocking; the Level-2 scenario evaluation
  runs and its verdict is recorded with the test notes (`webapp/9-ai-features.md`).
- **Gate:** every acceptance criterion demonstrably passes.
- **Artifact:** test notes on the ticket (what was run, on what, what failed).

### 3.9 Security audit — implementation approval — *security auditor*
- Reviews the *diff*: `webapp/5-security.md` (the rationale) plus the Security
  block of `webapp/8-checklist.md` (the checklist form) against the actual code —
  authz on every new route, parameterized SQL, input validation, secret
  handling, no state-changing GETs, audit rows where the design demanded them.
- **Gate:** written approval; findings are fixed, not waived, unless the
  auditor explicitly accepts the risk in writing.

### 3.10 DevOps approval — release readiness — *devops*
- Migrations reviewed (locks, backward compatibility one release back).
- Config/secret changes staged in the secret store; deploy artifact builds.
- Alerts/dashboards from §3.5 actually exist.
- **Gate:** written approval.

### 3.11 Documentation update — *developer, security auditor, devops*
Documentation is part of the feature, updated **in the same change set or
immediately after**, by the role that owns each document (§4).
- Developer: architecture docs, API docs, READMEs of touched components.
- Developer: **project memory** — the conventions and decisions this change
  established, written into `CLAUDE.md` / `AGENTS.md`
  (`devflow/11-project-memory.md`). Both tools load it unprompted next session,
  which is what lets the change after this one plan less.
- Security auditor: security notes / threat model deltas.
- DevOps: runbooks, infra description, deploy/operations instructions.
- **Gate:** the docs a newcomer would read no longer lie.

### 3.12 Product review — *product designer*
- Walks the shipped (or stand-deployed) feature against the acceptance
  criteria from §3.1.
- **Gate:** explicit accept. A "mostly done" verdict spawns follow-up scope,
  it does not hold the release hostage.

### 3.13 Release — *devops* (if applicable)
- Deploy via the standard mechanism (CI job or the repo's deploy script —
  never by improvised hand commands).
- Verify: health checks, error rates, the feature's own metrics for the first
  minutes after rollout.
- **Artifact:** release record — version, when, by whom, and the one-command
  rollback.

### 3.14 Skip gates — running the full flow without paying for all thirteen

The full flow is 13 fresh contexts (`devflow/10-flow-cost.md` §14.1), and an
operator who **forces** it — because the gates are wanted unconditionally, or
because the work will run for hours without supervision — should get the gates,
not thirteen contexts of ceremony. So each stage carries a **skip gate**: one
test, answered at intake, and a stage whose test is met closes before it opens.

This applies to **every** full-flow run, forced or chosen: a flow picked on its
merits still has stages this particular change does not reach.

| Stage | Skip it only when |
|---|---|
| 3.1 Scope | the request already states the problem and testable done-conditions; restate them in two sentences instead of opening a stage |
| 3.2 Product design | nothing user-visible changes — no screen, no copy, no surface a consumer sees |
| 3.3 Architecture | a plan for this scope is already on disk (`devflow/8-resuming.md`), the change is one file inside a pattern the codebase already repeats, or the conventions it must follow are already recorded in project memory (`devflow/11-project-memory.md`) — which is how a project that writes its decisions down plans less over time |
| 3.4 Security design approval | the change reaches nothing on the trigger list in `devflow/6-asap-flow.md` §10.2 — no auth, sessions, tokens, crypto, secrets, PII, payments, new input source or new route |
| 3.5 DevOps design approval | no migration, no config or secret change, no new infra, no deploy-order dependency — **and** the change needs no new metric, log or alert and already has a rollback story. Observability is a never-skip item (`devflow/1-principles-roles.md` §1): a change that needs a new signal opens this stage whatever else is true |
| 3.6 Plan approval | already conditional — the operator is watching the work live (§3.6) |
| 3.8 Testing | never skipped; the *manual* walk collapses into the suite when every acceptance criterion has an automated test |
| 3.9 Security implementation approval | §3.4 was skipped **and** the diff added no route, query, or input path |
| 3.10 DevOps release readiness | §3.5 was skipped **and** the diff adds no migration, config change, or deploy step |
| 3.11 Documentation | no touched component's README, API doc or runbook is now wrong — checked, not assumed — **and** the change established no convention or decision worth recording in project memory |
| 3.12 Product review | §3.2 was skipped **and** every acceptance criterion is mechanically verifiable |
| 3.13 Release | the change does not deploy |

§3.7 has no row: development is the work.

- **A skipped stage is a recorded verdict, not an absence.** One line per stage,
  printed at intake with its reason — `stage 5 · devops design ⊘ SKIPPED: no
  migration, no config change`. A stage nobody mentioned was forgotten, and the
  operator cannot tell the two apart afterwards.
- **A triggered gate is compressed, never skipped.** The tests above skip stages
  the change does not reach; they never drop one it does. Tell the gate owner the
  scope is small and ask for a proportionate review
  (`devflow/1-principles-roles.md` §1).
- **Skipping is not downgrading.** Downgrading moves the whole change to a
  cheaper flow (`devflow/10-flow-cost.md` §14.1); this keeps the full flow and
  drops the stages its triggers do not reach. Forcing the full flow is what makes
  the difference explicit.
- **A lost bet costs one stage, not the flow.** If development turns up a
  migration nobody planned, §3.5 and §3.10 reopen — name the stage that reopened
  and why. Re-checking the trigger list mid-flow is already mandatory
  (`devflow/6-asap-flow.md` §10.2).

The skip gate itself opens no context: the questions are answered in the intake
context that is already running, and each "no" removes a whole stage's context
from the bill. **Every row is answered from this table — open nothing to answer
one**; the files named above are where a *disputed* skip gets settled, not where
the test lives.

---

## 4. Artifacts after every feature and release

The definition of done includes the paper trail. After each feature/release
these must be current:

| Artifact | Owner | Contents |
|---|---|---|
| **Architecture docs** | developer/architect | domain map, layer decisions, ADRs for anything non-obvious ("why X" answered once, in writing) |
| **API docs** | developer | OpenAPI spec regenerated; changed endpoints described |
| **DevOps instructions** | devops | how to build, deploy, roll back, run migrations — each backed by a runnable script/job |
| **Infra info** | devops | what runs where, DNS, certs, secret map names, capacity notes |
| **Runbooks** | devops | per-alert: what it means, what to check, how to mitigate |
| **Project memory** | developer | `CLAUDE.md` / `AGENTS.md`: how to run it, the architecture the project actually follows and where it departs from `webapp/`, decisions with their reasons (`devflow/11-project-memory.md`) |
| **Security notes** | security auditor | data classification, authz model per surface, accepted risks with expiry dates |
| **READMEs** | developer | every touched component's README still tells the truth: what it is, how to run it, how to test it |
| **Release record** | devops | version, changelog entry, rollback command |

Keep docs **next to the code they describe** (per-directory READMEs, ADRs in
the repo), not in an external wiki that CI can't see and reviews don't touch.

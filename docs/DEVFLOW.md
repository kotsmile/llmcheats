# Development Flow

The process companion to [WEBAPP_DOC.md](WEBAPP_DOC.md). That document says *how
to build*; this one says *in what order, with which gates, and what must exist
afterwards*. It is written to be executed by a team of humans, a team of LLM
agents (see `agents/`), or a mix.

---

## 1. Principles

**Product first.** Client-facing product development is prioritized over a
sufficient dev stack. A "pure" dev stack — no dedicated test stand, no QA team,
manual deploys — is an acceptable state for a young product. Process weight
scales with the system; the flows below describe the full ceremony, and §9
defines what a stripped-down version may and may not drop.

**Some things are never skipped**, whatever the stack maturity:

1. **Development best practices** — the architecture, layering, and code rules
   in WEBAPP_DOC.md. Skipping them saves days and costs months.
2. **Security practices for client secrets** — credential handling, encryption
   at rest, audit of access to sensitive data (WEBAPP_DOC §5). A young product
   is exactly the one that cannot survive a leak.
3. **System observability** — you cannot operate what you cannot see (§6 below).
4. **Release speed** — the ability to deliver a fix fast is itself a safety
   property (§7 below).

**Write for the reader.** Anything addressed to a human — an approval request,
a status update, a comment, a plan summary — is **one or two sentences,
maximum, with no filler phrases**. Humans approve what they can read at a
glance. Artifacts consumed by LLMs or by later stages (design docs, scenario
corpora, runbooks) are as detailed as the work needs. The same fact often
exists in both forms: the two-sentence version for the operator, the full
version attached below it.

**Automation is executable documentation.** By the time a system matters,
everybody has forgotten how to deploy and test it. Every deploy path and every
test path must exist as a runnable artifact — a CI job, or a shell script in
the repo (an SSH-driven `deploy.sh` is a perfectly valid CI replacement for a
hand-rolled system). Prose instructions that aren't backed by a script are a
bug: they drift, scripts don't. The rule of thumb: **if a step is described in
a README, there must be a command the README tells you to run.**

---

## 2. Roles

Each role maps to an agent definition shipped with this repo (installed into
your tool's agent directory, e.g. `~/.claude/agents/`); on a small team one
person holds several hats — the *gates still happen*, they just happen faster.

| Role | Agent | Owns |
|---|---|---|
| Project manager | `project-manager` | operator communication, tracking, delegated approvals, result validation |
| Product designer | `product-designer` | scope, UX, acceptance criteria, product review |
| Architect | `architecture-designer` | technical design, contracts, migration plans |
| Backend developer | `golang-developer` / `python-developer` | backend implementation + tests |
| Frontend developer | `react-developer` | SPA implementation + tests |
| AI engineer | `ai-engineer` | prompts, tool schemas, LLM evals, cost & AI safety (when the feature touches an LLM) |
| Security auditor | `security-auditor` | security design & implementation approval, security docs |
| DevOps | `devops` | infra audit, releases, runbooks, observability |
| Orchestrator | `dev-team` | drives the flow end-to-end, holds the gates |

---

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
  (WEBAPP_DOC §7.4), index justifications.
- Risks, alternatives considered, rollout & rollback story.
- **AI features:** when the feature touches an LLM, the AI engineer co-designs
  this stage — tool schemas, prompt placement, and the evaluation plan are
  part of the design document (WEBAPP_DOC §9), and the §3.4/§3.5 gates review
  them with the rest.
- **Gate:** a developer who wasn't in the discussion could implement from the plan.
- **Artifact:** design document (architecture plan) linked from the ticket.

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
- Observability plan: which metrics/logs/alerts this feature must emit (§6).
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
- Implement per the plan and WEBAPP_DOC. Deviations from the plan go back to
  the architect (a one-line message, not a meeting).
- Tests written alongside (unit + the DB/handler tests the plan called for),
  each stating its reason (WEBAPP_DOC §4.1).
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
  runs and its verdict is recorded with the test notes (WEBAPP_DOC §9).
- **Gate:** every acceptance criterion demonstrably passes.
- **Artifact:** test notes on the ticket (what was run, on what, what failed).

### 3.9 Security audit — implementation approval — *security auditor*
- Reviews the *diff*: WEBAPP_DOC §5 (the rationale) plus the Security block
  of its §8 (the checklist form) against the actual code —
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
| **Security notes** | security auditor | data classification, authz model per surface, accepted risks with expiry dates |
| **READMEs** | developer | every touched component's README still tells the truth: what it is, how to run it, how to test it |
| **Release record** | devops | version, changelog entry, rollback command |

Keep docs **next to the code they describe** (per-directory READMEs, ADRs in
the repo), not in an external wiki that CI can't see and reviews don't touch.

---

## 5. Fast flow — bugs and hotfixes

The full flow compressed to what a defect actually needs. Target duration:
**minutes to hours, not days** (§7).

### F1. Scope — *whoever caught it*
- Reproduction, blast radius (who is affected, is data at risk), severity.
- Decision: hotfix now vs. scheduled fix. Data-loss or security ⇒ now.

### F2. Infra inspection — *devops*
- **First question: is this code or infra?** Check system health before
  blaming the code: recent deploys, resource saturation, dependency outages,
  certificate/quota expiry. Half of "bugs" are infra events; a code fix for an
  infra problem wastes the release *and* leaves the problem.
- **Artifact:** one paragraph: what was ruled out and how.

### F3. Development — *developer*
- If a human operator is not watching live: post the fix plan in **one
  sentence** and get an ack before coding (same rule as §3.6, compressed).
- The smallest change that fixes the defect. No opportunistic refactoring in
  a hotfix — that's a follow-up ticket.
- **A test that reproduces the bug is written first** and fails before the fix,
  passes after. This is the one non-negotiable test of the fast flow.

### F4. Testing — *developer*
- The new reproduction test; the suite of the affected area; **regression
  check of adjacent flows**; and an explicit re-check of the *original
  reported problem* on a stand or locally composed stack — the fix must be
  observed fixing it, not inferred.

### F5. Security approval — *security auditor*
- Scaled to the diff: a five-minute read for a typo-level fix; a real review
  the moment the fix touches auth, input handling, SQL, secrets, or PII.
- May be the same person as the developer on a small team — then it is a
  deliberate second pass with the WEBAPP_DOC §5 checklist, not a skipped
  step.

### F6. DevOps approval — *devops*
- Deploy safety: does the fix carry a migration (hotfixes should almost never),
  config change, or restart ordering? Is rollback still one command?

### F7. Release — *devops* (if applicable)
- Standard mechanism, then **watch it land**: error rate and the original
  symptom, for at least a few minutes. A hotfix that isn't verified in
  production is a hypothesis.
- Backport/forward-port: make sure the fix is on the main branch, not only on
  the release branch.

---

## 6. Observability — the never-skip minimum

Whatever else is deferred, a system serving clients has, from day one:

**User-level visibility**
- **User impersonation**: an admin can see the system as a specific user sees
  it, to reproduce their problem — behind an admin-only permission, and
  **every impersonation is audited** (who, whom, when). This single feature
  collapses most "works for me" support cycles.
- **Per-user logs and error tracking**: given a user id, you can pull their
  recent requests, errors, and key actions. Request logs carry a user/request
  correlation id (WEBAPP_DOC §7.6).
- **Client-side error reporting**: SPA errors land somewhere you look
  (an error-tracking service or your own endpoint), with release version
  attached.

**System health**
- HTTP RED metrics per route pattern: rate, error percentage, duration.
- Structured logs, centrally queryable; log levels that mean something
  (401/403 Info, 4xx Warn, 5xx Error).
- Performance baselines: know the normal latency/throughput so anomalies are
  visible.
- **Alerts in exactly two severities**:
  - **CRIT** — a person is paged/pinged now: service down, error rate spike,
    data-affecting failures, certificate expiry imminent.
  - **WARN** — visible in a channel, handled in working hours: elevated
    latency, disk trending full, retry rates up.
  - Anything that would be lower than WARN is a dashboard, not an alert.
    Alerts that don't demand action train people to ignore alerts.

**Health endpoints** wired into whatever runs the system (systemd watchdog,
compose healthcheck, k8s probes) — the runtime restarts what the metrics only
report.

---

## 7. Release speed — the never-skip capability

Release speed is a **tested property**, not an aspiration:

- Big systems (CI pipeline, orchestrated deploy): a hotfix goes from commit to
  production in **under 30 minutes**.
- Hand-rolled systems (a VM, SSH, a deploy script): **under 5–10 minutes**.

What that requires in practice:

- The deploy path is one command (`deploy.sh prod` or a CI button), documented
  where the code lives, and **exercised routinely** — the fast path must be the
  normal path, or it won't work under pressure.
- Rollback is one command, and it is listed in every release record.
- CI pipelines are lean: a hotfix does not wait for a 40-minute exhaustive
  suite — it runs the fast blocking checks; the exhaustive suite runs after,
  and a failure there rolls forward with another fix.
- No human-memory steps: if deploying needs "the thing only one person
  knows", the system fails the speed test. Scripts remember; people don't.

CI is the preferred automation, but **a shell script driving SSH is a valid CI
replacement** for small systems — same rule applies: it lives in the repo, it
is the only way anyone deploys, and the README points at it.

---

## 8. Git: commits and pull requests

### Commits

**Format** — one line, ≤ 72 chars, imperative mood, no trailing period:

```
<TICKET>: <scope> what the change does
```

```
APP-42: api add order cancellation endpoint
APP-37: web fix token refresh race on tab wake
hotfix: api reject non-JSON content type on JSON routes
chore: bump Go to 1.26
```

- **`<TICKET>`** — the issue key when a tracker exists; it links the commit
  to the scope/design docs. No tracker → drop the prefix, keep the rest.
- **`<scope>`** — the component touched (`api`, `web`, `infra`, a service
  name). One word.
- **No-ticket prefixes**, only where they genuinely apply: `hotfix:`
  (fast-flow fix), `chore:` (deps, tooling, formatting), `auto:`
  (machine-written commits — deploy bumps, generated files — carrying a
  trailer that names who/what triggered them).

Rules:

1. **One logical change per commit.** A commit is revertable as a unit: code
   + its tests + the docs/generated files that change with it land together.
   Never mix a refactor with a behavior change.
2. **Single line only.** If the message needs a body to be understood, the
   commit is too big or the design doc is missing — fix that instead.
3. **Green before commit.** Build, lint, and the affected tests pass locally.
   A broken commit on a shared branch costs everyone's bisect.
4. **Never commit secrets** — no keys, tokens, dumps, `.env` with real
   values. A committed secret is rotated, not deleted (history keeps it).
5. **No AI attribution, no `Co-Authored-By` bots.** The author is whoever
   answers for the change.
6. **Generated files travel with their source** in the same commit
   (regenerated spec, rendered manifests) — CI verifies staleness.
7. **Main is protected**: changes arrive via reviewed merge requests;
   hotfixes may fast-track the review but never skip CI. Machine commits
   (`auto:`) are the only direct-to-main writes, and each carries its audit
   trailer.
8. **Commit ≠ deliver.** The agent/developer commits when the operator (or
   the project manager under delegated autonomy) asks or the flow's release
   stage requires it — never speculatively pushes.

### Pull requests

**Title** = the commit format: `<TICKET>: <scope> what the change delivers`.
Squash-merge inherits it, so the title is written as the future commit
message.

**Description** — four short blocks, no template theater:

```
What:     one or two sentences — the change as shipped
Why:      link to the scope/design doc (or one sentence when none exists)
Testing:  what was run and where (suite, stand walk, repro test) —
          and what was NOT verified, stated explicitly
Rollback: how to undo (revert is the default answer; say so if it isn't —
          e.g. a migration that needs the contract step)
```

Rules:

1. **One PR = one flow stage's output.** A feature lands as one reviewable
   PR (or a short stack); a hotfix is its own PR. Never bundle an unrelated
   "while I was here".
2. **Small enough to review honestly.** If the diff exceeds what a reviewer
   can actually read (~400 lines of non-generated change is the practical
   ceiling), split it — stacked PRs beat a rubber stamp.
3. **CI green is an entry condition for review**, not a post-review chore.
   Draft status while red or incomplete; mark ready only when it's
   reviewable.
4. **Gates map to approvals.** The flow's gate verdicts land as PR
   approvals: developer review always; security-auditor approval when the
   diff touches auth/input/SQL/secrets/PII; devops approval when it touches
   migrations/config/deploy. A BLOCKED verdict is a requested-changes
   review, not a comment.
5. **The author never merges over an unresolved finding.** Findings are
   fixed or explicitly risk-accepted by the gate owner in the PR thread —
   the thread is the audit trail.
6. **No self-merge**, with one exception: a hotfix under the fast flow may
   be merged by its author after CI + one post-factum review is requested —
   the review still happens, after the fire.
7. **Squash-merge by default** — main history is one commit per PR,
   revertable as a unit. Keep merge commits only for stacked PRs where
   intermediate history matters.
8. **Re-request review after force-push.** A force-push invalidates prior
   approvals; re-request instead of merging on a stale approval.
9. **Delete the branch on merge**; a PR open longer than a few days is
   re-scoped or closed — stale PRs rot into merge-conflict archaeology.
10. **Generated-file and docs updates ride the same PR** as their source
    (commit rule 6 — CI verifies staleness).

## 9. Scaling the process down

A two-person team building an MVP runs the same flows with the ceremony
collapsed:

- One person holds several roles — the **gates become deliberate second
  passes** with the relevant checklist, not meetings, and not omissions.
- Design docs become ten-line ticket comments. Fine. The test is unchanged:
  could someone else implement/operate from what's written?
- The test stand may be a locally composed stack (`docker compose up`). Fine.
  What's not fine is releasing what was never run composed.
- What never collapses: the §1 never-skip list, the F3 reproduction test, the
  release record, and the rule that docs updated in §3.11 tell the truth.

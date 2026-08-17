# Development Flow — principles and roles

## 1. Principles

**Product first.** Client-facing product development is prioritized over a
sufficient dev stack. A "pure" dev stack — no dedicated test stand, no QA
team, manual deploys — is an acceptable state for a young product. Process
weight scales with the system: the flows below describe the full ceremony, §9
(`devflow/5-git.md`) defines what a stripped-down version may and may not
drop, and §10 (`devflow/6-asap-flow.md`) is the smallest flow that is still a
flow — one pass, one person, for work that must land now.

**Some things are never skipped**, whatever the stack maturity:

1. **Development best practices** — the engineering constraints in `webapp/`:
   client input validated at the boundary, every dynamic value bound as a SQL
   parameter, secrets out of code, errors handled rather than swallowed, no
   authorization check weakened. Skipping them saves days and costs months.
2. **Security practices for client secrets** — credential handling, encryption
   at rest, audit of access to sensitive data (`webapp/5-security.md`). A young product
   is exactly the one that cannot survive a leak.
3. **System observability** — you cannot operate what you cannot see (§6,
   `devflow/4-never-skip.md`).
4. **Release speed** — the ability to deliver a fix fast is itself a safety
   property (§7, `devflow/4-never-skip.md`).

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

**A pattern is not a constraint.** `webapp/` carries both and they answer to
different authorities. A **constraint** — the never-skip list above — holds in
every project; deviating from one is a vulnerability and needs a written reason.
A **pattern** — the four backend layers, ports on the service, FSD slices on the
frontend — is how this reference builds one, and a project that already builds
differently keeps its own architecture: consistency with the surrounding code
beats the pattern in these files (§10.4, `devflow/6-asap-flow.md`). What a
project's architecture never buys is relief from a constraint — a different
layering, an ORM or a framework convention still owes a parameterized query and
a validated boundary.

**Minimize process, not gates.** The target is the cheapest flow that still
clears the gates the change actually triggers (§14, `devflow/10-flow-cost.md`);
the trigger list decides that (§10.2, `devflow/6-asap-flow.md`), not how large
the request sounds. Work that reduces no real risk is not diligence, it is cost
— do not open a stage to look thorough, and do not manufacture an artifact a
rule did not ask for. The one thing this never licenses is dropping a gate the
change *did* trigger: a triggered gate is compressed, not skipped, and whatever
was compressed or left unverified is named in the hand-back.

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
| Fullstack (asap) | `asap` | small urgent work end-to-end in one pass — every hat at once, under the §10 floor (`devflow/6-asap-flow.md`) and its escalation triggers |

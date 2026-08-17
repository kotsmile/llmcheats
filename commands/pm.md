---
description: Deliver work through the full llmcheats team — this session is the project manager: intake, flow choice, gates, status and validation, specialists launched directly
argument-hint: <what to deliver> [--full to force the full flow]
disable-model-invocation: true
---

Run the standard llmcheats flow on the request below. **You are the project
manager for this flow.** You hold intake, the flow choice, every gate, operator
communication and final validation — and you launch each specialist yourself.

Do **not** hand the orchestration to `project-manager` or `dev-team` here. The
running-agent indicator only names agents this session launched itself;
anything deeper collapses into `(+N)`, so a delegated chain shows the operator
`project-manager (+2)` and never the `golang-developer` that is actually
running (`devflow/7-flow-visibility.md`). Launching the specialists from here
puts each of them in the indicator by name.

**Request:** $ARGUMENTS

## 1. Intake

1. If the request is empty, ask what to deliver — one sentence — and stop.
2. **Declare the autonomy level in one line before anything starts**: is the
   operator watching live, reachable for approvals, or away? If you do not
   know, say "the operator is in the loop — plan approvals get surfaced, not
   self-approved". Repeat that line in every delegation; it decides who holds
   the plan-approval gate.
3. Restate the goal and the constraints in one or two sentences. Get
   confirmation if your restatement adds interpretation.
4. **If the request is to continue, resume, or finish something already
   underway** — including anything picked up after a stopped run — take the
   inventory *first* (`devflow/8-resuming.md`): what is committed, what is
   written but uncommitted, which plan artifacts exist, which gates already
   have verdicts. Report in two sentences what you found and which stages you
   are skipping as already done. A resume treated as a fresh request gets the
   same phase planned for the fourth time.

## 2. Choose the flow, then read it

- **Full flow** (`devflow/2-full-flow.md`) — feature, migration, behavior
  change, anything with product surface.
- **Fast flow** (`devflow/3-fast-flow.md`) — an agreed-correct behavior is
  broken. If deciding what "correct" means is part of the fix, it is a feature.
- Too small for either? Say so and use `/llmcheats:asap`
  (`devflow/6-asap-flow.md`) instead of opening a flow around it.

**Choose the cheapest flow that still clears the gates this change actually
triggers** (`devflow/10-flow-cost.md`). The full flow is 13 fresh contexts and
the asap flow is one, so the choice you make here sets the bill for everything
after it. The test is the trigger list in `devflow/6-asap-flow.md` §10.2 — the
one list, read there rather than from a copy — not how large the request sounds.
If the docs are unavailable, treat auth, secrets, payments, PII, migrations,
deploys, product surface, a published contract and an oversized diff as that
list.
Downgrading later is allowed and is not a failure: if the architecture stage
finds the change is a config knob, say so in one line and re-flow it down
instead of finishing nine more stages around it.

**Whenever the flow is the full flow, run the per-stage skip gates**
(`devflow/2-full-flow.md` §3.14) before you delegate anything: answer each
stage's skip test here, in this context, and print one `⊘ SKIPPED: <reason>` line
per stage you close unopened. This holds whether you chose the full flow or the
operator **forced** it — `--full`, "run the whole flow", or work that will run for
hours unsupervised, which you honor without re-choosing. Either way it buys the
gates, not thirteen contexts of ceremony, and a gate this change *does* trigger
is compressed, never skipped.

State which flow you chose and why, then read **exactly that one file** — not
both, not the tree, not `INDEX.md`. Docs live in the first of these that
exists: `<project>/.claude/llmcheats/docs/`, `~/.claude/llmcheats/docs/`,
`~/.codex/llmcheats/docs/`. If none exist, say so explicitly and run from the
stage names below — never invent a stage or a gate.

Full flow: scope → product design → architecture → security design approval →
devops design approval → plan approval (optional) → development → testing →
security implementation approval → devops release readiness → docs → product
review → release. Fast flow: scope → infra inspection → development → testing
→ security approval → devops approval → release.

## 3. Launch each specialist yourself, in the background

One `Task` call per stage, `subagent_type` set to the specialist that owns it,
**run in the background** so the stage is named in the indicator and fires a
completion notification. Then:

- **A background result is an identifier, not a verdict.** It means launched.
  Wait for the completion notification and read the hand-back before the stage
  is closed (`devflow/7-flow-visibility.md`).
- **Never paste doc contents into a delegation.** Each specialist's own
  definition names the doc files it reads; add `devflow/9-agent-io.md` to every
  read-heavy delegation and let it do its own reading. A pasted doc is paid for
  twice and breaks the cached prefix that would have made the second pass cheap
  (`devflow/10-flow-cost.md`).
- **Tier the model per stage on the `Task` call**, not per agent. Pass the cheap
  tier where the output is looked up, transcribed, or mechanically checked — an
  inventory, a docs update whose content was decided elsewhere, a formatting
  pass. Leave `model` unset, so the specialist inherits the operator's choice,
  wherever a wrong answer is expensive and does not look wrong: architecture,
  security judgment, the acceptance-criteria walk. If a cheap-tier stage has to
  be redone, run it at the operator's tier and say that you moved it.
- **Ask for the summary, not the transcript.** A specialist's context is its own
  — that is the saving. Tell it to hand back the verdict, the artifact paths and
  what it could not verify, and to leave file contents, full diffs and raw tool
  output in its own context where you do not pay for them.
- **Parallelism buys wall clock, never tokens**, so use it only where the gates
  already allow it: the two design audits (security and devops read the same
  design doc and neither feeds the other), backend and frontend development once
  the API contract is fixed, and the three docs owners updating the documents
  they each own. Everything else is sequential — the next stage's input is the
  previous stage's output. Two branches that would read the same files to answer
  the same question are one delegation, not two.

## 4. Report every stage as a status line

Emit one line when a stage starts and one when it closes, and keep the block
current — this is the operator's only view of a flow that now runs from here:

```
stage 3 · architecture  ✓ docs/plans/supply-p4.md  (architecture-designer)
stage 4 · implement     ▸ golang-developer, 2m
```

`▸` running with elapsed minutes, `✓` closed with the artifact path, `!`
blocked or re-gating with the round number, `⊘` closed unopened by a skip gate
with its reason. **Every line names who did the work
and where the artifact landed.** A closed stage with no path is not closed: ask
the specialist for the path (`devflow/8-resuming.md` — the plan is a file).
Twenty minutes with nothing sent up is a defect; send stage, elapsed time and
what you are waiting on.

## 5. You do not touch project files while this flow is open

You hold Write and Edit in this session, and that is exactly the trap: an
orchestrator that starts implementing removes every gate at once — no
architecture, no security approval, no independent review of the code it just
wrote (`devflow/8-resuming.md`).

**While a flow is open you do not create or edit any project file.** Not a fix
"the developer missed", not the last file of a phase, not a one-line
correction. Your writes are the status block, the report, and nothing else.

**If you are about to edit a project file: STOP.** Relaunch the specialist that
owns it with what went wrong, or tell the operator in two sentences that the
chain will not converge and what you recommend. "Continuing directly, the chain
kept re-planning" is the failure this command exists to prevent, not a rescue.

## 6. Hold the gates

- A gate is a written verdict from the owning specialist: **APPROVED** /
  **APPROVED_WITH_FINDINGS** (MINOR findings become follow-ups) / **BLOCKED**
  (any BLOCKER or MAJOR). Record stage, verdict and key findings as you go.
- Findings go back to the producing stage and re-gate. **Every re-gate carries
  its round number** from round 1, and so does every re-plan.
- **Escalation bound:** after two failed rounds on the same finding, stop and
  put both positions in front of the operator. There is no round 3 on a plan —
  show the existing plan instead of commissioning another. The bound is a cost
  control as much as a patience one: a re-run stage costs everything it cost the
  first time and produces nothing new (`devflow/10-flow-cost.md`).
- Anything needing a product decision goes to the operator, never to a guess.
  Never skip a gate the change **triggers**, to save time; tell the gate owner the
  scope is small and ask for a proportionate review. A stage the change does not
  reach at all is the skip gate's business, not this rule's, and it closes with
  its reason printed.

## 7. Validate, then report

Before you report done: every acceptance criterion has a verdict from product
review rather than from its implementer; every gate has a recorded verdict or a
recorded `⊘ SKIPPED: <reason>`, with no stage simply absent, and nothing shipped
over a BLOCKED; the artifacts exist as files at the paths you
were given; no stage ran twice on the same scope without a stated reason; and
the code was written by the specialists.

Final report — two sentences of summary, then the table: goal, per-gate
verdicts, **every stage a skip gate closed unopened with its reason**, who held
each approval, artifacts with paths, open follow-ups, and
for a release the version and the one-command rollback. **Carry every
specialist's "what was NOT verified" into it, gate by gate.** Never soften a
BLOCKED verdict, and never report a prediction as a result.

`/llmcheats:status` shows the flow from the sidecar transcripts, and
`/llmcheats:agents <name>` opens one stage that has gone quiet.

---
title: Skip gates — running the full flow without paying for all thirteen stages
summary: Each full-flow stage carries one skip test answered at intake; a stage whose test is met closes before it opens, and the verdict is printed rather than silent.
keywords: [skip gate, skip test, intake, forced full flow, stage closed, recorded verdict, compressed gate, downgrading, reopened stage, trigger list]
related:
  - devflow/full-flow.md
  - devflow/flow-cost.md
  - devflow/asap-flow.md
  - devflow/principles.md
  - devflow/project-memory.md
---

# Skip gates — running the full flow without paying for all thirteen stages

## Why skip gates exist

The full flow is 13 fresh contexts (`devflow/flow-cost.md`), and an operator who
**forces** it — because the gates are wanted unconditionally, or because the
work will run for hours without supervision — should get the gates, not
thirteen contexts of ceremony.

So each stage carries a **skip gate**: one test, answered at intake, and a stage
whose test is met closes before it opens.

This applies to **every** full-flow run, forced or chosen: a flow picked on its
merits still has stages this particular change does not reach.

## The skip test per stage

| Stage                              | Skip it only when                                                                                                                                                                                                                                                                                                           |
| ---------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 1 Scope                            | the request already states the problem and testable done-conditions; restate them in two sentences instead of opening a stage                                                                                                                                                                                               |
| 2 Product design                   | nothing user-visible changes — no screen, no copy, no surface a consumer sees                                                                                                                                                                                                                                               |
| 3 Architecture                     | a plan for this scope is already on disk (`devflow/resuming.md`), the change is one file inside a pattern the codebase already repeats, or the conventions it must follow are already recorded in project memory (`devflow/project-memory.md`) — which is how a project that writes its decisions down plans less over time |
| 4 Security design approval         | the change reaches nothing on the trigger list in `devflow/asap-flow.md` — no auth, sessions, tokens, crypto, secrets, PII, payments, new input source or new route                                                                                                                                                         |
| 5 DevOps design approval           | no migration, no config or secret change, no new infra, no deploy-order dependency — **and** the change needs no new metric, log or alert and already has a rollback story. Observability is a never-skip item (`devflow/principles.md`): a change that needs a new signal opens this stage whatever else is true           |
| 6 Plan approval                    | already conditional — the operator is watching the work live                                                                                                                                                                                                                                                                |
| 8 Testing                          | never skipped; the *manual* walk collapses into the suite when every acceptance criterion has an automated test                                                                                                                                                                                                             |
| 9 Security implementation approval | stage 4 was skipped **and** the diff added no route, query, or input path                                                                                                                                                                                                                                                   |
| 10 DevOps release readiness        | stage 5 was skipped **and** the diff adds no migration, config change, or deploy step                                                                                                                                                                                                                                       |
| 11 Documentation                   | no touched component's README, API doc or runbook is now wrong — checked, not assumed — **and** the change established no convention or decision worth recording in project memory                                                                                                                                          |
| 12 Product review                  | stage 2 was skipped **and** every acceptance criterion is mechanically verifiable                                                                                                                                                                                                                                           |
| 13 Release                         | the change does not deploy                                                                                                                                                                                                                                                                                                  |

Stage 7 has no row: development is the work.

## Rules for skipping

- **A skipped stage is a recorded verdict, not an absence.** One line per stage,
  printed at intake with its reason — `stage 5 · devops design ⊘ SKIPPED: no
  migration, no config change`. A stage nobody mentioned was forgotten, and the
  operator cannot tell the two apart afterwards.
- **A triggered gate is compressed, never skipped.** The tests above skip stages
  the change does not reach; they never drop one it does. Tell the gate owner
  the scope is small and ask for a proportionate review
  (`devflow/principles.md`).
- **Skipping is not downgrading.** Downgrading moves the whole change to a
  cheaper flow (`devflow/flow-cost.md`); this keeps the full flow and drops the
  stages its triggers do not reach. Forcing the full flow is what makes the
  difference explicit.
- **A lost bet costs one stage, not the flow.** If development turns up a
  migration nobody planned, stages 5 and 10 reopen — name the stage that
  reopened and why. Re-checking the trigger list mid-flow is already mandatory
  (`devflow/asap-flow.md`).

The skip gate itself opens no context: the questions are answered in the intake
context that is already running, and each "no" removes a whole stage's context
from the bill. **Every row is answered from this table — open nothing to answer
one**; the files named above are where a *disputed* skip gets settled, not where
the test lives.

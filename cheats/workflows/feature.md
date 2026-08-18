---
name: feature
description: "feature: build new user-visible behavior. Use for a prompt starting feature:, or any request to add a capability, endpoint, screen or flow. Runs the full flow with skip gates."
---

# `feature:` — full flow

<!-- F-010 -->
Thirteen stages, most of which this change will not reach. Run the skip gates
first: a stage whose test is met **closes before it opens**, and the verdict is
printed rather than silent.

## 1. Intake — print the skip verdicts

<!-- F-019 --><!-- F-021 -->
Answer every row from this table. Open nothing to answer one. Print one line per
stage, including the skipped ones.

```
stage 2 · product design ⊘ SKIPPED: nothing user-visible changes
stage 5 · devops design   ● OPEN:    adds a migration
```

| Stage             | Skip it only when                                                                                                                                                  |
| ----------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| 1 Scope           | the request already states the problem and testable done-conditions                                                                                                |
| 2 Product design  | nothing user-visible changes — no screen, no copy, no consumer surface                                                                                             |
| 3 Architecture    | a plan is already on disk, or the change is one file inside a pattern the repo already repeats, or the conventions are already in `AGENTS.md`                      |
| 4 Security design | the change reaches nothing on the trigger list in `routing.md`                                                                                                     |
| 5 DevOps design   | no migration, no config or secret change, no new infra, no deploy-order dependency — **and** it needs no new metric, log or alert and already has a rollback story |
| 6 Plan approval   | the operator is watching the work live                                                                                                                             |
| 8 Testing         | never skipped; the *manual* walk collapses when every criterion has an automated test                                                                              |
| 9 Security impl   | stage 4 was skipped **and** the diff added no route, query or input path                                                                                           |
| 10 DevOps release | stage 5 was skipped **and** the diff adds no migration, config change or deploy step                                                                               |
| 11 Documentation  | no touched README, API doc or runbook is now wrong — checked, not assumed — **and** the change established no convention worth recording                           |
| 12 Product review | stage 2 was skipped **and** every criterion is mechanically verifiable                                                                                             |
| 13 Release        | the change does not deploy                                                                                                                                         |

<!-- F-020 -->
A **triggered** gate is compressed, never skipped. Tell the gate owner the scope
is small and ask for a proportionate review. Whatever was compressed is named in
the hand-back.

## 2. Scope

Problem statement: who hurts, how, and how we will know it stopped. Testable
acceptance criteria, enumerated. Explicit non-goals.

**Gate:** the problem can be restated without mentioning the solution.

## 3. Architecture

<!-- F-022 -->
Read `stack.md`, then the `docs/` files it points at for the layers you touch.

Write the plan **to a path in the repo** — `docs/plans/<slug>.md` or whatever
this repo already uses. A plan that exists only as a message dies with the agent
that sent it. Report the path.

<!-- F-029 -->
Cap: **12 KB**. Over it, split into phases and plan the first. Do not restate
code the reader can open; name the file, name what changes, stop.

Contents: files to create or touch; the API contract (endpoints, DTOs, error
reasons); schema changes as **expand → migrate → contract**; risks; the rollback
story.

**Gate:** someone who was not in the discussion could implement from it.

## 4. Security and devops design review

Open these only if the trigger list says so. Both read the *design*, before code
exists — this is the cheap moment to fix an authz model.

<!-- F-029 -->
Cap: **8 KB** each. A feature with no rollback story does not proceed.

## 5. Build

<!-- F-038 -->
Extend the pattern already in the repo. Consistency with neighbours beats
anything in `docs/`.

<!-- F-012 -->
`practices/floor.md` is binding throughout and is not a judgment call.

Tests alongside, in the order in `practices/testing.md`, each stating its reason.

**Gate:** build, lint and the affected tests pass — run, not assumed.

## 6. Verify

Walk every acceptance criterion. Regression-check the adjacent flows.

<!-- F-014 -->
Whatever you could not run is named. An unrun path is never reported as passing.

## 7. Documentation

<!-- F-007 -->
Update only what is now wrong. Then: did this change establish a convention or a
decision the next session must know? If yes, write it into `AGENTS.md` per
`practices/project-memory.md`. The trigger is a repeat, not a first occurrence.

## 8. Hand-back

<!-- F-013 -->
```
Changed:      files touched, one line each
Ran:          build / lint / tests / manual check, and what they said
Not verified: what you could not exercise, explicitly
Skipped:      follow-ups consciously left, and every gate compressed
```

<!-- F-066 -->
Do not commit unless asked. Commit ≠ deliver.

---
title: Asap flow — small work, one person, one pass
summary: The smallest flow that is still a flow — one sentence of intake, build, verify, four-line hand-back — with an escalation trigger list and a floor that never moves.
keywords: [asap flow, one pass, small work, glue, spike, escalation triggers, published contract, intake, finish it, verify, hand-back, not verified, floor, never skip, hotfix commit]
related:
  - devflow/principles.md
  - devflow/full-flow.md
  - devflow/fast-flow.md
  - devflow/git.md
  - devflow/flow-cost.md
---

# Asap flow — small work, one person, one pass

The third flow, and the smallest. The full flow designs before it builds
(`devflow/full-flow.md`); the fast flow fixes an agreed-broken behavior
(`devflow/fast-flow.md`); the **asap flow delivers a small piece of work in a
single pass**, with one person — or one agent, `asap` — holding every hat.

Target duration: **minutes**. Work that cannot plausibly finish in one sitting
is not asap work; it is a feature wearing a hurry.

This flow is a deliberate trade, and it is written down so the trade is visible:
you give up the design artifact, the independent product review, and the
separate security and devops gates. You do **not** give up the never-skip list
in `devflow/principles.md`, and you do not give up knowing what you did not
verify.

## When the asap flow applies

- A small feature or tweak inside patterns that already exist in the codebase.
- Glue: wiring an existing endpoint to an existing screen, a config knob, a
  script, a one-off migration of *local* data.
- Spikes, prototypes, internal tooling, developer experience.
- Anything where a wrong answer is cheap and instantly visible.

## When to hand back to another flow

This is the trigger list the rest of the reference points at.

- Auth, sessions, tokens, crypto, secrets, payments, PII.
- Schema migrations, data backfills, anything irreversible on real data.
- Production deploys, infra topology, anything needing a rollback story.
- Public product surface, or any task where *what correct means* is still open
  — that is a product decision, and it is not the implementer's to make.
- **A published contract**: a request or response shape, an event payload, a
  generated client, a shared library's exported signature. The consumer is
  someone else's code and it is not in this diff, so the change cannot be
  verified in one pass — which is the whole premise of this flow.
- Anything whose diff outgrows what a reviewer reads in one sitting
  (`devflow/git.md`).

The trigger list is checked **at intake and again mid-task**: an asap task that
grows into one of these stops and is re-flowed. That is a normal outcome, not a
failure.

## A1 — Intake in one sentence

State the task and what "done" looks like, in one sentence, and start. No scope
doc, no acceptance-criteria table, no plan-approval gate: if the operator is
watching, the sentence *is* the plan; if they are away, it is still a statement,
not a request — the escalation triggers above are what protects them, not an
approval round-trip.

## A2 — Build

- Read the surrounding code first. Extend the pattern that is already there;
  consistency with neighbours beats the pattern you would have chosen.
- The smallest change that fully does the job. No opportunistic refactor.
- **Finish it.** No TODO stubs, no half-wired path. Work delivered at 80% is
  work the operator now has to finish, which is the opposite of fast.

## A3 — Verify

- Build, lint, and the tests around the change — run, not assumed.
- Fixing a defect under this flow still means the **reproduction test is written
  first** and fails before the fix (`devflow/fast-flow.md`; it does not
  collapse).
- New behavior gets a test on the terms in `webapp/testing-strategy.md` — worth
  protecting, not merely changed. Skip it for a spike or a throwaway script, and
  *say* you skipped it.
- Whatever you could not run is named. An unrun path is never reported as
  passing.

## A4 — Hand-back

Four lines, no ceremony:

```
Changed:      files touched, one line each
Ran:          build / lint / tests / manual check, and what they said
Not verified: what you could not exercise, explicitly
Skipped:      follow-ups you consciously left (the refactor, the doc, the test)
```

## The floor the asap flow never crosses

Speed buys the ceremony, never these:

- Secrets are never hardcoded, logged, or committed.
- SQL is parameterized; client input is validated at the boundary.
- No auth or authz check is weakened, bypassed, or temporarily disabled.
- No test is deleted or skipped, and no `//nolint` / `# noqa` /
  `eslint-disable` is added, to make a build green.
- Errors are handled or returned, never swallowed.
- Nothing destructive touches shared or production state without an explicit
  go-ahead: no drop, truncate, mass delete, force-push, or deploy.

A task that cannot be done without breaking one of these is an escalation, not a
judgment call. This is the never-skip list of `devflow/principles.md` at asap
scale — the ceremony scales down, the floor does not.

## Git under the asap flow

`hotfix:`-style single-line commits per `devflow/git.md`, one logical change,
green before commit. An asap change still arrives via a PR when the repo
requires one; what it may skip is the *gate approvals* that its scope does not
trigger — and if it triggers them, it was never an asap task.

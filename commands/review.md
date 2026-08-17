---
description: Review a finished change through both llmcheats review lenses — code/architecture (code-reviewer) and security (security-auditor) — and aggregate one verdict. Use on a feature-sized diff after the work is done. Do NOT use inside a running /llmcheats:pm flow, which gates its own diff, and not to fix what the review returns.
argument-hint: [range, PR, or diff to review — defaults to the working tree]
---

Review the code below through both llmcheats review lenses. **You are the review
lead.** You establish the range, launch both reviewers, aggregate one verdict and
report it. You do **not** review the code yourself and you do **not** fix what
comes back.

**What to review:** $ARGUMENTS

## 1. Establish the range, once

If the argument is empty, review the working tree against the branch point.
**Aim it at a whole feature, not at each increment**: layering, a contract's
consumers and test coverage are not visible in a three-line commit, and every
separate invocation pays for both contexts again. Batching the work and reviewing
once is faster and finds more than reviewing as you go.
Resolve the range here — `git diff --stat`, `git log --oneline` — and pass the
**same range** to both reviewers as a range, never as a pasted diff: they read
the repository themselves, and a pasted diff is paid for twice and breaks the
cached prefix (`devflow/10-flow-cost.md`). If the range is empty, say so in one
sentence and stop.

Name the plan if there is one (`docs/plans/`), so the reviewers can check the
diff against what was designed rather than against their own taste.

## 2. Launch both reviewers in parallel, in the background

Two `Task` calls in **one block**, both `run_in_background`, so each is named in
the running-agent indicator and fires its own completion notification
(`devflow/7-flow-visibility.md`):

- `subagent_type: code-reviewer` — layers and dependency direction, transactions
  and invariants, contract compatibility, migration safety, errors and
  boundaries, tests worth their reason, scope creep.
- `subagent_type: security-auditor` — the implementation review of
  `webapp/5-security.md` plus the Security block of `webapp/8-checklist.md`
  against the actual code.

They read the same files to answer different questions, so this is the one
fan-out that is worth its second context; parallel here buys wall clock, not
tokens (`devflow/10-flow-cost.md`). Leave `model` unset on both — a review is
where a wrong answer is expensive and does not look wrong.

**A background result is an identifier, not a verdict.** It means launched. Wait
for each completion notification, and report each verdict upward as it lands
rather than batching both to the end.

## 3. Aggregate one verdict

Both reviewers use the same gate scale, so combine them mechanically: any
**BLOCKED** blocks; otherwise any MINOR finding makes it
**APPROVED_WITH_FINDINGS**; otherwise **APPROVED**. Report:

- the aggregate verdict and the range that was reviewed;
- findings most severe first, each with its `file:line`, its severity and which
  reviewer raised it — **quoted as written, never softened**;
- the union of both reviewers' **Not verified** blocks;
- findings either reviewer handed to another owner (`devops`,
  `product-designer`) rather than adjudicating.

## 4. You do not fix what came back

A review that edits the code it just reviewed has no reviewer left. Hand the
findings to the operator: a MINOR list is a follow-up, a BLOCKER goes to
`/llmcheats:asap` for a contained fix or `/llmcheats:pm` when the fix reopens a
design decision.

**A re-review after a fix is round 2 and says so**, because it costs both
contexts again. A third round on the same finding is a design problem, not a
review problem — state both positions and give the operator the decision
(`devflow/10-flow-cost.md` §14.6).

This is two contexts against the full flow's thirteen
(`devflow/10-flow-cost.md`), and it is **not** a fourteenth full-flow stage. What
`/llmcheats:pm` gates is security (`devflow/2-full-flow.md` §3.9) and release
readiness (§3.10); the code lens is the one its thirteen stages do not hold, so
running this after a flow is legitimate rather than duplicated work. It is also
the whole review path when there was no flow — code written by plain prompts, by
another tool, or by someone else, gated by nothing so far.

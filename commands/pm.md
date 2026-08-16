---
description: Deliver work through the full llmcheats team — project-manager holds intake, tracking, gates and validation
argument-hint: <what to deliver>
---

Run the standard llmcheats flow on the request below. `project-manager` is the
single point of contact; it engages `dev-team`, which picks the full flow
(`devflow/2-full-flow.md`) or the fast flow (`devflow/3-fast-flow.md`) and holds
every gate.

**Request:** $ARGUMENTS

1. If the request is empty, ask what to deliver — one sentence — and stop.
2. Launch `project-manager` (Task tool, `subagent_type: project-manager`) with
   the request **verbatim**, plus the autonomy level: is the operator watching
   live, reachable for approvals, or away? If you do not know, tell it "the
   operator is in the loop — surface plan approvals rather than self-approving".
3. Do not do the work yourself, and do not call the specialists directly.
   Everything goes through `project-manager`: relay its questions up to the
   operator and their answers back down, in one or two sentences each way.
4. Report its final table as it returned it — goal, per-gate verdicts, who held
   each approval, open follow-ups, and for a release the version and the
   one-command rollback. Two sentences of summary on top, detail below. Never
   soften a BLOCKED verdict, and never report a prediction as a result.

Use `/llmcheats:status` while this runs to see where it is, and
`/llmcheats:agents <name>` when one stage goes quiet. If the operator wanted
this *fast* rather than *gated*, `/llmcheats:asap` is the right command.

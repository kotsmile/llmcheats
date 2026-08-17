---
description: Deliver a small task now — the llmcheats asap flow, one agent, no design docs, no gate rounds
argument-hint: <what to do>
disable-model-invocation: true
---

Deliver the task below on the asap flow (`devflow/6-asap-flow.md`): one agent,
one pass, no design doc, no separate security or devops gate.

**Task:** $ARGUMENTS

1. If the task is empty, ask what to do — one sentence — and stop.
2. Launch the `asap` agent (Task tool, `subagent_type: asap`) with the task
   **verbatim**. Do not pre-plan it, do not decompose it across specialists, do
   not open the reference docs on its behalf — skipping exactly that is what
   this command is for.
3. If it escalates — on any trigger in `devflow/6-asap-flow.md` §10.2, which is
   the one list, not a copy of it — relay the escalation to the operator in one
   sentence and offer `/llmcheats:pm`. Do not push past it, and do not re-launch
   it with the trigger removed from the prompt.
4. Report exactly what it hands back: files changed, what was run and what it
   said, **what was not verified**, and the follow-ups it deliberately skipped.
   Do not upgrade "not verified" into "works".

The floor still applies at this speed: no committed secrets, no weakened
authz, no test deleted to make a build green, nothing destructive against
shared state without an explicit go-ahead.

This is one context against the full flow's thirteen, which is most of why it
exists (`devflow/10-flow-cost.md`). Keep it that way: do not add a review pass,
a second opinion, or a design step to make the result feel safer. A task that
needs those needs `/llmcheats:pm`, and a one-pass flow wearing extra stages is
the most expensive way to deliver either one.

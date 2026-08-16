---
description: Deliver a small task now — the llmcheats asap flow, one agent, no design docs, no gate rounds
argument-hint: <what to do>
---

Deliver the task below on the asap flow (`devflow/6-asap-flow.md`): one agent,
one pass, no design doc, no separate security or devops gate.

**Task:** $ARGUMENTS

1. If the task is empty, ask what to do — one sentence — and stop.
2. Launch the `asap` agent (Task tool, `subagent_type: asap`) with the task
   **verbatim**. Do not pre-plan it, do not decompose it across specialists, do
   not open the reference docs on its behalf — skipping exactly that is what
   this command is for.
3. If it escalates — auth, secrets, payments, PII, a migration, a production
   deploy, or a task that turns out to need a product decision — relay the
   escalation to the operator in one sentence and offer `/pm`. Do not push past
   it, and do not re-launch it with the trigger removed from the prompt.
4. Report exactly what it hands back: files changed, what was run and what it
   said, **what was not verified**, and the follow-ups it deliberately skipped.
   Do not upgrade "not verified" into "works".

The floor still applies at this speed: no committed secrets, no weakened
authz, no test deleted to make a build green, nothing destructive against
shared state without an explicit go-ahead.

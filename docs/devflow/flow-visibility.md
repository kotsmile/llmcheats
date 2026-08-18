---
title: Flow visibility — is anything actually happening?
summary: A flow the operator cannot observe is not being run; report at every stage transition, count gate rounds out loud, poll background agents, and read agent state off disk.
keywords: [visibility, operator, reporting cadence, twenty minutes, silence, gate round, escalation, background agent, polling, hand-back, summarize upward, running-agent indicator, subagents directory, spawnDepth, stoppedByUser, orchestration depth]
related:
  - devflow/resuming.md
  - devflow/agent-io.md
  - devflow/flow-cost.md
  - devflow/principles.md
---

# Flow visibility — is anything actually happening?

Every other section is about doing the work right. This one is about the
operator being able to *see* it — which is a separate property, and the one that
fails silently.

It is written from a run that went wrong in exactly that way: a full flow, 17
agents, three levels deep, 1h30m with nothing reaching the operator. Nothing was
broken. A gate had looped six times, and the orchestrator's report was written
and never delivered. Both were visible on disk the whole time.

**A flow the operator cannot observe is not being run — it is being hoped for.**

## The operator's clock

The gate you have not reported does not exist. Report at **every stage
transition**, in one or two sentences: stage, verdict, what starts next.

**Twenty minutes of silence is a defect**, whatever is happening underneath. Not
a warning sign — a defect, with the same standing as a failing test. If twenty
minutes pass with nothing sent up, send what you have: current stage, elapsed
time, and what you are waiting on. "Still working" is not a status; it carries
no information the operator did not already have.

This is not a request for narration. Two sentences on a transition is the whole
obligation, and it costs less than the one message that explains a lost hour.

## Counting gate rounds out loud

Every re-gate carries its round number in the report line: `security re-gate,
round 2 — BLOCKED, one MAJOR`. From round 1, not from the round it starts
hurting.

The orchestrator's escalation bound — two failed re-gates on the same finding,
then stop and escalate with both positions stated — is only enforceable if the
count is visible from outside. Uncounted, round 6 looks exactly like round 1: an
agent working. In the run this section comes from, the same two gates blocked the
same phase three times each, and no one saw a loop because no line ever said
"round".

**Round 3 is not a status, it is an escalation that already happened.** State
both positions and hand the decision to the operator.

## Tracking background agents

Launching an agent in the background returns a result in seconds. That result is
its identifier. It means *launched* — never *finished*, never *succeeded*.
Treating it as completion is the single most effective way to lose an hour.

So:

- **Poll it.** An agent you launched and stopped thinking about is an agent
  whose failure you will discover from the operator.
- **Pull its hand-back explicitly when it finishes.** A report that was written
  but not delivered is an undelivered report; the work in it has not landed.
- **Finished-and-silent is the first thing you check** when a flow looks frozen.
  It is more common than a genuinely stuck agent, and it looks identical from
  the outside.

## Summarizing upward at every hop

`project-manager` → `dev-team` → specialist puts the operator three hops from
the work. Each layer reports **as each child stage completes**, not once at the
end. A layer that batches its reporting until the finish converts every hop
below it into silence.

The rule is per-hop and unconditional: when a child hands back to you, its
verdict is in your next message up. You may compress — a specialist's ten
findings become one line and a verdict — but you may not defer.

## Reading agent state off disk

**The running-agent indicator under the input names only agents the session
launched itself.** Everything deeper collapses into a `(+N)` counter:
`project-manager (+2)` means two descendants are live, with no name, agent type,
task or state for either. An orchestrator that delegates everything therefore
shows up as a single line — in the run this section comes from, five
`project-manager` entries were top level and thirty-one nested agents were only
ever a number. One name in the UI is not evidence that one agent is running, and
`(+N)` is not evidence that the flow is progressing.

The state is on disk. Under
`~/.claude/projects/<cwd-slug>/<session-id>/subagents/`, every agent — at any
nesting depth — writes a live `agent-<id>.jsonl` and an `agent-<id>.meta.json`
carrying its type, description, `spawnDepth`, `parentAgentId`, and
`stoppedByUser`.

That is what `/llmcheats:status` and `/llmcheats:agents` read. Reach for them
before theorizing about a quiet flow: they answer *did it finish*, *what did it
last do*, *how long has it been idle*, and *what did it hand back*, from
observation rather than inference.

An agent's last event tells you its state: an assistant message with no tool call
means it finished, and that message **is** its hand-back. Anything else means it
is mid-turn — unless its meta carries `stoppedByUser` or its last event is an
interrupt, which mean the operator stopped it and nothing will resume it. A
stopped agent looks exactly like a slow one otherwise.

**This subsection describes Claude Code.** Codex has no subagent sidecars and no
`/llmcheats:` commands: under it, the reporting rules above *are* the mechanism,
because nothing else records that the work is progressing.

## Orchestrating at a depth the operator can see

Since the indicator only names what the session launched itself, every nesting
level costs a name. In the run this section comes from, the sidecar metas read
`project-manager` at spawnDepth 1, `dev-team` at 2, and
`architecture-designer`, `golang-developer`, `security-auditor` and `devops` all
at 3 — so the five agents doing the actual work were, to the operator, the `+N`
after one name.

**The stage owner belongs at depth 1.** An orchestrator that only picks the next
stage and holds its gate is not worth a level of nesting: fold that sequencing
into the layer above it and launch the specialists directly, in the background,
so each one is named in the indicator and each completion fires a notification.
That is what `/llmcheats:pm` does — the main session holds intake, flow choice,
gates and validation, and every specialist runs at depth 1.

The trade is real and one-directional: the orchestrating context now carries the
whole flow instead of delegating it away, and it holds Write and Edit. So the
rule in `devflow/resuming.md` — the orchestrator never finishes the work itself
— stops being advice and needs a hard stop: no editing project files while a
flow is open, and a per-stage line naming who did the work and where the
artifact landed.

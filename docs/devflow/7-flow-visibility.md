# Development Flow — flow visibility (is anything actually happening?)

## 11. Flow visibility

Every other section is about doing the work right. This one is about the
operator being able to *see* it — which is a separate property, and the one
that fails silently.

It is written from a run that went wrong in exactly that way: a full flow, 17
agents, three levels deep, 1h30m with nothing reaching the operator. Nothing
was broken. A gate had looped six times, and the orchestrator's report was
written and never delivered. Both were visible on disk the whole time.

**A flow the operator cannot observe is not being run — it is being hoped
for.** Everything below is the minimum that makes it observable.

### 11.1 The operator's clock

The gate you have not reported does not exist. Report at **every stage
transition**, in one or two sentences: stage, verdict, what starts next.

**Twenty minutes of silence is a defect**, whatever is happening underneath.
Not a warning sign — a defect, with the same standing as a failing test. If
twenty minutes pass with nothing sent up, send what you have: current stage,
elapsed time, and what you are waiting on. "Still working" is not a status; it
carries no information the operator did not already have.

This is not a request for narration. Two sentences on a transition is the whole
obligation, and it costs less than the one message that explains a lost hour.

### 11.2 Gate rounds are counted out loud

Every re-gate carries its round number in the report line: `security re-gate,
round 2 — BLOCKED, one MAJOR`. From round 1, not from the round it starts
hurting.

The orchestrator's escalation bound — two failed re-gates on the same finding,
then stop and escalate with both positions stated (`agents/dev-team.md`,
"Holding gates") — is only enforceable if the count is visible from outside.
Uncounted, round 6 looks exactly like round 1: an agent working. In the run
this section comes from, the same two gates blocked the same phase three times
each, and no one saw a loop because no line ever said "round".

**Round 3 is not a status, it is an escalation that already happened.** State
both positions and hand the decision to the operator.

### 11.3 A background agent is not tracked by its result

Launching an agent in the background returns a result in seconds. That result
is its identifier. It means *launched* — never *finished*, never *succeeded*.
Treating it as completion is the single most effective way to lose an hour.

So:

- **Poll it.** An agent you launched and stopped thinking about is an agent
  whose failure you will discover from the operator.
- **Pull its hand-back explicitly when it finishes.** A report that was written
  but not delivered is an undelivered report; the work in it has not landed.
- **Finished-and-silent is the first thing you check** when a flow looks
  frozen. It is more common than a genuinely stuck agent, and it looks
  identical from the outside.

### 11.4 Every hop summarizes upward

`project-manager` → `dev-team` → specialist puts the operator three hops from
the work. Each layer reports **as each child stage completes**, not once at the
end. A layer that batches its reporting until the finish converts every hop
below it into silence.

The rule is per-hop and unconditional: when a child hands back to you, its
verdict is in your next message up. You may compress — a specialist's ten
findings become one line and a verdict — but you may not defer.

### 11.5 Reading the state instead of guessing at it

The state is on disk. Under
`~/.claude/projects/<cwd-slug>/<session-id>/subagents/`, every agent — at any
nesting depth — writes a live `agent-<id>.jsonl` and an `agent-<id>.meta.json`
carrying its type, description, `spawnDepth`, and `parentAgentId`.

That is what `/llmcheats:status` and `/llmcheats:agents` read. Reach for them
before theorizing about a quiet flow: they answer *did it finish*, *what did it
last do*, *how long has it been idle*, and *what did it hand back*, from
observation rather than inference.

An agent's last event tells you its state: an assistant message with no tool
call means it finished, and that message **is** its hand-back. Anything else
means it is mid-turn.

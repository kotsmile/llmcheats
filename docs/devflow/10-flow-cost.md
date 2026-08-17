# Development Flow — what a flow costs

## 14. Flow cost

The same change can be delivered three ways that differ by an order of
magnitude in price. Ceremony is not free and it is not paid in patience — it is
paid in tokens, and the bill is set by decisions taken before any code is
written. `devflow/9-agent-io.md` bounds what **one pass** costs; this section
bounds what **the flow** costs.

### 14.1 The flow choice is the cost decision

Anthropic reports its multi-agent research system consuming about **15× the
tokens of a chat interaction**, with token spend explaining roughly 80% of the
performance difference — the architecture is a way of spending more, and it pays
off only when the task actually needs it
([Anthropic, *How we built our multi-agent research system*](https://www.anthropic.com/engineering/built-multi-agent-research-system)).

The same shape is here. The full flow (`devflow/2-full-flow.md`) is 13 stages,
each a fresh context that re-reads its own doc slice and re-derives what the
previous stage already knew. The asap flow (`devflow/6-asap-flow.md`) is one
pass reading at most one file. Between them sits the fast flow
(`devflow/3-fast-flow.md`) at seven stages.

**Pick the cheapest flow that still clears the gates the change actually
triggers.** The test is the trigger list in `devflow/6-asap-flow.md` §10.2 —
read it there rather than from a copy, and read it before choosing — not how
large the request sounds. A three-line change inside an existing pattern does
not become a feature because it was asked for in a paragraph.

Once the flow **is** the full flow — chosen on its merits or forced by the
operator — the same question is asked per stage instead of per flow: the skip
gates in `devflow/2-full-flow.md` §3.14 close the stages this change does not
reach, each one removing a context from the bill without dropping a gate the
change triggered.

**Downgrading mid-flow is allowed, and it is not a failure.** If the
architecture stage discovers the change is a config knob, say so in one line and
re-flow it down rather than finishing the remaining nine stages around it. The
upward move is already mandatory (§10.2); the downward one has to be explicit or
nobody ever takes it.

### 14.2 Tier the model to the stage, not to the agent

The cheap tier is roughly an order of magnitude below the frontier tier per
token ([Claude pricing](https://claude.com/pricing)), so the tier is worth
choosing deliberately:

- **Cheap tier** where the output is looked up, transcribed, or mechanically
  checked: locating code, collecting an inventory, reformatting a hand-back,
  updating a document whose content was decided elsewhere.
- **Strong tier** where a wrong answer is expensive and does not look wrong:
  architecture, security judgment, the acceptance-criteria walk, anything the
  operator would have to catch personally.

Under Claude Code this is the `model` parameter on the `Task` call, so it is
chosen **per stage**, not baked into the agent. Shipped agents therefore leave
`model` unset and inherit the operator's choice — pinning a specialist up would
overrule the operator, and pinning one down would quietly ship worse code. The
two orchestrators are the exception: they route, gate and report rather than
produce, so they are pinned down.

**The bound:** if a stage run on the cheap tier has to be redone more than about
one time in five, the retries cost more than the tier saved. Move that stage up
permanently and say that you did — a tiering decision that is never revisited
decays as the models change.

### 14.3 A hand-back is a summary, not a transcript

A subagent's context is its own, and that is the whole point: it reads forty
files and the orchestrator never pays for them. That saving is lost the moment
the subagent pastes what it read into its hand-back.

What travels up is the **verdict, the artifact paths, and what was not
verified** — never file contents, never the full diff, never raw tool output.
The artifact is written to a file and the message names the path
(`devflow/8-resuming.md`); a hand-back that inlines the artifact pays for it
twice and still leaves nothing on disk to resume from.

The same rule points the other way, and it is already binding: **never paste doc
contents into a delegation.** Name the file and let the subagent read it — it
has its own context and its own budget.

### 14.4 Prompt caching pays for stable prefixes

Providers cache on an exact prefix match, and a cache read costs a fraction of
the same tokens read fresh
([Anthropic, prompt caching](https://platform.claude.com/docs/en/build-with-claude/prompt-caching)).
Across a flow that re-enters the same agents repeatedly, the agent definition
and the doc slice are the same bytes every time — they should be the cheap part.

They stop being the cheap part when something volatile is placed ahead of them.
A timestamp, a run id, the live status block, or the task text sitting above the
stable instructions changes the prefix on every call and the hit rate collapses.

- **Stable first**: the agent's own definition, the doc file it reads, the
  standing rules.
- **Volatile last**: the task, the current status, anything carrying a round
  number or a clock.

This is the same constraint `webapp/9-ai-features.md` puts on the product's own
system prompts. It applies to the agent files with equal force, and it is a
second reason for the rule in §14.3: a delegation that inlines a doc is also a
delegation whose prefix nobody can cache.

### 14.5 Parallel buys wall clock, not tokens

Fanning out N subagents costs N contexts. It is never cheaper than running the
same stages serially — at best it costs the same tokens sooner, and it usually
costs more, because branches that need the same background each pay for it.

So parallelism is a **latency** decision: run it where the gates already allow
it — the two design audits, backend and frontend once the API contract is fixed,
the three docs owners on the documents they each own — and because the operator
is waiting, not to save money.

**If two branches would read the same files to answer the same question, that is
one pass, not two.** Overlapping context is the fan-out's dominant waste, and it
is invisible in the result: both branches come back correct.

### 14.6 The loops are where the money actually goes

A stage run twice on the same scope costs everything it cost the first time and
produces nothing new. That makes the bounds elsewhere in this reference cost
controls, not just patience controls:

- **Re-planning** is a full stage with no code at the end of it. Bounded at two
  rounds, with the round number carried (`devflow/8-resuming.md`).
- **Re-gating** on the same finding is bounded the same way, and for the same
  reason (`devflow/7-flow-visibility.md`).
- **A resume treated as a fresh request** re-runs the architecture stage against
  scope that already has a plan on disk — the single most expensive mistake in
  this flow, and the reason the inventory comes first
  (`devflow/8-resuming.md`).
- **A pass the operator kills** has spent its full budget and delivered nothing;
  everything it read is discarded with it (`devflow/9-agent-io.md` §13.4). Hand
  back a partial result with the gap named instead.

The cheapest stage remains the one that never had to run. Before opening a
stage, the question is not "is this stage useful" — most are — but "does this
change trigger the gate this stage exists to hold".

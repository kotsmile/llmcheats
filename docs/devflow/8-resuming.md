# Development Flow — resuming an interrupted flow

## 12. Resuming an interrupted flow

A long flow gets interrupted: the operator stops it, a context runs out, a
session ends. What happens next decides whether the run continues or starts
over, and starting over is the default unless something on disk prevents it.

It is written from a run that started over four times. One migration phase was
handed to `project-manager` four times across two hours; each run opened a fresh
flow, each flow delegated the architecture stage again, and four architects
produced four plans for the same phase — 17, 11, 18 and 6 minutes. The third one
finished and was delivered. Forty minutes later a fourth architect was asked to
plan the same work again. No line of code from that phase was ever written, and
the run ended with the top-level agent abandoning the chain to do the work
itself.

Nothing was stuck. Every agent did its job correctly, and the flow still
produced nothing, because **a plan that exists only as a message dies with the
agent that sent it**.

### 12.1 The plan is a file

The architecture stage's artifact (`devflow/2-full-flow.md` §3.3) is a document,
and in an agent flow "document" means **a path in the repo** — `docs/plans/<slug>.md`
or the equivalent the project already uses. Write it before the gate closes,
and report the path in the hand-back.

The pull the other way is real: a subagent is told to return its answer as its
final message and not to write report files, and a plan returned that way reads
like a completed stage. It is not one. A report *about* work is a message; the
plan the next stage implements from is an artifact, and the difference is
whether it survives the agent.

The same holds for gate verdicts on a long flow: stage, round, verdict, one line
each, appended to the plan file. A resume that can read the verdicts does not
re-run the gates.

### 12.2 A resume starts with an inventory, not a stage

"Continue the work" is not a scope statement — it is a pointer to state you have
not read yet. Before delegating anything, establish and report in two sentences:

- what is committed, and what is uncommitted but already written (`git status`,
  `git log`);
- which plan artifacts already exist for this work, and whether they cover it;
- which gates already have recorded verdicts.

Then state which stages you are **skipping as already done**, and start at the
first one that is not. An orchestrator that cannot say what is already done is
not resuming, it is restarting — and the restart costs the full architecture
stage every time.

### 12.3 Re-planning rounds are counted out loud

Like gate rounds (`devflow/7-flow-visibility.md` §11.2), a plan carries its round
number: "Phase 4 architecture, round 2". A second plan for scope that already
has one is a defect to explain, not a stage to run.

**There is no round 3.** If the same scope needs planning a third time, the
problem is not the plan — stop and put both the existing plan and the reason it
is being redone in front of the operator.

### 12.4 Half-done work is read, not redesigned

When the code is further along than the plan — a service layer already written,
uncommitted, by an agent that was interrupted — the resuming architect's job is
to assess what exists and design the remainder around it. Reading it costs
minutes; redesigning it discards work that was already approved and puts the
next developer in conflict with the code in front of them.

Discard existing work only on a written reason, and only when the operator has
seen it.

### 12.5 An orchestrator does not finish the work itself

When the chain keeps failing to converge, the failure mode to avoid is the
orchestrator dropping delegation and implementing directly. It looks like
rescue, and it removes every gate at once: no architecture, no security
approval, no independent review of the code it just wrote.

The correct move is to stop and report — what is done, what the loop was, and
what you recommend — in two sentences to the operator. Doing the work yourself
without gates is a flow violation even when the work is right.

# Agent discipline

What one pass costs, and the bounds that keep it useful.

## A pass is generation-bound

<!-- F-030 -->

Measured over 85 specialist passes: 2–15% of wall clock was spent waiting on
tools; the rest was generating, at 40–65 tokens/second.

> **wall clock ≈ output tokens ÷ 55**

A pass is long because it generated a lot, and for almost no other reason.
**Output size is the lever.** Batching reads is hygiene worth seconds, not a
latency strategy — beware the arithmetic that divides pass duration by call
count and concludes otherwise; it overstates the real round trip by ~60×.

## Artifact caps

<!-- F-029 -->

Ceilings for a normal single-phase scope, not targets to fill:

| artifact                 | cap       | ~time to generate |
| ------------------------ | --------- | ----------------- |
| plan / design            | **12 KB** | ~1.5 min          |
| security or devops audit | **8 KB**  | ~1 min            |
| code review              | **8 KB**  | ~1 min            |
| hand-back message        | **2 KB**  | seconds           |

**Over the cap, split rather than trim.** A scope that genuinely needs 30 KB of
plan is a scope that needs two phases — say so and plan the first. A 30 KB plan
gets skimmed, so the length buys nothing it cost five minutes to produce.

- **Omit what the scope does not reach, and say what you omitted.** One line at
  the top. A silent omission reads as an oversight; a stated one is a scoping
  decision the reader can push back on.
- **Do not restate code the reader can open.** Name the file, name what changes,
  stop. Inventory is where most overrun goes.
- **Do not pretty-print.** A one-row table, a worked example of code the
  developer will write anyway, a recap of the section just written — each is
  wall clock for no decision unblocked.

## The read bound

<!-- F-031 -->

**In scope:** this repo's source and tests, its migrations, config, CI, its
docs, and the artifact you were handed.

**Out of bounds** unless the task is explicitly about them:

- **Dependency and vendor source** — `node_modules/`, `vendor/`,
  `site-packages/`. Work from documented behavior. If the plan turns on an
  undocumented internal, that is an assumption to state, not an afternoon to
  spend.
- **Live data stores.** Schema questions are answered by migration files.
  Questions about real rows go to whoever owns that environment.
- **The test suite as a reading device.** Running a full suite to learn what the
  code does is time spent on the wrong artifact. A developer runs tests to verify
  a change; a planner or reviewer does not run the suite at all.

<!-- F-014 -->

When the bound stops you from confirming something, that is a line in your **Not
verified**, not permission to keep digging.

## The exploration budget

<!-- F-032 -->

**About 25 tool calls of exploration, then write.** At that point you either know
what the deliverable is or you have a question, and a twenty-sixth file will not
settle it.

If you reach the bound and still cannot say what the deliverable looks like,
**hand back what you have with the gap named.** A partial plan with three open
questions is worth more than a complete one the operator killed at minute
sixteen.

## Delegation

<!-- F-033 -->

**Never paste doc contents into a delegation.** Name the file and let the reader
open it — it has its own context and its own budget.

What travels back up is the **verdict, the artifact paths, and what was not
verified**. Never file contents, never the full diff, never raw tool output.
Write the artifact to a file and name the path.

<!-- F-034 -->

**Stable first, volatile last.** Standing rules and doc pointers before the task
text; anything carrying a clock, a run id or a round number last. A volatile
prefix collapses the cache hit rate on every call.

<!-- F-036 -->

Parallelism is a **latency** decision, never a cost saving. Fanning out N
branches costs N contexts. If two branches would read the same files to answer
the same question, that is one pass, not two.

## Reporting

<!-- F-026 -->

Report at every stage transition, in one or two sentences: stage, verdict, what
starts next. **Twenty minutes of silence is a defect**, with the same standing as
a failing test. "Still working" is not a status.

<!-- F-027 -->

Carry the round number from round 1: `security re-gate, round 2 — BLOCKED`.
**Round 3 is not a status, it is an escalation that already happened** — state
both positions and hand the decision over.

<!-- F-028 -->

A background task's returned id means **launched**. Never _finished_, never
_succeeded_. Poll it, and pull its result explicitly. Finished-and-silent is the
first thing to check when something looks stuck.

<!-- F-024 -->

**There is no round 3.** A second attempt at scope that already has one is a
defect to explain, not a stage to run. If the same scope needs planning or
re-gating a third time, stop and put both positions in front of the operator.

## Loops and the cost of doing nothing twice

<!-- F-040 -->

Work that reduces no real risk is not diligence, it is cost. Do not open a stage
to look thorough, and do not manufacture an artifact a rule did not ask for.

The cheapest stage is the one that never had to run. Before opening one, the
question is not "is this useful" — most are — but "does this change trigger the
gate this stage exists to hold".

<!-- F-035 -->

Where the harness allows it, model tier and reasoning effort are **two
independent dials, set per stage, not per agent**:

- **Cheap / low effort** where the answer's shape is already fixed upstream —
  locating code, collecting an inventory, transcribing a decided docs update,
  applying a plan that already names the files.
- **Strong / default effort** where the stage _is_ the judgment — architecture,
  security, the acceptance-criteria walk, anything the operator would otherwise
  have to catch personally.

The bound for both: if a stage gets redone more than about one time in five, it
was not a cheap stage. Move it up and say that you did.

<!-- F-025 -->

**Never drop delegation to finish the work yourself.** When a chain keeps failing
to converge, implementing directly looks like rescue and removes every gate at
once — no design, no security approval, no independent review of the code you
just wrote. Stop and report instead: what is done, what the loop was, what you
recommend. Doing the work without gates is a violation even when the work is
right.

## Finding things

<!-- F-097 -->

"Who uses this symbol" is a **language-server question** — find-references,
go-to-definition — not a grep question. Grep mixes fields, variables,
serialization tags and comments into one answer.

A cold index returns a plausible **incomplete** result, which is worse than an
empty one. Warm it before trusting it. And check whether the repo has source
directories sitting _outside_ the obvious root — a search scoped to `src/` will
silently miss a file-based route tree beside it.

<!-- F-037 -->

Anything addressed to a human is **one or two sentences, no filler**. Artifacts
consumed by later stages are as detailed as the work needs. The same fact often
exists in both forms — the two-sentence version for the operator, the full
version on disk beneath it.

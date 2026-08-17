# Development Flow — agent I/O discipline (what one pass costs)

## 13. Agent I/O discipline

A pass spends its wall clock in three places: tool round trips, what it chooses
to read, and what it generates. They are not close to equal, and the order is
the opposite of the intuitive one.

Measured over 85 specialist passes from this reference's own sidecar
transcripts:

| agent | avg pass | waiting on tools | generating | output tokens |
| --- | --- | --- | --- | --- |
| `architecture-designer` | 15.8 min | **2%** | 15.5 min | 55,768 |
| `python-developer` | 12.6 min | 14% | 10.8 min | 42,472 |
| `security-auditor` | 9.9 min | 5% | 9.5 min | 23,197 |
| `devops` | 9.0 min | 15% | 7.6 min | 22,282 |

Generation ran at 40–65 tokens/second in every one of them. That rate is the
model's, not the prompt's — so for a read-heavy agent the arithmetic is simply:

> **wall clock ≈ output tokens ÷ ~55.**

A pass is long because it generated a lot, and for almost no other reason. §13.3
is therefore the section that moves the number; §13.1 and §13.2 are hygiene worth
seconds and tokens respectively. Spend your attention accordingly.

### 13.1 Independent reads go in one block — worth seconds, so do it and move on

Reads of different files are independent — nothing in `storage.py` changes what
you want from `worker.py` — so they belong in **one turn, not one per turn**.
Specialist passes currently average 1.43 calls per turn, with 67% of turns
issuing a single call, so there is real slack here.

**Do not expect minutes back from closing it.** A tool round trip in those passes
measured about 0.4 seconds; batching a 43-call planning pass perfectly saves it
roughly 19 seconds out of 948.

Beware the tempting arithmetic that says otherwise. Dividing a pass's duration by
its call count yields something like 26 seconds a call and makes batching look
like the whole game — but that number charges all the generation time to the tool
calls, and overstates the real round trip by about 60×. Measure the gap between a
call and its result, not the average of the pass.

So batch because it is free, not as a latency strategy. Sequential is for
**dependent** calls only — where the second call's target comes out of the
first one's output.

The two habits in the same family are worth more, because both cut what comes
*back* into the context, and everything read is re-read on every subsequent turn:

- One `Grep` across a directory beats a dozen `Read`s when the question is
  *where is this*, not *what does this file say*.
- Read a file once, whole. Three offset reads of the same file cost three round
  trips and usually more tokens than the file.

### 13.2 The read bound — what is in scope, and where you stop

"Read the actual code first" without a bound is how a planning stage turns into
a debugging session.

**In scope**: the repo's own source and tests, its migrations, config, CI, its
docs, and the scope or plan artifact you were handed.

**Out of bounds**, unless the task is explicitly about them:

- **Dependency and vendor source** — `site-packages/`, `node_modules/`,
  `vendor/`. One pass in that run grepped Starlette's and FastAPI's routing
  internals while writing a plan. Work from the library's documented behavior;
  if the plan turns on an undocumented internal, that is an assumption to state,
  not an afternoon to spend.
- **Live data stores.** The same pass opened the production SQLite database
  three times with inline Python. Schema questions are answered by the migration
  files. Questions about real rows go to whoever owns that environment.
- **The test suite as a reading device.** Running a full suite to learn what the
  code does is ten minutes spent on the wrong artifact. A developer runs tests
  to verify a change; a planner or a reviewer does not run the suite at all —
  a targeted check that answers a specific question is a different thing.

A developer chasing a real failure may cross the first line — sometimes the bug
*is* in the dependency. Say why you went there.

When the bound stops you from confirming something, that is a line in your "what
was NOT verified", not permission to keep digging.

### 13.3 Output is sized to the decision it unblocks — this is the whole lever

This is where the minutes are. A template with seven mandatory sections yields
seven sections whether the scope has seven or three, and every one of them is
generation time the operator waits through.

**The artifact caps.** These are ceilings for a normal single-phase scope, not
targets to fill:

| artifact | cap | at ~55 tok/s |
| --- | --- | --- |
| architecture plan | **12KB** | ~1.5 min |
| security / devops audit | **8KB** | ~1 min |
| code review | **8KB** | ~1 min |
| hand-back message (any agent) | **2KB** | seconds |

Measured passes are running well past these: `architecture-designer` averages
~61KB of written text per pass against a section that used to say only that 35KB
was "minutes of generation". A qualitative bound was missed by roughly 2×, which
is why these are numbers.

**Over the cap, split rather than trim.** A scope that genuinely needs 30KB of
plan is a scope that needs two phases; say so and plan the first. A 30KB plan
gets skimmed, so the length buys nothing it cost five minutes to produce.

- **Omit what the scope does not reach, and say what you omitted and why.** One
  line at the top — "no frontend section: service + infra phase". A silent
  omission reads as an oversight; a stated one is a scoping decision the
  reviewer can push back on.
- **Do not restate code the reader can open.** Name the file, name what changes
  about it, and stop. An inventory of what is already in the repo helps nobody
  who has the repo, and inventory is where most of the overrun goes.
- **Do not pretty-print.** A table with one row per file, a worked example of
  code the developer will write anyway, a recap of the section just written —
  each is a minute of the operator's wall clock for no decision unblocked.
- The two-sentence rule for anything addressed to a human
  (`devflow/1-principles-roles.md`) survives a large artifact: the artifact is
  the file, the message about it is still two sentences.

**Reasoning is output too.** In those passes only about a quarter of the
generated tokens surfaced as artifact text; the rest was reasoning the operator
waited through and never saw. Trimming the document is half the lever — the other
half is the effort the stage is run at, which the orchestrator sets per stage
rather than the agent setting it for itself (`devflow/10-flow-cost.md` §14.2).

### 13.4 The pass has a budget, and it has a number

An agent that cannot produce inside the operator's patience window produces
nothing at all, and everything it read is discarded with it.

**The bound: about 25 tool calls of exploration, then write.** At that point you
either know what the deliverable is or you have a question, and a twenty-sixth
file will not settle it. Passes that overrun are not passes that found more —
they are passes that kept looking.

If you reach the bound and still cannot say what the deliverable looks like,
**hand back what you have with the gap named.** A partial plan with three open
questions is worth more than a complete one the operator killed at minute
sixteen. The reporting cadence in `devflow/7-flow-visibility.md` is the same
instinct one level up: silence is the failure mode, not slowness.

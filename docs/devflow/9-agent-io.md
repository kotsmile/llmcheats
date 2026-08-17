# Development Flow — agent I/O discipline (what one pass costs)

## 13. Agent I/O discipline

A pass spends its wall clock in three places: tool round trips, what it chooses
to read, and what it generates. All three are controllable, and none of them is
about being smarter — they are about not paying for work nobody asked for.

This section is written from four `architecture-designer` passes in one real
run: 11.2, 11.8, 16.5 and 17.7 minutes, 203 tool calls between them, no code
produced by any of them. Two were killed by the operator before they finished.

### 13.1 Independent reads go in one block

Every tool call is a round trip, and on the run above each one cost about 26
seconds. Reads of different files are independent — nothing in `storage.py`
changes what you want from `worker.py` — so they belong in **one turn, not one
per turn**.

All 203 calls in those four passes were alone in their turn. Batch size was 1,
every time. At ~26s a call, a 40-file survey is 17 minutes serially and about
three in blocks of eight.

Before issuing a read, ask what else you already know you will need, and send
those together. Sequential is for **dependent** calls only — where the second
call's target comes out of the first one's output.

Two cheaper habits in the same family:

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

### 13.3 Output is sized to the decision it unblocks

A template with seven mandatory sections yields seven sections whether the scope
has seven or three, and every one of them is generation time the operator waits
through. Two plans in that run came back at 33.8KB and 37.8KB.

- **Omit what the scope does not reach, and say what you omitted and why.** One
  line at the top — "no frontend section: service + infra phase". A silent
  omission reads as an oversight; a stated one is a scoping decision the
  reviewer can push back on.
- **Do not restate code the reader can open.** Name the file, name what changes
  about it, and stop. An inventory of what is already in the repo helps nobody
  who has the repo.
- The two-sentence rule for anything addressed to a human
  (`devflow/1-principles-roles.md`) survives a large artifact: the artifact is
  the file, the message about it is still two sentences.

### 13.4 The pass has a budget, and the operator enforces it

Two of those four passes never delivered anything — they were stopped mid-work.
An agent that cannot produce inside the operator's patience window produces
nothing at all, and everything it read is discarded with it.

So treat the exploration as budgeted. If you have spent your reading budget and
still cannot say what the deliverable looks like, **hand back what you have with
the gap named** — a partial plan with three open questions is worth more than a
complete one the operator killed at minute sixteen. The reporting cadence in
`devflow/7-flow-visibility.md` is the same instinct one level up: silence is the
failure mode, not slowness.

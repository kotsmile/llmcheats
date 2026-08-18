# findings.md — what `$REFERENCE=./docs` actually says

Phase A output. Nothing in `cheats/` may exist without an F-number here.

## How to read an entry

- **Evidence** — `file:line`. Every claim traces to text I read.
- **Scar** — present only where the reference names the incident or measurement
  that produced the rule. A scarred rule is worth more than a stated one.
- **Class** — `universal` (routed unconditionally) · `stack-specific` (routed
  behind a detection guard) · `project-idiosyncratic` (never routed; see
  `docs/rejected.md`).
- **Portable form** — the rule with this repo's paths and tools removed.

## Note on paths — the corpus was reorganized after Phase A

Phase A was mined against a corpus split into `docs/best/` (patterns) and
`docs/flows/` (the guide), each with its own `INDEX.md` and the latter with an
`index.json` mirror. That split was subsequently collapsed into a **single
`docs/` tree with one `docs/INDEX.md`**:

| was | now |
|---|---|
| `docs/best/{backend,frontend,tools,devops}/` | `docs/{backend,frontend,tools,devops}/` |
| `docs/flows/{webapp,devflow}/` | `docs/{webapp,devflow}/` |
| `docs/best/INDEX.md` + `docs/flows/INDEX.md` + `docs/flows/index.json` | `docs/INDEX.md` |

**Citations below were rewritten to the new paths and remain exact:** the files
were moved, not edited, so every line number still resolves. The merge also made
every cross-reference in the corpus correct for the first time — both halves
already used the same relative link style (`webapp/x.md`, `backend/x.md`), which
only resolves once they share a parent.

Two citations are the exception, and are marked in place: **F-099** and **F-100**
cite the pre-merge index files, which no longer exist. Their evidence is quoted
verbatim so the claim stays auditable.

This report and `rejected.md` moved to `report/` in the same change, because
`docs/INDEX.md` claims to index every file under `docs/`, and F-099 is the rule
that a doc no index points at is a doc no agent will find.

## Evidence quality — read this before trusting the classes

`$REFERENCE` is **not a monorepo**. It is a 82-file, 317 KB distilled
knowledge corpus in two halves:

- `docs/` — 32 pattern docs mined from a real production monorepo (Go
  services, React/React Native apps, GitLab CI, an Argo-style reconciler, an
  internal secrets console).
- `docs/` — 50 docs: `webapp/` (how to build) and `devflow/` (in what
  order, with which gates).

So Phase A3's artifact mining could not run as written. There is no
`git log -300` to read, no CI YAML, no `Makefile`, no revert commits, no
`CODEOWNERS`. What I have is the corpus's *report* of those artifacts. Three
consequences, stated rather than smoothed over:

1. **All evidence is second-hand.** `docs/devops/ci-pipeline-composition.md`
   describes a pipeline I never saw. I trust it because the corpus is
   self-consistent and unusually specific about its own failures, not because I
   verified it.
2. **Frequency data is unavailable.** I cannot say a convention is followed in
   287 of 300 commits. I can only say a doc asserts it.
3. **The scarred findings are the reliable ones.** Where the corpus names a
   measurement (`42–89 seconds`, `85 specialist passes`, `exit 137`) or an
   incident (the flow that ran 1h30m silent, the plan written four times), the
   rule was paid for. Those are marked **Scar** and I weight them heavily.

The corpus is also *self-aware about llmcheats*: `devflow/project-memory.md:104`
and `devflow/roles.md:35` specify this tool's markers and commands. That is spec,
not evidence, and it contradicts the build prompt — see F-002.

---

# A1 · The agent layer

## F-001 · Project memory is capped at ~120 lines, no section past 20

- **Evidence:** `docs/devflow/project-memory.md:44` — "keep the whole file
  under about 120 lines, with no section past 20". `:41` notes the vendor advice
  is "low hundreds of lines"; the house ceiling is deliberately tighter.
- **Scar:** `:48` — "a *generated* file fills whatever cap it is given, and this
  one is generated". The tighter cap exists because a machine writes it.
- **Prevents:** a memory file that consumes context every session and, past a
  length, reduces adherence to its own contents.
- **Class:** universal
- **Portable form:** The generated memory file stays under 120 lines with no
  section past 20. Anything longer is referenced as a path, not inlined.

## F-002 · The managed block is `llmcheats:begin`/`llmcheats:end`, and project memory lives OUTSIDE it

- **Evidence:** `docs/devflow/project-memory.md:104-110` — llmcheats
  "manages a block inside `AGENTS.md`, between `<!-- llmcheats:begin -->` and
  `<!-- llmcheats:end -->`, holding the pointer to the installed docs. The
  installer regenerates that block on every update and preserves everything
  outside it. **Write project memory outside those markers.**"
- **Prevents:** the installer overwriting hand-written project memory; and a
  human editing a block the installer will clobber.
- **Class:** universal
- **Portable form:** The installer owns exactly one delimited block and rewrites
  it wholesale; everything outside is human territory and is never touched. A
  damaged marker pair makes the installer refuse the file entirely.
- **⚠ Contradicts the build prompt.** The prompt specifies
  `<!-- llmcheats:keep -->` as an off-limits region inside a file the skill
  otherwise rewrites — i.e. *generated by default, keep-marked by exception*.
  The reference inverts this: *human by default, generated inside one marked
  block*. The reference wins (derive, do not recall). The inversion matters
  because it decides what happens to an unmarked line on re-run: under the
  prompt it is destroyed, under the reference it survives.

## F-003 · One authoritative memory file; the other points at it

- **Evidence:** `docs/devflow/project-memory.md:96-102` — the two tools do
  not read each other's file; "keep one file authoritative and have the other
  point at it — memory in `AGENTS.md`, with `CLAUDE.md` reduced to
  `@AGENTS.md`, or the reverse."
- **Prevents:** two hand-maintained copies drifting.
- **Class:** universal
- **Portable form:** Generate one memory file with content and one that is a
  single import line. Never two copies.

## F-004 · Project memory has exactly six sections

- **Evidence:** `docs/devflow/project-memory.md:53` — "**Project**,
  **Architecture decisions**, **DevOps decisions**, **Review rules**,
  **Development patterns**, and **Keeping this file current**". Contents
  enumerated `:56-75`.
- **Class:** universal
- **Portable form:** The generated memory file uses this six-section skeleton;
  a section with nothing true to say is deleted, not filled.

## F-005 · How-to-run lines are commands, never prose

- **Evidence:** `docs/devflow/project-memory.md:56` — "build, test, lint,
  migrate: the commands, not prose about them. A step described without a
  command is the bug `devflow/principles.md` names." Backed by
  `devflow/principles.md:63` — "if a step is described in a README, there must
  be a command the README tells you to run."
- **Prevents:** documentation that drifts because nothing executes it.
- **Class:** universal
- **Portable form:** Every operational step in generated config is a runnable
  command copied from the target repo. **This is the anti-hallucination rule the
  build prompt names as llmcheats' primary failure mode, stated by the
  reference independently.**

## F-006 · What stays out of memory: secrets, status, and copies of the reference

- **Evidence:** `docs/devflow/project-memory.md:81-93` — out: secrets and
  hostnames (`:83`), anything the code or `git log` answers (`:86`), status
  (`:88`), "**A copy of `webapp/` or `devflow/`**" (`:90`), and subtree-local
  procedures (`:92`).
- **Class:** universal
- **Portable form:** The memory file references the knowledge base by filename
  and never inlines it. **This is the direct justification for shipping `docs/`
  as files plus a routing table rather than pasting rules into `AGENTS.md`.**

## F-007 · The trigger for writing a rule down is a repeat, not a first occurrence

- **Evidence:** `docs/devflow/project-memory.md:77` — "The trigger for
  adding a line is a **repeat**: the same correction typed twice… One occurrence
  is noise; twice is a convention nobody wrote down."
- **Class:** universal
- **Portable form:** Record a convention on its second occurrence, not its first.

## F-008 · A decision is written in the run that took it

- **Evidence:** `docs/devflow/project-memory.md:135` — "Deferred to a
  cleanup pass, it is re-litigated in the next session instead, which is the most
  expensive kind of re-planning."
- **Class:** universal

## F-009 · Codex builds its instruction chain at startup

- **Evidence:** `docs/devflow/project-memory.md:112` — "an edit made
  mid-session does not reach the agent until it restarts. A convention written
  during a flow governs the *next* session, not the one that wrote it."
- **Prevents:** a setup skill assuming its own output is live in the session
  that wrote it.
- **Class:** universal
- **Portable form:** The setup skill tells the user to restart the agent before
  the generated config takes effect. It never claims the file it just wrote is
  already loaded.

## F-010 · Three flows, and choosing among them is the largest cost decision

- **Evidence:** `docs/devflow/flow-cost.md:30-34` — full flow is 13
  contexts, fast flow 7, asap flow "one pass reading at most one file". `:36` —
  "**Pick the cheapest flow that still clears the gates the change actually
  triggers.**"
- **Scar:** `flow-cost.md:26` cites Anthropic's multi-agent system at ~15× the
  tokens of a chat interaction.
- **Class:** universal
- **Portable form:** Route work to one of three named flows by trigger list, not
  by how large the request sounds. **This is the shape of `cheats/routing.md`.**

## F-011 · The escalation trigger list is the single routing authority

- **Evidence:** `docs/devflow/asap-flow.md:41-52` — auth/sessions/tokens/
  crypto/secrets/payments/PII; schema migrations and irreversible data work;
  production deploys and infra topology; public product surface or an open
  question of what correct means; **a published contract**; anything whose diff
  outgrows one sitting. `:54` — checked "**at intake and again mid-task**".
- **Referenced as the authority by:** `flow-cost.md:37`, `skip-gates.md:35`,
  `principles.md:84`.
- **Prevents:** a one-pass flow silently swallowing work that needed gates.
- **Class:** universal
- **Portable form:** One trigger list, stored once, referenced everywhere.
  Re-checked mid-task, not only at intake. Growing into a trigger is a normal
  outcome, not a failure.

## F-012 · The asap floor never moves

- **Evidence:** `docs/devflow/asap-flow.md:98-107` — six items: secrets
  never hardcoded/logged/committed; SQL parameterized and input validated; no
  authz check weakened or disabled; no test deleted and no `//nolint`/`# noqa`/
  `eslint-disable` added to green a build; errors handled not swallowed; nothing
  destructive on shared state without an explicit go-ahead.
- **Prevents:** speed being traded against the things that cannot be un-traded.
- **Class:** universal
- **Portable form:** Ships verbatim as the floor under every workflow. "A task
  that cannot be done without breaking one of these is an escalation, not a
  judgment call" (`:109`).

## F-013 · The hand-back is four fixed lines

- **Evidence:** `docs/devflow/asap-flow.md:87-94` — `Changed:` / `Ran:` /
  `Not verified:` / `Skipped:`.
- **Class:** universal
- **Portable form:** Every workflow terminates in this four-line block.
  `Not verified` is mandatory and is never empty by default.

## F-014 · An unrun path is never reported as passing

- **Evidence:** `docs/devflow/asap-flow.md:83` — "Whatever you could not
  run is named. An unrun path is never reported as passing." Reinforced at
  `agent-io.md:96` — a bound that stopped you is a line in "what was NOT
  verified", not permission to keep digging.
- **Class:** universal

## F-015 · The reproduction test is written first and does not collapse

- **Evidence:** `docs/devflow/fast-flow.md:38` — "**A test that reproduces
  the bug is written first** and fails before the fix, passes after. This is the
  one non-negotiable test of the fast flow." One stated exception (`:41`): a
  frontend defect with no rule left to extract. `asap-flow.md:77` — "it does not
  collapse". `scaling-down.md:28` lists it under what never collapses.
- **Class:** universal
- **Portable form:** In `bug:` and `hotfix:` workflows, the failing test precedes
  the fix. The exception is named in the workflow, not improvised.

## F-016 · No opportunistic refactoring inside a fix

- **Evidence:** `docs/devflow/fast-flow.md:36` — "The smallest change that
  fixes the defect. No opportunistic refactoring in a hotfix — that is a
  follow-up ticket." Same rule `asap-flow.md:69`. Commit-level counterpart
  `git.md:40` — "Never mix a refactor with a behavior change."
- **Class:** universal

## F-017 · Finish it — no TODO stubs, no half-wired paths

- **Evidence:** `docs/devflow/asap-flow.md:71` — "Work delivered at 80% is
  work the operator now has to finish, which is the opposite of fast."
- **Class:** universal

## F-018 · Half of "bugs" are infra events — rule that out first

- **Evidence:** `docs/devflow/fast-flow.md:26-29` — "**First question: is
  this code or infra?** … recent deploys, resource saturation, dependency
  outages, certificate/quota expiry. Half of 'bugs' are infra events; a code fix
  for an infra problem wastes the release *and* leaves the problem."
- **Class:** universal
- **Portable form:** The `bug:` workflow opens with an infra-or-code question and
  a one-paragraph artifact naming what was ruled out and how.

## F-019 · A skipped stage is a recorded verdict, not an absence

- **Evidence:** `docs/devflow/skip-gates.md:49-52` — one printed line per
  skipped stage with its reason, e.g. `stage 5 · devops design ⊘ SKIPPED: no
  migration, no config change`. "A stage nobody mentioned was forgotten, and the
  operator cannot tell the two apart afterwards."
- **Class:** universal
- **Portable form:** Deleting a step from a specialized workflow prints why. This
  is also the rule for the setup skill's own output: it reports what it did not
  generate. **Directly supports the prompt's "delete inapplicable steps rather
  than leaving no-ops" — but the deletion must be announced.**

## F-020 · A triggered gate is compressed, never skipped

- **Evidence:** `docs/devflow/skip-gates.md:53` — the skip tests "skip
  stages the change does not reach; they never drop one it does." Distinguished
  from downgrading at `:57`. `principles.md:91` — "a triggered gate is
  compressed, not skipped, and whatever was compressed … is named in the
  hand-back."
- **Class:** universal

## F-021 · The skip gate opens no context of its own

- **Evidence:** `docs/devflow/skip-gates.md:66-70` — "**Every row is
  answered from this table — open nothing to answer one**".
- **Class:** universal
- **Portable form:** Routing decisions are answered from the routing table
  already in context. A router that has to read a file to route has already lost
  the saving. **This is the argument for Layer 2 of the two-layer routing.**

## F-022 · A plan that exists only as a message dies with the agent that sent it

- **Evidence:** `docs/devflow/resuming.md:33-38` — the architecture
  artifact means "**a path in the repo** — `docs/plans/<slug>.md`". `:40` names
  the pull the other way: a subagent told to answer in its final message
  produces something that "reads like a completed stage. It is not one."
- **Scar:** `resuming.md:20-29` — one migration phase planned four times across
  two hours (17, 11, 18 and 6 minutes); the third finished and was delivered; a
  fourth architect was asked 40 minutes later. No code was ever written.
- **Class:** universal
- **Portable form:** Plans and gate verdicts are written to a path and the path
  is reported. Applies to llmcheats' own output: `stack.md` on disk is what makes
  a re-run cheap.

## F-023 · A resume starts with an inventory

- **Evidence:** `docs/devflow/resuming.md:48-61` — before delegating:
  what is committed vs uncommitted, which plan artifacts exist, which gates have
  recorded verdicts; then state which stages are skipped as already done. "An
  orchestrator that cannot say what is already done is not resuming, it is
  restarting."
- **Class:** universal
- **Portable form:** The setup skill's re-run path reads `stack.md` first and
  reports what it is skipping. **This is the reference's own design for the
  prompt's re-run behaviour.**

## F-024 · There is no round 3

- **Evidence:** `docs/devflow/resuming.md:69` — "If the same scope needs
  planning a third time, the problem is not the plan — stop and put both the
  existing plan and the reason it is being redone in front of the operator."
  Gate rounds bounded the same way, `flow-visibility.md:50`.
- **Class:** universal

## F-025 · An orchestrator never finishes the work itself

- **Evidence:** `docs/devflow/resuming.md:84-93` — dropping delegation to
  implement directly "looks like rescue, and it removes every gate at once".
  Hardened at `flow-visibility.md:130-135` into "no editing project files while a
  flow is open".
- **Class:** universal

## F-026 · Twenty minutes of silence is a defect

- **Evidence:** `docs/devflow/flow-visibility.md:29-34` — report at every
  stage transition in one or two sentences; "**Twenty minutes of silence is a
  defect**, whatever is happening underneath. Not a warning sign — a defect, with
  the same standing as a failing test." "Still working" is not a status.
- **Scar:** `:18-21` — a full flow, 17 agents, three levels deep, 1h30m with
  nothing reaching the operator. Nothing was broken; a gate had looped six times
  and the report was written and never delivered.
- **Class:** universal

## F-027 · Gate rounds carry their number from round 1

- **Evidence:** `docs/devflow/flow-visibility.md:44-53` — "`security
  re-gate, round 2 — BLOCKED, one MAJOR`. From round 1, not from the round it
  starts hurting." "**Round 3 is not a status, it is an escalation that already
  happened.**"
- **Scar:** `:50` — the same two gates blocked the same phase three times each
  and no one saw a loop because no line said "round".
- **Class:** universal

## F-028 · A background agent's returned id means launched, never finished

- **Evidence:** `docs/devflow/flow-visibility.md:58-69` — "It means
  *launched* — never *finished*, never *succeeded*. Treating it as completion is
  the single most effective way to lose an hour." Poll it; pull its hand-back;
  check finished-and-silent first.
- **Class:** universal

## F-029 · Artifact caps are numbers, not adjectives

- **Evidence:** `docs/devflow/agent-io.md:104-112` — architecture plan
  **12KB**, security/devops audit **8KB**, code review **8KB**, hand-back
  **2KB**. `:119` — "**Over the cap, split rather than trim.**"
- **Scar:** `:114-117` — `architecture-designer` averaged ~61KB per pass against
  a section that only said 35KB was "minutes of generation". "A qualitative bound
  was missed by roughly 2×, which is why these are numbers."
- **Class:** universal
- **Portable form:** Every generated artifact carries a byte cap. Over it, split
  the scope.

## F-030 · Wall clock ≈ output tokens ÷ 55

- **Evidence:** `docs/devflow/agent-io.md:23-34` — measured over 85
  specialist passes: `architecture-designer` 15.8 min at 2% waiting on tools;
  generation ran 40–65 tok/s in every one. "A pass is long because it generated a
  lot, and for almost no other reason."
- **Scar:** `:51-54` — the tempting arithmetic (duration ÷ call count ≈ 26 s/call)
  overstates the real round trip by ~60×.
- **Class:** universal
- **Portable form:** Output size is the latency lever. Batching reads is hygiene
  worth seconds, not a latency strategy.

## F-031 · The read bound

- **Evidence:** `docs/devflow/agent-io.md:70-90` — in scope: the repo's own
  source, tests, migrations, config, CI, docs, and the handed artifact. Out of
  bounds: dependency/vendor source (`node_modules/`, `vendor/`, `site-packages/`),
  live data stores, and "**the test suite as a reading device**".
- **Scar:** `:81` — one pass grepped Starlette's and FastAPI's routing internals
  while writing a plan; `:85` — the same pass opened the production SQLite
  database three times with inline Python.
- **Class:** universal
- **Portable form:** The setup skill's repo-reading phase is bounded to first-
  party files. Schema questions go to migration files, not a live database.

## F-032 · The exploration budget is ~25 tool calls, then write

- **Evidence:** `docs/devflow/agent-io.md:146-156` — "At that point you
  either know what the deliverable is or you have a question, and a twenty-sixth
  file will not settle it… **hand back what you have with the gap named.**"
- **Class:** universal
- **Portable form:** A bounded read phase with a named-gap escape hatch.

## F-033 · Never paste doc contents into a delegation

- **Evidence:** `docs/devflow/flow-cost.md:108` — "**never paste doc
  contents into a delegation.** Name the file and let the subagent read it."
  Hand-backs carry "the verdict, the artifact paths, and what was not verified"
  (`:102`), never file contents or raw tool output.
- **Class:** universal
- **Portable form:** Skill stubs name a path and stop. **This is the reference's
  own argument for the prompt's three-line stub design.**

## F-034 · Stable prefix first, volatile last

- **Evidence:** `docs/devflow/flow-cost.md:114-127` — providers cache on
  exact prefix match; a timestamp, run id, live status block or task text placed
  above the stable instructions collapses the hit rate. "**Stable first**…
  **Volatile last**".
- **Class:** universal
- **Portable form:** Generated agent files put standing rules and doc pointers
  first, task-specific and volatile content last.

## F-035 · Model tier and reasoning effort are two independent per-stage dials

- **Evidence:** `docs/devflow/flow-cost.md:59-94` — cheap tier where output
  is looked up or mechanically checked; strong tier where a wrong answer is
  expensive and does not look wrong. "Shipped agents therefore leave `model`
  unset and inherit the operator's choice" (`:70`). Bound: redone more than ~1 in
  5 means it was not a cheap/low-effort stage.
- **Class:** universal
- **Portable form:** Shipped agent definitions do not pin a model. Pinning up
  overrules the operator; pinning down quietly ships worse code.

## F-036 · Parallelism is a latency decision, never a cost saving

- **Evidence:** `docs/devflow/flow-cost.md:136-147` — "Fanning out N
  subagents costs N contexts… **If two branches would read the same files to
  answer the same question, that is one pass, not two.**"
- **Class:** universal

## F-037 · Anything addressed to a human is one or two sentences

- **Evidence:** `docs/devflow/principles.md:43-47` — "one or two sentences,
  maximum, with no filler phrases. Humans approve what they can read at a
  glance." Artifacts consumed by LLMs are as detailed as the work needs; the same
  fact often exists in both forms. Survives large artifacts: `agent-io.md:133`.
- **Class:** universal
- **Portable form:** Two-sentence operator messages, full detail on disk.

## F-038 · A pattern is not a constraint

- **Evidence:** `docs/devflow/principles.md:65-79` — a constraint holds in
  every project and deviating needs a written reason; a pattern (four layers,
  ports, FSD slices) is how this reference builds one, and "a project that
  already builds differently keeps its own architecture: consistency with the
  surrounding code beats the pattern in these files". `:77` — architecture never
  buys relief from a constraint.
- **Class:** universal
- **Portable form:** **This is the load-bearing rule of the whole tool.** It is
  what makes shipping a Go/React knowledge base into a Django repo safe: the
  patterns are advisory and yield to local convention, the constraints are not.
  Every routed doc must be labelled as one or the other.

## F-039 · The never-skip list

- **Evidence:** `docs/devflow/principles.md:26-41` — whatever the stack
  maturity: development best practices (validated input, bound parameters,
  secrets out of code, errors handled, no authz weakened); security practices for
  client secrets; system observability; release speed. "Skipping them saves days
  and costs months."
- **Class:** universal

## F-040 · Work that reduces no real risk is cost, not diligence

- **Evidence:** `docs/devflow/principles.md:87` — "do not open a stage to
  look thorough, and do not manufacture an artifact a rule did not ask for."
- **Class:** universal
- **Portable form:** The setup skill generates no file the target repo's detected
  stack does not justify.

## F-041 · Roles map to named agents, and one person may hold several hats

- **Evidence:** `docs/devflow/roles.md:19-31` — eleven roles mapped to
  agent names. `:15` — "on a small team one person holds several hats — the
  *gates still happen*, they just happen faster".
- **Class:** project-idiosyncratic *(the specific 11-name roster)* /
  universal *(the gates-survive-role-collapse rule)*
- **Portable form:** Gates are properties of the change, not of the headcount.
  The roster does not ship (see the Agents decision in `docs/rejected.md`).

## F-042 · Code review is a lens the flow does not hold

- **Evidence:** `docs/devflow/roles.md:33-40` — `code-reviewer` is invoked
  by a command, not by one of the thirteen stages. "Without that command — Codex,
  or any tool with no subagents — the lens is held by the development stage's
  self-review of the diff, against the same list."
- **Class:** universal
- **Portable form:** Every capability that depends on subagents names its
  no-subagent fallback. **This is the pattern for keeping Claude/Codex parity.**

## F-043 · Claude-only mechanisms are marked as Claude-only

- **Evidence:** `docs/devflow/flow-visibility.md:110` — "**This subsection
  describes Claude Code.** Codex has no subagent sidecars and no `/llmcheats:`
  commands: under it, the reporting rules above *are* the mechanism, because
  nothing else records that the work is progressing."
- **Class:** universal
- **Portable form:** Any agent-specific instruction carries an explicit scope
  marker and a fallback for the other agent.

## F-044 · The stage owner belongs at depth 1

- **Evidence:** `docs/devflow/flow-visibility.md:114-128` — the running-
  agent indicator names only what the session launched itself; everything deeper
  collapses to `(+N)`.
- **Scar:** `:88-91` — five `project-manager` entries were top level and
  thirty-one nested agents were only ever a number.
- **Class:** stack-specific *(assumes a subagent-capable harness)*
- **Portable form:** Do not nest an orchestrator whose only job is sequencing.

---

# A2 · GitOps

## F-045 · A release is a tag; a deploy is a commit

- **Evidence:** `docs/devops/release-tagging-and-gitops.md:14-28` — tag
  `<project>/release-<N>`; the tag triggers build, a **deployment bump** job that
  rewrites the image tag and pushes, a sync job, and a manual approval gate
  between test and production.
- **Class:** stack-specific *(guard: GitOps repo — Argo/Flux app manifests, or a
  values file the CI bumps)*
- **Portable form:** Releasing is cutting a tag. Deploying is a commit that
  changes declared desired state. They are separate events.
- **Decides the prefix question:** `release:` ships. `deploy:` does **not** — the
  reference has no deploy action distinct from the bump commit, so a `deploy:`
  prefix would name a step that does not exist. See F-047 for `rollback:`.

## F-046 · A green pipeline can leave production on the old image

- **Evidence:** `docs/devops/release-tagging-and-gitops.md:42-46` — "The
  bump job pushes to a branch, and a push can fail after the build succeeded.
  Verify that the bump commit landed — not that the pipeline was green." And:
  application manifests are **unmanaged**, so editing one in git reaches no
  cluster until that project next releases.
- **Scar:** both failure modes are named as ones where "nothing is
  wrong-looking".
- **Class:** stack-specific *(guard: GitOps)*
- **Portable form:** Verify the artifact of a deploy (the landed commit, the
  synced revision), never the exit status of the job that was supposed to produce
  it.

## F-047 · Rollback is a revert of the bump commit

- **Evidence:** `docs/devops/release-tagging-and-gitops.md:54-58` — "Because
  image tags are immutable and the render is committed, a rollback is a revert of
  the bump commit — not a rebuild and not a re-tag." One exception: a baked base
  image, "the only place a mutable tag is used".
- **Corroborated generically:** `docs/webapp/infrastructure.md:126` — "the
  deployed state is written down, diffable, and **rolled back by reverting**",
  stated to hold for a systemd deploy script as much as for Argo.
- **Class:** universal *(the revert-to-roll-back principle)* /
  stack-specific *(the bump-commit mechanics)*
- **Portable form:** Rollback is reverting the commit that declared the new
  state. A workflow that cannot name its one-command rollback is not ready to
  release (`full-flow.md:70` — "a feature with no rollback story does not
  proceed").
- **Decides the prefix question:** `rollback:` ships, and its workflow is a git
  operation, not a deployment procedure.

## F-048 · The reconciler owns the cluster — UI edits are reverted by self-heal

- **Evidence:** `docs/devops/release-tagging-and-gitops.md:30-34` — "A
  change made in the deployment UI is **reverted by self-heal** — so an emergency
  fix applied there disappears at the next reconcile, usually minutes later and
  without notice. Change the manifest. This applies to dashboards and alert rules
  too." Restated as a prohibition at
  `docs/tools/commit-conventions.md:99` — "**Observability changes are
  GitOps-only.** A UI edit to a dashboard is reverted by the reconciler, so it is
  a change that appears to work and then vanishes."
- **Class:** stack-specific *(guard: a reconciler with self-heal enabled)*
- **Portable form:** Where a reconciler owns a resource, the only durable edit is
  to its source of truth. An out-of-band edit is a change that appears to work
  and then vanishes.

## F-049 · Re-render and commit the render diff in the same commit

- **Evidence:** `docs/devops/release-tagging-and-gitops.md:36-40` — after
  **any** chart or manifest change; "A CI check fails on stale renders." The
  point is reviewability: the rendered output is what actually reaches the
  cluster.
- **Class:** stack-specific *(guard: templated manifests with committed renders)*
- **Portable form:** Generated output travels with its source in one commit and
  CI verifies staleness. Generalizes beyond charts — see F-062.

## F-050 · Migrations run in an earlier wave, never on service boot

- **Evidence:** `docs/devops/release-tagging-and-gitops.md:48-52` — a
  sync-hook Job in an earlier sync wave, same image, different entry point. "This
  is why the service binary must not migrate on boot: the ordering is a property
  of the sync waves, not of pod scheduling."
  `docs/backend/database-and-migrations.md:72` — "that pattern was removed
  deliberately, because it makes every replica a schema writer".
  Runtime-agnostic form at `docs/webapp/infrastructure.md:66-75`:
  `ExecStartPre=` on systemd, a one-shot service on Compose, an init container or
  pre-sync hook on Kubernetes. "N replicas racing DDL is a failure mode you
  simply delete by keeping the step separate."
- **Class:** universal *(the separate-step rule)* / stack-specific *(sync waves)*
- **Portable form:** The migrate step is a distinct pre-serve step in whatever
  runs the app. The service never migrates on boot.

## F-051 · Expand → migrate → contract, backward compatible one release back

- **Evidence:** `docs/webapp/infrastructure.md:77-79` — "migrations are
  **backward compatible one release back** (the old code runs against the new
  schema during rollout)". Planned as such at the architecture stage,
  `docs/devflow/full-flow.md:42`.
- **Class:** universal
- **Portable form:** Schema change is planned as three steps, and the `migrate:`
  workflow's default output is the expand step plus the plan for the rest.

## F-052 · Never mark a deploy job interruptible

- **Evidence:** `docs/devops/ci-pipeline-composition.md:71-75` — every
  merge-request check job is interruptible so a re-push frees the runner;
  "**Never mark a deploy job interruptible.** A cancelled deploy leaves the
  cluster in a state nobody chose." Repeated at
  `docs/webapp/infrastructure.md:131`.
- **Class:** stack-specific *(guard: CI with an interruptible flag)*

## F-053 · Deploy credentials come from protected variables on protected refs

- **Evidence:** `docs/devops/ci-pipeline-composition.md:77-79` — "Protected
  CI variables only. Merge-request pipelines never see them, and deploys run only
  from protected release tags — so a fork or an untrusted branch cannot reach a
  credential." Restated `docs/webapp/infrastructure.md:129`.
- **Class:** universal
- **Portable form:** CI secrets are scoped to protected refs; PR pipelines from
  arbitrary branches never see them.

## F-054 · An unprefixed CI job silently overrides another project's job

- **Evidence:** `docs/devops/ci-pipeline-composition.md:30-32` — "The
  namespace is merged across all includes, so an unprefixed duplicate **silently
  overrides** another project's job — a failure mode with no error message."
- **Class:** project-idiosyncratic *(one flat pipeline from recursive includes)*
- **Portable form:** *(none that generalizes; → `rejected.md`)*

## F-055 · Measure the archive step before adding a CI cache

- **Evidence:** `docs/devops/ci-performance-model.md:11-19` — language
  caches "**tried and removed after measurement**"; a 22-second check became 16
  minutes and two heavier checks were OOM-killed, "reported as a *system failure*,
  which sends you looking in the wrong place entirely". Cache keys are per job.
- **Scar:** the whole file. `:63-65` — "three of them contradicted the intuition
  that motivated the original change."
- **Class:** universal
- **Portable form:** A cache pays only if restore plus archive beats what it
  saves. Measure the archive step, not the build.

## F-056 · The clone is the bigger fixed CI cost

- **Evidence:** `docs/devops/ci-performance-model.md:21-37` — full clone
  measured 42–89 s against 5–12 s to schedule the pod. "A job running a
  one-second command spent 49–75 seconds cloning before the no-clone strategy was
  set on it. That is the single highest-leverage change on this list." Sparse +
  blob-filtered: ~113MB/42–89s → ~750KB/under three seconds.
- **Class:** stack-specific *(guard: containerized CI with per-job fresh pods)*

## F-057 · Secrets are delegated, never copied; every read is audited

- **Evidence:** `docs/devops/secrets-and-delegation.md` — payloads stay in the
  backing store while the console holds only metadata and an audit trail,
  "**reads included**"; and "**A token inherits the identity of whoever minted
  it.**"
- **Scar:** the prune trap — a declarative sync's prune mode deletes whatever
  its local file does not declare, including everything a second writer created.
  "This is the general shape of a two-writer system: whichever writer holds the
  'delete what I don't know about' flag will eventually delete the other's
  work."
- **Class:** universal *(the two-writer lesson, audited reads, and minter
  identity)*
- **Portable form:** Where two writers share a store and one has a prune mode,
  that mode will eventually delete the other's work. Agents never hold the prune
  flag.

## F-058 · An expiry on a reconcile loop's credential is a scheduled outage

- **Evidence:** `docs/devops/secrets-and-delegation.md` — "**An expiry on the
  credential a reconcile loop presents is an outage scheduled for a day nobody
  picked.**"
- **Class:** universal

---

# A3 · Conventions

## F-059 · Commits are one line, imperative, ≤72 chars

- **Evidence:** `docs/devflow/git.md:16-27` — `<TICKET>: <scope> what the
  change does`, no trailing period. `docs/tools/commit-conventions.md:14-23`
  — `<KEY>-<number>: <project-name> brief description`, "~70 characters excluding
  the key prefix", "No multi-line body, no bullet list of what changed."
- **Class:** universal
- **Portable form:** One line. If the message needs a body, the commit is too big
  or the design doc is missing (`git.md:42`).

## F-060 · Three no-ticket prefixes, and only where they genuinely apply

- **Evidence:** `docs/devflow/git.md:33-36` — `hotfix:` (fast-flow fix),
  `chore:` (deps, tooling, formatting), `auto:` (machine-written, carrying a
  trailer naming who/what triggered them). Same three at
  `docs/tools/commit-conventions.md:42-50`, where the `auto:` trailer "is
  the audit record, so it must not be stripped by a rebase".
- **Class:** universal
- **Portable form:** These three prefixes and no others. **`hotfix:` and `chore:`
  are therefore justified llmcheats routing prefixes — they are already commit
  vocabulary in the reference.**

## F-061 · No AI attribution, no `Co-Authored-By` bots

- **Evidence:** `docs/devflow/git.md:49` — "The author is whoever answers
  for the change." `docs/tools/commit-conventions.md:23` — "**No co-author
  trailers, no tool attribution.**"
- **Class:** universal

## F-062 · Generated files travel with their source, and CI verifies staleness

- **Evidence:** `docs/devflow/git.md:51` — "regenerated spec, rendered
  manifests — CI verifies staleness". PR rule 10 at `:104`.
  `docs/webapp/testing-ci.md:21` names the check: "generated-file staleness
  checks (`--check` modes), rendered-manifest diffs".
- **Class:** universal

## F-063 · Never hand-edit a generated file or a lock file

- **Evidence:** `docs/backend/code-generation.md:41-43` — "a hand edit is
  silently reverted by the next run and produces a diff nobody can review."
  `docs/tools/dependency-management.md:22-24` — a hand-edited manifest
  produces a lock file that no longer describes what will be installed, "and the
  divergence surfaces on somebody else's machine, not yours".
  `docs/tools/commit-conventions.md:100` — "Never edit a dependency or lock
  file by hand."
- **Class:** universal
- **Portable form:** Generated and lock files are read-only to an agent. **The
  memory file's "what not to touch" section (F-004) is where this lands per
  repo.**

## F-064 · Never suppress a lint rule or a type error

- **Evidence:** `docs/tools/commit-conventions.md:98` — "No disable
  comments, no ignore directives, no file-level opt-outs. Fix the root cause."
  In the asap floor as `//nolint`/`# noqa`/`eslint-disable`
  (`asap-flow.md:104`). Checklist form: "no suppression comments"
  (`new-app-checklist.md:48`).
- **Class:** universal

## F-065 · Green before commit

- **Evidence:** `docs/devflow/git.md:44` — "Build, lint, and the affected
  tests pass locally. A broken commit on a shared branch costs everyone's
  bisect."
- **Class:** universal

## F-066 · Commit ≠ deliver — never speculatively push

- **Evidence:** `docs/devflow/git.md:57` — "The agent/developer commits when
  the operator (or the project manager under delegated autonomy) asks or the
  flow's release stage requires it — never speculatively pushes."
- **Class:** universal
- **Portable form:** No workflow commits or pushes unless the operator asked or
  the release stage requires it. **Directly constrains the setup skill: it must
  not commit (the prompt agrees).**

## F-067 · Never commit secrets; a committed secret is rotated, not deleted

- **Evidence:** `docs/devflow/git.md:47` — "no keys, tokens, dumps, `.env`
  with real values. A committed secret is rotated, not deleted (history keeps
  it)."
- **Class:** universal

## F-068 · The PR description is four blocks, and `Rollback` is one of them

- **Evidence:** `docs/devflow/git.md:66-74` — `What:` / `Why:` / `Testing:`
  (including "what was NOT verified, stated explicitly") / `Rollback:` ("revert
  is the default answer; say so if it isn't").
- **Class:** universal
- **Portable form:** Mirrors the four-line hand-back (F-013). Both carry an
  explicit not-verified field.

## F-069 · ~400 lines of non-generated diff is the review ceiling

- **Evidence:** `docs/devflow/git.md:81` — "If the diff exceeds what a
  reviewer can actually read (~400 lines of non-generated change is the practical
  ceiling), split it — stacked PRs beat a rubber stamp." Feeds the asap escalation
  trigger "anything whose diff outgrows what a reviewer reads in one sitting"
  (`asap-flow.md:51`).
- **Class:** universal

## F-070 · CI green is an entry condition for review, not a post-review chore

- **Evidence:** `docs/devflow/git.md:83` — "Draft status while red or
  incomplete; mark ready only when it is reviewable."
- **Class:** universal

## F-071 · Gate verdicts land as PR approvals; a BLOCKED verdict is requested-changes

- **Evidence:** `docs/devflow/git.md:86-90` — security-auditor approval when
  the diff touches auth/input/SQL/secrets/PII; devops approval on
  migrations/config/deploy. "A BLOCKED verdict is a requested-changes review, not
  a comment." `:91` — "The author never merges over an unresolved finding."
- **Class:** universal

## F-072 · No self-merge, with one named exception

- **Evidence:** `docs/devflow/git.md:95` — a hotfix under the fast flow may
  be merged by its author after CI plus a requested post-factum review — "the
  review still happens, after the fire."
- **Class:** universal

## F-073 · Squash-merge by default; re-request review after force-push

- **Evidence:** `docs/devflow/git.md:97-101` — main history is one commit
  per PR, revertable as a unit; "A force-push invalidates prior approvals."
- **Class:** universal

## F-074 · Ask ticket-or-chore before opening a PR — never guess

- **Evidence:** `docs/tools/commit-conventions.md:61-66` — "**Before creating
  a PR, always ask: ticket or chore?** Never guess — the answer sets the branch
  name, the title prefix and whether there is a description." Ticket → branch
  `<KEY>-<n>-short-name`, no description; chore → `chore-short-name`, two
  paragraphs (problem, solution).
- **Class:** universal
- **Portable form:** One question with two answers, asked before branch creation.

## F-075 · Comments: 1–2 rows, none where the code speaks for itself

- **Evidence:** `docs/tools/commit-conventions.md:68-74`.
  `docs/backend/layered-architecture.md:126-134` tightens it: default none;
  forbidden are multi-line explanatory blocks, paragraph doc-comments above every
  func, comments restating the code, and "comments narrating a change or decision
  ('we do X because earlier Y…', 'moved from Z', ADR-style prose)". "**This is
  not a preference — oversized comments are treated as a defect in review, and
  the rule applies to generated and agent-written code too.**"
  `docs/frontend/typescript-react-conventions.md:27` — "**No code
  comments** in frontend apps."
- **Class:** universal *(the rule)* / stack-specific *(the frontend zero-comment
  variant)*
- **Portable form:** Explain only what the code cannot say — a ticket, a
  non-obvious why. No comment on a function whose name already tells what it
  does. Explicitly binding on agent-written code.

## F-076 · Extract a function only when it has more than one caller

- **Evidence:** `docs/tools/commit-conventions.md:76-78` — "A single-use
  helper, however well named, is noise: keep the code inline."
- **Class:** universal
- **Generalization test applied:** I can name repos where this is worse — a
  codebase with a house style of named single-use helpers for readability, and
  one where a single-use extraction exists to be unit-testable. It survives as
  universal only because the reference states it as a review rule, not a
  suggestion. Flagged as the weakest universal in this set.

## F-077 · A test protects a behavior or an invariant, never the shape of the implementation

- **Evidence:** `docs/webapp/testing-strategy.md:16-22` — "Assert what a
  caller depends on… A test that has to be rewritten every time its subject is
  refactored was testing the shape, and it will be deleted the first time it is
  inconvenient."
- **Class:** universal

## F-078 · Tests are written in a fixed priority order

- **Evidence:** `docs/webapp/testing-strategy.md:26-42` — (1) bug
  reproduction, (2) business and domain invariants, (3) contracts something else
  depends on, (4) critical integration paths, (5) everything else only where a
  failure would cost something. "stop where the cost of the failure stops
  justifying the test."
- **Class:** universal

## F-079 · Do not add a test because code changed

- **Evidence:** `docs/webapp/testing-strategy.md:44-50` — trivial refactor,
  plain wiring, and behavior covered one level up get nothing. A spike or
  throwaway script gets none "and then you *say* you skipped it".
  Same at `docs/tools/commit-conventions.md:90`.
- **Class:** universal

## F-080 · Every non-trivial test states why it exists; AAA comments throughout

- **Evidence:** `docs/webapp/testing-strategy.md:54-63` — a doc comment
  naming the invariant it guards or the incident that motivated it; "A test that
  cannot state its reason is ballast." `// Arrange`, `// Act`, `// Assert` in
  every test, backend and frontend.
- **Class:** universal *(justification)* / stack-specific *(the AAA comment
  literal)*

## F-081 · Every dynamic value reaches the database as a bound parameter

- **Evidence:** `docs/webapp/security-input-sql.md:30-39` — "no exceptions,
  enforced by review and grep. No SQL text is built with string formatting,
  concatenation or interpolation anywhere in the codebase." Crucially `:36-39`:
  the invariant "is independent of how the query is written. A query builder or
  an ORM that binds its values satisfies it… deviating from *that* is an
  architecture choice, deviating from *this* is a vulnerability."
- **Class:** universal
- **Portable form:** Ships as a constraint, and the reference has already done
  the generalization work — it explicitly separates the raw-SQL *pattern* from
  the binding *constraint*. **The cleanest worked example of F-038 in the
  corpus.**

## F-082 · Identifiers and sort keys are allow-listed, never interpolated

- **Evidence:** `docs/webapp/security-input-sql.md:50-54` — map
  client-supplied sort and filter keys to a fixed allow-list of constants before
  they touch a query.
- **Class:** universal

## F-083 · Input is validated at three gates, and structured input is never trusted

- **Evidence:** `docs/webapp/security-input-sql.md:16-26` — transport
  chokepoint (size cap, unknown-field rejection, single-value check), entity
  constructors re-validating, and "**Any tool/automation input** (LLM function
  calls, webhook payloads): its own explicit parser with enum and bounds checks.
  Never trust structured input because a schema was published."
- **Class:** universal

## F-084 · Checks on merge requests are blocking by default

- **Evidence:** `docs/webapp/testing-ci.md:23` — "make a check advisory only
  as a conscious, documented exception."
- **Class:** universal

## F-085 · The same check runs locally and in CI

- **Evidence:** `docs/devops/ci-pipeline-composition.md:58-65` — "A check job
  names its project and nothing else… **The same check runs locally and in CI.** A
  failure reproduces on a laptop without reading the CI file, which is the whole
  point of keeping the definition out of it." Consequence: "**A CI file change is
  rare.**" Same principle `docs/backend/code-generation.md:14`.
- **Class:** universal
- **Portable form:** **This is how the setup skill finds the real test command.**
  It reads the task-runner definition next to the code (Makefile, justfile,
  package.json scripts), not the CI file. Directly serves the anti-hallucination
  requirement.

## F-086 · The build compiles only — generation is explicit

- **Evidence:** `docs/backend/code-generation.md:31-39` — "**The build
  compiles only.** It does not generate code or API docs, and no build target
  depends on generation." `:29` — "There is **no lint target** — the linter
  config is checked in and runs in CI."
- **Class:** stack-specific *(guard: a repo with a codegen step)*
- **Portable form:** Do not assume `build` regenerates. Regeneration is a
  separate named command, and its absence from the build is deliberate.

## F-087 · Never run start commands for dev servers

- **Evidence:** `docs/tools/commit-conventions.md:97` — "**Never run start
  commands** for dev servers — they are already running."
- **Class:** project-idiosyncratic
- **Portable form:** *(the underlying rule — do not start a long-running process
  an operator may already be running — is real, but the flat prohibition assumes
  the reference's local setup. → `rejected.md`, with the generalized form offered
  as a `stack.md` question instead.)*

## F-088 · Do not write documentation unless explicitly asked

- **Evidence:** `docs/tools/commit-conventions.md:96`.
- **Class:** universal
- **Portable form:** Ships, and it constrains llmcheats itself: the setup skill
  writes the memory file and the stubs it was asked for, and no README.
- **⚠ Tension with the reference.** `full-flow.md:132` makes documentation stage
  11 of the full flow, and `release-artifacts.md:15` requires nine current
  documents. These are reconcilable — the prohibition is on unrequested prose,
  the stage is on keeping owned documents true — but a shipped rule must say
  which it means. Noted for `cheats/`.

## F-089 · Config is one file; secrets arrive as `${VAR}`; unset is fatal

- **Evidence:** `docs/webapp/system-shape.md:50-55` — one YAML via
  `--config`, secrets as `${VAR}` resolved at parse time, "The service itself
  never calls `os.Getenv` for its own settings."
  `docs/webapp/new-app-checklist.md:32` — "one YAML, `${VAR}` secrets,
  fatal on unset". `docs/backend/configuration-loading.md:33` records that
  struct `env` tags "are dead" — a trap where a mechanism appears to work.
- **Class:** stack-specific *(guard: a config-file-driven service)*

## F-090 · The runtime contract is four things

- **Evidence:** `docs/webapp/infrastructure.md:22-36` — env vars, a config
  file, a network, and SIGTERM with a grace period ≥ the drain window. "**systemd
  on a VM, Docker Compose, Kubernetes, a PaaS — all are equally valid
  runtimes**". "That contract is the whole portability story."
- **Class:** universal
- **Portable form:** The most portable thing in the corpus — the reference
  deliberately wrote its infra chapter to hold under any runtime, and every
  section gives the systemd, Compose and k8s form of the same rule. **Model for
  how a guarded rule should be written.**

## F-091 · Artifacts are immutable; a fix is a new tag

- **Evidence:** `docs/webapp/infrastructure.md:119-121` — "a re-upload of
  identical bytes is a no-op, different bytes under the same version are refused
  — a fix is a new tag."
- **Class:** universal

## F-092 · Release speed is a tested property with a number

- **Evidence:** `docs/devflow/release-speed.md:18-20` — commit to
  production under **30 minutes** on a CI pipeline, **5–10 minutes** hand-rolled.
  `:24-32` — the deploy path is one command and "**exercised routinely** — the
  fast path must be the normal path, or it will not work under pressure";
  rollback is one command listed in every release record; "No human-memory
  steps".
- **Class:** universal
- **Portable form:** A named number, a one-command deploy, a one-command
  rollback. "Scripts remember; people do not."

## F-093 · Two alert severities, and anything below WARN is a dashboard

- **Evidence:** `docs/devflow/observability-minimum.md:38-47` — CRIT (paged
  now) and WARN (channel, working hours). "Alerts that do not demand action train
  people to ignore alerts."
- **Class:** universal

## F-094 · Log levels carry meaning: 401/403 Info, 4xx Warn, 5xx Error

- **Evidence:** `docs/devflow/observability-minimum.md:33`, repeated
  `docs/webapp/infrastructure.md:100`.
- **Class:** stack-specific *(guard: an HTTP service)*

## F-095 · Route *pattern*, never raw path, in logs and metrics

- **Evidence:** `docs/webapp/infrastructure.md:98` — "route *pattern* (not
  raw path — cardinality)".
- **Class:** stack-specific *(guard: HTTP service with metrics)*

## F-096 · `any` is prohibited; no manual memoization

- **Evidence:** `docs/frontend/typescript-react-conventions.md:15` — "use
  `unknown` plus type guards"; `:22` — "**No manual `useMemo`, `useCallback` or
  `memo`.** The compiler handles memoization; hand-written memoization is noise
  that goes stale."
- **Class:** stack-specific *(guard: TypeScript; React 19 + compiler)*
- **Generalization test:** the memo rule is actively wrong on React ≤18 without
  the compiler. Must carry a version guard, not just a language guard.

## F-097 · "Who uses this symbol" is a language-server question, not a grep question

- **Evidence:** `docs/frontend/typescript-react-conventions.md:56-62` — "Grep
  mixes fields, variables, serialization tags and comments into one answer." A
  cold index returns a plausible **incomplete** result, so warm it first. And: a
  file-based router directory sits beside the source root, so "a search scoped to
  the source root silently misses every route screen".
- **Class:** universal
- **Portable form:** Prefer find-references over grep for symbol questions; treat
  a cold index's answer as incomplete rather than empty. Relevant to the setup
  skill's own repo-reading phase.

## F-098 · Docs live next to the code, not in an external wiki

- **Evidence:** `docs/devflow/release-artifacts.md:29-32` — "not in an
  external wiki that CI cannot see and reviews do not touch."
- **Class:** universal

## F-099 · The index is maintained in the same change as the file

- **Evidence:** *(pre-merge `docs/flows/INDEX.md:84-87`, since replaced by
  `docs/INDEX.md` — quoted verbatim so the claim stays auditable)* — "**Every
  file added to, renamed in, or removed from `docs/` updates both
  `docs/INDEX.md` and `docs/index.json` in the same change.**… A doc no index
  points at is a doc no agent will find." A machine-readable mirror existed at
  `docs/flows/index.json:9`.
- **Class:** universal
- **Applied to this build:** the mirror was dropped in the merge rather than
  regenerated. A hand-maintained JSON copy of the same table is exactly the drift
  this rule warns about, and the routing an agent actually uses now lives in
  `cheats/routing.md`. One index, one source.
- **Portable form:** **This is the reference's own version of the prompt's
  extensibility contract** — adding a workflow is one file plus one routing row,
  and the routing row is not optional.

## F-100 · Read the file before acting; do not work from memory of it

- **Evidence:** *(pre-merge `docs/flows/INDEX.md:72-80`, since carried forward
  verbatim into the Rules section of the merged `docs/INDEX.md`)* — and the
  deviation rule: deviating from "a **constraint**, a security rule, or a
  triggered workflow gate" needs a written reason, while "an ordinary
  implementation choice — naming, file layout, which of two equivalent idioms —
  is not a deviation and needs no paragraph defending it."
- **Class:** universal
- **Portable form:** The scoping half matters as much as the rule. An agent that
  writes a justification paragraph for every naming choice is as broken as one
  that silently weakens an authz check.

---

# Counts

| Class | Pure | In a split | Total mentions |
|---|---|---|---|
| universal | 80 | 6 | 86 |
| stack-specific | 12 | 4 | 16 |
| project-idiosyncratic | 2 | 2 | 4 |
| **entries** | **94** | **6** | **100** |

Six findings are split — the principle is universal, the mechanism is not:
F-041 (roster vs. gates-survive-role-collapse), F-047 (bump commit vs.
revert-to-roll-back), F-050 (sync waves vs. separate migrate step), F-057
(the console vs. the two-writer lesson), F-075 (frontend zero-comment variant
vs. the comment rule), F-080 (AAA literal vs. justification).

**On the count:** the prompt asked for 40–80. This is 100, which by the
reference's own F-040 ("do not manufacture an artifact a rule did not ask for")
and F-029 (artifact caps) is an overrun worth naming rather than hiding. The
extra 20 are not padding — they are the `docs/` layer, which the prompt's
Phase A did not anticipate because it assumed a monorepo rather than a
two-corpus reference. If you want it at 80, the ones to cut are the
stack-specific frontend and CI-performance entries (F-055, F-056, F-086, F-094,
F-095, F-096), which inform routing guards but produce no shipped rule.

# Open items carried into Phase B

1. **F-002 inverts the build prompt's marker semantics.** Reference wins; the
   prompt's `llmcheats:keep` does not ship.
2. **F-088 vs. stage 11** — the shipped rule must state which of the two it
   means.
3. **F-076** is the weakest universal; it survives the generalization test only
   on the strength of being a stated review rule.
4. **F-096** needs a version guard, not merely a language guard — the strongest
   evidence in the corpus that a `stack-specific` class without a *version*
   dimension is not enough.
5. **Prefix set decided from evidence** (F-010, F-011, F-045, F-047, F-060):
   `feature:` `bug:` `refactor:` `migrate:` `hotfix:` `chore:` `release:`
   `rollback:`. **`deploy:` is rejected** — the reference has no deploy action
   distinct from the bump commit (F-045).

---

# S2 · Second source — the AI prompt playbook

Added after Phase D, when `prompt:` was built. These findings do **not** come
from `$REFERENCE=./docs`. Their source is a separate distillation of the same
production system:

**`ai-prompt-playbook.md`** — how prompts are assembled, verified and made to
ask good clarifying questions in one Go/React-Native product with four LLM agent
roles. Every claim in it carries a `file:line` into that codebase
(`internal/ai/agent/*`, `internal/ai/service/*`, `internal/ai/script/*`), so the
evidence chain is one hop longer than for F-001..F-100: I read the playbook, the
playbook cites the code.

**Why it is trustworthy anyway:** it is the same system `docs/backend/llm-*.md`
describes, and the two agree where they overlap without being copies of each
other — router-as-classifier, load-on-demand read tools replacing preloaded
blocks, the L2 tool-input guard, structured extraction instead of raw user text,
non-PII baggage with content capture gated off. Four independent corroborations
of a second-hand source is the strongest evidence class this report has.

**Citations below are `ai-prompt-playbook.md:<line>`.**

**Class, stated once for the group:** every entry here is `stack-specific`
behind one guard — *the product has a model-facing prompt*. That guard already
exists in `cheats/routing.md` (`docs/backend/llm-*`). Nothing here ships
unconditionally, because a repo with no LLM surface pays context for all of it
and gets nothing.

## F-101 · A prompt is assembled from named blocks; a shared rule lives in exactly one

- **Evidence:** `:30-45` — no specialist prompt exists as one string; a role
  identity prompt is concatenated with six shared rule blocks. `:47-51` — each
  shared block is a const with a doc comment saying which roles get it and why
  one deliberately does not. `:53-56` — one role is assembled at runtime from
  named blocks, and "the assembly function *is* the reading order of the prompt".
- **Prevents:** the same rule drifting between four copies; and a rule silently
  widening an agent's remit because nobody recorded who was meant to get it.
- **Portable form:** Assemble prompts from named blocks. A rule used by more than
  one agent exists once, with a comment naming its audience and its exclusions.

## F-102 · Order a prompt by rate of change; a timestamp in the stable half invalidates everything after it

- **Evidence:** `:58-70` — two system blocks: stable (persona, language,
  injection rules, response rules) invariant per `role + locale + attachment
  kind`, and dynamic (date/time, profile, wearable summary, memory, summary)
  never cached. Quoted verbatim: "Keeping date/time out of the stable block is
  critical: a single changing character invalidates the cache for the rest of
  the block."
- **Scar:** the comment is written in the imperative in production code, which is
  where a cache-cost lesson ends up after it has been paid for.
- **Portable form:** Order prompt sections by rate of change, not by topic.
  Nothing per-request goes above anything per-session.

## F-103 · Every capability carries a trigger and an anti-trigger; confusable pairs carry a contrast

- **Evidence:** `:81-88` — the tool catalogue gives one line per tool with what
  it does, when to call it and what it does NOT do; a separate anti-trigger block
  exists per over-triggered tool and is called "the single highest-leverage
  section in the whole file"; two named tool pairs get an explicit contrast.
  `:106-108` — the domain's own rules make both mandatory when adding a tool:
  "когда вызывать (trigger) и когда НЕТ (anti-trigger — guards against
  over-trigger)".
- **Prevents:** a write tool firing on ambiguous conversation.
- **Portable form:** No capability ships with a trigger alone. Every pair of
  capabilities that get confused is contrasted in both entries.

## F-104 · A role prompt has a fixed section order, and states principles rather than tables

- **Evidence:** `:78-102` — fourteen sections in order: identity, voice, tool
  catalogue, anti-triggers, disambiguation, reasoning framework, conflict
  priority, quality rubric, domain principles, negative space, self-check,
  branching on tool outcomes, forbidden output, output format. `:109-112` — the
  prompts are "a reasoning framework …, not lookup tables", because "tables
  invite pattern-matching; rubrics survive inputs you did not anticipate".
  `:237-258` — the same order restated as a template.
- **Portable form:** Write the stable half in a fixed order ending in forbidden
  output and output format. Express domain knowledge as a framework to apply,
  not a table to match.

## F-105 · Capability awareness in the prompt, data behind a tool

- **Evidence:** `:116-127` — three preloaded blocks were deleted and replaced by
  read tools: a task block whose backward-only window "hid the forward plan and
  bred duplicate tasks", a meals block, a health-scores dump ("a bare block of
  numbers is low-signal in every prompt") and a lab catalogue. What remains in
  the prompt is that the data exists and how to pull it.
- **Scar:** the removed task window is named as the cause of duplicate task
  creation.
- **Prevents:** paying context on every turn for data needed on few; and a fixed
  retrieval window silently hiding what falls outside it.
- **Portable form:** Put capability awareness in the prompt and data behind a
  tool call.

## F-106 · User text and retrieved memory are tagged DATA, with the injection categories enumerated

- **Evidence:** `:135-150` — a verbatim safety block declaring text inside
  `<user_message>` to be data, not instructions; enumerating what an injection
  tries to do (change persona, disable safety rules, reveal the system prompt,
  call tools with fabricated data); and specifying the response as *answer the
  legitimate part, ignore the injection, do not mention it*. `:152-153` — stored
  memory gets the same treatment: "Anything you pulled from a store is untrusted
  input too."
- **Portable form:** Tag every untrusted span as data, enumerate the injection
  categories rather than saying "ignore injections", and specify the behaviour
  positively rather than as a refusal.

## F-107 · Precompute arithmetic, dates and aggregates; state them as authoritative

- **Evidence:** `:157-161` — a precomputed time-and-calendar block exists "so
  the LLM never performs date arithmetic", and tool rules reference the anchor
  instead of asking for a calculation. `:163-165` — today's calorie balance is
  rendered from the same source the product's own screen uses, "so the model
  quotes them instead of re-summing meal logs and contradicting the app".
- **Prevents:** the model's arithmetic disagreeing with the UI's.
- **Portable form:** Every number the model would derive is computed in code,
  injected, and marked authoritative.

## F-108 · Structured output ships a closed enum, two worked examples, and the consequence of an invalid value

- **Evidence:** `:171-181` — the extraction schema lists a closed 10-value
  dictionary verbatim plus allowed groups and enums, then Example A (clear case,
  high confidence) and Example B (vague signal → observation flag, confidence
  0.55), closing with the failure mode: a value outside the closed dictionary is
  rejected by the backend.
- **Portable form:** enum → confident example → uncertain example → what happens
  when the value is invalid.

## F-109 · Ban echoing internal markers; deliberate duplication is fine when the copies agree

- **Evidence:** `:184-195` — a shared block bans two leak classes for all four
  roles: app mechanics ("block", "reject", "error") and verbatim internal labels
  (`[SAFETY CONSTRAINTS]`, `[NEEDS REVIEW]`, `task=<id>`, `severity=`) — "это
  внутренние метки для тебя — пересказывай их СУТЬ". The doc comment states the
  overlap with a role's own ban is "reinforcement, not contradiction".
- **Portable form:** Every internal marker injected into context is explicitly
  banned from output. Repeating a load-bearing rule is allowed; say in a comment
  that it is a duplicate and keep the copies in agreement.

## F-110 · The output contract is a contract with the renderer

- **Evidence:** `:203-211` — the prompt forbids listing in prose what a card
  renders; options a tool returns as cards must not be re-listed. On the client
  those cards are attachments on the stream frame driving the reply bars, so
  "duplicated content is a bug, missing content is a bug". `:213-216` — the
  prompt also specifies when prose and when a list, plus a phone-reading
  constraint, because format follows the medium.
- **Portable form:** Decide the rendering surface first, then write the output
  format rule from it. Content the UI renders is banned from the prose.

## F-111 · In a classifier prompt, the boundaries are the work

- **Evidence:** `:220-233` — an intent-classifier prompt on the cheap tier: one
  line of role, the closed label set with trigger vocabulary, tie-break rules for
  every overlap, a continuity rule with three enumerated exceptions, and a
  JSON-only output line. Measured proportion: "~15% defining the labels, ~75%
  resolving collisions between them, ~10% output format".
- **Portable form:** Budget a classification prompt by collisions, not by labels,
  and write the tie-breaks as ordered rules.

## F-112 · Tool input is validated in code, and the failure string is part of the contract

- **Evidence:** `:267-284` — every tool has a parser that validates enum, bounds
  and format before anything executes; raw user text is never stored in a
  content field, which is length-capped; and an executor that fails must return
  an `Error:`-prefixed string, "because otherwise the next layer reads it as
  success and *'LLM confirms work that didn't happen'*".
- **Portable form:** Validate every model-supplied argument in code before
  execution, and standardise one failure-string contract across executors.

## F-113 · Must-not-happen is a deterministic pre-execution guard, with a named redaction boundary

- **Evidence:** `:285-297` — a second guard validates the model's tool call
  against the user's structured contraindications "regardless of what the prompt
  said", producing block / soft / caution. The matched internal pattern id never
  leaves the guard: it maps to a plain-language area, and an unmapped pattern
  degrades to a generic phrase rather than leaking the enum. Stated as a rule:
  "prompt-level safety is a preference; a deterministic pre-execution check is a
  guarantee".
- **Portable form:** Anything that must not happen is enforced in code before
  execution. Internal identifiers are translated at one named boundary and never
  cross it.

## F-114 · "Did nothing" is a distinct outcome from success

- **Evidence:** `:299-315` — tool results are classified into
  `success | skip | error | safety_abort`, with CI failing when an executor
  emits a string no pattern matches. The enumerated traps: "Successfully created
  0 …" is a skip, not a success; safety aborts intentionally lack the `Error:`
  prefix because they carry model-facing instructions, so without their own
  branch "they leak into 'success' and blind the metric to every safety abort";
  cap rejections and already-set no-ops are skips.
- **Scar:** the safety-abort branch exists because the metric was blind.
- **Portable form:** Classify outcomes into at least success / skip / error /
  abort. A binary signal counts "did nothing" as success and inflates quality.

## F-115 · Pin the tool surface with a golden hash; never unit-test prompt prose

- **Evidence:** `:319-328` — a snapshot test pins, per role and **in order**, a
  sha256 of every tool description and input schema, because order is the prompt
  cache prefix; an intentional change is re-baselined with the reason written
  into the golden table's comment. Bijection tests catch a half-registered tool.
  And explicitly: "DO NOT test prompt contents on their own (flaky, changes
  often)" — test the surface and the parsers, test the prompt behaviourally.
- **Portable form:** Hash the model-facing surface in order and fail CI on drift.
  Do not assert on prompt wording; assert on behaviour and on structure.

## F-116 · The eval pack lives in data, behind a flag, and asserts present / absent / count

- **Evidence:** `:330-347` — evals sit behind a build tag because they bill real
  API calls, with the per-pack cost stated in the file header (~$0.10 for 20
  scenarios); scenarios live in YAML testdata so non-engineers can extend them;
  each declares allowed types, expected content, **`must_NOT_contain`**, and
  count bounds. The negative assertion and the count bounds "are what most
  home-grown evals lack — they are how you catch over-extraction and
  hallucinated extras". The domain rule is mandatory: "After any changes — an
  eval is mandatory", and "After eval fails — a separate fix commit, not amend".
- **Portable form:** Eval scenarios are data, gated behind a flag, with cost
  stated, asserting what must appear, what must not, and how many. Running one is
  mandatory after any prompt change; a failure is repaired in its own commit.

## F-117 · Judge a prompt change by a read-only replay diff over N real cases

- **Evidence:** `:349-368` — a replay harness runs production AI logic against
  real users from a dev database: read-only enforced twice (a read-only
  transaction *and* no-op stubs recording what would have been created, sent or
  written), refusing production without an explicit flag and an interactive
  confirmation; structured per-run output is the diff source of truth, and a
  `diff <run-a> <run-b>` subcommand answers "what changed across N users" rather
  than "is this one answer good". Fixtures stand in for state you cannot
  reproduce. The README states the residual cost: model calls still bill.
- **Portable form:** Before/after over N real cases, on a harness that is
  read-only at the store *and* at every mutating dependency.

## F-118 · Traces carry ids only; content capture is a separate gate; cost is logged per call

- **Evidence:** `:370-380` — one span per model call, identity from baggage set
  once at flow entry, with the invariant that baggage carries only non-PII ids
  and slugs while message content sits behind a `CaptureContent` gate that is
  off by default. Every call logs into a usage table including cached vs written
  prompt tokens, with the tiers named ($0.02-0.05/call vs $0.0005) and the rule
  "Default to Haiku for meta". Tool outcomes are exported as a labelled counter
  so a rise in aborts or skips is visible without reading transcripts.
- **Portable form:** Trace with ids; gate content separately and default it off.
  Log per-call cost and state a budget per model tier.

## F-119 · Two question regimes; a scripted question has a fixed anatomy and is validated at load

- **Evidence:** `:404-408` — two deliberate regimes, and "mixing them is how
  interrogation-feeling chatbots happen". `:452-473` — the anatomy: acknowledge
  what you already know first ("a question that ignores prior answers reads as
  'you weren't listening'"); one question per step; options as sentences, not
  labels, because a bare label "forces them to guess your threshold"; an honest
  opt-out in every set; 3-7 options, with the widest set reserved for the single
  most important question; a stable slug to branch on versus localised display
  text; and the answer's destination declared with the question, so a closed
  question needs no model call and completes in ~100ms against ~1-3s for an open
  one. `:564-571` — the parser rejects a broken step at load: options missing,
  variants on a step type that cannot use them, a variant set without a
  fallback. `:553-562` — the conditional vocabulary is deliberately two
  operators, so "config languages" do not grow into unmaintainable programs.
- **Portable form:** Pick the regime deliberately. A closed question acknowledges
  prior answers, asks one thing, offers 3-7 sentence-length options with a
  truthful out, branches on slugs, and declares where the answer goes. Validate
  the graph at load, not when a user reaches the broken step.

## F-120 · Every open question carries its extraction instruction, ending in the non-answer clause

- **Evidence:** `:499-536` — each free-text step declares its extraction: the
  allowed fact types (narrowing the output space, enforced engine-side), a
  written instruction, and a declared failure action that advances instead of
  trapping the user. Four moves called out: justify the question inside the
  question ("это критически важно для подбора упражнений"); one fact per thing
  ("не объединяй несколько травм в один факт"); and the non-answer clause —
  *"если ответ 'не помню' — не делай вызовов"*, *"не выдумывай данные"* —
  identified as "the single most repeated line in the entire script family, and
  it is what prevents an empty answer from becoming a fabricated fact".
- **Scar:** the clause is repeated in every script because fabricated facts are
  what happens without it.
- **Portable form:** Attach the extraction instruction to the question. Narrow
  the output space, state one-record-per-thing, end with "if the reply is a
  non-answer, extract nothing; do not invent", and declare what a failed
  extraction does.

## F-121 · Classify non-answers: one re-ask, then skip; a question back is never charged

- **Evidence:** `:538-551` — every free-text reply is classified `relevant` /
  `off_topic` / `user_question`. "Don't know" counts as relevant. Off-topic gets
  one soft redirect (cap configured per script) and then the step is skipped
  with a null. A question back is answered in the specialist's voice, the
  question re-emitted, and it "does not count toward the off-topic cap —
  engaging with a question is legitimate".
- **Portable form:** Re-ask once, then move on with a null. Never charge a
  question back against the retry cap.

## F-122 · Gate an expensive question chain behind one cheap question

- **Evidence:** `:490-497` — a yes/no gate ("do you remember your working
  weights?") precedes four consecutive open questions; users who cannot answer
  never see them.
- **Portable form:** Ask "do you know X?" before asking "what is X?".

## F-123 · The "when NOT to ask" list is longer than the "when to ask" list

- **Evidence:** `:577-598` — four when-to-ask cases (a hard input is missing and
  guessing is unsafe; which object to act on is genuinely ambiguous; a safety
  block; equipment/level unknown) against five when-not-to, "stated more
  emphatically": act immediately on a typical request; do not stall on data a new
  user does not have yet; do not ask which of one candidate ("лишний вопрос про
  единственную обсуждаемую тренировку выглядит так, будто ты забыл контекст");
  do not fish for additional goals; do not ask about anything this agent has no
  authority to change. `:600-611` — how to ask when you do: a short concrete
  question with options; and a stateless retry must be described as stateless,
  "or the model will assume partial persistence".
- **Portable form:** Write both lists, and make the negative one longer. State
  explicitly when a rejected call persisted nothing.

## F-124 · Design the answer surface before the question

- **Evidence:** `:613-630` — single-choice renders as a chip list, multi-choice
  as checkboxes with an explicit submit; a scripted step locks free typing by
  default with a per-step override; quick replies derive from message
  attachments rather than store state so there is one source of truth; and
  option labels must fit a phone row, which is what produced the four-to-seven
  word sentences in the script. "A closed question with no chip UI is a worse
  open question."
- **Portable form:** Settle how an answer will be rendered and captured before
  writing the question.

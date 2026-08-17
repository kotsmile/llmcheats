# Development Flow — the project memory file

## 15. Project memory — `CLAUDE.md` and `AGENTS.md`

Every other artifact in this reference has to be asked for by name. This one
arrives on its own: Claude Code loads `CLAUDE.md` into a fresh context before the
first turn — the project file plus every `CLAUDE.md` above the working
directory, concatenated root-first so the most specific instruction is read last
([Claude Code, *How Claude remembers your project*](https://code.claude.com/docs/en/memory)).
Codex does the same with `AGENTS.md`, discovering files from the git root down
and merging them root-first, with the file closest to the work overriding what
came before
([OpenAI, *Custom instructions with AGENTS.md*](https://learn.chatgpt.com/docs/agent-configuration/agents-md)).

That makes it the only place where a decision outlives the run that took it, and
the reason a project can plan less over time. An architecture stage exists to
tell a developer what this system's patterns are; once the patterns are written
here, every later session starts already knowing them, and the architecture
stage's skip test (`devflow/2-full-flow.md` §3.14) starts being met — the stage
closes because its work is already done. The architecture is
then enforced where the code is actually written — the developer against
`webapp/`, and the diff against `code-reviewer` — rather than proved in advance
by a document nobody rereads.

Two properties set the rules below. It is **context, not configuration**:
delivered as a message, with no guarantee of compliance, so anything that *must*
happen belongs in a hook or in CI, not in a memory line. And it is loaded **in
full, every session**, so its length is a permanent per-session cost — Anthropic
advises keeping it to the low hundreds of lines and warns that longer files both
consume more context and reduce adherence, while Codex simply stops adding files
once the instruction chain hits a configurable byte cap.

**The house ceiling is tighter than the vendor's advice: keep the whole file
under about 120 lines, with no section past 20.** Anything longer is named as a
file path instead of inlined. The reason for going tighter is that a *generated*
file fills whatever cap it is given, and this one is generated
(`/llmcheats:artifacts`) — the vendor's guidance is written for a file a human
adds to a line at a time.

### 15.1 What goes in

Six sections — **Project**, **Architecture decisions**, **DevOps decisions**,
**Review rules**, **Development patterns**, and **Keeping this file current** —
holding the facts every session needs and nothing else:

- **How to run it** — build, test, lint, migrate: the commands, not prose about
  them. A step described without a command is the bug `devflow/1-principles-roles.md`
  §1 names.
- **The architecture this project actually follows**, and every place it departs
  from `webapp/` *with the reason*. This is the consistency half: the next
  session extends what is there instead of importing this reference's defaults
  over a codebase that decided otherwise.
- **Decisions that cost a discussion** — why raw SQL here, why this queue, why
  this auth model — one line each, naming the ADR or plan file that holds the
  argument. The line is the index; the file is the record.
- **Conventions a diff would otherwise break**: error mapping, naming, migration
  ordering, where tests live, what the module boundaries are.
- **What not to touch** — generated files, vendored code, paths that look editable
  and are not.
- **Review rules** — what a reviewer of this repo blocks on: the constraints of
  §1 above, plus whatever this project has learned the hard way.
- **Keeping this file current** — the maintenance rule, written into the artifact
  itself so it outlives whatever wrote it: the repeat trigger below, no status, no
  secrets, and a decision recorded in the run that took it.

The trigger for adding a line is a **repeat**: the same correction typed twice,
the same mistake made twice, something review caught that the next session should
have known. One occurrence is noise; twice is a convention nobody wrote down.

### 15.2 What stays out

- **Secrets, tokens, hostnames, customer names.** The file is committed and fed
  to a model every session.
- **Anything the code or `git log` already answers.** It is loaded whether or not
  it is needed, which is exactly the cost `devflow/10-flow-cost.md` §14.3 exists
  to control.
- **Status.** "Currently working on X" is stale within a day; that belongs in the
  plan file (`devflow/8-resuming.md`).
- **A copy of `webapp/` or `devflow/`.** Reference by filename and let the agent
  read it when the task needs it.
- **Procedures that matter in one subtree only** — those go beside that code, not
  into the file every session pays for.

### 15.3 One source, two filenames

The two tools do not read each other's file: Claude Code reads `CLAUDE.md` and
not `AGENTS.md`, and documents an `@AGENTS.md` import or a symlink as the way to
serve both ([Claude Code](https://code.claude.com/docs/en/memory)). Two hand-maintained
copies is the drift this reference warns about everywhere else, so **keep one
file authoritative and have the other point at it** — memory in `AGENTS.md`, with
`CLAUDE.md` reduced to `@AGENTS.md`, or the reverse.

**When llmcheats is installed into a project it manages a block inside
`AGENTS.md`**, between `<!-- llmcheats:begin -->` and `<!-- llmcheats:end -->`,
holding the pointer to the installed docs. The installer regenerates that block
on every update and preserves everything outside it. **Write project memory
outside those markers.** Anything placed inside is overwritten by the next
`install.sh` run, and the markers themselves are not yours to move — a damaged
pair makes the installer refuse to touch the file at all.

Codex builds its instruction chain once at startup, so an edit made mid-session
does not reach the agent until it restarts. A convention written during a flow
governs the *next* session, not the one that wrote it.

### 15.4 Who writes it, and when

- **Under Claude Code, `/llmcheats:artifacts` writes it** — inventory the project,
  fill the six sections above, show what you would write before writing it. That
  is the normal way this file first comes to exist, whether after a delivery flow
  or against a codebase that predates all of this. It **refreshes rather than
  replaces**: where the documentation stage below already recorded something, that
  entry stands unless it is now wrong.
- **The documentation stage owns it** (`devflow/2-full-flow.md` §3.11), beside
  the READMEs and runbooks: the developer writes the convention and command
  lines, the decision lines come from the architecture stage's design document,
  and the security auditor's deltas from its implementation review.
- **The orchestrator never writes it directly.** It holds no project file while a
  flow is open (`devflow/8-resuming.md`); it delegates the update and then
  validates that the file exists and says what the flow decided.
- **The asap flow updates it only when the change established a convention.**
  Otherwise it names the omission in its hand-back under `Skipped`
  (`devflow/6-asap-flow.md` §10.6) — a one-pass flow does not get to invent
  project-wide rules quietly.
- **A decision is written in the run that took it.** Deferred to a cleanup pass,
  it is re-litigated in the next session instead, which is the most expensive
  kind of re-planning (`devflow/10-flow-cost.md` §14.6).

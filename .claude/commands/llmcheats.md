---
description: Work on the llmcheats repo itself — this session is the maintainer. Use to add or change a doc file under docs/, an agent under agents/, a slash command under commands/, the webapp-guide skill, install.sh, or the README — anything that ships to users of llmcheats. It holds the invariants, the per-change checklists, the install contract, and the nine checkers it launches directly. Do NOT use to build or review an application with llmcheats (that is dev-team, asap, or a specialist), and do NOT use outside the llmcheats checkout: it only knows this repo's conventions.
argument-hint: <what to change | check | what a run did>
---

Change or verify something in **llmcheats** itself: the reference (`docs/`), the
agents it ships (`agents/`), the slash commands (`commands/`), the skill
(`skills/`), `install.sh`, or the `README.md`.

**You are the maintainer for this run.** You hold the invariants, the path
choice, the writing and the hand-back — and you launch each checker yourself.

Do **not** hand this to a `llmcheats` subagent. The running-agent indicator only
names agents this session launched itself; anything deeper collapses into
`(+N)`, so a delegated chain shows the operator `llmcheats (+3)` and never the
`invariant-checker` that is actually running
(`docs/devflow/7-flow-visibility.md`). Launching the checkers from here puts
each of them in the indicator by name. The writing was never delegable anyway:
the checklists in `.claude/llmcheats-checklists.md` would have to be pasted into
a writer subagent's prompt, which is the one thing invariant 1 forbids.

**Task:** $ARGUMENTS

1. If the task is empty, ask what to change — one sentence — and stop.
2. Confirm the working directory has `install.sh` and `docs/INDEX.md` at its
   root. If it does not, say so in one sentence and stop — these conventions are
   about this repo, not whatever repo is open. Do not retarget the change at
   whatever repo is open, and never reconstruct a missing doc from memory.

## Where the reference is

The source of truth is this repo's working tree — `docs/INDEX.md`,
`docs/webapp/`, `docs/devflow/`. Read `docs/INDEX.md` to pick a file, then read
only that file. Never read an installed copy under
`~/.claude/llmcheats/docs/` or `~/.codex/llmcheats/docs/`: those are outputs of
`install.sh` and will be stale.

## The invariants

1. **The token budget is the whole point.** `Read` loads a file whole, and a
   full-flow run reads from a dozen fresh contexts. One topic per file; split
   anything past ~15KB. Point agents at *files*, never at the tree, and never
   paste doc contents into a delegation prompt.
2. **Every doc file has a row in `docs/INDEX.md`** with its § range and a "read
   it when" line. A file that is not in the index is invisible to every agent.
3. **Cross-reference by filename** (`webapp/5-security.md`) — never by a bare
   "§5". An agent cannot open a section number.
4. **Section numbers are stable.** They are cited from agent files and from
   other docs. Add new sections at the end (§10, §11); do not renumber, and do
   not renumber the files either — `devflow/3-fast-flow.md` is referenced by
   name from half the repo.
5. **Every shipped agent states where the docs are** — first existing of
   `<project>/.claude/llmcheats/docs/`, `~/.claude/llmcheats/docs/`,
   `~/.codex/llmcheats/docs/` — **and what to do when none exist**: say so, work
   from the agent file, never invent the contents. It names its own files and
   reads neither the tree nor `INDEX.md`; the index is for choosing a file, and
   an agent whose files are already chosen has no reason to pay for it.
6. **Nothing is theoretical.** Every rule here came out of a system that shipped.
   If you cannot say where a rule came from, it does not go in.
7. **Prose addressed to a human is one or two sentences.** The docs say that;
   the docs obey it.
8. **Tokens are the second budget, and it is measured in contexts.** The full
   flow is 13 fresh contexts, the fast flow seven, the asap flow one, so a
   change that adds a stage, an agent, a gate round or a doc read has to say
   what it costs and why it is worth it (`docs/devflow/10-flow-cost.md`).
9. **A claim from outside this repo carries a link to a primary source.**
   Invariant 6 bans the theoretical; this is the one exception and its price —
   a vendor number or a published result is cited inline, fetched not
   remembered, and stated as a shape ("about an order of magnitude cheaper")
   rather than a figure that goes stale the next time pricing moves.

## What ships and what does not

`agents/`, `commands/`, `skills/` and `docs/` at the repo root are the payload:
`install.sh` copies them into the user's `~/.claude` and `~/.codex`.

`.claude/` in this repo is **not** payload — it is this repo's own tooling (this
command and the nine maintenance checkers it launches), tracked in git and never
installed anywhere. Repo-maintenance tooling goes there; anything a user of
llmcheats should get goes in the root directories. Do not add a maintenance
agent to `agents/`, and never commit `.llmcheats/`, `AGENTS.md`, or an installed
copy of the payload under `.claude/` — those are install artifacts of
`./install.sh --project .` and are git-ignored for that reason.

## What each tool supports

Only Claude Code reads `agents/`, `commands/` and `skills/`; Codex receives the
docs and the `AGENTS.md` pointer and nothing else. Anything that must reach both
tools therefore lives in `docs/` — frontmatter is a Claude-side lever only, and
a rule that exists only in an agent file does not exist for Codex users.

The four frontmatter levers and the only reasons to reach for them:

- `tools:` — restricts, never grants. Orchestrators and reviewers are
  restricted; developers inherit everything.
- `disallowedTools: Task` — on every agent that produces rather than routes. A
  specialist that can delegate opens a fan-out nobody counted and nobody
  budgeted; only `dev-team` and `project-manager` keep `Task`.
- `model:` — only downward, only on a router
  (`.claude/llmcheats-checklists.md`, "Add a shipped agent").
- `disable-model-invocation: true` — on a command that starts a whole flow
  (`commands/pm.md`, `commands/asap.md`). The operator decides to open a
  13-context run; the model does not get to open one on its own initiative.
  **Not** on this command: a plain-English request to change llmcheats must be
  able to land here, because the alternative is a session editing the payload
  without ever reading the invariants above.

## Keeping a running flow visible

`commands/status.md` and `commands/agents.md` reconstruct a running flow from
the subagent sidecar transcripts on disk, so anything you change about how
agents are launched, named or nested changes what those two can see. When you
edit them, preserve the rules `observer` states in full — a `Task` result means
*launched*, a repeated `agentType` is a loop **or** a fan-out — and keep saying
what to print when nothing is found (`docs/devflow/7-flow-visibility.md`).

## The checkers

You are the only one here that writes. Nine repo-local specialists under
`.claude/agents/` read, check and report; you decide and edit. They exist
because each one is *read a lot, hand back a little*: a round trip's stdout, a
grep across forty files, a fetched web page and a directory of sidecar
transcripts would otherwise all land in this context beside the change being
written. Split out, each costs one context and returns a verdict
(`docs/devflow/10-flow-cost.md` §14.3).

| agent | answers | open it when |
|---|---|---|
| `bestpractice-searcher` | is this outside claim sourced (invariant 9) | the change states a vendor number, a published result, or tool behavior this repo cannot observe |
| `invariant-checker` | index rows, filename cross-references, stable §, the docs-location paragraph | anything under `docs/` or `agents/` changed |
| `contradiction-checker` | do the files citing a changed doc still agree with it | a doc gained or changed a rule |
| `drift-detector` | have the copies of a repeated paragraph diverged | the change edited prose that appears in more than one file |
| `support-checker` | the Claude/Codex split, the frontmatter levers, the marker string, manifests | `agents/`, `commands/`, `skills/` or `install.sh` changed |
| `cost-optimizer` | bytes, contexts, cache prefix, model tiering (invariants 1 and 8) | a file grew, or a stage, agent or gate was added |
| `install-verifier` | the round trip, for real, in a `/tmp` scratch dir | `install.sh` changed, or a payload file was added or removed |
| `routing-prober` | does the model actually route on this `description:` | a `description:` was added or reworded, or two agents may now claim the same work |
| `observer` | what the run did, and what nobody checked | more than two of the above ran, or the run looks stalled |

**Every one of them is conditional.** A doc-only edit opens three contexts, not
nine. Name the ones you skipped and why — an unopened check is a line in "not
verified", never a silent pass. `routing-prober` is the expensive one — it spends
a headless session per variant per run — so it is gated on a changed
`description:`, never run for completeness.

Delegating to any of them: pass the **scope** — which files changed and what the
change is for — and never paste doc contents or a diff, since they read the repo
themselves. **One `Task` call per checker, run in the background** so the check
is named in the indicator and fires a completion notification. A `Task` result
means *launched*, never *finished*: pull each hand-back as it lands and report
each verdict upward as it arrives rather than batching them to the end
(`docs/devflow/7-flow-visibility.md` §11.3–11.4).

## The three paths

**Change** — the request names something to add or alter:

1. **Research** — only if the change makes a claim from outside this repo. Give
   `bestpractice-searcher` the claim, not the file. It hands back a shape and a
   URL; you write the sentence.
2. **Write** — you, from `.claude/llmcheats-checklists.md`: the per-change
   checklist for a doc, a shipped agent, a command, a skill, maintenance tooling
   or `install.sh`. Open it when you reach this stage and not before — the Check
   and Observe paths never need it. Never delegate the writing: the checklists
   would have to be pasted into a writer subagent's prompt, which is the one
   thing invariant 1 forbids.
3. **Check** — launch every applicable checker **in parallel, in one block**.
   They read disjoint things, so the fan-out costs no overlapping context
   (`docs/devflow/10-flow-cost.md` §14.5). `invariant-checker` and
   `install-verifier` are mechanical, so pick the cheap tier for them on the
   `Task` call — the tier belongs to the stage, not to the agent file (§14.2).
4. **Fix** — you apply, then re-run only the checker that found something.
   **Bounded at two rounds.** A third is an escalation that already happened:
   state both positions and hand the decision to the operator (§14.6).
5. **Report** — the hand-back below, with every skipped check named.

**Check** — the request is to verify without changing. Skip stages 1, 2 and 4.
Run every checker the current tree warrants, including the ones a change would
have gated off, because there is no change to gate on. **A check path edits
nothing**, even when a checker hands back a one-line fix — that fix is the
operator's next request, not this run's work.

**Observe** — the request is about the run itself. `observer` alone; relay its
table and its "not verified" list. Do not re-derive what it reports: if it says
a check never ran, that is the finding.

## Hand-back

Report, in this order:

- **What changed** — files touched, one line each.
- **Invariants involved** — which of the nine the change had to satisfy, and
  how (index row added, filename cross-references used, sections appended not
  renumbered, an added stage priced, an outside claim linked).
- **Checks** — which checkers ran and their verdicts, one line each
  (`invariant-checker CLEAN`, `cost-optimizer OVER BUDGET: 1`), and which you
  skipped with the reason. Quote a verdict as written; never soften one.
- **Verified** — what you actually ran: `bash -n install.sh`, a scratch-dir
  round trip, a grep proving no stale cross-reference to a renamed file.
- **Not verified** — the union of every checker's own "not verified" block
  plus the checks nobody opened, and what could break because of it:
  agents whose text you did not re-read after a doc rename, the other tool
  (Claude vs Codex) you did not install into, whether a reworded `description`
  still wins delegation. Name it; do not leave it implied.

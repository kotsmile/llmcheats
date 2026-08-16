---
description: Work on the llmcheats repo itself — conventions, per-change checklists, and the install contract
argument-hint: <what to change>
---

You are working on **llmcheats** itself: a reference (`docs/`), the agent
definitions that enforce it (`agents/`), the slash commands (`commands/`), a
skill (`skills/`), and `install.sh`, which ships all of it into `~/.claude` and
`~/.codex`.

**Task:** $ARGUMENTS

First check you are in the right place: the working directory must have
`install.sh` and `docs/INDEX.md` at its root. If it does not, say so in one
sentence and stop — these conventions are about this repo, not about whatever
repo is open.

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
5. **Every agent states where the docs are** — first existing of
   `<project>/.claude/llmcheats/docs/`, `~/.claude/llmcheats/docs/`,
   `~/.codex/llmcheats/docs/` — **and what to do when none exist**: say so, work
   from the agent file, never invent the contents.
6. **Nothing is theoretical.** Every rule here came out of a system that shipped.
   If you cannot say where a rule came from, it does not go in.
7. **Prose addressed to a human is one or two sentences.** The docs say that;
   the docs obey it.

## Checklists

**Add a doc file** → create it under `docs/webapp/` or `docs/devflow/` with the
next free number and a §-numbered heading; add its `docs/INDEX.md` row; name it
in the agents that should read it, including the specialist→file table in
`agents/dev-team.md`; update the `README.md` tree if the shape of the reference
changed.

**Add an agent** → `agents/<name>.md` with YAML frontmatter: `name`, and a
`description` that says **when to use it and when not to** (delegation is
chosen from that line alone). Add `tools:` only to restrict — orchestrators and
reviewers are restricted, developers inherit everything. The body names the one
or two doc files it may read, and ends with a hand-back section that includes
*what was not verified*. Then: the `README.md` agent list, and the roles table
in `docs/devflow/1-principles-roles.md` if it owns a role.

**Add a command** → `commands/<name>.md`, frontmatter `description` +
`argument-hint`, body uses `$ARGUMENTS`. A command that delegates says which
agent and passes the request verbatim; a command that computes says what to run
and how to report an empty result. Add it to `README.md`. `install.sh` picks up
`commands/*.md` automatically — no installer edit needed, but **the file must
contain the word "llmcheats" somewhere**: that string is how the installer
tells its own files from the user's, and a file without it gets a spurious
`.bak-llmcheats` copy and a warning on every update.

**Touch `install.sh`** → it must stay re-runnable and non-destructive:

- A same-named file llmcheats did not install is backed up to `.bak-llmcheats`,
  never silently replaced.
- The manifests under `<base>/llmcheats/` (`agents.list`, `commands.list`) drive
  both stale-file removal and uninstall — anything installed must be recorded.
- The Codex `AGENTS.md` block only ever replaces itself between its markers;
  damaged markers abort the edit instead of truncating the file.
- Verify with `bash -n install.sh`, then a real round trip into a scratch dir:
  `./install.sh --project /tmp/x`, check what landed, `./install.sh uninstall
  --project /tmp/x`, confirm it is clean again.

## Repo conventions

Commit messages are one line. Comments are 1–2 rows, only where the code cannot
speak for itself. Keep the `README.md` file tree in sync with reality — it is
the first thing anyone reads, and a tree that lies is worse than no tree.

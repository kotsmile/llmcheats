# llmcheats per-change checklists

Read this only on the Change path of `/llmcheats`, once the request is known to
add or alter something. The Check and Observe paths never need it.

**Add a doc file** → create it under `docs/webapp/` or `docs/devflow/` with the
next free number and a §-numbered heading; add its `docs/INDEX.md` row; name it
in the agents that should read it, including the specialist→file table in
`agents/dev-team.md`; update the `README.md` tree if the shape of the reference
changed.

**Add a shipped agent** → `agents/<name>.md` with YAML frontmatter: `name`, and
a `description` that says **when to use it and when not to** (delegation is
chosen from that line alone). Add `tools:` only to restrict — orchestrators and
reviewers are restricted, developers inherit everything. Add `model:` **only to
pin downward**, and only for an agent that routes rather than produces:
inheriting is the default so the operator's model choice wins, and pinning a
specialist up overrules them while pinning one down quietly ships worse work
(`docs/devflow/10-flow-cost.md`). The body names the one or two doc files it may
read, and ends with a hand-back section that includes *what was not verified*.
Then: the `README.md` agent list, and the roles table in
`docs/devflow/1-principles-roles.md` if it owns a role.

**Add a shipped command** → `commands/<name>.md`, frontmatter `description` +
`argument-hint`, body uses `$ARGUMENTS`. A command that delegates says which
agent and passes the request verbatim; a command that computes says what to run
and how to report an empty result. Add it to `README.md`. `install.sh` picks up
`commands/*.md` automatically — no installer edit needed, but **the file must
contain the word "llmcheats" somewhere**: that string is how the installer
tells its own files from the user's, and a file without it gets a spurious
`.bak-llmcheats` copy and a warning on every update.

**Add a shipped skill** → `skills/<name>/SKILL.md`, plus any reference files
beside it: skills install as whole directories, so a skill may grow files.
`install.sh` picks up `skills/*/` automatically and records the name in
`skills.list`, but `SKILL.md` must contain the word "llmcheats" for the same
reason a command must. Add it to the `README.md` tree and the install table.

**Add repo-maintenance tooling** → `.claude/agents/<name>.md` or
`.claude/commands/<name>.md`, same frontmatter rules as above. It stays out of
the root `agents/`/`commands/` so `install.sh` never ships it. Un-ignore it by
name in `.gitignore` — `/.claude/agents/*` is ignored so an install artifact can
never be committed, which means a new maintenance agent is invisible to git
until it has its own `!` line. Add it to the `README.md` tree. A new *checker*
also needs its row in the checker table in `.claude/commands/llmcheats.md` and
the condition that opens it, and it must justify its context against invariant
8: what it reads that the session would otherwise read, and what it hands back
instead.

**Touch `install.sh`** → it must stay re-runnable and non-destructive:

- A same-named file llmcheats did not install is backed up to `.bak-llmcheats`,
  never silently replaced. Removal is held to the same standard: every path that
  drops a file checks the marker first, and one without it belongs to the
  operator — kept with a warning where nothing is landing to replace it
  (`sync_md_dir`, `sync_skills`), backed up where a flat-era copy is being
  superseded (`drop_flat_commands`).
- The manifests under `<base>/llmcheats/` (`agents.list`, `commands.list`,
  `skills.list`) drive both stale-file removal and uninstall — anything
  installed must be recorded. Build a manifest in a temp file and `mv` it into
  place: a copy that dies halfway must not leave a short manifest, because what
  is missing from it can never be updated or removed again.
- **Uninstall is as careful as install.** A file whose "llmcheats" marker is
  gone was edited by the user, so it is kept with a warning rather than
  deleted, and a skill's backup lives *beside* the skill directory because
  uninstall removes that directory whole.
- The Codex `AGENTS.md` block only ever replaces itself between its markers;
  damaged markers abort the edit instead of truncating the file. Check the
  markers *before* copying the docs, and remove the block *before* deleting
  them — an abort must never leave docs nothing points at, or a pointer to
  docs that are gone. Rewrite through a temp beside the target seeded with
  `cp -p`, so the user's file keeps its own mode instead of `mktemp`'s 0600.
- Verify with `bash -n install.sh`, then a real round trip into a scratch dir:
  `./install.sh --project /tmp/x`, check what landed, `./install.sh uninstall
  --project /tmp/x`, confirm it is clean again. Never round-trip into this repo
  itself — that is what leaves install artifacts behind.

## Repo conventions

Commit messages are one line. Comments are 1–2 rows, only where the code cannot
speak for itself. Keep the `README.md` file tree in sync with reality — it is
the first thing anyone reads, and a tree that lies is worse than no tree.

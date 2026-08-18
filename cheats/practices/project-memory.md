# Project memory — `AGENTS.md` and `CLAUDE.md`

<!-- F-001 -->
The one artifact loaded unprompted every session. That makes its length a
permanent per-session cost.

**Keep the whole file under about 120 lines, with no section past 20.** Anything
longer is named as a file path instead of inlined.

This is tighter than the vendor guidance on purpose: a *generated* file fills
whatever cap it is given, and this one is generated.

## One source, two filenames

<!-- F-003 -->
The two tools do not read each other's file. Claude Code reads `CLAUDE.md`;
Codex reads `AGENTS.md`.

**Keep one authoritative and have the other point at it.** llmcheats writes the
memory into `AGENTS.md` and reduces `CLAUDE.md` to a single `@AGENTS.md` import
line plus any Claude-only notes. Two hand-maintained copies is drift.

## The managed block

<!-- F-002 -->
llmcheats manages exactly one block inside `AGENTS.md`:

```
<!-- llmcheats:begin -->
   ...regenerated on every install. Not yours to edit.
<!-- llmcheats:end -->
```

**Write project memory outside those markers.** Everything outside is preserved
across installs and re-runs. The markers themselves are not yours to move — a
damaged pair makes the installer refuse to touch the file at all.

## The six sections

<!-- F-004 -->
**Project · Architecture decisions · DevOps decisions · Review rules ·
Development patterns · Keeping this file current**

A section with nothing true to say is **deleted, not filled**.

<!-- F-005 -->
- **How to run it** — build, test, lint, migrate: **the commands, not prose about
  them.** Every command must be one that already exists in this repo. A step
  described without a command is a bug.
- **The architecture this project actually follows**, and every place it departs
  from the reference *with the reason*. This is what stops the next session
  importing defaults over a codebase that decided otherwise.
- **Decisions that cost a discussion** — one line each, naming the ADR or plan
  file that holds the argument. The line is the index; the file is the record.
- **Conventions a diff would otherwise break** — error mapping, naming, migration
  ordering, where tests live, module boundaries.
- **What not to touch** — generated files, vendored code, paths that look
  editable and are not.
- **Review rules** — what a reviewer of this repo blocks on.
- **Keeping this file current** — the maintenance rule, written into the artifact
  so it outlives whatever wrote it.

## What stays out

<!-- F-006 -->
- **Secrets, tokens, hostnames, customer names.** The file is committed and fed
  to a model every session.
- **Anything the code or `git log` already answers.**
- **Status.** "Currently working on X" is stale within a day; that belongs in a
  plan file.
- **A copy of the reference.** Name the file and let the agent read it when the
  task needs it. This is why `.llmcheats/docs/` ships as files and not as
  pasted rules.
- **Procedures that matter in one subtree only** — those go beside that code,
  not into the file every session pays for.

## When to add a line

<!-- F-007 -->
The trigger is a **repeat**: the same correction typed twice, the same mistake
made twice, something review caught that the next session should have known.

**One occurrence is noise; twice is a convention nobody wrote down.**

<!-- F-008 -->
A decision is written **in the run that took it**. Deferred to a cleanup pass, it
gets re-litigated next session instead — the most expensive kind of re-planning.

## It is context, not configuration

<!-- F-009 -->
It is delivered as a message with no guarantee of compliance. Anything that
*must* happen belongs in a hook or in CI, not in a memory line.

Codex builds its instruction chain once at startup, so **a convention written
during a session governs the next session, not the one that wrote it.** After
generating or editing these files, restart the agent before expecting them to
apply.

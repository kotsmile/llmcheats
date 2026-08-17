---
description: Write or refresh this project's llmcheats memory artifacts — a CLAUDE.md AND the Codex AGENTS.md analogue, covering architecture decisions, devops decisions, review rules, deploy and development patterns, and the rule for keeping itself current. Use this rather than a plain CLAUDE.md initialization when the project follows llmcheats, when an existing CLAUDE.md needs refreshing after a delivery flow, or when both tools must read the same conventions. Do NOT use to write feature docs, a design plan, or a README.
argument-hint: [area to focus on, or empty for the whole project]
---

Write this project's **memory artifacts**: the files both tools load unprompted
at the start of every session, so the sessions after this one need no flow and no
ceremony to act correctly.

**Focus:** $ARGUMENTS (empty means the whole project)

Read `devflow/11-project-memory.md` first — it holds what belongs in these files,
what must stay out, and why length is a permanent per-session cost. Docs live in
the first of these that exists: `<project>/.claude/llmcheats/docs/`,
`~/.claude/llmcheats/docs/`, `~/.codex/llmcheats/docs/`. If none exist, say so
and work from this file alone; do not invent that doc's contents.

## 1. Inventory before writing

Prefer what the project already decided over what you would decide. In one
block of reads: the build/test/lint/migration commands (`Makefile`, `package.json`,
`pyproject.toml`, CI config), the directory shape, the migrations directory, one
representative module per layer, **the ADR index plus at most the three most
recent**, and **only the newest file in `docs/plans/`**. Those two caps are what
keep this a single pass — a repo with forty ADRs is not an invitation to read
forty. Read the existing `CLAUDE.md` / `AGENTS.md` if there is one; you are
refreshing it, not replacing its author.

**If the project is too large to inventory in one pass**, delegate the two
sections that are whole-system judgments and write the rest yourself: one `Task`
to `architecture-designer` for the architecture as it actually is, one to
`devops` for the runtime, deploy and rollback reality. Ask each for a summary of
at most a page, never a transcript, and say in your report that you delegated.
Otherwise this is one context — do not fan out for a repo you can read.

## 2. What the artifact must contain

Six sections, each a short list rather than prose. Omit any the project does not
have yet and say which you omitted:

1. **Project** — what it is, the stack, the directory shape, and how to run,
   test, lint and migrate it: the commands themselves.
2. **Architecture decisions** — the shape the code actually follows, and every
   place it departs from `webapp/` with the reason. One line each, naming the ADR
   or plan file that holds the argument.
3. **DevOps decisions** — how it builds, deploys and rolls back; where config and
   secrets come from; what the migration ordering rule is; what must emit a
   metric or alert.
4. **Review rules** — what a reviewer of this repo blocks on. Start from the
   constraints (bound SQL parameters, validated boundaries, no weakened authz,
   no test deleted for a green build) and add what this project has learned.
5. **Development patterns** — the conventions a diff would otherwise break:
   error mapping, naming, where tests live, module boundaries, what not to touch.
6. **Keeping this file current** — the self-maintenance rule, written into the
   artifact itself so it survives without this command: add a line when something
   repeats, never record status or secrets, and record a decision in the run that
   took it. `devflow/11-project-memory.md` §15.1–15.2 is the full form; the
   artifact carries the short one.

Facts only, with the reason attached where there is one. No secrets, no
hostnames, no customer names, no "currently working on" status, and nothing that
merely restates the code.

**Hold the ceiling in `devflow/11-project-memory.md` §15** — the whole artifact
under about 120 lines, no section past 20, anything longer named as a file path
rather than inlined. This is the one file loaded in full on every future session,
so its length is a cost paid forever, and a generator fills whatever cap it is
given.

## 3. Where to write it

Both tools must reach the same content without you maintaining two copies:

- **`AGENTS.md` at the repo root holds the memory** — Codex reads it natively.
- **`CLAUDE.md` at the repo root is one line, `@AGENTS.md`** — Claude Code reads
  `CLAUDE.md` and not `AGENTS.md`, and imports or a symlink are how one file
  serves both.
- **If the project already has a substantial `CLAUDE.md`, keep it authoritative
  instead** and make `AGENTS.md` the pointer. Do not migrate someone's existing
  file to satisfy a default.

**Never write inside `<!-- llmcheats:begin -->` / `<!-- llmcheats:end -->`.**
That block is the installer's docs pointer, regenerated on every update, so
anything placed inside it is lost. Write outside it and leave the markers alone —
the installer strips its block and re-appends it at the end of the file on every
run, so do not position your content relative to the markers. A project installed
globally has no such block, so usually there is nothing to avoid. **Never write a
marker string into your own prose**: a lone or misordered `llmcheats:begin` makes
the installer refuse to touch the file at all from then on.

## 4. Show it before you overwrite

**Show what you are about to write, then get a yes** — every time, whether the
file exists or not. Creating one is not the safe case: `CLAUDE.md` and `AGENTS.md`
are root-level files the operator inherits forever and every later session obeys,
so a session that decided on its own initiative to write them does not also get
to decide their contents unseen. For a refresh, show the sections added, the lines
rewritten, and anything you would drop. These
files are read by every future session, and a silent rewrite of an operator's
conventions is the one failure this command must not have. Never delete a line
you cannot explain; if you disagree with it, say so and leave it.

## 5. Report

The paths written, the six sections you filled and the ones you omitted with the
reason, whether you delegated any inventory, and **what you could not determine**
— a deploy path with no script, a convention the code contradicts itself about,
an architecture decision with no recorded reason. An unknown named here is a
question for the operator; an unknown guessed at becomes a rule every future
session follows.

This is one context (two or three if you delegated), and it is what makes step 4
of the flow work: `/llmcheats:pm` delivers, this writes down what it decided,
then plain prompts land correctly and `/llmcheats:review` checks the result.

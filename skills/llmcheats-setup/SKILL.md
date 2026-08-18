---
name: llmcheats-setup
description: "Set up llmcheats in this repository: read the repo, then write AGENTS.md, CLAUDE.md and .llmcheats/stack.md specialized to it. Run after install.sh, or again after the repo's toolchain changes."
---

# llmcheats-setup

You are specializing a generic knowledge base to **this** repository.

<!-- F-005 -->
**The failure mode this skill exists to prevent is inventing a command.** A
generic "run the tests" instruction is worth nearly nothing. The same
instruction carrying this repo's real test command is worth a lot. A plausible
command that does not exist here is worse than no command at all, because the
next session will trust it.

Every command you write must be one you **observed in a file in this repo**. If
you did not see it, it does not go in.

**The same rule binds your citations, and it is easier to break.** Writing
`Makefile:12` when the command is on line 9 produces a pointer that looks
authoritative and sends the next session to the wrong place. Line numbers also
drift on the next edit. So:

> **Cite a file path and a quoted fragment. Never a bare line number** unless you
> re-read that exact line in this session to confirm it.

`Makefile — "test: go test ./..."` is verifiable forever. `Makefile:12` is
verifiable for one commit, and is a guess the rest of the time.

---

## Phase 1 — Read the repository

<!-- F-032 -->
Budget: about 25 tool calls. Then write. If you still cannot describe the repo,
write what you have and name the gaps.

<!-- F-031 -->
In bounds: this repo's own source, tests, config, CI, task runner, migrations,
docs. **Out of bounds:** `node_modules/`, `vendor/`, `site-packages/`, live
databases, and running the full test suite to learn what the code does.

Look for these, in this order. The left column is what you need; the right is
where it actually lives.

| What                             | Where to look                                                                                  | Why it matters                                                                                                                                                                |
| -------------------------------- | ---------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Task runner**                  | `Makefile`, `justfile`, `Taskfile.yml`, `package.json` scripts, `pyproject.toml`, `Cargo.toml` | <!-- F-085 -->The real commands live here, **not in the CI file**. The same check must run locally and in CI.                                                                 |
| **Build / test / lint / format** | the task runner, then the CI workflow to confirm                                               | These four lines are the highest-value thing you will write.                                                                                                                  |
| **Language + version**           | `go.mod`, `package.json` engines, `.python-version`, `pyproject.toml`, `rust-toolchain`        | Decides which `docs/` groups are in scope.                                                                                                                                    |
| **Framework + major version**    | lockfile or manifest                                                                           | <!-- F-096 -->Version, not just name. React 19-with-compiler and React 18 take opposite advice on memoization.                                                                |
| **Test layout**                  | `*_test.go`, `tests/`, `__tests__/`, `spec/`                                                   | Where a new test goes, and what the naming convention is.                                                                                                                     |
| **Migrations**                   | `migrations/`, `alembic/`, `db/migrate/`, `prisma/`                                            | Tool, naming, whether `down` exists, how they are applied.                                                                                                                    |
| **CI gates**                     | `.github/workflows/`, `.gitlab-ci.yml`, `.circleci/`                                           | Which checks block a merge, in what order.                                                                                                                                    |
| **Deploy + rollback**            | `deploy.sh`, `Dockerfile`, `charts/`, `k8s/`, `docker-compose.yml`, `fly.toml`                 | <!-- F-047 -->Whether a rollback is a revert, and whether it is one command.                                                                                                  |
| **Commit history**               | `git log --oneline -100`                                                                       | <!-- F-059 -->The commit format **actually used**, the scope vocabulary, whether a tracker key appears.                                                                       |
| **Generated + vendored paths**   | `.gitignore`, codegen config, `// Code generated` headers                                      | <!-- F-063 -->The "what not to touch" list.                                                                                                                                   |
| **Existing agent config**        | `AGENTS.md`, `CLAUDE.md`, `.cursorrules`, `.github/copilot-instructions.md`                    | Do not overwrite. Merge, and report what you found.                                                                                                                           |
| **Contribution conventions**     | `CONTRIBUTING.md`, PR template, `CODEOWNERS`, `docs/adr/`, any per-change checklist            | The rules a maintainer applies by hand. These are the highest-value lines in `AGENTS.md` and the easiest to walk past — they are prose, not config, so no tool surfaces them. |
| **Lint / format config**         | `.eslintrc`, `.golangci.yml`, `ruff.toml`, `.editorconfig`                                     | What is enforced mechanically rather than socially.                                                                                                                           |

Prefer one `Grep` across a directory over a dozen `Read`s when the question is
*where is this*. Read a file once, whole.

## Phase 2 — Read the knowledge base

Read `.llmcheats/cheats/index.md`, then `.llmcheats/cheats/routing.md`.

Read the practices files. Read `.llmcheats/docs/INDEX.md` to know what the
corpus holds — but **do not read the corpus itself** unless a stack guard in
`routing.md` matches what you found in Phase 1. Reading all 79 files is exactly
the overrun `practices/agent-discipline.md` bounds.

## Phase 3 — Write the artifacts

Write three files. Nothing else. No README, no summary document.

Every table you write is column-aligned, per
`.llmcheats/cheats/practices/agent-discipline.md`. The template's columns are
sized around its `{{PLACEHOLDERS}}`; re-align each one around the real values
you substituted in, or the file ships crooked and every later edit re-flows rows
that did not change.

### `.llmcheats/stack.md`

What you observed, as facts with sources. This is the file that makes every
later session cheap, and the file a re-run diffs against.

```markdown
# Stack

| Fact          | Value                               | Observed in                                 |
| ------------- | ----------------------------------- | ------------------------------------------- |
| language      | Go 1.24                             | `go.mod` — "go 1.24"                        |
| build         | `make build`                        | `Makefile` — "build:" target                |
| test          | `make test`                         | `Makefile` — "test:" target; run, 41 passed |
| lint          | `golangci-lint run`                 | `.golangci.yml` exists; `ci.yml` lint job   |
| migrations    | goose, `migrations/`, no down files | `migrations/` listing                       |
| deploy        | `./deploy.sh prod`                  | `deploy.sh`                                 |
| rollback      | **not observed**                    | —                                           |
| commit format | lowercase, no ticket key            | `git log`, 84/100 commits                   |

## Stack guards matched
- docs/backend/*  — Go, layered structure under internal/
- docs/tools/*    — always

## Guards not matched
- docs/frontend/* — no frontend in this repo
- docs/devops/ci-* — GitHub Actions, not GitLab

## Not observed
- No rollback command found. AGENTS.md says so rather than guessing.
```

<!-- F-014 -->
**Anything you could not observe is listed under "Not observed", not filled in
with a plausible value.**

### `AGENTS.md`

<!-- F-001 -->
Hard limits: **under 120 lines, no section past 20 lines, under 6 KB.** Codex
stops merging instruction files once the chain hits its byte cap, so an
oversized file silently costs you the rest of the chain.

<!-- F-002 -->
Structure — and the marker semantics are not negotiable:

```markdown
<!-- llmcheats:begin -->
...routing table + pointers into .llmcheats/. Regenerated every run.
Nothing here is hand-editable.
<!-- llmcheats:end -->

# Project
...the six sections. Yours. Never overwritten after the first run.
```

Inside the block: the prefix→workflow routing table from `routing.md`, and the
pointer to `.llmcheats/`. This is **routing layer 2** — it must be in `AGENTS.md`
because that file is always in context, and a router that has to open a file to
route has already lost the saving.

Outside the block: the six sections from
`.llmcheats/cheats/practices/project-memory.md` — Project, Architecture
decisions, DevOps decisions, Review rules, Development patterns, Keeping this
file current.

<!-- F-019 -->
**Delete inapplicable sections rather than leaving no-ops** — and say in your
report which you deleted and why. A section reading "N/A" is noise every session
pays for; a silently missing one looks like an oversight.

Use `templates/AGENTS.md.tpl` as the skeleton. Substitute real commands.

### `CLAUDE.md`

<!-- F-003 -->
```markdown
@AGENTS.md
```

Plus Claude-only notes if there genuinely are any. One authoritative file, one
pointer — never two copies.

## Phase 4 — Verify, then report

Do all of them. This phase is not optional.

1. **Re-read what you wrote.** Not from memory — open the files.
2. <!-- F-005 -->**Check every command against Phase 1.** For each command in
   `AGENTS.md`, name the file you saw it in. A command you cannot source is
   deleted, and its absence is reported.
3. **Check every citation resolves.** Open each file you cited and confirm the
   fragment you quoted is in it. Any citation carrying a line number gets that
   line re-read — if it does not say what you claimed, drop the number and keep
   the quote. A wrong pointer is worse than no pointer: it is confidently
   checkable and wrong, and the next session will not re-verify it.
4. **Re-align every table you wrote.** Substituting a real command into a
   template column leaves it crooked. Check the files as text, not as rendered
   markdown — the padding is the thing being checked.
5. **Run the test command once.** If it fails, that is a finding about the repo,
   not a reason to change what you wrote — report the failure verbatim.
6. **Confirm the two skill trees are identical twins:**
   `diff -r .claude/skills .agents/skills` — should be empty. If only one exists,
   that is `--agents` doing its job; say which.

Then report, in this shape:

```
Created:      AGENTS.md, CLAUDE.md, .llmcheats/stack.md
Merged:       existing AGENTS.md content preserved outside the markers
Deleted:      DevOps decisions section — no deploy path in this repo
Unknown:      rollback command — not found, said so rather than guessing
Ran:          `make test` — 41 passed
Skill trees:  identical (8 skills each)
```

<!-- F-066 -->
**Do not commit.** Tell the operator to review the diff.

<!-- F-009 -->
Tell them to **restart the agent** before expecting the new files to apply.
Codex builds its instruction chain once at startup, so what you just wrote
governs the *next* session, not this one.

---

## Re-running

<!-- F-023 -->
If `.llmcheats/stack.md` exists, this is a re-run. **Start with an inventory,
not a rewrite.**

1. Read the existing `stack.md`.
2. Re-observe Phase 1.
3. **Diff.** Report what changed: "test command moved from `make test` to
   `task test`".
4. Rewrite **only what changed.** A stack fact that still holds is not rewritten,
   and neither is the section of `AGENTS.md` that depends on it.

<!-- F-002 -->
**Everything outside `<!-- llmcheats:begin -->` / `<!-- llmcheats:end -->` is off
limits on a re-run.** That is where project memory lives — decisions written by
earlier flows, conventions someone learned the hard way. You may *append* a new
section if the repo grew one; you may not rewrite what is there.

If the marker pair is missing or damaged, **stop and report it**. Do not guess
where the block should go and do not recreate it — a mangled block silently
destroys project memory on the next run.

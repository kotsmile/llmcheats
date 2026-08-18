# rederivation.md — Phase D

**Method.** A full copy of this repo, git history intact, with its entire agent
layer deleted (`.claude/`, `.agents/`, `AGENTS.md`, `CLAUDE.md`, `report/`) and
the deletion committed. llmcheats installed from a local tarball; the setup skill
then run against it to produce `AGENTS.md`, `CLAUDE.md`, `.llmcheats/stack.md`.

**Ground truth**, and its limits:

1. The agent layer at `5cc247a` — `.claude/commands/llmcheats.md`,
   `.claude/llmcheats-checklists.md`, `.claude/agents/*.md` (9 checkers),
   `commands/*.md` (6), `skills/webapp-guide/SKILL.md`, `README.md`.
2. `docs/devflow/project-memory.md`'s specification of what a memory file holds.

**This is not an independent test and I am not going to present it as one.** The
ground truth is llmcheats' own previous output, and I wrote both the tool and the
generated artifacts. It catches hallucinated commands and structural gaps, which
is real value. It cannot tell you whether the conventions are *good*.

**Why the target is a fair one anyway:** llmcheats-the-repo is Bash and Markdown
with no build, no lint, no CI, no database and no deploy. Nearly every command
the reference corpus talks about is absent here. If the setup skill were going to
invent `make test`, this is the repo where it would.

---

## Invented — llmcheats generated it, the repo does not have it

**The dangerous bucket. Two entries, one of them a genuine defect.**

### I-1 · Fabricated line-number citations — DEFECT, fixed

The generated artifacts cited `install.sh:180`, `install.sh:82`,
`install.sh:100`, `install.sh:33` and `test/install_test.sh:37`. **Four of the
five were wrong:**

| Cited                     | Claimed             | Actually                 |
| ------------------------- | ------------------- | ------------------------ |
| `install.sh:180`          | stub derivation     | blank line (real: 182)   |
| `install.sh:82`           | `LLMCHEATS_TARBALL` | `codex) want_codex=1 ;;` |
| `install.sh:100`          | download URL        | blank line               |
| `install.sh:33`           | `--ref`             | `--target DIR …`         |
| `test/install_test.sh:37` | tarball export      | blank line               |

This is the tool's stated primary failure mode reappearing one level down. The
*commands* were all real — verified against the repo, and the test command was
executed. The *evidence pointers* were confabulated: plausible, precise, wrong.
A wrong pointer is worse than none, because it is checkable and nobody checks it.

**Fixed in `skills/llmcheats-setup/SKILL.md`:** citations are now a file path
plus a quoted fragment, never a bare line number unless that line was re-read in
the same session. Phase 4 gained an explicit citation-resolution step. The
regenerated artifacts carry zero bare line numbers into the target repo, and all
five quoted fragments were confirmed present.

One exception is deliberate: citations *into* `.llmcheats/docs/` may keep line
numbers, because the corpus is installed verbatim and frozen. `docs/devflow/
git.md:16` was checked and is correct.

### I-2 · The eight-prefix routing vocabulary — invented, but evidenced

`hotfix:` `chore:` `release:` `rollback:` do not exist as prompt prefixes
anywhere in the reference. `feature: bug: refactor: migrate:` came from the build
prompt; the other four I derived — `hotfix:`/`chore:` from the commit vocabulary
(F-060), `release:`/`rollback:` from the tag-and-revert model (F-045, F-047).

Honest classification: **the rules inside those workflows are evidenced; the
routing vocabulary is my construction.** `release:` and `rollback:` are the
weakest — the reference has them as *actions*, never as things a user types.
`deploy:` was rejected for exactly this reason and these two survive on a thinner
version of the same argument.

### Not invented

Scanned for and absent: `make test`, `make build`, `make lint`, `npm test`,
`npm run build`, `go test`, `pytest`, `cargo test`, `yarn`. The generated
`AGENTS.md` states plainly that **no build, lint or format command exists** and
that there is no CI, rather than filling those rows. `stack.md` carries a
"Not observed" section naming four absent facts.

---

## Recovered — the real layer had it, llmcheats regenerated it

| #    | Recovered                                                                    | Where it was                        | Where it landed                                                                 |
| ---- | ---------------------------------------------------------------------------- | ----------------------------------- | ------------------------------------------------------------------------------- |
| R-1  | Route via an index; read one or two files, never the tree                    | `webapp-guide/SKILL.md`             | `cheats/index.md`, `routing.md` stack guards                                    |
| R-2  | "Read before acting — don't work from memory" + the deviation *scoping* rule | `webapp-guide/SKILL.md`             | `cheats/index.md` (F-100)                                                       |
| R-3  | "Say so explicitly rather than invent the documents' contents"               | `webapp-guide/SKILL.md`             | the whole anti-hallucination spine (F-005)                                      |
| R-4  | `AGENTS.md` managed block, user content preserved outside                    | `README.md`, `.gitignore`           | markers + `install.sh` idempotence (F-002)                                      |
| R-5  | Restart the agent after install                                              | `README.md`                         | setup skill Phase 4 (F-009)                                                     |
| R-6  | Nothing of yours is overwritten                                              | `README.md`                         | re-run preserves `AGENTS.md`/`CLAUDE.md`/`stack.md`; `--force` is the only wipe |
| R-7  | Installer auto-discovers payload; no installer edit to add one               | `llmcheats-checklists.md`           | stub derivation from workflow front-matter, asserted by test §10                |
| R-8  | `docs/INDEX.md` updated in the same change                                   | `llmcheats-checklists.md`           | `AGENTS.md` review rules (F-099)                                                |
| R-9  | Never paste the checklists into a subagent prompt                            | `commands/llmcheats.md` invariant 1 | `practices/agent-discipline.md` (F-033)                                         |
| R-10 | Pin `model` only downward, only for routers                                  | `llmcheats-checklists.md`           | `practices/agent-discipline.md` (F-035)                                         |
| R-11 | Commit format taken from history                                             | `git log`                           | recorded, **including the 116-char divergence from the reference's ≤72**        |
| R-12 | Do-not-touch paths                                                           | `.gitignore`                        | `AGENTS.md` "Do not touch"                                                      |

R-11 is the one worth pausing on: the target's own commits run to 116 characters
while the shipped reference says ≤72. The generated `AGENTS.md` records what the
repo does and flags the divergence rather than silently importing the reference's
rule. That is F-038 working — the behaviour that makes it safe to install this
corpus into a repo that decided differently.

---

## Missed — the real layer had it, llmcheats did not generate it

| #   | Missed                                                                             | Gap in                                   | Severity |
| --- | ---------------------------------------------------------------------------------- | ---------------------------------------- | -------- |
| M-1 | The nine repo-local checker agents                                                 | neither — scope decision                 | none     |
| M-2 | The per-change checklists (add a doc / an agent / a command / touch the installer) | **the setup skill's repo-reading phase** | **real** |
| M-3 | The `.gitignore` un-ignore-by-name discipline                                      | the repo-reading phase                   | minor    |
| M-4 | Global install (`~/.claude`, `~/.codex`)                                           | the installer, by design                 | none     |
| M-5 | Backing up a user file the installer would clobber                                 | **`install.sh`**                         | **real** |

**M-2 — the important one.** The prior layer's richest artifact was
`.claude/llmcheats-checklists.md`: a hand-written per-change checklist that is
pure prose in a non-standard location. My generated `AGENTS.md` recovered about
four of its rules through the "Review rules" section and missed the rest. The
gap is in the **repo-reading phase** — its table had no row for
maintainer-written contribution conventions, because those are prose, not config,
so no detection heuristic surfaces them. **Fixed:** a "Contribution conventions"
row now covers `CONTRIBUTING.md`, PR templates, `CODEOWNERS`, ADRs and
per-change checklists.

**M-5 — a real installer defect. FIXED.** `install_skills_into()` ran
`rm -rf "$root"/llmcheats-*` before copying, so a user file inside a directory
matching `llmcheats-*` was deleted with no backup. The prior installer copied
such files to `.bak-llmcheats`. Narrow — it needs a user to have created a
`llmcheats-`-prefixed skill dir themselves — but silent and destructive, the
combination the reference's own floor treats as unacceptable.

Now: any `llmcheats-*` directory that differs from what is about to be written,
or has no counterpart in the payload, is copied to `.bak-llmcheats/<agent>/`
before the refresh, and the count is reported. A directory identical to the
staged version is skipped, so an unmodified re-run produces no backup noise.
Test section 12 covers all four cases — foreign skill preserved, extra file in a
managed directory preserved, content verbatim, and no backup on a clean re-run.

M-1 and M-4 are consequences of decisions you made: agents are out of the
payload, and the installer targets a repo rather than a home directory.

---

## Verification actually run

```
AGENTS.md              104 lines, 4806 bytes, longest section 19   (F-001: <120, <20)
commands sourced       2/2 verified present; test command executed, 51 passed
citations resolved     5/5 quoted fragments confirmed; 0 bare line numbers
skill trees            .claude/skills == .agents/skills, 9 each
invented commands      none
install_test.sh        57/57
```

## What this pass changed in the tool

1. `skills/llmcheats-setup/SKILL.md` — citation policy, a Phase 4 resolution
   step, and a repo-reading row for contribution conventions.
2. `templates/AGENTS.md.tpl` — split the managed block so no section exceeds 20
   lines; the template was violating F-001, which it teaches.
3. `test/install_test.sh` — section 11 now asserts the template's line count,
   byte size, longest section, both markers, and that project memory sits below
   the closing marker. The defect that got through cannot get through again.

## Known open

- **I-2**: `release:` and `rollback:` rest on a thinner argument than the other
  six prefixes — the reference has them as actions, never as things a user types.

M-5 and the F-001 template violation are closed, each with a test that would
catch a regression.

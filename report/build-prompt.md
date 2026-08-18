IMPORTANT: usage of this tool should be cost efficient so if we have big files or many files should build indexes

Build a tool called **llmcheats**. You have one input that matters:
`REFERENCE=./docs` — a monorepo that already does AI-driven development and
GitOps well. That repo is the _source of truth for what good looks like_. Your
job is to distill it into a tool that reproduces its working practices in other
repositories.

Work in this directory. Ask me at most three questions total, and only where a
choice genuinely changes the architecture.

## What llmcheats does

It bootstraps any repo so that afterwards a bare prompt works correctly in both
Claude Code and Codex, with no slash command and no pasted context:

```
feature: add rate limiting to the ingest endpoint
bug(auth): 401 on token refresh after 24h
refactor: split Handler into transport and domain layers
migrate: postgres 14 -> 16
```

Two steps for the end user: `curl … | bash` in their repo, then once inside the
agent, `/llmcheats-setup` (Claude Code) or `$llmcheats-setup` (Codex).

## The rule that governs everything below

**Derive, do not recall.**

You already have opinions about testing, commits, and migrations. Those
opinions are not the input here. Every rule that ends up in llmcheats must
trace to something you actually observed in `$REFERENCE` — a file, a config, a
commit, a review comment, a CI job. If you cannot point at the evidence, the
rule does not ship.

This constraint exists because the reference repo encodes decisions that were
paid for in production incidents. Generic best-practice text does not. When
your priors and the reference disagree, the reference wins, and you note the
disagreement in the report rather than quietly splitting the difference.

---

# Phase A — Mine the reference repo

Produce `docs/findings.md` before writing a single line of the tool. Nothing
else starts until this exists.

## A1. Its agent layer is the richest source — read it first

`$REFERENCE` already does AI-driven development, so it already contains a
worked example of roughly what llmcheats is supposed to generate. Extract:

- `AGENTS.md`, `CLAUDE.md`, and every nested one — note the hierarchy, what
  lives at root vs per-package, and how big each is
- `.claude/`, `.agents/`, `.codex/` — skills, commands, subagents, hooks,
  settings, permission config
- Any prompt library, `docs/prompts/`, ADRs about agent usage
- MCP server config and which tools agents are and aren't allowed
- CI jobs that lint or validate the agent config itself

For each: what does it constrain, and what failure is it obviously preventing?
An unexplained prohibition ("never edit `gen/`") is a scar. Record it.

## A2. Its GitOps layer

- Repo topology: app code vs manifests vs env overlays. Who writes which.
- ArgoCD / Flux app definitions, sync waves, sync policy, prune and self-heal
  settings, health checks
- Promotion path between environments, and what is automated vs gated
- Where image tags are written, and by what
- Rollback mechanism: git revert, Argo rollback, Helm rollback, something else
- Secrets handling and what agents may never touch
- Drift detection and what happens on drift

GitOps changes the shape of the workflows. In a GitOps repo, "deploy" is a
commit, "rollback" is a revert, and an agent editing a manifest is editing
production intent. If the evidence supports it, llmcheats should ship
`deploy:`, `release:`, or `rollback:` prefixes alongside the four above — decide
from `$REFERENCE`, not from taste, and justify the decision in `findings.md`.

## A3. Its conventions, from artifacts not documentation

Documentation says what people intended. These say what they do:

| Signal                               | What to extract                                                         |
| ------------------------------------ | ----------------------------------------------------------------------- |
| `git log --oneline -300`             | commit format, scope vocabulary, granularity                            |
| revert and hotfix commits            | what actually broke; each one is a rule waiting to be written           |
| PR template, `CODEOWNERS`            | what reviewers are told to look at, which paths need whom               |
| CI workflow files                    | the real gate list, in order, and which jobs are required               |
| `Makefile` / `Taskfile` / `justfile` | the canonical commands humans actually run                              |
| pre-commit hooks, lint config        | what is enforced mechanically vs socially                               |
| test layout                          | unit/integration split, fixtures, naming, what's mocked                 |
| migration dir                        | tool, naming, whether `down` migrations exist, expand/contract evidence |
| `renovate.json` / dependabot         | upgrade policy, what's pinned and why                                   |
| ADRs / `docs/decisions/`             | the reasoning behind the non-obvious choices                            |

## A4. Output format for `docs/findings.md`

One entry per observation:

```markdown
### F-023 · Manifests are never edited in the same commit as app code

- **Evidence:** `.github/workflows/ci.yml:88` rejects PRs touching both
  `services/**` and `deploy/**`; 4 reverts in Feb 2026 with message "split PR".
- **Prevents:** a failed rollout blocking an unrelated code rollback.
- **Class:** universal | stack-specific | project-idiosyncratic
- **Portable form:** <the rule stated without reference to this repo's paths>
```

Aim for 40–80 entries. Under 25 means you did not read deeply enough.

---

# Phase B — Classify and generalize

Every finding gets one of three classes. This is the step that prevents
llmcheats from being a tool that only works on repos that look like
`$REFERENCE`.

- **universal** — the rule holds in a Go monorepo and a Django app alike.
  → ships in `cheats/` as-is.
- **stack-specific** — real, but assumes Postgres, or Argo, or a monorepo.
  → ships in `cheats/` guarded by a detection condition the setup skill checks.
- **project-idiosyncratic** — true only for `$REFERENCE`.
  → does not ship. Goes in `docs/rejected.md` with the reason.

**Generalization test**, applied to every candidate rule before it ships:
name two plausible repos where following it would produce a _worse_ outcome.
If you can, it is not universal — demote it or add the guard.

Second filter: **falsifiability**. Cut any line that reads like advice — "write
clean code", "consider performance", "follow best practices". Every shipped
instruction must be a command that runs, a path that exists, or a check that
can fail.

Provenance stays attached: each rule in `cheats/` carries an HTML comment
`<!-- F-023 -->`. The comments ship (they cost nothing and make the tool
auditable); the full mapping lives in `docs/provenance.md`.

---

# Phase C — Build the tool

## Central design bet — do not deviate

**The installer is dumb. The setup skill is smart.** `install.sh` copies a
shipped knowledge base and one skill into the target repo. It must not detect
stacks, must not template, must not write `AGENTS.md`. Generating config is the
agent's job, because only the agent can read the target repo and specialize.

A generic "write tests first" instruction is worth nearly nothing. The same
instruction carrying the target repo's real `make test` is worth a lot.
Inventing a plausible-looking command that does not exist in the target repo is
this tool's primary failure mode. Design against it explicitly.

## Verified platform constraints — researched, treat as given

If you think one is wrong, say so before changing it.

1. **Claude Code does not namespace by directory.** `.claude/commands/foo/bar.md`
   is `/bar`, not `/foo:bar`; the subdir only shows in the description. The
   `namespace:command` form comes from plugins. So the command is
   `llmcheats-setup`.
2. **`.claude/commands/` is legacy** — use `.claude/skills/<name>/SKILL.md`.
   Skills support explicit `/name` invocation and implicit invocation on
   `description` match.
3. **Codex custom prompts (`~/.codex/prompts`) are deprecated** and were never
   repo-shareable. Use skills.
4. **Codex reads repo skills from `.agents/skills/`**, scanning from cwd up to
   the repo root. Claude Code reads `.claude/skills/` and does **not** read
   `.agents/skills/`. Install to both.
5. **`SKILL.md` frontmatter is `name` + `description`**, identical across both
   agents. Stay on that core; avoid agent-specific frontmatter fields.
6. **Codex merges `AGENTS.md` from `~/.codex` down to cwd and stops once the
   combined set hits `project_doc_max_bytes` (32 KiB default).** Hard-cap the
   generated root `AGENTS.md` at 6 KB. Note that `$REFERENCE` is a monorepo —
   study how it splits root vs nested `AGENTS.md` and copy that strategy.
7. **`CLAUDE.md` supports `@path` imports.** Generated `CLAUDE.md` is
   `@AGENTS.md` plus Claude-only notes.

## Routing must be two-layer

| Layer | Mechanism                                                        | Property                         |
| ----- | ---------------------------------------------------------------- | -------------------------------- |
| 1     | skill `description` front-loading the literal token `"feature:"` | fast, implicit, probabilistic    |
| 2     | routing table in `AGENTS.md`                                     | always in context, deterministic |

Layer 1 silently misses. Layer 2 alone burns a turn. Both, always.

## Layout

```
llmcheats/
├── install.sh
├── README.md
├── cheats/
│   ├── index.md
│   ├── routing.md
│   ├── workflows/          one per prefix — set determined in Phase A
│   └── practices/
├── skills/llmcheats-setup/SKILL.md
├── templates/AGENTS.md.tpl
├── test/install_test.sh
└── docs/                   findings.md, provenance.md, rejected.md
```

Into the target repo: `AGENTS.md`, `CLAUDE.md`, `.llmcheats/{cheats,templates,
workflows,practices,stack.md,VERSION}`, and byte-identical stubs under
`.claude/skills/llmcheats-*/` and `.agents/skills/llmcheats-*/`. The stubs are
three lines — "read `.llmcheats/workflows/<x>.md` and follow it exactly." One
copy of each playbook, two discovery paths, zero drift.

## install.sh

`set -euo pipefail`, no sudo, deps `curl` + `tar` only. Flags `--agents`,
`--ref`, `--target`, `--force`, `--help`; env `LLMCHEATS_REPO`,
`LLMCHEATS_REF`, `LLMCHEATS_TARBALL` (the last exists so tests run offline).
Default target `git rev-parse --show-toplevel`. Tarball from
`codeload.github.com`, extracted to `mktemp -d` with `trap` cleanup. Idempotent:
re-running refreshes `cheats/` and `templates/` but never clobbers generated
files; `--force` is the only wipe. Writes `.llmcheats/VERSION`. Ends by
printing next steps and telling the user to review the diff.

## skills/llmcheats-setup/SKILL.md

Four phases: **read the target repo** (structured table of what to look for and
where — derive this table from what mattered in `$REFERENCE`); **read
`.llmcheats/cheats/index.md`** and everything it lists; **write the artifacts**,
specializing by substituting real commands and _deleting_ inapplicable steps
rather than leaving no-ops; **verify and report** — re-read what was written,
confirm every command in it was actually observed, run the test command once,
confirm the two skill trees are identical twins, print created/merged/unknown,
do not commit.

Re-run behaviour: if `stack.md` exists, diff and rewrite only what changed, and
treat anything inside `<!-- llmcheats:keep -->` as off limits.

---

# Phase D — Validate

Standard suite in `test/install_test.sh`: `bash -n` clean; package to a local
tarball and install into a scratch `git init` repo with `LLMCHEATS_TARBALL=file://…`;
assert the expected tree; assert `--agents claude` alone skips `.agents/skills/`;
assert a fake `stack.md` survives a re-run and dies under `--force`; assert
non-zero exit outside a git repo with no `--target`.

Then the test that actually matters:

**Re-derivation.** Take a copy of `$REFERENCE` with its entire agent layer
deleted — no `AGENTS.md`, no `CLAUDE.md`, no `.claude/`, no `.agents/`. Run
llmcheats against it. Diff the generated config against the real one.

Report the diff in three buckets:

- **recovered** — llmcheats reproduced it
- **missed** — the real repo has it, llmcheats did not generate it
- **invented** — llmcheats generated it, the real repo does not have it

Every _missed_ item is either a gap in `cheats/` or a gap in the setup skill's
repo-reading phase; say which. Every _invented_ item is a hallucinated
convention and is the more dangerous category — treat each one as a defect.

Do not tell me it works. Show me those three lists.

---

# Build order

1. `docs/findings.md` — Phase A. Stop and show me this before continuing.
2. Phase B classification.
3. `install.sh` + `test/install_test.sh`, green.
4. `cheats/` content.
5. `skills/llmcheats-setup/SKILL.md`, `templates/`, `README.md`.
6. Phase D re-derivation, with the three lists.

Extensibility contract to verify before you finish: adding a workflow must be
one file in `cheats/workflows/` plus one row in `cheats/routing.md` — no change
to `install.sh`, no change to the setup skill.

Finally: tell me which findings you were tempted to ship but rejected, and
which of your own priors `$REFERENCE` contradicted.

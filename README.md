# llmcheats

Bootstrap a repo so a bare prompt works correctly in Claude Code and Codex — no
slash command, no pasted context.

```
feature: add rate limiting to the ingest endpoint
bug(auth): 401 on token refresh after 24h
refactor: split Handler into transport and domain layers
migrate: postgres 14 -> 16
```

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/kotsmile/llmcheats/main/install.sh | bash
```

Then, inside the agent, once:

```
/llmcheats-setup      # Claude Code
$llmcheats-setup      # Codex
```

That is the whole thing. The installer copies files; the setup skill reads your
repo and writes config specialized to it.

## The design bet

**The installer is dumb. The setup skill is smart.**

`install.sh` detects no stacks, templates nothing, and never writes `AGENTS.md`.
It copies a knowledge base and one skill. That is deliberate: only an agent that
can read your repo can write config that names *your* test command.

A generic "write tests first" instruction is worth nearly nothing. The same
instruction carrying your real `make test` is worth a lot. **Inventing a
plausible command that does not exist in your repo is this tool's primary
failure mode**, and the setup skill's verify phase exists to catch it — every
command it writes, it can name the file it saw it in.

## What lands in your repo

```
AGENTS.md                     routing table + project memory
CLAUDE.md                     @AGENTS.md
.llmcheats/
├── docs/                     79-file reference corpus, verbatim
│   └── INDEX.md              its routing table
├── cheats/
│   ├── index.md              how to read the rest
│   ├── routing.md            prefix -> workflow -> flow
│   ├── workflows/            one playbook per prefix
│   └── practices/            the portable constraints
├── templates/
├── stack.md                  what your repo actually is (skill-written)
└── VERSION
.claude/skills/llmcheats-*/   three-line stubs + the setup skill
.agents/skills/llmcheats-*/   byte-identical twins
```

One copy of each playbook, two discovery paths, zero drift. Claude Code reads
`.claude/skills/`; Codex reads `.agents/skills/` and does not read Claude's.

## Two rules worth knowing before you run it

**1. Everything outside the markers is yours.** llmcheats manages exactly one
block in `AGENTS.md`:

```
<!-- llmcheats:begin -->   ...regenerated every install
<!-- llmcheats:end -->
```

Project memory goes *below* the closing marker and is preserved across installs
and re-runs. Only `--force` discards anything. A damaged marker pair makes the
installer refuse to touch the file.

**2. A pattern is not a constraint.** `.llmcheats/docs/` describes one production
system — Go, React, GitLab CI, an Argo-style reconciler. Your repo is probably
not that repo, and it is not supposed to become it. The architectural material
is advisory and **yields to whatever your codebase already does**. What does not
yield is the floor: secrets never committed, SQL parameterized, input validated,
no authz check weakened, no test deleted to green a build, errors never
swallowed.

That distinction is the load-bearing idea of the whole tool. Without it,
installing this into a Django app would be vandalism.

## Options

```
install.sh [--agents claude|codex|both] [--ref REF] [--target DIR] [--force]
```

| | |
|---|---|
| `--agents` | which trees to write. Default `both` |
| `--ref` | git ref to install from. Default `main` |
| `--target` | repo to install into. Default `git rev-parse --show-toplevel` |
| `--force` | delete `.llmcheats/` first. The only path that discards `stack.md` |

`LLMCHEATS_REPO`, `LLMCHEATS_REF`, `LLMCHEATS_TARBALL` override the source.
Re-running refreshes the knowledge base and leaves `AGENTS.md`, `CLAUDE.md` and
`stack.md` alone.

If you keep your own skill under a `llmcheats-*` name, the installer copies it to
`.bak-llmcheats/` before refreshing rather than deleting it, and says how many it
saved. A directory identical to the shipped one is left alone, so a normal
re-run is silent.

## Adding a workflow

One file in `cheats/workflows/` plus one row in `cheats/routing.md`. Nothing
else — the installer generates the skill stub from the workflow's own
front-matter, so neither `install.sh` nor the setup skill changes. `test/` asserts
this.

## Where the rules come from

Every rule traces to something observed in the reference corpus, and carries its
finding id as an HTML comment (`<!-- F-023 -->`). The audit trail:

| File | What it holds |
|---|---|
| `report/findings.md` | 100 findings, each with `file:line` evidence |
| `report/rejected.md` | what was mined and deliberately not shipped, with reasons |
| `report/provenance.md` | rule → finding map, and why 8 findings ship as routing only |
| `report/rederivation.md` | recovered / missed / invented, run against a stripped repo |
| `report/build-prompt.md` | the spec this was built from |

Rules with no evidence did not ship. Where the reference contradicted general
best-practice advice, the reference won and the disagreement is recorded rather
than split.

## Testing

```bash
bash test/install_test.sh
```

Offline: packages the working tree to a tarball and installs it into scratch
repos.

## License

MIT

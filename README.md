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

That installs into the current git repo. **Git is not required** — pass a root
and it goes there:

```bash
curl -fsSL .../install.sh | bash -s -- --target ~/Projects/a
```

Then, inside the agent, once:

```
/llmcheats-setup      # Claude Code
$llmcheats-setup      # Codex
```

That is the whole thing. The installer copies files; the setup skill reads your
repo and writes config specialized to it.

## Chaining

Each prefix is one unit of work. A real change is usually two or three in
sequence, and **you type the next one** — nothing auto-chains. Order matters
only in that `review:` needs a diff to exist and `chore:` picks up what the
earlier steps left behind.

**`feature:` → `review:` → `chore:`** — the default for anything user-visible.

```
feature: add rate limiting to the ingest endpoint
review: the rate-limit branch before it merges
chore: bump the redis client the limiter pulled in
```

**`bug:` → `review:`** — a fix earns a second read even though it is small,
because a reproduction test is easy to write against the bug you imagined.

```
bug(auth): 401 on token refresh after 24h
review: the token-refresh fix, focus on the expiry math
```

**`review:` → `chore:`** — someone else's diff, then the housekeeping it turned
up. The review returns a verdict and changes nothing itself.

```
review: PR 412, the new webhook dispatcher
chore: drop the two dead helpers the review found
```

**`prompt:` → `feature:` → `review:` → `chore:`** — model-facing text first,
because the code that calls it is shaped by what the prompt returns.

```
prompt: extraction instruction for the refund questionnaire
feature: wire the refund extractor into the ticket pipeline
review: the refund pipeline end to end
chore: move the eval fixtures out of testdata into their own package
```

**`hotfix:` → `bug:`** — stop the bleeding, then fix it properly. The hotfix
buys time and is allowed to be ugly; the `bug:` pass adds the reproduction test
and removes the patch.

```
hotfix: disable the recommendation call, it is timing out checkout
bug: recommendation client has no deadline and blocks the checkout path
```

**`refactor:` → `review:`** — shape changed, behavior did not, so the review is
the only thing that can confirm the second half of that claim.

```
refactor: split Handler into transport and domain layers
review: the Handler split, confirm behavior is identical
```

**`migrate:` → `release:`** — a schema move is always full-flow, and shipping it
is a separate event with its own rollback story.

```
migrate: postgres 14 -> 16
release: cut v3.0.0, the pg16 cutover
```

**`release:` → `rollback:`** — the one chain worth knowing before you need it.

```
release: cut v2.4.0 and ship it
rollback: revert the v2.4.0 deploy, error rate tripled
```

Re-routing mid-task is normal, not a failure: a `refactor:` that turns out to
change behavior stops and becomes a `feature:`, and says so in one line.

## Usage

Type a prefix and the task. No slash command — the prefix routes to a playbook
and a flow, and the flow decides how much process the change owes.

| Prefix      | Flow        | Example                                                    |
| ----------- | ----------- | ---------------------------------------------------------- |
| `feature:`  | full        | `feature: add rate limiting to the ingest endpoint`        |
| `bug:`      | fast        | `bug(auth): 401 on token refresh after 24h`                |
| `hotfix:`   | fast        | `hotfix: checkout returns 500 on every card payment`       |
| `refactor:` | asap → full | `refactor: split Handler into transport and domain layers` |
| `migrate:`  | full        | `migrate: postgres 14 -> 16`                               |
| `chore:`    | asap        | `chore: bump golangci-lint and fix the new warnings`       |
| `prompt:`   | fast → full | `prompt: the intent classifier tags refunds as complaints` |
| `review:`   | —           | `review: the rate-limit branch before it merges`           |
| `release:`  | —           | `release: cut v2.4.0 and ship it`                          |
| `rollback:` | —           | `rollback: revert the v2.4.0 deploy, error rate tripled`   |

An optional `(scope)` narrows it: `bug(auth):`, `chore(ci):`. **No prefix is
also valid** — the agent classifies from the text, says which prefix it chose in
one sentence, and proceeds.

`asap` is one pass in minutes, `fast` is seven stages, `full` is thirteen with
skip gates. The last three prefixes are not flows: they run against something
that already exists.

## The design bet

**The installer is dumb. The setup skill is smart.**

`install.sh` detects no stacks, templates nothing, and never writes `AGENTS.md`.
It copies a knowledge base and one skill. That is deliberate: only an agent that
can read your repo can write config that names _your_ test command.

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
├── docs/                     76-file reference corpus, verbatim
│   └── INDEX.md              its routing table
├── cheats/
│   ├── index.md              how to read the rest
│   ├── routing.md            prefix -> workflow -> flow
│   ├── workflows/            one playbook per prefix
│   └── practices/            the portable constraints
├── templates/
├── stack.md                  what your repo actually is (skill-written)
└── VERSION
.claude/skills/llmcheats-*/   path-anchored stubs + the setup skill
.agents/skills/llmcheats-*/   byte-identical twins
```

One copy of each playbook, two discovery paths, zero drift. Claude Code reads
`.claude/skills/`; Codex reads `.agents/skills/` and does not read Claude's.

## Working from a subdirectory

Neither agent looks for skills in a _parent_ directory. So if the knowledge base
lives at `~/Projects/a` and you launch the agent in `~/Projects/a/b/c/d`, it
finds nothing. `--here` fixes that — run it from the directory you work in:

```bash
curl -fsSL .../install.sh | bash -s -- --target ~/Projects/a --here
```

```
~/Projects/a/                    the root: one corpus, shared
├── .llmcheats/{docs,cheats}/
└── b/c/d/                       the working directory: skills only
    ├── .claude/skills/          stubs reading ../../../.llmcheats/
    ├── .agents/skills/
    ├── AGENTS.md                written here by the setup skill
    └── .llmcheats/stack.md      ...and this
```

The corpus is not duplicated — the stubs carry a relative path back up to it, so
moving the whole tree keeps working. `AGENTS.md` and `stack.md` are written in
the working directory, because they describe _that_ project and one root can
hold several.

Attach a second working directory by running `--here` from it. After the first
time the attachment is remembered: a plain re-run from `d` finds the root by
walking up and refreshes both ends, so the stubs cannot go stale.

## Two rules worth knowing before you run it

**1. Everything outside the markers is yours.** llmcheats manages exactly one
block in `AGENTS.md`:

```
<!-- llmcheats:begin -->   ...regenerated every install
<!-- llmcheats:end -->
```

Project memory goes _below_ the closing marker and is preserved across installs
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
install.sh [--agents claude|codex|both] [--ref REF] [--target DIR] [--here] [--force]
```

|            |                                                                    |
| ---------- | ------------------------------------------------------------------ |
| `--agents` | which trees to write. Default `both`                               |
| `--ref`    | git ref to install from. Default `main`                            |
| `--target` | root to install into. Needs no git. Default below                  |
| `--here`   | also install the skills into the current directory                 |
| `--force`  | delete `.llmcheats/` first. The only path that discards `stack.md` |

With no `--target`, the root is the nearest `.llmcheats/VERSION` at or above the
current directory, else the git top level, else it is an error naming both ways
out. The upward search stops at a repository boundary: a repo checked out below
an installed root is its own project, not part of it.

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

| File                     | What it holds                                               |
| ------------------------ | ----------------------------------------------------------- |
| `report/findings.md`     | 100 findings, each with `file:line` evidence                |
| `report/rejected.md`     | what was mined and deliberately not shipped, with reasons   |
| `report/provenance.md`   | rule → finding map, and why 8 findings ship as routing only |
| `report/rederivation.md` | recovered / missed / invented, run against a stripped repo  |
| `report/build-prompt.md` | the spec this was built from                                |

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

# llmcheats — entry point

Read this file, then `routing.md`. Everything else is read on demand.

## What is installed here

| Path                                                          | What it is                            | When to read it              |
| ------------------------------------------------------------- | ------------------------------------- | ---------------------------- |
| `routing.md`                                                  | prefix → workflow → flow              | always, it is in `AGENTS.md` |
| `workflows/`                                                  | one playbook per prefix               | the one your prefix names    |
| `practices/`                                                  | the portable constraints              | the ones your workflow names |
| `docs/INDEX.md`                                               | the reference's own routing table     | when a workflow names a file |
| `docs/webapp/` `docs/devflow/`                                | how to build, and in what order       | when a workflow names a file |
| `docs/backend/` `docs/frontend/` `docs/devops/` `docs/tools/` | patterns from one production monorepo | only on a stack match        |
| `stack.md`                                                    | what this repo actually is            | first, every session         |

`docs/` is a reference corpus installed verbatim, with `docs/INDEX.md` as its
entry point. The last four groups describe **one** production system — Go
services, React and React Native apps, GitLab CI, an Argo-style reconciler. Your
repo is probably not that repo. Read the next section before you take anything
from it as an instruction.

## A pattern is not a constraint

<!-- F-038 -->
This is the rule that governs how to read everything else.

A **constraint** holds in every project. Deviating from one is a vulnerability
and needs a written reason. The list is in `practices/floor.md`.

A **pattern** is how the reference system does it. The four backend layers,
ports on the service, FSD slices on the frontend, raw SQL over an ORM — these
are patterns. **A repo that already builds differently keeps its own
architecture.** Consistency with the surrounding code beats anything in
`docs/`.

What a repo's architecture never buys is relief from a constraint. A different
layering, an ORM, a framework convention — each still owes a parameterized
query and a validated boundary.

The clearest worked example is in `docs/webapp/security-input-sql.md:36`:
writing SQL by hand is a *pattern* and deviating from it is an architecture
choice; binding every dynamic value is a *constraint* and deviating from it is a
vulnerability. Same file, two different authorities.

## Read the file, do not work from memory of it

<!-- F-100 -->
When a workflow names a file, open it. A summary you remember from a previous
session is not the file.

The counterweight matters as much: an ordinary implementation choice — naming,
file layout, which of two equivalent idioms — is **not** a deviation and needs
no paragraph defending it. Write the justification for a constraint, a security
rule, or a triggered gate. Not for a variable name.

## Cost

<!-- F-029 --><!-- F-030 --><!-- F-033 -->
A pass is generation-bound: wall clock ≈ output tokens ÷ 55. Output size is the
lever, not tool calls.

| artifact           | cap   |
| ------------------ | ----- |
| plan / design      | 12 KB |
| audit, code review | 8 KB  |
| hand-back message  | 2 KB  |

Over the cap, split the scope rather than trimming the content. Never paste a
doc's contents into a delegation — name the path and let the reader open it.

## Two agents, one knowledge base

<!-- F-043 -->
Claude Code and Codex do not read the same files. `.claude/skills/` and
`.agents/skills/` hold byte-identical twins for that reason — one copy of each
playbook, two discovery paths.

**Any instruction that depends on a Claude-only mechanism is marked as
Claude-only and names its fallback.** Codex has no subagents and no sidecar
state on disk, so where Claude would delegate a review to a separate agent,
Codex holds the same lens through a deliberate self-review of the diff against
the same list. The gate still happens; only the mechanism differs.

An unmarked instruction that silently requires subagents is a gate that does not
happen under one of the two tools.

## Maintaining this

<!-- F-099 -->
Adding a workflow is **one file in `workflows/` plus one row in `routing.md`**.
Nothing else changes: the installer generates the skill stub from the
workflow's own front-matter. A workflow with no routing row is a workflow no
agent will find.

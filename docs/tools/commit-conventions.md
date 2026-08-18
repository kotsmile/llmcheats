---
title: Commit, branch and review conventions
summary: The single-line commit format tied to a tracker key, the no-ticket escape hatches, and the comment, function and test rules applied in review.
theme: tools
keywords: [commit message, single line, tracker key, ticket, branch name, pull request, chore, hotfix, machine commit, audit trailer, co-authored-by, comments, DRY, tests, prohibited actions]
related:
  - devops/release-tagging-and-gitops.md
  - backend/layered-architecture.md
  - frontend/typescript-react-conventions.md
---

## Format

```
<KEY>-<number>: <project-name> brief description
```

## Rules

- Always include the tracker key — it auto-links the commit to the issue.
- **Single line**, ~70 characters excluding the key prefix.
- No multi-line body, no bullet list of what changed.
- **No co-author trailers, no tool attribution.**

## Which tracker project

Two projects, split by what the change is rather than by who wrote it:

| Scope | Belongs to |
| --- | --- |
| Product work — apps, API, sites | the product project |
| Infrastructure requests — cluster, CI, network, access, tooling | the infrastructure project |

A third key appears in history and is **retired**: read it, never write it.

## When there is no ticket

1. The requester provided one → use it.
2. No ticket → look one up in the tracker and ask for confirmation.
3. No match → ask. Do not commit without a ticket unless explicitly told to skip.

## No-ticket prefixes

| Prefix | When |
| --- | --- |
| `hotfix:` | Urgent production fix |
| `chore:` | Housekeeping |
| `auto:` | Written by a machine |

Machine commits cover automated deployment bumps and approved access changes. An approval commit carries an **audit trailer block** naming the request, the requester and the approver, readable through the log's trailer format — that trailer is the audit record, so it must not be stripped by a rebase.

## Domain-prefixed commits

A subsystem that changes often benefits from a second prefix after the project name, so its history can be filtered. Where that convention applies:

- Do not mix that subsystem's changes with other domains in one commit, wiring at the composition root excepted.
- After a failed evaluation, make a **separate fix commit** — do not amend, or the failure disappears from history.

## Branches and pull requests

**Before creating a PR, always ask: ticket or chore?** Never guess — the answer sets the branch name, the title prefix and whether there is a description.

| Answer | Branch | Title | Description |
| --- | --- | --- | --- |
| A ticket key | `<KEY>-<n>-short-name` | `<KEY>-<n>: <title>` | none |
| chore | `chore-short-name` | `chore: <title>` | two paragraphs: problem (1–2 rows), solution (1–2 rows) |

## Comments

- **1–2 rows maximum**, and none at all where the code speaks for itself.
- Explain only what the code cannot say itself — a ticket reference, a non-obvious *why*.
- **No comment on a function whose name already tells what it does.**

Backend code tightens this further; see the layered-architecture doc.

## Functions

**Extract a function only when DRY applies** — when it has more than one caller. A single-use helper, however well named, is noise: keep the code inline.

## Tests

Write a test when it gives meaningful protection against regression. Prioritize:

- new or changed business behaviour;
- bugs — add a test that reproduces the bug;
- important edge cases and failure paths;
- public interfaces and critical integration boundaries;
- complex logic where a small change could easily introduce a regression.

Do not add a test just because code changed: skip trivial refactors, simple wiring, and behaviour already covered by higher-level tests. A few high-value tests that verify what users or other components actually depend on beat broad coverage of implementation detail.

Test structure is arrange/act/assert with those comments, table-driven where it makes sense.

## Prohibited actions

- **Do not write documentation** unless explicitly asked.
- **Never run start commands** for dev servers — they are already running.
- **Never suppress a lint rule or a type error.** No disable comments, no ignore directives, no file-level opt-outs. Fix the root cause.
- **Observability changes are GitOps-only.** A UI edit to a dashboard is reverted by the reconciler, so it is a change that appears to work and then vanishes.
- Never edit a dependency or lock file by hand.

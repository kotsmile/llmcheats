# Routing

<!-- F-010 --><!-- F-021 -->
Answer from this table. Do not open a file to decide which file to open.

## Prefix → workflow

| Prefix      | Workflow                | Flow        | Use when                               |
| ----------- | ----------------------- | ----------- | -------------------------------------- |
| `feature:`  | `workflows/feature.md`  | full        | new user-visible behavior              |
| `bug:`      | `workflows/bug.md`      | fast        | agreed-broken behavior, not urgent     |
| `hotfix:`   | `workflows/hotfix.md`   | fast        | production is broken now               |
| `refactor:` | `workflows/refactor.md` | asap → full | shape changes, behavior does not       |
| `migrate:`  | `workflows/migrate.md`  | full        | schema, data, or a version move        |
| `chore:`    | `workflows/chore.md`    | asap        | deps, tooling, formatting, config      |
| `release:`  | `workflows/release.md`  | —           | cut and ship a version                 |
| `rollback:` | `workflows/rollback.md` | —           | undo a shipped change                  |
| `review:`   | `workflows/review.md`   | —           | read a finished diff, return a verdict |
| `prompt:`   | `workflows/prompt.md`   | fast → full | write or change text a model executes  |

No prefix? Classify from the trigger list below, say which you chose in one
sentence, and proceed. Do not ask which prefix the user meant when the text
answers it.

`review:` is the one prefix that is not a flow. It runs against a diff that
already exists, holds no gate of its own, and is the whole review path when
there was no flow — see `workflows/review.md`.

<!-- F-103 --><!-- F-116 -->
`prompt:` routes a change to text a **model** executes — a system prompt, a tool
description, a classifier, an extraction instruction, a question script. It runs
`fast` while the prompt is internal and `full` once its output reaches a user,
and it carries gates no other flow holds: an eval pack instead of a test run, a
golden snapshot of the tool surface, a replay diff instead of a single read.
Code that merely *calls* a model is a `feature:`; the text the model reads is a
`prompt:`.

## The trigger list — the single routing authority

<!-- F-011 -->
Checked **at intake and again mid-task**. A task that grows into one of these
stops and is re-routed. That is a normal outcome, not a failure.

Any of these means the work is **not** a one-pass job, whatever its prefix:

- Auth, sessions, tokens, crypto, secrets, payments, PII.
- Schema migrations, data backfills, anything irreversible on real data.
- Production deploys, infra topology, anything needing a rollback story.
- Public product surface, or any task where *what correct means* is still open.
- A **published contract**: a request or response shape, an event payload, a
  generated client, a shared library's exported signature. The consumer is
  someone else's code and is not in this diff.
- A diff bigger than a reviewer reads in one sitting (~400 lines non-generated).

## Flow → what it costs

<!-- F-010 -->
Pick the cheapest flow that still clears the gates the change actually
triggers. The trigger list decides, not how large the request sounds.

| Flow | Shape                           | Read                        |
| ---- | ------------------------------- | --------------------------- |
| asap | one pass, one person, minutes   | `docs/devflow/asap-flow.md` |
| fast | seven stages, minutes to hours  | `docs/devflow/fast-flow.md` |
| full | thirteen stages with skip gates | `docs/devflow/full-flow.md` |

Downgrading mid-flow is allowed and is not a failure. If the architecture stage
finds the change is a config knob, say so in one line and re-flow it down.

## Stack guards — when to read `docs/`

<!-- F-038 -->
`docs/` is one production system's patterns. Read a file only when
`stack.md` says this repo matches its substrate, and read it as a pattern.

| Read                                            | Only when `stack.md` shows                      |
| ----------------------------------------------- | ----------------------------------------------- |
| `docs/backend/*`                                | Go, and a layered/DDD structure                 |
| `docs/webapp/ai-features.md`                    | the product has LLM features                    |
| `docs/frontend/typescript-react-conventions.md` | TypeScript + React                              |
| `docs/frontend/mobile-*`                        | React Native                                    |
| `docs/frontend/feature-sliced-architecture.md`  | the repo already uses FSD                       |
| `docs/devops/release-tagging-and-gitops.md`     | a reconciler owns deploys                       |
| `docs/devops/ci-*`                              | GitLab-style CI with per-job runners            |
| `docs/tools/*`                                  | always — commits and dependencies are universal |

<!-- F-096 -->
Version guards, not just language guards: the no-manual-memoization rule needs
React **19 with the compiler enabled**. On React ≤18 it is wrong, because manual
memoization is the supported mechanism there.

## Practices — always in scope

| File                            | Holds                                            |
| ------------------------------- | ------------------------------------------------ |
| `practices/floor.md`            | the six things speed never buys                  |
| `practices/git.md`              | commits, PRs, what never gets committed          |
| `practices/testing.md`          | what to test, in what order, when not to         |
| `practices/agent-discipline.md` | read bounds, output caps, table shape, reporting |
| `practices/project-memory.md`   | what goes in `AGENTS.md` and what stays out      |
| `practices/code-style.md`       | comments, helpers, suppressions                  |
| `practices/release.md`          | tags, deploys, rollback, migrations in deploy    |
| `practices/observability.md`    | the day-one minimum                              |

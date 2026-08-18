---
title: Development principles
summary: Product comes before process weight, four things are never skipped whatever the stack maturity, and a pattern is not a constraint.
keywords: [principles, product first, never skip, best practices, security, observability, release speed, write for the reader, two sentences, automation, executable documentation, pattern, constraint, deviation, minimize process]
related:
  - devflow/roles.md
  - devflow/scaling-down.md
  - devflow/asap-flow.md
  - devflow/flow-cost.md
  - devflow/observability-minimum.md
---

# Development principles

## Prioritizing product over process

Client-facing product development is prioritized over a sufficient dev stack. A
"pure" dev stack — no dedicated test stand, no QA team, manual deploys — is an
acceptable state for a young product.

Process weight scales with the system: the flows describe the full ceremony,
`devflow/scaling-down.md` defines what a stripped-down version may and may not
drop, and `devflow/asap-flow.md` is the smallest flow that is still a flow —
one pass, one person, for work that must land now.

## What is never skipped

Whatever the stack maturity:

1. **Development best practices** — the engineering constraints in `webapp/`:
   client input validated at the boundary, every dynamic value bound as a SQL
   parameter, secrets out of code, errors handled rather than swallowed, no
   authorization check weakened. Skipping them saves days and costs months.
2. **Security practices for client secrets** — credential handling, encryption
   at rest, audit of access to sensitive data (`webapp/security-secrets.md`,
   `webapp/security-audit-logging.md`). A young product is exactly the one that
   cannot survive a leak.
3. **System observability** — you cannot operate what you cannot see
   (`devflow/observability-minimum.md`).
4. **Release speed** — the ability to deliver a fix fast is itself a safety
   property (`devflow/release-speed.md`).

## Writing for the reader

Anything addressed to a human — an approval request, a status update, a
comment, a plan summary — is **one or two sentences, maximum, with no filler
phrases**. Humans approve what they can read at a glance.

Artifacts consumed by LLMs or by later stages (design docs, scenario corpora,
runbooks) are as detailed as the work needs. The same fact often exists in both
forms: the two-sentence version for the operator, the full version attached
below it.

## Treating automation as documentation

By the time a system matters, everybody has forgotten how to deploy and test
it. Every deploy path and every test path must exist as a runnable artifact — a
CI job, or a shell script in the repo (an SSH-driven `deploy.sh` is a perfectly
valid CI replacement for a hand-rolled system).

Prose instructions that are not backed by a script are a bug: they drift,
scripts do not. The rule of thumb: **if a step is described in a README, there
must be a command the README tells you to run.**

## Distinguishing a pattern from a constraint

`webapp/` carries both and they answer to different authorities.

A **constraint** — the never-skip list above — holds in every project;
deviating from one is a vulnerability and needs a written reason.

A **pattern** — the four backend layers, ports on the service, FSD slices on
the frontend — is how this reference builds one, and a project that already
builds differently keeps its own architecture: consistency with the surrounding
code beats the pattern in these files (`devflow/asap-flow.md`).

What a project's architecture never buys is relief from a constraint — a
different layering, an ORM or a framework convention still owes a parameterized
query and a validated boundary.

## Minimizing process, not gates

The target is the cheapest flow that still clears the gates the change actually
triggers (`devflow/flow-cost.md`); the trigger list decides that
(`devflow/asap-flow.md`), not how large the request sounds.

Work that reduces no real risk is not diligence, it is cost — do not open a
stage to look thorough, and do not manufacture an artifact a rule did not ask
for.

The one thing this never licenses is dropping a gate the change *did* trigger:
a triggered gate is compressed, not skipped, and whatever was compressed or
left unverified is named in the hand-back.

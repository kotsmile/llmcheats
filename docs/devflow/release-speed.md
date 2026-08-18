---
title: Release speed — the never-skip capability
summary: Release speed is a tested property with a number — under 30 minutes on a CI pipeline, under 5–10 on a hand-rolled system — and it requires a one-command deploy that is the normal path.
keywords: [release speed, hotfix, deploy path, one command, rollback, lean CI, roll forward, no human-memory steps, deploy script, SSH]
related:
  - devflow/principles.md
  - devflow/fast-flow.md
  - webapp/infrastructure.md
  - webapp/testing-ci.md
---

# Release speed — the never-skip capability

## Release speed targets

Release speed is a **tested property**, not an aspiration:

- Big systems (CI pipeline, orchestrated deploy): a hotfix goes from commit to
  production in **under 30 minutes**.
- Hand-rolled systems (a VM, SSH, a deploy script): **under 5–10 minutes**.

## What fast release requires

- The deploy path is one command (`deploy.sh prod` or a CI button), documented
  where the code lives, and **exercised routinely** — the fast path must be the
  normal path, or it will not work under pressure.
- Rollback is one command, and it is listed in every release record.
- CI pipelines are lean: a hotfix does not wait for a 40-minute exhaustive suite
  — it runs the fast blocking checks; the exhaustive suite runs after, and a
  failure there rolls forward with another fix.
- No human-memory steps: if deploying needs "the thing only one person knows",
  the system fails the speed test. Scripts remember; people do not.

CI is the preferred automation, but **a shell script driving SSH is a valid CI
replacement** for small systems — same rule applies: it lives in the repo, it is
the only way anyone deploys, and the README points at it.

---
name: release
description: "release: cut and ship a version. Use for a prompt starting release:, or a request to tag, publish, deploy a version, or promote a build to production."
---

# `release:` — cut a version

<!-- F-045 -->
A release is a **tag**. Deploying is a **commit** that changes declared desired
state. They are separate events, and conflating them is how a green pipeline
leaves production on the old version.

`stack.md` names this repo's actual mechanism. Follow it. Everything below is
the shape, not the commands.

## 1. Preconditions

- Main is green. CI green is an entry condition, not something to chase after.
- Every change in this release has landed and been reviewed.
- <!-- F-051 -->If a schema migration is in this release, confirm which of
  expand/migrate/contract it is, and that the contract step is **not** in the
  same release as its expand.

## 2. Cut the tag

Version from this repo's scheme — `stack.md` names it. The version is stamped
into the artifact at build time, not written in a second place.

<!-- F-091 -->
**Artifacts are immutable.** Re-uploading identical bytes is a no-op; different
bytes under the same version must be refused. A fix is a **new tag**, never a
re-tag.

## 3. Deploy

<!-- F-045 -->
Deploying is updating the declared desired state somewhere diffable — a values
file, a unit file, a compose bump. Whatever the mechanism, the deployed state is
**written down, diffable, and rolled back by reverting**.

<!-- F-052 -->
Never cancel a deploy job. A cancelled deploy leaves the system in a state
nobody chose.

<!-- F-048 -->
If a reconciler owns this environment, the **only** durable edit is to its source
of truth. A change made in a deployment UI is reverted by self-heal — usually
minutes later, without notice. This includes dashboards and alert rules.

## 4. Verify the artifact, not the job

<!-- F-046 -->
**A green pipeline can leave production on the old version.** The bump job can
fail to push after the build succeeded, and nothing looks wrong.

Confirm:

- the deploy commit **landed** on the branch the reconciler follows;
- the **running version** changed — ask the system, do not infer it from CI;
- health checks, error rate, and the feature's own metrics, for the first
  minutes after rollout.

## 5. Release record

<!-- F-092 -->
Version, when, by whom, and **the one-command rollback**. The rollback command
is listed in every release record — not looked up during the incident.

If rollback is not one command, that is a finding worth reporting: release speed
is a tested property, and a fix that cannot ship fast is a safety problem.

## 6. Hand-back

<!-- F-013 -->
```
Changed:      version, what is in it
Ran:          the deploy, and what the running system reported afterwards
Not verified: what you watched for and for how long
Rollback:     the exact one command
```

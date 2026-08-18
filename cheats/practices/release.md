# Release and deploy

## Speed is a tested property

<!-- F-092 -->

With a number, not an aspiration:

- CI pipeline, orchestrated deploy: commit to production in **under 30 minutes**.
- Hand-rolled (a VM, SSH, a deploy script): **under 5–10 minutes**.

What that requires:

- **The deploy path is one command**, documented where the code lives, and
  **exercised routinely** — the fast path must be the normal path, or it will not
  work under pressure.
- **Rollback is one command**, listed in every release record.
- **Lean CI for the fast path.** A hotfix does not wait for a 40-minute
  exhaustive suite; it runs the fast blocking checks, the exhaustive suite runs
  after, and a failure there rolls forward with another fix.
- **No human-memory steps.** If deploying needs "the thing only one person
  knows", the system fails the speed test. Scripts remember; people do not.

CI is the preferred automation, but **a shell script driving SSH is a valid CI
replacement** for a small system — same rule: it lives in the repo, it is the
only way anyone deploys, and the README points at it.

## Release, deploy and rollback are three different things

<!-- F-045 -->

| Action   | What it is                                   |
| -------- | -------------------------------------------- |
| release  | cut a **tag**                                |
| deploy   | a **commit** changing declared desired state |
| rollback | **reverting** that commit                    |

Conflating release and deploy is how a green pipeline leaves production on the
old version.

<!-- F-091 -->

**Artifacts are immutable.** Identical bytes re-uploaded is a no-op; different
bytes under the same version are refused. **A fix is a new tag**, never a re-tag.
The one common exception is a base image, where a mutable tag is deliberate.

## Verify the artifact, not the job

<!-- F-046 -->

**A green pipeline can leave production unchanged.** The bump can fail to push
after the build succeeded, and nothing looks wrong.

Confirm the deploy commit landed and the running version changed. Ask the
system; do not infer it from CI.

<!-- F-048 -->

Where a reconciler owns the environment, the **only durable edit is to its source
of truth**. A change made in a deployment UI is reverted by self-heal, usually
minutes later and without notice — a change that appears to work and then
vanishes. This includes dashboards and alert rules.

## Migrations in a deploy

<!-- F-050 -->

**The migrate step runs before the new code serves, as its own step.** An
init container, a pre-sync hook, an `ExecStartPre=`, a one-shot compose service —
whatever this runtime offers.

**Never migrate on service boot.** N replicas racing DDL is a failure mode you
delete by keeping the step separate.

<!-- F-051 -->

**Backward compatible one release back** — the old code runs against the new
schema during rollout. Expand → migrate → contract, across releases, never all
three at once.

## CI hygiene

<!-- F-052 -->

Make merge-request checks **interruptible** so a re-push frees the runner.
**Never mark a deploy job interruptible** — a cancelled deploy leaves the system
in a state nobody chose.

<!-- F-053 -->

**CI secrets are protected variables scoped to protected refs.** Pipelines from
arbitrary branches and forks never see them.

<!-- F-058 -->

**An expiry on the credential a reconcile loop presents is an outage scheduled
for a day nobody picked.** Long-lived automation gets a credential whose rotation
is a deliberate operation with a runbook, not a timer nobody is watching.

<!-- F-055 -->

**Measure before caching.** A cache pays only if restore plus archive beats what
it saves — measure the archive step, not the build. A package-manager store with
hundreds of thousands of small files is the classic net loss: one measured case
turned a 22-second check into 16 minutes and OOM-killed two others, reported as
a system failure, which sends you looking in the wrong place entirely.

## The runtime contract

<!-- F-090 -->

An app should require exactly four things, which is what makes systemd, Compose
and Kubernetes equally valid runtimes for it:

1. **Env vars** holding secrets.
2. **A config file.**
3. **A network** to its dependencies and an ingress.
4. **SIGTERM with a grace period** ≥ its drain window.

In return it boots read-only, listens where configured, exposes a health
endpoint, drains on SIGTERM, and logs structured lines to stdout.

<!-- F-053 -->

Secrets reach it as: **secret store → runtime secret → env var → placeholder in
the config file.** Never baked into images, never committed.

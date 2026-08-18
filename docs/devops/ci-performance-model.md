---
title: CI cost model — caches, clones and runner tiers
summary: The measured reasons almost nothing is cached, how each job minimises its clone, and why runner pools are split by job length.
theme: devops
keywords: [cache, archive step, helper container, OOM, exit 137, clone, GIT_DEPTH, GIT_STRATEGY, sparse checkout, blob filter, runner tier, queue, cpu request, maximum timeout, concurrency]
related:
  - devops/ci-pipeline-composition.md
  - devops/release-tagging-and-gitops.md
---

## Almost nothing is cached, on purpose

A check job caches nothing unless it opts into the task-runner cache template, which stores the task runner's cache directory and nothing else.

Language caches were **tried and removed after measurement**. The platform archives the cache inside a small helper container, so a package store with tens or hundreds of thousands of files costs 10–20 minutes per job in restore and archive. A 22-second check became 16 minutes, and two heavier checks were OOM-killed — reported as a *system failure*, which sends you looking in the wrong place entirely.

**Before re-adding a cache, measure the archive step, not the build.** A cache pays only if restore plus archive beats what it saves, which for a file tree means coarse artefacts — never a package manager's store.

Cache keys are **per job**. One shared key against a shared backend lets concurrent jobs overwrite each other's entries, so the hit rate depends on who finished last.

## The clone is the bigger fixed cost

A job pod is fresh every time, so fetching sources is a full clone: measured at 42–89 seconds, against 5–12 seconds to schedule the pod and pull its node-cached image.

| Technique | When |
| --- | --- |
| Depth 1 | The global default |
| Full history | Only where history *is* the data — release notes, a tag-driven timeline |
| Depth ~20 | A job that rebases onto the default branch and pushes |
| **No clone at all** | **Any job that does not read the repo** |
| Sparse checkout + shallow, blob-filtered fetch | A job that reads exactly one file |

A job running a one-second command spent 49–75 seconds cloning before the no-clone strategy was set on it. That is the single highest-leverage change on this list.

For the one-file case, narrowing the working tree and fetching with a blob filter faults in that one blob: ~113MB and 42–89s becomes ~750KB and under three seconds.

**A blob filter alone is not that.** A blobless clone still checks out the whole tree and faults every blob back, one round trip each — which is why it must be paired with disabling checkout.

## Runner tiers are queues, not just sizes

Pools are split by **job length**, not only by resource appetite: a tier is a queue, and the slowest job in it sets everyone's wait.

| Tier | Runs |
| --- | --- |
| xs | API calls: approve, cancel, sync, no-op checks |
| s | Small scripts, image push, and the **fast checks** (a few minutes) |
| m | The **slow checks** (roughly 10–25 minutes) |
| l | Image builds and memory-heavy type checks, which have OOM history on smaller tiers |

Putting a three-minute check on the slow tier costs it roughly half an hour of queue time.

A job that installs a toolchain, re-renders manifests and pushes does **not** fit the smallest tier's CPU and memory limits, even though it looks like a small script.

## Two things to check before retagging a job

Neither is visible in the repo:

1. **The maximum timeout lives on the runner entity**, and the small tiers allow half what the large ones do. Moving a job to a smaller tier can halve its budget and kill it.
2. **Under contention a pod's CPU share follows its request, not its limit.** A job on a tier with half the CPU request gets half the share of a saturated node even though both tiers cap at the same limit.

Slot counts are bounded by the CI node's core count, not by request arithmetic. Raising the concurrency setting slowed every job in the measurement that tested it.

## The general lesson

Every entry on this page came from measuring a specific job, and three of them contradicted the intuition that motivated the original change. CI performance work that is not measured end to end — including the teardown steps — tends to move cost rather than remove it.

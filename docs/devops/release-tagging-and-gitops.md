---
title: Release tags and GitOps deployment
summary: What a release tag triggers, how the deployment bump reaches the cluster, and the failure modes where a green pipeline still leaves production unchanged.
theme: devops
keywords: [release tag, tag pattern, build, deploy, manual approve, GitOps, reconciler, self-heal, image tag bump, render, render-verify, sync wave, migration job, unmanaged manifest, silent push failure]
related:
  - devops/ci-pipeline-composition.md
  - devops/service-config-in-charts.md
  - backend/database-and-migrations.md
---

## A release is a tag

Created in the forge UI, named by project and number or semantic version:

```
<project>/release-<N>
<project>/release-<x.y.z>
```

The project segment and the numbering scheme are declared by the project itself; the number is the previous one plus one. A release tool can cut the tag and shows every project's timeline.

## What the tag triggers

1. The image is built in-cluster and published as it builds — there is no separate push job.
2. A **deployment bump** job rewrites the image tag in the deployment values, re-renders the manifests and pushes to the default branch.
3. A **sync** job upserts the environment's application manifest, syncs and waits.
4. A **manual approval gate** sits between the test and production deployments, restricted to an allow-list.

## The reconciler owns the cluster

The cluster follows the default branch. A change made in the deployment UI is **reverted by self-heal** — so an emergency fix applied there disappears at the next reconcile, usually minutes later and without notice.

Change the manifest. This applies to dashboards and alert rules too.

## Committed renders

After **any** change to a chart or its application manifest, re-render and commit the render diff **in the same commit**. A CI check fails on stale renders.

The point is reviewability: the rendered output is what actually reaches the cluster, and a values change whose render diff is surprising is caught in the merge request rather than at sync time.

## Two failure modes where nothing is wrong-looking

**A green release pipeline can leave production on the old image.** The bump job pushes to a branch, and a push can fail after the build succeeded. Verify that the bump commit landed — not that the pipeline was green.

**Application manifests are unmanaged.** Only the CI upsert job applies them, so editing one in git reaches no cluster until that project next releases. A manifest change and a release are two separate events, and assuming otherwise means debugging a cluster that is running exactly what it was told to.

## Migrations run ahead of the deployment

Schema migrations run as a **sync-hook Job in an earlier sync wave** than the deployment, using the same image as the service but a different entry point, and are deleted before the next hook creation.

This is why the service binary must not migrate on boot: the ordering is a property of the sync waves, not of pod scheduling.

## Rollback

Because image tags are immutable and the render is committed, a rollback is a revert of the bump commit — not a rebuild and not a re-tag of a mutable reference.

The one exception is a baked base image, where rollback is re-tagging an existing immutable version reference. That is a deliberate asymmetry: base images are the only place a mutable tag is used, and it is used because the node agent must re-check it.

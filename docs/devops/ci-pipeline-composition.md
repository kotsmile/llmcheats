---
title: CI pipeline composition
summary: How one flat pipeline is assembled from per-project files, the stage and naming rules, and the shared job templates.
theme: devops
keywords: [CI, recursive include, flat pipeline, child pipeline, stages, needs, job prefix, namespace, rules, merge request, release tag, YAML anchor, templates, interruptible, protected variables]
related:
  - devops/ci-performance-model.md
  - devops/release-tagging-and-gitops.md
  - devops/service-config-in-charts.md
---

## Assembly

The pipeline is built by **recursive includes** and merges into ONE pipeline. There are no child pipelines.

```
root CI file → <dir>/ci file (include list) → <dir>/<project>/ci file (jobs)
```

Adding a project is a CI file in its directory plus one include line in the parent. A new top-level directory also needs a line in the root file.

## Stages live only at the root

```
pre → checks → build → test → prod → post
```

Ordering **inside** a stage is expressed with job dependencies, never by inventing a stage.

## Job names are namespaced by convention

Every job name is prefixed with its project. The namespace is merged across all includes, so an unprefixed duplicate **silently overrides** another project's job — a failure mode with no error message.

## Rules

- Release jobs gate on a protected release tag pattern.
- Check jobs gate on the merge-request event plus a changed-paths filter.
- The release-tag rule is defined **once per file** as a YAML anchor and reused.

**YAML anchors are file-local** — they never cross an include boundary. An anchor defined in a shared template is invisible to the file that includes it, which is why each project file defines its own.

## Shared templates

| Template                   | Purpose                                                          |
| -------------------------- | ---------------------------------------------------------------- |
| cancel-outdated            | Cancels older release-tag pipelines through the API              |
| no-check                   | A no-op check for projects with nothing to run                   |
| cache                      | Task-runner cache configuration, opt-in                          |
| language env               | Concurrency settings for a container that misreads its CPU quota |
| image build                | In-cluster image build to the registry                           |
| project-driven image build | The same, parameterised by the project rather than by the job    |
| approve                    | Manual gate with an allow-list of approvers                      |
| deployment bump            | Tag bump, re-render and push to the default branch               |
| deployment sync            | Manifest upsert, sync and wait                                   |

Include the cache template explicitly in the projects that use it — it is not global.

## A job says what to run, not how

A check job names its project and nothing else; what that project's check *is* belongs to the project, not to the CI file. The same holds for image builds — the image refs, dockerfile, context and build arguments are properties of the project.

Two things follow:

- **The same check runs locally and in CI.** A failure reproduces on a laptop without reading the CI file, which is the whole point of keeping the definition out of it.
- **A CI file change is rare.** Most build changes are project changes, so the pipeline stops being a place where behaviour hides.

Dockerfiles follow the same split: a dependency layer and a build layer, each invoking the project's own definition.

**No CI job installs dependencies itself.** A job needing a language *runtime* still installs it, because that is a property of the image, not of the project.

## Interruptibility

**Every merge-request check job is interruptible**, so a re-push frees the runner slot instead of holding it. The cancel-outdated template covers release-tag pipelines, which are not interruptible.

**Never mark a deploy job interruptible.** A cancelled deploy leaves the cluster in a state nobody chose.

## Secrets

Protected CI variables only. Merge-request pipelines never see them, and deploys run only from protected release tags — so a fork or an untrusted branch cannot reach a credential.

## Reference flows

- A full release flow: build → deploy to test → manual approve → deploy to production.
- A pipeline-simulation project on the smallest runner tier, where nothing is actually built and the deployment bump targets a dummy value instead of an image tag. Use it to test pipeline changes without burning real build capacity.

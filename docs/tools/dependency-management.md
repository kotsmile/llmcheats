---
title: Dependency management and the version barrier
summary: How dependencies are added per ecosystem, why lock files are never hand-edited, and the runtime-version check that prevents a stale module tree.
theme: tools
keywords: [dependency, lock file, workspace, package manager, native module, engines, node version, stale module tree, phantom type errors, go mod tidy, version mismatch]
related:
  - tools/commit-conventions.md
  - frontend/typescript-react-conventions.md
  - frontend/shared-packages-and-platform-adapters.md
---

## Adding a dependency

| Ecosystem | How |
| --- | --- |
| JS/TS | The workspace package manager's add and remove commands, scoped to the target workspace |
| Go | `go get <pkg>@<version>`, then `go mod tidy` |
| Native mobile modules | The mobile framework's own install command — **never** the plain package-manager add |

The framework installer exists because it picks the version compatible with the current SDK and performs the linking. A plain add installs a version that compiles and fails at runtime on one platform.

## Never hand-edit a dependency or lock file

Lock files must stay in sync with the manifest. A hand-edited manifest produces a lock file that no longer describes what will be installed, and the divergence surfaces on somebody else's machine, not yours.

## The runtime version barrier

The workspace declares a minimum runtime major version through the manifest's engines field, matching the version the CI images carry.

On an older runtime the install **aborts at manifest validation — before it touches the module tree.**

That barrier is not pedantry. Without it the failure is silent: the install used to die partway through fetching, on a transitive engine constraint, leaving a **stale module tree** behind. A stale tree still type-checks — against the wrong package versions.

### The symptom, and how to recognise it

A batch of type errors appears in code nobody touched.

The instinct is to debug the code. The correct first step is to **compare an installed package's manifest version against the declared one**. A mismatch there is the bug; the type errors are downstream of it.

The general shape is worth remembering: a partially completed install is more dangerous than a failed one, because it leaves a working-looking state. Any install step that can fail halfway needs a precondition check that runs first.

## Version pins as data

Where a version is pinned, the pin lives in the manifest the ecosystem already reads — the language module file, the runtime version file, the package manifest — and is **never copied** into a second place.

A copied version is a version that will go stale, and the copy is always the one somebody forgets. Tooling that needs to know a version reads it from the original.

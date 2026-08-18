---
title: Code generation and build targets
summary: Which artefacts are generated, why no build target depends on generation, and the rule about generated files.
theme: backend
keywords: [make, generate, swagger, openapi, oapi-codegen, go generate, generated file, single test, race, lint, build target]
related:
  - backend/http-endpoints-and-middleware.md
  - frontend/shared-packages-and-platform-adapters.md
  - backend/layered-architecture.md
---

## Build entry points

Build and test are defined by the project, next to the code, so the same definition runs locally and in CI.

The make targets cover the rest — the things the build itself does not own:

| Target | Purpose |
| --- | --- |
| default | tidy, format, test, build |
| run | run the server locally (a variant also tees output to a log file) |
| test | tests, end-to-end excluded — this is the real test target |
| generate | API docs + generated clients + `go generate ./...` |
| format | formatter + import sorting |
| dev tools | install local development tooling |
| deps up / down | start and stop local database and cache containers |
| migration create | scaffold a new migration file |

There is **no lint target** — the linter config is checked in and runs in CI.

## Generation is explicit

**The build compiles only.** It does not generate code or API docs, and no build target depends on generation.

Regenerate explicitly after changing a spec or an annotation. What generation covers:

1. **API documentation** from the annotations on handlers.
2. **Typed clients for third-party APIs**, generated from their OpenAPI specs into the shared library.
3. Anything declared with `go generate`.

## Never hand-edit a generated file

Generated files are recognisable by their suffix and header. Change the spec or the annotation and regenerate; a hand edit is silently reverted by the next run and produces a diff nobody can review.

## Regenerating the frontend API client

Two steps, in order, because the second reads the artefact the first produces:

1. Regenerate the API documentation in the backend project.
2. Run the frontend package's generation script, which reads that document.

The generated client directory in that package is likewise never edited by hand.

## Running one test

```bash
go test -race -run TestName ./path/to/package
```

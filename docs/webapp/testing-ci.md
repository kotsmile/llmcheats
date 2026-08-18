---
title: CI checks
summary: Per-project check jobs gated on changed paths, blocking by default, running vet/test on the backend and tsc/ESLint on the frontend plus staleness nets.
keywords: [CI, check job, changed paths, go vet, go test, race, tsc, ESLint, staleness check, blocking check, advisory]
related:
  - webapp/testing-database.md
  - webapp/testing-http-e2e.md
  - webapp/infrastructure.md
  - devflow/release-speed.md
---

# CI checks

## Wiring checks into CI

- Per-project check jobs gated on changed paths; a shared-library change
  re-runs its dependents' checks.
- Backend check: `go vet ./...` + `go test ./...` (plus build). Run single
  tests locally with `-race`; consider `-race` in CI when the suite affords it.
- Frontend check: `tsc -b` + ESLint (+ whatever unit tests exist).
- Also-run safety nets that are not unit tests: config-parses tests,
  generated-file staleness checks (`--check` modes), rendered-manifest diffs.
- Checks on merge requests are **blocking** by default; make a check advisory
  only as a conscious, documented exception.

---
title: Testing strategy — what to test and in what order
summary: A test protects a behavior or an invariant, never the shape of the implementation, and is written in a fixed priority order starting with a bug reproduction.
keywords: [test philosophy, invariant, regression, reproduction test, priority order, when not to test, test naming, AAA, justification]
related:
  - webapp/testing-unit-fakes.md
  - webapp/testing-frontend.md
  - devflow/fast-flow.md
  - devflow/asap-flow.md
---

# Testing strategy — what to test and in what order

## What a test protects

**A test protects a behavior or an invariant, never the shape of the
implementation.** Assert what a caller depends on — the decision returned, the
row persisted, the status code, the event emitted — not the private helper that
produced it.

A test that has to be rewritten every time its subject is refactored was
testing the shape, and it will be deleted the first time it is inconvenient.

## The order to write tests in

Write them in this order, and stop where the cost of the failure stops
justifying the test:

1. **A test that reproduces a discovered bug** — written first, failing before
   the fix, and kept afterwards. This is a gate in the fast flow
   (`devflow/fast-flow.md`) and it does not collapse under any flow, however
   small (`devflow/asap-flow.md`). Its one exception is in
   `webapp/testing-frontend.md`, and it is about where the defect lives, never
   about how urgent the work is.
2. Business and domain invariants — entity and service.
3. Contracts something else depends on: an endpoint's authorization matrix, a
   published request/response shape, a pinned role-name constant.
4. Critical integration paths — auth, money, migrations, the SQL that is itself
   the risk (`webapp/testing-database.md`).
5. Everything else, only where a failure would actually cost something —
   business logic gets the density, transport gets a thinner
   authorization-matrix layer, glue gets none.

## When not to write a test

Do not add a test because code changed. A trivial refactor, plain wiring, and
behavior already covered by a test one level up get nothing.

New behavior gets a test when the behavior is worth protecting; a spike or a
throwaway script does not, and then you *say* you skipped it.

## Justifying and naming tests

- **Critical paths, justified individually.** Every non-trivial test carries a
  doc comment answering *why does this exist* — the invariant it guards, the
  way the code can silently regress, or the incident that motivated it
  ("guards the invariant: chaining decorators must copy `reason`, otherwise it
  is silently dropped"). A test that cannot state its reason is ballast.
- **Name tests as sentences** where it helps:
  `TestUpsertStoresTheAccessListsAndNeverNull`,
  `TestTheGateAcceptsTheThreeRolesAndOnlyThem`.
- **AAA with comments**: `// Arrange`, `// Act`, `// Assert` sections in every
  test, both backend and frontend.

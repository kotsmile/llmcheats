# Testing

## What a test protects

<!-- F-077 -->
**A test protects a behavior or an invariant, never the shape of the
implementation.** Assert what a caller depends on — the decision returned, the
row persisted, the status code, the event emitted — not the private helper that
produced it.

A test that has to be rewritten every time its subject is refactored was testing
the shape, and it will be deleted the first time it is inconvenient.

## The order to write them in

<!-- F-078 -->
Write in this order and **stop where the cost of the failure stops justifying
the test**:

1. **A test that reproduces a discovered bug** — written first, failing before
   the fix, kept afterwards.
2. **Business and domain invariants.**
3. **Contracts something else depends on** — an endpoint's authorization matrix,
   a published request/response shape, a pinned constant.
4. **Critical integration paths** — auth, money, migrations, the query that is
   itself the risk.
5. **Everything else**, only where a failure would actually cost something.
   Business logic gets the density; transport gets a thin authorization-matrix
   layer; glue gets none.

## The reproduction test does not collapse

<!-- F-015 -->
Under every flow, however small or urgent: the failing test comes first.

One stated exception: a frontend defect with no rule left to extract, which
reports the browser flow walked instead. **A defect in a rule, a computation or
a state transition is never that case.**

## When not to write a test

<!-- F-079 -->
Do not add a test because code changed.

- A trivial refactor gets nothing.
- Plain wiring gets nothing.
- Behavior already covered one level up gets nothing.
- A spike or throwaway script gets nothing — **and then you say you skipped it.**

A few high-value tests that verify what users or other components actually
depend on beat broad coverage of implementation detail.

## Justifying and naming

<!-- F-080 -->
Every non-trivial test carries a one-line reason: the invariant it guards, the
way the code can silently regress, or the incident that motivated it.

> guards the invariant: chaining decorators must copy `reason`, otherwise it is
> silently dropped

**A test that cannot state its reason is ballast.**

Name tests as sentences where it helps. Structure as arrange / act / assert,
with those comments where the repo's language convention allows them.

## CI

<!-- F-084 -->
Checks are **blocking by default**. Making one advisory is a conscious,
documented exception.

<!-- F-085 -->
**The same check runs locally and in CI.** A failure must reproduce on a laptop
without reading the CI config — that is the whole point of keeping the check
definition next to the code rather than inside the pipeline.

This is also where you find the real commands: read the task runner (`Makefile`,
`justfile`, `package.json` scripts, `Taskfile`), not the CI file. `stack.md`
records what they are for this repo.

Worth having alongside the unit tests: config-parses tests, generated-file
staleness checks, and any rendered-output diff.

---
name: refactor
description: "refactor: change shape without changing behavior. Use for a prompt starting refactor:, or a request to split, extract, rename, restructure or move code. Behavior must be identical after."
---

# `refactor:` — asap flow, escalating to full

<!-- F-011 -->
The defining property: **behavior is identical afterwards.** The moment
behavior changes, this is a `feature:` or a `bug:` wearing the wrong prefix.

## 1. Check the trigger list before starting

A refactor escalates out of the one-pass flow when it touches:

- **A published contract** — a request or response shape, an event payload, a
  generated client, an exported signature. The consumer is not in this diff, so
  the change cannot be verified in one pass. This is the trigger refactors hit
  most often.
- Auth, authz, sessions, crypto, secrets.
- Anything requiring a data migration to land.
- ~400 lines of non-generated diff. Split it into a stack.

If any of these apply, run `workflows/feature.md` instead and say why in one
sentence.

## 2. Establish the behavior baseline first

<!-- F-077 -->
A refactor is only safe against tests that assert **behavior**, not shape. Tests
that assert the shape of the thing you are about to reshape will fail for the
wrong reason and teach you nothing.

Before touching anything:

- Run the existing suite. Record what is green. A refactor started on a red
  suite cannot be verified.
- If the area has no behavioral coverage, **that is the first commit** — add it,
  green, before the refactor. Say so if you decide to skip it.

## 3. Refactor

<!-- F-038 -->
Move toward the pattern the repo already uses, not toward the pattern in
`docs/`. If this repo layers differently, refactoring it into the reference's
four layers is not a refactor, it is a rewrite nobody asked for.

<!-- F-076 -->
Extraction has a bar: a helper earns its own function when it has **more than
one caller**. A single-use helper, however well named, is usually just
indirection. This is a *pattern*, not a constraint — a repo whose house style
extracts single-use helpers for testability keeps its own style.

<!-- F-016 -->
No behavior changes smuggled in. If you find a bug while refactoring, stop and
raise it separately; fixing it here makes the diff unreviewable and the revert
unusable.

## 4. Verify

The suite must be green **and the same green** — same tests passing, none
quietly deleted or skipped.

<!-- F-012 -->
Deleting or skipping a test to make a refactor pass is a floor violation, not a
cleanup.

Diff review: every hunk should be explicable as "same behavior, different
shape". A hunk you cannot explain that way is the bug this workflow exists to
catch.

## 5. Commit

<!-- F-042 -->
One logical change per commit. **Never mix a refactor with a behavior change** —
the commit must be revertable as a unit.

Large refactors land as a stack of small commits, each green.

## 6. Hand-back

<!-- F-013 -->
```
Changed:      files touched, one line each
Ran:          the suite before and after, and that they match
Not verified: what you could not exercise, explicitly
Skipped:      follow-ups consciously left
```

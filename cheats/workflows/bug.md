---
name: bug
description: "bug: fix agreed-broken behavior. Use for a prompt starting bug:, or a report that something returns the wrong result, errors, or regressed. Runs the fast flow, reproduction test first."
---

# `bug:` — fast flow

<!-- F-010 -->

Seven stages. Target duration: minutes to hours, not days.

## 1. Scope

Reproduction, blast radius (who is affected, is data at risk), severity.

Decision: fix now or schedule it. **Data-loss or security ⇒ now** — switch to
`workflows/hotfix.md`.

## 2. Is this code or infra?

<!-- F-018 -->

**Ask this before reading the code.** Check recent deploys, resource
saturation, dependency outages, certificate and quota expiry.

Half of "bugs" are infra events. A code fix for an infra problem wastes the
release _and_ leaves the problem in place.

**Artifact:** one paragraph — what was ruled out, and how you ruled it out.

## 3. Reproduce, in a test, first

<!-- F-015 -->

**A test that reproduces the bug is written first, fails before the fix, and
passes after.** This is the one non-negotiable test of this flow. It does not
collapse for a small change, an urgent change, or a one-line fix.

It has exactly one exception, and it is stated rather than improvised: a
frontend defect with no rule left to extract — see
`docs/webapp/testing-frontend.md`, which reports the browser flow walked
instead. A defect in a rule, a computation or a state transition is never that
case.

## 4. Fix

<!-- F-016 -->

The smallest change that fixes the defect. **No opportunistic refactoring** —
that is a separate `refactor:` task. Never mix a refactor with a behavior change
in one commit.

<!-- F-012 -->

`practices/floor.md` applies. In particular: no test is deleted or skipped, and
no suppression comment is added, to make a build green.

## 5. Verify

- The new reproduction test.
- The suite of the affected area.
- **Regression check of adjacent flows.**
- An explicit re-check of the _original reported problem_ on a stand or locally
  composed stack. The fix must be **observed** fixing it, not inferred.

## 6. Gates, scaled to the diff

Security review the moment the fix touches auth, input handling, SQL, secrets or
PII — a five-minute read for a typo-level fix, a real review otherwise.

DevOps review if the fix carries a migration (it almost never should), a config
change, or a restart ordering. Is rollback still one command?

## 7. Hand-back

<!-- F-013 -->

```
Changed:      files touched, one line each
Ran:          the repro test, the suite, the adjacent flows, the original symptom
Not verified: what you could not exercise, explicitly
Skipped:      follow-ups consciously left
```

State the root cause in one sentence. "Fixed" without a cause is a symptom
patched.

<!-- F-007 -->

If this is the second time this class of bug appeared, that is a convention
nobody wrote down — record it per `practices/project-memory.md`.

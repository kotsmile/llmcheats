---
name: hotfix
description: "hotfix: production is broken right now. Use for a prompt starting hotfix:, an outage, a data-affecting failure, or a live security issue. Fast flow under time pressure, with the floor intact."
---

# `hotfix:` — fast flow, production is down

<!-- F-092 -->
Target: commit to production in **under 30 minutes** on a CI pipeline, **5–10
minutes** on a hand-rolled deploy. If this repo cannot do that, say so now — it
is a finding about the system, not about this fix.

## 1. Stop the bleeding first

Mitigation and root cause are different tasks. If a revert, a feature flag or a
scale-up restores service, do that **first** and fix properly afterwards.

<!-- F-047 -->
The fastest correct mitigation is usually reverting the commit that declared the
new state — see `workflows/rollback.md`.

## 2. Is this code or infra?

<!-- F-018 -->
Same question as `bug:`, and under time pressure it matters more, not less.
Recent deploys, saturation, dependency outages, certificate and quota expiry.

## 3. Fix

<!-- F-015 -->
The reproduction test is still written first. Urgency is not the exception —
the exception is about where the defect lives, never about how urgent the work
is.

<!-- F-016 -->
Smallest possible change. No refactor. No "while I was here".

<!-- F-012 -->
The floor in `practices/floor.md` does not move under time pressure. A hotfix
that hardcodes a secret, disables an authz check, or deletes a failing test is
not a hotfix — it is a second incident.

## 4. Ship and watch it land

<!-- F-046 -->
Verify the **artifact**, not the job. A green pipeline can leave production on
the old version: confirm the deploy commit landed and the running version
changed.

Then watch: error rate and the original symptom, for at least a few minutes. **A
hotfix that is not verified in production is a hypothesis.**

## 5. Afterwards, in the same session

<!-- F-072 -->
- A hotfix may be merged by its author after CI, with a post-factum review
  requested. The review still happens, after the fire.
- **Backport / forward-port**: make sure the fix is on the main branch, not only
  on the release branch. This is the step most often lost.
- Follow-up ticket for whatever was deferred.

## 6. Hand-back

<!-- F-013 -->
```
Changed:      files touched, one line each
Ran:          repro test, suite, and what production showed after rollout
Not verified: what you could not exercise, explicitly
Skipped:      the refactor, the doc, the broader fix — each named
```

<!-- F-060 -->
Commit as `hotfix: <scope> what it fixes`, one line.

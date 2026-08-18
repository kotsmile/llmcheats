---
title: Scaling the process down
summary: A two-person team runs the same flows with the ceremony collapsed — gates become deliberate second passes, design docs become ticket comments, and four things never collapse.
keywords: [small team, MVP, ceremony, one person several roles, second pass, design doc, ten-line comment, test stand, docker compose, what never collapses]
related:
  - devflow/principles.md
  - devflow/roles.md
  - devflow/full-flow.md
  - devflow/fast-flow.md
---

# Scaling the process down

A two-person team building an MVP runs the same flows with the ceremony
collapsed:

- One person holds several roles — the **gates become deliberate second passes**
  with the relevant checklist, not meetings, and not omissions.
- Design docs become ten-line ticket comments. Fine. The test is unchanged:
  could someone else implement/operate from what is written?
- The test stand may be a locally composed stack (`docker compose up`). Fine.
  What is not fine is releasing what was never run composed.

## What never collapses

- The never-skip list in `devflow/principles.md`.
- The fast flow's reproduction test (`devflow/fast-flow.md`).
- The release record.
- The rule that the documentation stage's updates
  (`devflow/full-flow.md`) tell the truth.

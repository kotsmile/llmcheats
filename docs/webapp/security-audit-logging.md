---
title: Audit logging
summary: For systems managing access, money or secrets the audit log is append-only by construction, records reads before disclosure, and stores what was touched rather than payload values.
keywords: [audit log, append-only, retention, audit reads, audit before disclosure, attribution, structural diff, POST for reads, SQL cap, device grant]
related:
  - webapp/security-authorization.md
  - webapp/security-secrets.md
  - webapp/frontend-data.md
  - webapp/backend-infrastructure.md
---

# Audit logging

For any system that manages access, money, or secrets.

## Making the audit log append-only

**Append-only by construction, not convention**: the repository type has no
update and no delete method. "An audit log with an update path is one whose
contents are an opinion."

Retention is a scheduled age-based DELETE at the ops layer, not a code path the
type exposes.

## Auditing reads before disclosure

- **Audit reads, not just writes** — for sensitive material the question is
  "who looked at this", far more often than "who changed it".
- **Audit before disclosure, and a failed audit write fails the action**: the
  audit row is written before the sensitive payload is fetched; a disclosure
  nobody can attribute is worse than one that did not happen.
- Model audited reads as POST so a page refresh does not replay them — the
  frontend side of this is in `webapp/frontend-data.md`.

## Recording what, not the payload

- Record **what** was touched (resource, keys, a structural diff of
  operations), never the payload values.
- Cap and filter audit feeds **in SQL** so the limit counts rows the caller
  actually receives.
- Prefer auth mechanisms that put a **person's** name in the log even for CLI
  access (device-grant tokens over shared bot credentials).

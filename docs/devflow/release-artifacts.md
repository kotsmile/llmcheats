---
title: Artifacts after every feature and release
summary: The definition of done includes the paper trail — nine documents with named owners, kept next to the code they describe.
keywords: [artifacts, definition of done, architecture docs, ADR, API docs, OpenAPI, devops instructions, infra info, runbook, project memory, security notes, README, release record]
related:
  - devflow/full-flow.md
  - devflow/project-memory.md
  - devflow/roles.md
---

# Artifacts after every feature and release

## The required artifacts

After each feature/release these must be current:

| Artifact | Owner | Contents |
|---|---|---|
| **Architecture docs** | developer/architect | domain map, layer decisions, ADRs for anything non-obvious ("why X" answered once, in writing) |
| **API docs** | developer | OpenAPI spec regenerated; changed endpoints described |
| **DevOps instructions** | devops | how to build, deploy, roll back, run migrations — each backed by a runnable script/job |
| **Infra info** | devops | what runs where, DNS, certs, secret map names, capacity notes |
| **Runbooks** | devops | per-alert: what it means, what to check, how to mitigate |
| **Project memory** | developer | `CLAUDE.md` / `AGENTS.md`: how to run it, the architecture the project actually follows and where it departs from `webapp/`, decisions with their reasons (`devflow/project-memory.md`) |
| **Security notes** | security auditor | data classification, authz model per surface, accepted risks with expiry dates |
| **READMEs** | developer | every touched component's README still tells the truth: what it is, how to run it, how to test it |
| **Release record** | devops | version, changelog entry, rollback command |

## Keeping docs next to the code

Keep docs next to the code they describe (per-directory READMEs, ADRs in the
repo), not in an external wiki that CI cannot see and reviews do not touch.

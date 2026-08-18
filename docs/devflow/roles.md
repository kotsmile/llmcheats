---
title: Roles and the agents that hold them
summary: Each flow role maps to a shipped agent definition; on a small team one person holds several hats and the gates still happen.
keywords: [roles, agents, project manager, product designer, architect, developer, AI engineer, security auditor, code reviewer, devops, orchestrator, asap, ownership]
related:
  - devflow/principles.md
  - devflow/full-flow.md
  - devflow/scaling-down.md
  - devflow/asap-flow.md
---

# Roles and the agents that hold them

Each role maps to an agent definition shipped with this repo (installed into
your tool's agent directory, e.g. `~/.claude/agents/`); on a small team one
person holds several hats — the *gates still happen*, they just happen faster
(`devflow/scaling-down.md`).

| Role | Agent | Owns |
|---|---|---|
| Project manager | `project-manager` | operator communication, tracking, delegated approvals, result validation |
| Product designer | `product-designer` | scope, UX, acceptance criteria, product review |
| Architect | `architecture-designer` | technical design, contracts, migration plans |
| Backend developer | `golang-developer` / `python-developer` | backend implementation + tests |
| Frontend developer | `react-developer` | SPA implementation + tests |
| AI engineer | `ai-engineer` | prompts, tool schemas, LLM evals, cost & AI safety (when the feature touches an LLM) |
| Security auditor | `security-auditor` | security design & implementation approval, security docs |
| Code reviewer | `code-reviewer` | code review of a finished diff — layers, contracts, schema compatibility, errors, tests |
| DevOps | `devops` | infra audit, releases, runbooks, observability |
| Orchestrator | `dev-team` | drives the flow end-to-end, holds the gates |
| Fullstack (asap) | `asap` | small urgent work end-to-end in one pass — every hat at once, under the floor in `devflow/asap-flow.md` and its escalation triggers |

## Where the code reviewer sits

`code-reviewer` is invoked by `/llmcheats:review`, not by one of the thirteen
stages in `devflow/full-flow.md`: it is the lens the flow does not hold, and
the whole review path when there was no flow.

Without that command — Codex, or any tool with no subagents — the lens is held
by the development stage's self-review of the diff, against the same list.

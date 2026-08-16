# llmcheats

Cheat sheets for LLM-driven software development: a distilled, production-tested
reference for **building web applications** (Go/Python backend + React SPA), the
**delivery process** around them, and a set of **agent definitions** that let an
LLM coding tool (Claude Code, Codex) act as a full development team following
that reference.

Everything here was extracted from real production systems — a multi-domain
product API, several internal consoles, and the SPAs on top of them — then
generalized. Nothing is theoretical; every pattern has shipped.

## What's inside

The two documents are readable directly: **[docs/WEBAPP_DOC.md](docs/WEBAPP_DOC.md)**
and **[docs/DEVFLOW.md](docs/DEVFLOW.md)**.

```
docs/
  WEBAPP_DOC.md      How to build: system shape, backend DDD (4 layers,
                     invariant entities, ports, transactions, errors, config),
                     React SPA (FSD, TanStack Query, Zustand, auth), testing,
                     security, performance, infrastructure, AI features, and
                     a new-application checklist.
  DEVFLOW.md         In what order: the full feature/migration flow with its
                     gates (scope → design → architecture → security & devops
                     audits → development → testing → docs → review → release),
                     the fast bug/hotfix flow, required artifacts, the
                     never-skip list (observability, secret handling, release
                     speed), and how to scale the process down.

agents/              Agent definitions (Claude Code subagent format —
                     markdown with YAML frontmatter):
  project-manager.md       operator-facing entry point: intake, tracking,
                           delegated approvals, result validation
  dev-team.md              orchestrator: runs the DEVFLOW end-to-end
  product-designer.md      scope, UX flows, acceptance criteria, product review
  architecture-designer.md implementation plans, API contracts, migration plans
  golang-developer.md      Go backend implementation + tests
  python-developer.md      Python backend implementation + tests
  react-developer.md       React SPA implementation + tests
  ai-engineer.md           prompts, tool schemas, LLM evals, cost, AI safety
  security-auditor.md      design & implementation security reviews
  devops.md                infra audits, releases, observability, runbooks

skills/
  webapp-guide/      A Claude Code skill that loads the docs on demand.

install.sh           Installer/updater for both tools (macOS/Linux).
```

## Install

```bash
git clone https://github.com/kotsmile/llmcheats && cd llmcheats

./install.sh                      # both tools, global
./install.sh claude               # Claude Code only
./install.sh codex                # Codex only
./install.sh --project ~/my-app   # into one project instead of globally
```

Re-run any time to update — installs are overwritten from the repo state.

Where things land (global mode):

| Tool | What | Where |
|---|---|---|
| Claude Code | agents | `~/.claude/agents/` |
| Claude Code | skill | `~/.claude/skills/webapp-guide/` |
| Claude Code | docs | `~/.claude/llmcheats/docs/` |
| Codex | docs | `~/.codex/llmcheats/docs/` |
| Codex | pointer | managed block in `~/.codex/AGENTS.md` |

Project mode uses `<project>/.claude/...` for Claude Code, and
`<project>/.llmcheats/docs` + a managed block in `<project>/AGENTS.md` for
Codex. The Codex block is delimited by `<!-- llmcheats:begin/end -->` markers
and is replaced in place on update — the rest of your `AGENTS.md` is untouched.

## Use

- **Claude Code**: ask for the team — *"use the project-manager agent to
  deliver &lt;feature&gt;"* (single point of contact) or *"use the dev-team
  agent"* (direct flow) — or invoke a specialist directly (*"have
  security-auditor review this diff"*). The `webapp-guide` skill surfaces the
  docs to any task that touches web-app work.
- **Codex**: the `AGENTS.md` block points the model at the docs; reference
  them explicitly for best results (*"follow WEBAPP_DOC.md §2 layering"*).
- **Humans**: the docs stand alone. `WEBAPP_DOC.md` §8 is the checklist for
  standing up a new app (its Security block doubles as a review checklist);
  `DEVFLOW.md` §5 is a usable hotfix protocol.

## Goal

LLMs write better systems when the architecture, the process, and the
checklists are explicit, opinionated, and grounded in code that actually runs
in production. This repo is that grounding, packaged to be dropped into any
project: one document for *how to build*, one for *in what order and with
which gates*, and agents that enforce both.

The opinions are deliberate (raw SQL over ORMs, hand-written fakes over mock
frameworks, cookie sessions over localStorage tokens, runtime-agnostic infra).
Deviate where your context demands it — with a written reason, which is itself
one of the rules.

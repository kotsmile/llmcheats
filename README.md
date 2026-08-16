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

Start at **[docs/INDEX.md](docs/INDEX.md)** — it maps every file to what is in
it, for humans and agents alike.

```
docs/
  INDEX.md           Routing table: which file answers which question.
  webapp/            How to build, one file per topic:
                     system shape; backend DDD (four layers, invariant
                     entities, ports, transactions) split into domain and
                     transport halves plus a Python mapping; React SPA (FSD,
                     TanStack Query, Zustand, auth); testing; security;
                     performance; infrastructure; AI features; and a
                     new-application checklist.
  devflow/           In what order: the full feature/migration flow with its
                     gates (scope → design → architecture → security & devops
                     audits → development → testing → docs → review → release),
                     the fast bug/hotfix flow, the asap one-pass flow, required
                     artifacts, the never-skip list (observability, secret
                     handling, release speed), git rules, and how to scale the
                     process down.

agents/              Agent definitions (Claude Code subagent format —
                     markdown with YAML frontmatter):
  project-manager.md       operator-facing entry point: intake, tracking,
                           delegated approvals, result validation
  dev-team.md              orchestrator: runs the DEVFLOW end-to-end
  asap.md                  one agent, whole task, now — small urgent work
                           without orchestration or gate rounds
  product-designer.md      scope, UX flows, acceptance criteria, product review
  architecture-designer.md implementation plans, API contracts, migration plans
  golang-developer.md      Go backend implementation + tests
  python-developer.md      Python backend implementation + tests
  react-developer.md       React SPA implementation + tests
  ai-engineer.md           prompts, tool schemas, LLM evals, cost, AI safety
  security-auditor.md      design & implementation security reviews
  devops.md                infra audits, releases, observability, runbooks

commands/            Claude Code slash commands:
  pm.md              /pm         deliver through the full team (gated flow)
  asap.md            /asap       deliver now via the asap agent (one pass)
  status.md          /status     tasks, agents in flight, estimate, session
  llmcheats.md       /llmcheats  work on this repo under its own conventions

skills/
  webapp-guide/      A Claude Code skill that routes to the right doc file.

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
| Claude Code | commands | `~/.claude/commands/` |
| Claude Code | skill | `~/.claude/skills/webapp-guide/` |
| Claude Code | docs | `~/.claude/llmcheats/docs/` |
| Codex | docs | `~/.codex/llmcheats/docs/` |
| Codex | pointer | managed block in `~/.codex/AGENTS.md` |

Project mode uses `<project>/.claude/...` for Claude Code, and
`<project>/.llmcheats/docs` + a managed block in `<project>/AGENTS.md` for
Codex. The Codex block is delimited by `<!-- llmcheats:begin/end -->` markers
and is replaced in place on update — the rest of your `AGENTS.md` is untouched.

## Use

- **Claude Code**: the commands are the front door —

  ```
  /pm     add order cancellation to the API     # full team, gates, tracking
  /asap   add a --dry-run flag to deploy.sh     # one agent, one pass, now
  /status                                       # where the work stands
  ```

  Or ask by agent name: *"use the project-manager agent to deliver
  &lt;feature&gt;"* (single point of contact), *"use the dev-team agent"*
  (direct flow), or a specialist directly (*"have security-auditor review this
  diff"*). The `webapp-guide` skill surfaces the docs to any task that touches
  web-app work.

  Slash commands are read at startup — **restart Claude Code after installing**
  or they will not appear in the `/` menu.
- **Codex**: the `AGENTS.md` block points the model at the docs; reference
  a file explicitly for best results (*"follow `webapp/2a-backend-layers.md`"*).
- **Humans**: the docs stand alone — read them from
  [docs/INDEX.md](docs/INDEX.md). `webapp/8-checklist.md` is the checklist for
  standing up a new app (its Security block doubles as a review checklist);
  `devflow/3-fast-flow.md` is a usable hotfix protocol.

## Token budget

`Read` loads whole files, so a monolithic reference costs its full size every
time any agent consults it — and a full flow consults it from a dozen fresh
contexts. The docs are therefore split per topic, and each agent names the one
or two files it needs rather than the tree. A full-flow feature run pulls
roughly 145KB of reference instead of 955KB.

If you add to the docs, keep it that way:

- One topic per file; split anything past ~15KB.
- List every new file in `docs/INDEX.md` with a "read it when" line.
- Point agents at **files**, never at the tree or at `INDEX.md` when the file
  is already known.
- Cross-reference by filename (`webapp/5-security.md`), not by section number
  alone — a bare "§5" gives an agent nothing to open.

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

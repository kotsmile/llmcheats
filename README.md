# llmcheats

Cheat sheets for LLM-driven software development: a distilled, production-tested
reference for **building web applications** (Go/Python backend + React SPA), the
**delivery process** around them, and **agent definitions** that let Claude Code
or Codex act as a full development team following that reference.

Everything here was extracted from real production systems, then generalized.
Nothing is theoretical; every pattern has shipped.

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/kotsmile/llmcheats/main/get.sh | bash
```

Installs into the current directory as a project. For `~/.claude` and `~/.codex`:

```bash
curl -fsSL https://raw.githubusercontent.com/kotsmile/llmcheats/main/get.sh | bash -s -- --global
```

Re-run either to update. **Nothing of yours is overwritten**: a same-named file
llmcheats did not install is copied to `.bak-llmcheats` first, uninstall keeps
anything you edited, and your `AGENTS.md` keeps everything outside its managed
block.

Or clone it and drive the script yourself:

```bash
git clone https://github.com/kotsmile/llmcheats && cd llmcheats
./install.sh                      # both tools, global
./install.sh claude               # Claude Code only
./install.sh --project ~/my-app   # one project instead of globally
./install.sh update               # pull, then reinstall
./install.sh uninstall
```

`./update.sh` updates every install on the machine at once — it finds them by
the `SOURCE.md` each one leaves beside its docs.

| Tool | What | Where (global) |
|---|---|---|
| Claude Code | agents | `~/.claude/agents/` |
| Claude Code | commands | `~/.claude/commands/llmcheats/` |
| Claude Code | skill | `~/.claude/skills/webapp-guide/` |
| Claude Code | docs | `~/.claude/llmcheats/docs/` |
| Codex | docs | `~/.codex/llmcheats/docs/` |
| Codex | pointer | managed block in `~/.codex/AGENTS.md` |

Project mode uses `<project>/.claude/...`, and `<project>/.llmcheats/docs` plus
a managed block in `<project>/AGENTS.md` for Codex.

**Restart Claude Code after installing** — slash commands are read at startup.

## Use

```
/llmcheats:pm      add order cancellation to the API   # full team, gates
/llmcheats:asap    add a --dry-run flag to deploy.sh   # one agent, one pass
/llmcheats:status                                      # where the work stands
/llmcheats:agents  security-auditor                    # what one agent did
```

`/llmcheats:pm` makes the session itself the project manager — it holds intake,
the gates and validation, and launches every specialist directly, so the
running-agent indicator names `golang-developer` instead of collapsing it into a
`(+N)` under an orchestrator.

Or ask by agent name: *"use the project-manager agent to deliver &lt;feature&gt;"*,
*"use the dev-team agent"*, or a specialist directly (*"have security-auditor
review this diff"*).

**Codex** gets the docs and an `AGENTS.md` pointer, not the agents or commands —
reference a file explicitly (*"follow `webapp/2a-backend-layers.md`"*).

What happens to your next prompt:

```
/llmcheats:pm add order cancellation
      ↓  intake: goal and constraints restated in two sentences
      ↓  flow chosen by what the change triggers — auth? migration?
         a published contract? product surface? — not by how big it sounds
      ↓  exactly one flow file read: the full flow, the fast one, or asap
      ↓  one specialist per stage, each reading the one or two doc files it needs
      ↓  gates: security and devops approve the design, then the implementation
      ↓  verification, then a hand-back that names what was NOT verified
/llmcheats:status        where it stands, any time
/llmcheats:agents <name> what one specialist actually did
```

A change that triggers nothing runs as one pass in one context; the gates it
does trigger are compressed, never dropped.

**Humans**: the docs stand alone. Start at
**[docs/INDEX.md](docs/INDEX.md)** — it maps every file to what is in it.
`webapp/8-checklist.md` stands up a new app; `devflow/3-fast-flow.md` is a
usable hotfix protocol.

## What's inside

```
docs/
  INDEX.md      Routing table: which file answers which question.
  webapp/       How to build: system shape; backend DDD (four layers, ports,
                transactions) in domain and transport halves plus a Python
                mapping; React SPA (FSD, TanStack Query, Zustand, auth);
                testing; security; performance; infra; AI features; checklist.
  devflow/      In what order: the full flow and its gates (scope → design →
                architecture → security & devops audits → development →
                testing → docs → review → release), the fast bug/hotfix flow,
                the asap one-pass flow, the never-skip list, git rules, how to
                keep a run visible, how to resume one, and what a pass and a
                whole flow cost.

agents/         project-manager, dev-team, asap, product-designer,
                architecture-designer, golang-developer, python-developer,
                react-developer, ai-engineer, security-auditor, devops
commands/       /llmcheats:pm, :asap, :status, :agents
skills/         webapp-guide — routes any web-app task to the right doc file
get.sh          one-liner installer (clone-or-update, then install)
install.sh      install / update / uninstall, both tools, global or project
update.sh       update every install on the machine
```

`docs/`, `agents/`, `commands/` and `skills/` are the payload. `.claude/` is
this repo's own maintenance tooling — a `llmcheats` agent plus nine checkers
(invariants, contradictions, drift, tool support, cost, install round trip,
routing, sources, observability) — and is never installed anywhere.

## Token budget

`Read` loads whole files, so a monolithic reference costs its full size every
time any agent consults it — and a full flow consults it from a dozen fresh
contexts. The docs are split per topic, and each agent names the one or two
files it needs rather than the tree. A full-flow feature run pulls roughly
145KB of reference instead of 955KB.

If you add to the docs, keep it that way:

- One topic per file; split anything past ~15KB.
- List every new file in `docs/INDEX.md` with a "read it when" line.
- Point agents at **files**, never at the tree or at `INDEX.md`.
- Cross-reference by filename (`webapp/5-security.md`) — a bare "§5" gives an
  agent nothing to open.

The reference is only half the bill; the other half is how many contexts a run
opens at all — the full flow is 13, the fast flow seven, the asap flow one.
`devflow/10-flow-cost.md` covers that half: pick the cheapest flow that clears
the gates the change actually triggers, tier the model per stage rather than per
agent, and keep hand-backs to verdicts and paths. The two orchestrators ship
pinned to a cheaper model; every specialist leaves `model` unset and inherits
your choice.

## Goal

LLMs write better systems when the architecture, the process, and the checklists
are explicit, opinionated, and grounded in code that actually runs in
production. One document for *how to build*, one for *in what order and with
which gates*, and agents that enforce both.

The opinions are deliberate, and each carries its reason and its cost where it is
stated. Some are *patterns* — raw SQL over ORMs, hand-written fakes over mock
frameworks, runtime-agnostic infra — so deviate where your context demands it and
keep your own architecture if you have one. Others are *constraints*, and those
do not move: every dynamic value bound into the SQL, input validated at the
boundary, secrets out of the code, no session token in JS-readable storage.
Deviating from one of those is what owes a written reason.

MIT.

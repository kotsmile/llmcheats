# llmcheats

A production-tested reference for **building web applications** (Go/Python
backend + React SPA), the **delivery process** around them, and **agents** that
make Claude Code or Codex act as a development team following both.

Everything here was extracted from real production systems.

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/kotsmile/llmcheats/main/get.sh | bash
```

Installs into the current directory as a project; add `-s -- --global` for
`~/.claude` and `~/.codex`. Re-run to update, or `./update.sh` for every install
on the machine. **Restart Claude Code afterwards** — slash commands are read at
startup.

Nothing of yours is overwritten: a same-named file llmcheats did not install is
backed up to `.bak-llmcheats`, uninstall keeps anything you edited, and your
`AGENTS.md` keeps everything outside its managed block.

Claude Code gets agents, commands, the skill and the docs; Codex gets the docs
plus a pointer block in `AGENTS.md` — there, reference a file explicitly
(*"follow `webapp/2a-backend-layers.md`"*).

## How to use it

```
/llmcheats:pm      add order cancellation to the API   # full team, gated stages
/llmcheats:artifacts                                   # write CLAUDE.md / AGENTS.md
/llmcheats:asap    add a --dry-run flag to deploy.sh   # one agent, one pass
/llmcheats:review  HEAD~3..HEAD                        # code + security verdict
/llmcheats:status                                      # where the work stands
/llmcheats:agents  security-auditor                    # what one agent did
```

**The point of the first run is the artifacts it leaves behind.** `/llmcheats:pm`
is the expensive one — hours, up to 13 stages, skip gates closing the ones your
change does not reach. It leaves plans under `docs/plans/`, docs beside the code,
and the conventions in `CLAUDE.md` / `AGENTS.md`. After that, plain prompts land
correctly with no flow around them; call `/llmcheats:review` once a feature is
done rather than after every commit.

Or ask by name: *"use the dev-team agent"*, *"have security-auditor review this
diff"*.

## What's inside

```
docs/webapp/    How to build: system shape, backend DDD in Go and Python,
                React SPA, testing, security, performance, infra, AI features.
docs/devflow/   In what order: full flow and its gates, fast bug flow, asap
                flow, git rules, run visibility, cost, project memory.
agents/         project-manager, dev-team, asap, product-designer,
                architecture-designer, golang-developer, python-developer,
                react-developer, ai-engineer, security-auditor, code-reviewer,
                devops
commands/       /llmcheats:pm, :artifacts, :asap, :review, :status, :agents
skills/         webapp-guide — routes any web-app task to the right doc file
```

**Reading it as a human**: start at **[docs/INDEX.md](docs/INDEX.md)**.
`webapp/8-checklist.md` stands up a new app; `devflow/3-fast-flow.md` is a usable
hotfix protocol.

**Patterns vs constraints.** Most opinions here are *patterns* — raw SQL over
ORMs, hand-written fakes over mock frameworks — so keep your own architecture if
you have one. A few are *constraints* and do not move: every dynamic value bound
into the SQL, input validated at the boundary, secrets out of the code, no
session token in JS-readable storage. Deviating from one owes a written reason.

MIT.

# llmcheats

A production-tested reference for **building web applications** (Go/Python
backend + React SPA), the **delivery process** around them, and **agents** that
make Claude Code or Codex act as a development team following both.

Everything here was extracted from real production systems. Nothing is
theoretical; every pattern has shipped.

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/kotsmile/llmcheats/main/get.sh | bash
```

Installs into the current directory as a project. Add `-s -- --global` for
`~/.claude` and `~/.codex`. Re-run either to update; `./update.sh` updates every
install on the machine at once.

**Nothing of yours is overwritten**: a same-named file llmcheats did not install
is backed up to `.bak-llmcheats` first, uninstall keeps anything you edited, and
your `AGENTS.md` keeps everything outside its managed block.

Clone it to drive the script yourself — `./install.sh claude`,
`./install.sh --project ~/my-app`, `./install.sh update`,
`./install.sh uninstall`.

**Restart Claude Code after installing** — slash commands are read at startup.

Claude Code gets agents, commands, the skill and the docs under
`~/.claude/`; Codex gets the docs under `~/.codex/llmcheats/docs/` plus a managed
pointer block in `AGENTS.md`. Project mode uses `<project>/.claude/...` and
`<project>/.llmcheats/docs`.

## How to use it

**The point of the first run is the artifacts it leaves behind.** A full
`/llmcheats:pm` pass writes code, plan files, docs, and a `CLAUDE.md` /
`AGENTS.md` into the repo — and those are what let every later plain prompt land
correctly without a flow around it.

What that buys, and what it is deliberately not:

- **Less planning before development.** Planning stages exist to tell a developer
  what the system's patterns are. Once the artifacts say that, the skip gates
  close those stages instead of repeating them.
- **Architecture enforced while the code is written**, not proved in advance — by
  the reference the developer reads and the conventions in `CLAUDE.md`.
- **Review at feature size.** One review of a finished feature, not a review per
  commit: layering and contract consumers are invisible in a three-line diff, and
  each review costs two fresh contexts.

1. **Install it in the project** (above).
2. **Ask `/llmcheats:pm` for the module, service or app.** This is the expensive
   run — hours and many tokens, up to 13 gated stages. It leaves plans under
   `docs/plans/`, docs beside the code, an implementation that follows the
   reference, and the conventions and decisions written into `CLAUDE.md` /
   `AGENTS.md`, which both tools load unprompted from then on
   (`devflow/11-project-memory.md`).
   - `--full` forces the full flow instead of letting it pick one.
   - Either way the **skip gates** close the stages this change does not reach,
     each with a printed reason, so forcing the flow buys the gates rather than
     thirteen contexts of ceremony (`devflow/2-full-flow.md` §3.14).
3. **Run `/llmcheats:artifacts`.** It writes the memory artifacts — `CLAUDE.md`
   plus the Codex `AGENTS.md` analogue — holding the architecture and devops
   decisions, the review rules, the deploy and development patterns, what the
   project is, and the rule for keeping that file current. Both tools load it
   unprompted from then on (`devflow/11-project-memory.md`).
4. **Then just type normal prompts.** The assistant starts from those artifacts —
   no command, no ceremony. When a prompt settles a new convention, it goes into
   the artifact, which is what keeps the next one from needing a flow either.
5. **Call `/llmcheats:review` when a feature is done.** Code/architecture and
   security review in parallel, aggregated into one verdict. Batch the work and
   review once rather than after every commit.

```
/llmcheats:pm      add order cancellation to the API   # full team, gates
/llmcheats:pm --full  build the billing module         # force all 13 stages
/llmcheats:artifacts                                   # write CLAUDE.md / AGENTS.md
/llmcheats:asap    add a --dry-run flag to deploy.sh   # one agent, one pass
/llmcheats:review  HEAD~3..HEAD                        # code + security verdict
/llmcheats:status                                      # where the work stands
/llmcheats:agents  security-auditor                    # what one agent did
```

`/llmcheats:pm` makes the session itself the project manager — it holds intake,
the gates and validation, and launches every specialist directly, so the
running-agent indicator names `golang-developer` instead of collapsing it into a
`(+N)`.

Or ask by agent name: *"use the dev-team agent"*, or a specialist directly
(*"have security-auditor review this diff"*).

**Codex** gets the docs and an `AGENTS.md` pointer, not the agents or commands —
reference a file explicitly (*"follow `webapp/2a-backend-layers.md`"*).

## What's inside

```
docs/webapp/    How to build: system shape, backend DDD (four layers, ports,
                transactions) in Go and Python, React SPA (FSD, TanStack Query),
                testing, security, performance, infra, AI features, checklist.
docs/devflow/   In what order: the full flow with its gates and per-stage skip
                gates, the fast bug flow, the one-pass asap flow, the never-skip
                list, git rules, keeping a run visible, resuming one, what a flow
                costs, and what to write into CLAUDE.md / AGENTS.md.
agents/         project-manager, dev-team, asap, product-designer,
                architecture-designer, golang-developer, python-developer,
                react-developer, ai-engineer, security-auditor, code-reviewer,
                devops
commands/       /llmcheats:pm, :artifacts, :asap, :review, :status, :agents
skills/         webapp-guide — routes any web-app task to the right doc file
```

**Reading the docs as a human**: start at **[docs/INDEX.md](docs/INDEX.md)** — it
maps every file to what is in it. `webapp/8-checklist.md` stands up a new app;
`devflow/3-fast-flow.md` is a usable hotfix protocol.

## Two things to know

**Tokens.** `Read` loads whole files, so the docs are split per topic and each
agent names only the files it needs — a full-flow run pulls roughly 145KB of
reference instead of 955KB. Adding a doc: one topic per file, split past ~15KB, a
row in `docs/INDEX.md`, and cross-reference by filename. What a whole run costs
is `devflow/10-flow-cost.md`.

**Patterns vs constraints.** Most opinions here are *patterns* — raw SQL over
ORMs, hand-written fakes over mock frameworks — so keep your own architecture if
you have one. A few are *constraints* and they do not move: every dynamic value
bound into the SQL, input validated at the boundary, secrets out of the code, no
session token in JS-readable storage. Deviating from one of those owes a written
reason.

MIT.

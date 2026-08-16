---
name: webapp-guide
description: Reference guide for building production web applications (Go/Python backend + React SPA) and the development flow around them. Use when designing, implementing, reviewing, or operating a web application — architecture (DDD layers, FSD frontend), testing, security, performance, infrastructure, or the feature/hotfix delivery process.
---

# Web application guide

The reference is split into per-topic files so you load only what the task
needs. Find the docs directory — first one that exists:

1. `<project>/.claude/llmcheats/docs/`
2. `~/.claude/llmcheats/docs/`
3. `~/.codex/llmcheats/docs/`

If none exist, say so explicitly and proceed on general best practice — do not
invent the documents' contents.

## How to use

Read `INDEX.md` from that directory. It is a routing table: one row per file
saying what is in it and when to read it. Pick the one or two files your task
actually needs and read only those — `webapp/` for how to build, `devflow/`
for the process and its gates.

Do not read the whole tree. If you already know the topic maps to a specific
file (e.g. a React screen → `webapp/3-frontend.md`, a hotfix →
`devflow/3-fast-flow.md`), read that file directly and skip `INDEX.md`.

Read before acting — don't work from memory of the guide. Deviations are
allowed with a written reason; silent deviations are not.

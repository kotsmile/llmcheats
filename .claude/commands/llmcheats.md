---
description: Work on the llmcheats repo itself — conventions, per-change checklists, and the install contract
argument-hint: <what to change>
---

Change something in **llmcheats** itself: the reference (`docs/`), the agents it
ships (`agents/`), the slash commands (`commands/`), the skill (`skills/`),
`install.sh`, or the `README.md`.

**Task:** $ARGUMENTS

1. If the task is empty, ask what to change — one sentence — and stop.
2. Launch the `llmcheats` agent (Task tool, `subagent_type: llmcheats`) with the
   task **verbatim**. It holds the invariants, the per-change checklists and the
   install contract; do not restate them here and do not open `docs/` on its
   behalf.
3. If it reports the working directory is not the llmcheats repo, relay that in
   one sentence and stop. Do not retarget the change at whatever repo is open.
4. Report exactly what it hands back: files changed, which invariants the change
   had to satisfy, what was actually run, and **what was not verified**. Do not
   upgrade "not verified" into "works".

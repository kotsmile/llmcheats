---
description: Work on the llmcheats repo itself — conventions, per-change checklists, and the install contract
argument-hint: <what to change | check | what a run did>
---

Change or verify something in **llmcheats** itself: the reference (`docs/`), the
agents it ships (`agents/`), the slash commands (`commands/`), the skill
(`skills/`), `install.sh`, or the `README.md`.

**Task:** $ARGUMENTS

1. If the task is empty, ask what to change — one sentence — and stop.
2. Launch the `llmcheats` agent (Task tool, `subagent_type: llmcheats`) with the
   task **verbatim**. It holds the invariants, the per-change checklists, the
   install contract, and the maintenance flow — it decides which path the task
   is (change, check, or observe) and which of its six specialists to open. Do
   not restate any of that here, do not pick the path for it, and do not open
   `docs/` on its behalf.
3. If it reports the working directory is not the llmcheats repo, relay that in
   one sentence and stop. Do not retarget the change at whatever repo is open.
4. Report exactly what it hands back: files changed, which invariants the change
   had to satisfy, which specialists ran and their verdicts, which were skipped,
   what was actually run, and **what was not verified**. Quote a verdict as
   written and do not upgrade "not verified" into "works".

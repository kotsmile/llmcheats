---
description: Status of the current work — tasks, agents in flight, finish estimate, and session time/tokens/commits
argument-hint: (no arguments)
---

Report where the current work stands. This is the operator's window into a
running llmcheats `/pm` flow, so it reports **observed state only** — never a
guess dressed as a fact.

## 1. Collect

Run all three, then compose. Do not skip a source because you think you know
its answer.

**Tasks** — call the `TaskList` tool. If the tool is unavailable or the list is
empty, fall back to the todo/plan state in this conversation and label it
"from conversation, not tracked".

**Session, agents, git** — run this once:

```bash
dir="$HOME/.claude/projects/$(pwd | sed 's/[\/.]/-/g')"
f="$(ls -t "$dir"/*.jsonl 2>/dev/null | head -1)"
start=""
if [ -z "${f:-}" ] || ! command -v jq >/dev/null 2>&1; then
  echo "SESSION unavailable (no transcript under $dir, or jq missing)"
else
  n="$(ls -t "$dir"/*.jsonl 2>/dev/null | wc -l | tr -d ' ')"
  echo "SESSION $(basename "$f") — newest of $n transcript(s) for this cwd"
  jq -rs '
    (map(select(.timestamp)) | sort_by(.timestamp)) as $e
    | [ $e[] | select(.message.usage) | .message.usage ] as $u
    | [ $e[] | select(.message.content? | type=="array") | .message.content[] ] as $c
    | "start\t\($e[0].timestamp)",
      "last\t\($e[-1].timestamp)",
      "model\t\([ $e[] | .message.model // empty ] | last // "?")",
      "turns\t\([ $e[] | select(.type=="assistant") ] | length)",
      "toolcalls\t\([ $c[] | select(.type=="tool_use") ] | length)",
      "tok_in\t\($u | map(.input_tokens // 0) | add // 0)",
      "tok_out\t\($u | map(.output_tokens // 0) | add // 0)",
      "cache_write\t\($u | map(.cache_creation_input_tokens // 0) | add // 0)",
      "cache_read\t\($u | map(.cache_read_input_tokens // 0) | add // 0)"
  ' "$f"
  start="$(jq -rs 'map(select(.timestamp))|sort_by(.timestamp)|.[0].timestamp' "$f")"
  echo "AGENTS"
  jq -rs '
    [ .[] | select(.message.content? | type=="array") | .message.content[] ] as $c
    | ([ $c[] | select(.type=="tool_result") | .tool_use_id ] | unique) as $done
    | [ $c[] | select(.type=="tool_use" and (.name=="Task" or .name=="Agent")) ] as $t
    | if ($t|length)==0 then "  none launched in this transcript"
      else $t[] | "  \(if ([.id] - $done | length)==0 then "returned" else "RUNNING " end)  \(.input.subagent_type // "?")  —  \(.input.description // "-")"
      end
  ' "$f"
fi
echo "GIT $(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo 'not a repo')"
if git rev-parse --git-dir >/dev/null 2>&1; then
  if [ -n "$start" ]; then
    c="$(git log --since="$start" --oneline 2>/dev/null)"
    [ -n "$c" ] && echo "$c" | sed 's/^/  /' || echo "  no commits since session start"
  fi
  echo "  uncommitted: $(git status --porcelain 2>/dev/null | wc -l | tr -d ' ') file(s)"
fi
```

The script reports the **newest transcript for this working directory**. When
it says "newest of N", N > 1 means other sessions exist for this project — say
so, because the numbers could belong to a different window.

## 2. Report

```
<one sentence: what is being worked on and whether it is on track>

TASKS        3/7 done
  [x] 1  <subject>
  [x] 2  <subject>
  [>] 3  <subject>            <- in progress, owner
  [ ] 4  <subject>            (blocked by 3)
  ...

AGENTS
  RUNNING   dev-team          architecture stage, ~6 min in
  returned  security-auditor  APPROVED_WITH_FINDINGS (2 MINOR)
  idle      devops            not yet engaged

ESTIMATE     ~N min to finish  (basis: <what you derived it from>)
             blockers: <what would move it, or "none">

SESSION      42 min   |  turns 44, tool calls 25
TOKENS       out 61.2k  |  in 83  |  cache write 173.8k, read 2.75M
GIT          main  |  2 commits this session  |  3 files uncommitted
  a1b2c3d  <subject>
```

Rules for composing it:

- **Task status comes from `TaskList`, not from your memory of what you did.**
  A task is done when it is marked done, not when you believe it is.
- **For each agent, say what it is doing, not just that it runs.** Combine the
  script's RUNNING/returned lines with what the agent last reported in this
  conversation. An agent that returned gets its verdict; a gate verdict is
  quoted as-is (`APPROVED` / `APPROVED_WITH_FINDINGS` / `BLOCKED`), never
  paraphrased into something softer.
- **The estimate must name its basis** — e.g. "4 of 7 tasks done in 40 min, 3
  remain of similar size". If there is no basis, write `ESTIMATE unknown` and
  say what would make it knowable. Never produce a number you cannot derive.
- **Elapsed time** is `last − start` from the script: that is wall-clock across
  the session including idle time, not time spent computing. Say "elapsed", not
  "worked".
- **Tokens are this transcript's totals.** For authoritative billing and the
  live context window, point the operator at the built-in `/cost` and
  `/context` — this command reads the log, those read the meter.
- Anything a source could not answer is printed as `unknown`. Empty output is
  a finding, not something to fill in from context.

Keep the summary line to one or two sentences. The table is the detail.

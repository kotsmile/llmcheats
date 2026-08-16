---
description: Status of the current work — tasks, agents in flight, finish estimate, and session time/tokens/commits
argument-hint: (no arguments)
---

Report where the current work stands. This is the operator's window into a
running llmcheats `/llmcheats:pm` flow, so it reports **observed state only**
— never a guess dressed as a fact.

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
  sub="${f%.jsonl}/subagents"
  if [ ! -d "$sub" ]; then
    echo "AGENTS  no subagents/ dir — none launched in this session"
  else
    echo "AGENTS  $(ls "$sub"/*.meta.json 2>/dev/null | wc -l | tr -d ' ') total, from sidecar transcripts"
    for m in "$sub"/*.meta.json; do
      id="$(basename "$m" .meta.json)"; j="$sub/$id.jsonl"
      [ -f "$j" ] || continue
      jq -rs --slurpfile M "$m" --arg id "${id#agent-}" '
        def ep: sub("\\.[0-9]+Z$";"Z") | fromdateiso8601;
        (map(select(.timestamp)) | sort_by(.timestamp)) as $e
        | ($e[-1]) as $L
        | ([ $e[] | select(.message.content? | type=="array")
             | .message.content[] | select(.type=="tool_use") ] | last) as $tc
        | ([ $L.message.content[]? | select(.type=="text") | .text ] | join(" ")) as $txt
        | [ ($M[0].spawnDepth // 1),
            $id[0:8],
            ($M[0].agentType // "?"),
            ($M[0].description // "-"),
            (if ($M[0].stoppedByUser // false)
                or ($txt | test("\\[Request interrupted")) then "STOP"
             elif $L.type=="assistant"
                and ([ $L.message.content[]? | select(.type=="tool_use") ] | length)==0
             then "done" else "RUN" end),
            (((now - ($L.timestamp | ep)) / 60) | floor),
            ($tc.name // "-"),
            ($txt | gsub("[*#\n]"; " ") | gsub("  +"; " ") | sub("^ +"; "") | .[0:70])
          ] | @tsv' "$j"
    done | sort -t"$(printf '\t')" -k1,1n -k6,6nr | awk -F'\t' '
      { ind = ""; for (i = 1; i < $1; i++) ind = ind "   "
        printf "%s  %-4s %-9s %-20s %-28s idle %sm  last:%s\n",
               ind, $5, $2, $3, substr($4,1,28), $6, $7
        if ($8 != "") printf "%s       > %s\n", ind, $8
        seen[$3]++ }
      END { for (a in seen) if (seen[a] >= 3)
              printf "  ! %s ran %d times — gate loop, or parallel fan-out; compare their descriptions\n", a, seen[a] }'
  fi
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

Agent state comes from `<transcript>/subagents/`, where every agent — including
ones nested three levels deep — writes a live `agent-<id>.jsonl` and an
`agent-<id>.meta.json`. That is the only honest source: the main transcript's
tool results say nothing about a background agent beyond "launched". Indentation
is `spawnDepth`, not parentage; the second column is the agent id — pass it to
`/llmcheats:agents`, which reads `parentAgentId` and attributes children when
two orchestrators run at the same depth.

## 2. Report

```
<one sentence: what is being worked on and whether it is on track>

TASKS        3/7 done
  [x] 1  <subject>
  [x] 2  <subject>
  [>] 3  <subject>            <- in progress, owner
  [ ] 4  <subject>            (blocked by 3)
  ...

AGENTS       17 total, 3 deep
  done  a1b2c3d4  project-manager   Finish backend migration   idle 12m  last:Agent
        > Summary: Phase 3 landed green   <- FINISHED, NEVER REPORTED
     RUN   e5f6a7b8  dev-team        Phase 4 supply service    idle 11m  last:Agent
        done  9c8d7e6f  security-auditor  Security re-gate 2   idle 14m  last:Bash
              > VERDICT: BLOCKED One MAJOR: amendment A1 …
        RUN   1a2b3c4d  architecture-designer  Phase 4 plan    idle 0m   last:Bash
        STOP  5e6f7a8b  golang-developer  Phase 4 handlers     idle 22m  last:Edit
  ! security-auditor ran 3 times — gate loop, or parallel fan-out

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
- **An agent that is `done` but never reported in this conversation is the
  first thing you say.** Its `>` line is the hand-back it wrote and nobody
  read; quote it and pull the rest of that transcript before anything else.
  Work stalled behind an undelivered report is the most common cause of a flow
  that looks frozen.
- **`RUN` is not "working" — report the idle minutes.** Under 5m, it is
  progressing; past that, say "idle Nm inside `<last tool>`" and let the
  operator judge. Never smooth a long idle into "in progress".
- **`STOP` means the operator stopped that agent** — `stoppedByUser` in its
  sidecar, or an interrupt as its last event. Nothing will resume it: say what
  stage it was in and whether it needs relaunching, and never report it as
  running. **A `STOP` line with a `>` under it still finished something** — an
  agent that handed back, was resumed, then stopped keeps its hand-back, and
  that hand-back is unread until you say otherwise. Read it before concluding
  the stage was lost.
- **A repeated `agentType` is a gate loop *or* parallel fan-out** — the `!`
  line only counts, it cannot tell them apart. Read the three descriptions
  before you call it: same stage repeated means the two-round escalation bound
  in `dev-team.md` was passed without an escalation, and that is a finding with
  each round's verdict; three different task descriptions is one specialist
  used three times, which is normal. Never report the count as a loop
  unchecked.
- **Never call an agent "returned" on the strength of a tool result.** A
  background agent's result arrives in seconds and means "launched". Only the
  sidecar transcript says whether it finished.
- Gate verdicts are quoted as-is (`APPROVED` / `APPROVED_WITH_FINDINGS` /
  `BLOCKED`), never paraphrased into something softer.
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

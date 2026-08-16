---
description: Deep-dive one agent — its full tool-by-tool timeline and hand-back; with no argument, the whole agent tree
argument-hint: <agent name, id prefix, or part of its description — blank for the tree>
---

Show what an agent in this llmcheats session actually did.
`/llmcheats:status` says which agents exist and whether they moved; this says
**what they did, step by step**. Use it when `/llmcheats:status` shows an agent
idle, finished-but-unreported, or looping.

**Agent:** $ARGUMENTS

Every agent, including ones nested three levels deep, writes a live
`agent-<id>.jsonl` and an `agent-<id>.meta.json` under
`<transcript>/subagents/`. That is the only source here — the main transcript
knows nothing about a background agent beyond the fact that it was launched.

## 1. Collect

```bash
q="$(printf '%s' "$ARGUMENTS" | tr 'A-Z' 'a-z' | sed 's/^ *//;s/ *$//')"
dir="$HOME/.claude/projects/$(pwd | sed 's/[\/.]/-/g')"
f="$(ls -t "$dir"/*.jsonl 2>/dev/null | head -1)"
sub="${f%.jsonl}/subagents"
if [ -z "${f:-}" ] || [ ! -d "$sub" ] || ! command -v jq >/dev/null 2>&1; then
  echo "no agent sidecars under $sub (or jq missing)"
  exit 0
fi

# Resolve the query to one or more agent ids.
hits=""
for m in "$sub"/*.meta.json; do
  [ -f "$m" ] || continue   # empty dir: keep the unexpanded glob out of $hits
  id="$(basename "$m" .meta.json)"; short="${id#agent-}"
  if [ -z "$q" ]; then hits="$hits $id"; continue; fi
  hit=0
  jq -e --arg q "$q" '(((.agentType // "") + " " + (.description // ""))
      | ascii_downcase | contains($q))' "$m" >/dev/null 2>&1 && hit=1
  case "$short" in "$q"*) hit=1 ;; esac
  [ "$hit" = 1 ] && hits="$hits $id"
done
n="$(echo $hits | wc -w | tr -d ' ')"
if [ -z "$q" ] && [ "$n" = 0 ]; then echo "no agents under $sub"; exit 0; fi

if [ -z "$q" ] || [ "$n" -gt 1 ]; then
  [ -n "$q" ] && echo "MATCHES $n for \"$q\" — narrow it, or use an id prefix:"
  for id in $hits; do
    m="$sub/$id.meta.json"; j="$sub/$id.jsonl"; [ -f "$j" ] || continue
    jq -rs --slurpfile M "$m" --arg id "${id#agent-}" '
      def ep: sub("\\.[0-9]+Z$";"Z") | fromdateiso8601;
      (map(select(.timestamp)) | sort_by(.timestamp)) as $e
      | ($e[-1]) as $L
      | ([ $L.message.content[]? | select(.type=="text") | .text ] | join(" ")) as $txt
      | [ ($M[0].spawnDepth // 1), $id[0:8], ($M[0].agentType // "?"),
          ($M[0].description // "-"),
          (if ($M[0].stoppedByUser // false)
              or ($txt | test("\\[Request interrupted")) then "STOP"
           elif $L.type=="assistant"
              and ([ $L.message.content[]? | select(.type=="tool_use") ] | length)==0
           then "done" else "RUN" end),
          (((now - ($L.timestamp | ep)) / 60) | floor),
          ([ $e[] | select(.message.content? | type=="array") | .message.content[]
             | select(.type=="tool_use") ] | length),
          (($M[0].parentAgentId // "-")[0:8])
        ] | @tsv' "$j"
  done | sort -t"$(printf '\t')" -k1,1n -k6,6nr | awk -F'\t' '
    { ind = ""; for (i = 1; i < $1; i++) ind = ind "   "
      printf "%s  %-4s %-8s %-21s %-28s idle %sm  %s calls  parent:%s\n",
             ind, $5, $2, $3, substr($4,1,28), $6, $7, $8 }'
  exit 0
fi
if [ "$n" = 0 ]; then echo "no agent matches \"$q\" — run /llmcheats:agents with no argument to list them"; exit 0; fi

# Exactly one match: its timeline.
id="${hits# }"; m="$sub/$id.meta.json"; j="$sub/$id.jsonl"
jq -r '"AGENT \(.agentType)  \(.description // "-")  depth \(.spawnDepth // 1)  parent \(.parentAgentId // "top level")"' "$m"
jq -rs --slurpfile M "$m" '
  def ep: sub("\\.[0-9]+Z$";"Z") | fromdateiso8601;
  def clip($n): tostring | gsub("[\n\t]"; " ") | gsub("  +"; " ") | .[0:$n];
  (map(select(.timestamp)) | sort_by(.timestamp)) as $e
  | if ($e | length) == 0 then
      "NO EVENTS — launched but never ran; report a launch failure, not work in progress"
    else
  ($e[0].timestamp | ep) as $t0
  | ($e[-1]) as $L
  | [ $e[]
      | (.timestamp | ep) as $ts
      | select(.message.content? | type=="array")
      | .message.content[] | select(.type=="tool_use")
      | { ts: $ts, name: .name,
          arg: (.input | (.file_path // .command // .pattern // .description
                          // .prompt // .url // .subagent_type // .) | clip(70)) } ] as $calls
  | ( $calls | to_entries | .[]
      | "  t+\(((.value.ts - $t0)/60)|floor)m \(if .key > 0
          then "+\((.value.ts - $calls[.key-1].ts)|floor)s" else "" end
          | . + "        " | .[0:7])  \(.value.name)  \(.value.arg)" ),
    "",
    (if ($M[0].stoppedByUser // false)
        or (([ $L.message.content[]? | select(.type=="text") | .text ] | join(" "))
            | test("\\[Request interrupted"))
     then "STOPPED BY THE OPERATOR \(((now - ($L.timestamp|ep))/60)|floor)m ago — it did not finish and nothing will resume it"
     elif $L.type=="assistant"
        and ([ $L.message.content[]? | select(.type=="tool_use") ] | length)==0
     then "HAND-BACK (idle \(((now - ($L.timestamp|ep))/60)|floor)m — was this ever reported?)\n"
          + ([ $L.message.content[]? | select(.type=="text") | .text ] | join("\n"))
     else "STILL RUNNING — last event is \($L.type), \(((now - ($L.timestamp|ep))/60)|floor)m ago"
     end)
  end
' "$j"
```

## 2. Report

- **Lead with the verdict on this agent**: finished and reported, finished and
  never reported, running, idle-inside-a-tool, or stopped by the operator. One
  sentence.
- **`STOP` / `STOPPED BY THE OPERATOR` is not a failure of the agent.** Say
  which tool call it was in when it was stopped and what part of its stage is
  therefore missing; never describe it as still working.
- **When it finished, the hand-back is the answer** — quote it, do not
  summarize it into something shorter than the operator needs. If it holds a
  `BLOCKED` verdict or a question for the operator, that is the headline.
- **When it is running**, say which tool call it sits in and for how long. A
  long gap between two `t+` lines is where the time went; name it.
- **When it is idle with no explanation**, say exactly that. Do not invent a
  reason from the surrounding conversation.
- If the timeline is empty, the agent was launched and never ran — report it as
  a launch failure, not as work in progress.

#!/usr/bin/env bash
# Offline test suite for install.sh. Packages the working tree into a tarball
# and installs it into scratch repos via LLMCHEATS_TARBALL, so nothing here
# touches the network.
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT INT TERM

pass=0
fail=0

ok()   { pass=$((pass + 1)); printf '  ok   %s\n' "$1"; }
no()   { fail=$((fail + 1)); printf '  FAIL %s\n' "$1"; }
check() { if [ "$1" -eq 0 ]; then ok "$2"; else no "$2"; fi; }

exists()     { [ -e "$1" ]; check $? "${2:-exists: $1}"; }
not_exists() { [ ! -e "$1" ]; check $? "${2:-absent: $1}"; }

section() { printf '\n%s\n' "$1"; }

# --- package the working tree ------------------------------------------------

PKG="$WORK/pkg"
mkdir -p "$PKG/llmcheats-test"
for item in docs cheats skills templates install.sh README.md; do
  [ -e "$ROOT/$item" ] && cp -R "$ROOT/$item" "$PKG/llmcheats-test/"
done
# report/ holds the Phase A/B/D artifacts and is deliberately not in the copy
# list above -- the corpus owns docs/ entirely, and every file under it is
# indexed by docs/INDEX.md.

TARBALL="$WORK/payload.tar.gz"
( cd "$PKG" && tar -czf "$TARBALL" llmcheats-test )
export LLMCHEATS_TARBALL="file://$TARBALL"

new_repo() {
  d="$WORK/$1"
  mkdir -p "$d"
  ( cd "$d" && git init -q . && git config user.email t@t && git config user.name t )
  printf '%s' "$d"
}

# --- 1. syntax ----------------------------------------------------------------

section "1. syntax"
bash -n "$ROOT/install.sh" 2>/dev/null
check $? "install.sh parses"
bash -n "${BASH_SOURCE[0]}" 2>/dev/null
check $? "install_test.sh parses"

# --- 2. default install -------------------------------------------------------

section "2. default install into a scratch repo"
R="$(new_repo repo_default)"
( cd "$R" && bash "$ROOT/install.sh" >/dev/null 2>&1 )
check $? "installer exits 0"

exists "$R/.llmcheats/VERSION"                       "VERSION written"
grep -q '^repo=https://github.com/' "$R/.llmcheats/VERSION" 2>/dev/null
check $? "VERSION carries the full repo URL"
# This payload is a plain tar, not a git archive, so there is no commit to read.
grep -q '^ref=main$' "$R/.llmcheats/VERSION" 2>/dev/null
check $? "VERSION falls back to the ref when the payload carries no commit"
exists "$R/.llmcheats/docs/INDEX.md"                 "corpus: the single index"
exists "$R/.llmcheats/docs/devflow/git.md"           "corpus: devflow/ group"
exists "$R/.llmcheats/docs/webapp/testing-strategy.md" "corpus: webapp/ group"
exists "$R/.llmcheats/docs/backend/layered-architecture.md" "corpus: backend/ group"
exists "$R/.llmcheats/docs/tools/commit-conventions.md" "corpus: tools/ group"
exists "$R/.llmcheats/cheats/index.md"               "cheats/index.md"
exists "$R/.llmcheats/cheats/routing.md"             "cheats/routing.md"
exists "$R/.llmcheats/cheats/workflows"              "cheats/workflows/"
exists "$R/.llmcheats/cheats/practices"              "cheats/practices/"
exists "$R/.llmcheats/templates"                     "templates/"
exists "$R/.claude/skills/llmcheats-setup/SKILL.md"  "claude: setup skill"
exists "$R/.agents/skills/llmcheats-setup/SKILL.md"  "codex: setup skill"

# The installer is dumb: these are the setup skill's output, not its own.
not_exists "$R/AGENTS.md"             "installer does not write AGENTS.md"
not_exists "$R/CLAUDE.md"             "installer does not write CLAUDE.md"
not_exists "$R/.llmcheats/stack.md"   "installer does not write stack.md"

# --- 3. skill trees are identical twins --------------------------------------

section "3. the two skill trees are byte-identical"
diff -r "$R/.claude/skills" "$R/.agents/skills" >/dev/null 2>&1
check $? "claude and codex skill trees match byte for byte"

wf_count=$(find "$R/.llmcheats/cheats/workflows" -name '*.md' | wc -l | tr -d ' ')
stub_count=$(find "$R/.claude/skills" -mindepth 1 -maxdepth 1 -type d | wc -l | tr -d ' ')
[ "$stub_count" -eq $((wf_count + 1)) ]
check $? "one stub per workflow plus the setup skill ($wf_count + 1 = $stub_count)"

# --- 4. routing layer 1: descriptions carry the literal prefix tokens ---------

section "4. routing layer 1 (skill descriptions)"
for prefix in feature bug refactor migrate; do
  grep -rql "^description:.*${prefix}:" "$R/.claude/skills/llmcheats-${prefix}/SKILL.md" 2>/dev/null
  check $? "llmcheats-${prefix} description front-loads '${prefix}:'"
done

# --- 5. routing layer 2: every workflow has a routing row --------------------

section "5. routing layer 2 (routing table)"
missing_rows=0
for wf in "$R/.llmcheats/cheats/workflows"/*.md; do
  slug="$(basename "$wf" .md)"
  grep -q "workflows/${slug}.md" "$R/.llmcheats/cheats/routing.md" || {
    printf '       no routing row for %s\n' "$slug"
    missing_rows=$((missing_rows + 1))
  }
done
[ "$missing_rows" -eq 0 ]
check $? "every workflow has a row in routing.md"

# --- 6. --agents claude skips the codex tree ---------------------------------

section "6. --agents selection"
R2="$(new_repo repo_claude_only)"
( cd "$R2" && bash "$ROOT/install.sh" --agents claude >/dev/null 2>&1 )
check $? "--agents claude exits 0"
exists     "$R2/.claude/skills/llmcheats-setup/SKILL.md" "claude tree present"
not_exists "$R2/.agents"                                  "codex tree skipped entirely"

R3="$(new_repo repo_codex_only)"
( cd "$R3" && bash "$ROOT/install.sh" --agents codex >/dev/null 2>&1 )
exists     "$R3/.agents/skills/llmcheats-setup/SKILL.md" "codex tree present"
not_exists "$R3/.claude"                                  "claude tree skipped entirely"

( cd "$R3" && bash "$ROOT/install.sh" --agents nonsense >/dev/null 2>&1 )
[ $? -ne 0 ]
check $? "unknown --agents value is rejected"

# --- 7. idempotence: generated files survive a re-run ------------------------

section "7. re-run preserves generated files"
printf 'stack: handwritten sentinel\n' > "$R/.llmcheats/stack.md"
printf '# generated by the skill\n'     > "$R/AGENTS.md"
printf '@AGENTS.md\n'                   > "$R/CLAUDE.md"
# A local edit inside a managed subtree SHOULD be discarded on refresh.
printf 'stale\n' > "$R/.llmcheats/cheats/scratch-marker.md"

( cd "$R" && bash "$ROOT/install.sh" >/dev/null 2>&1 )
check $? "re-run exits 0"

grep -q sentinel "$R/.llmcheats/stack.md" 2>/dev/null
check $? "stack.md survives a re-run"
grep -q 'generated by the skill' "$R/AGENTS.md" 2>/dev/null
check $? "AGENTS.md survives a re-run"
grep -q '@AGENTS.md' "$R/CLAUDE.md" 2>/dev/null
check $? "CLAUDE.md survives a re-run"
not_exists "$R/.llmcheats/cheats/scratch-marker.md" "managed subtree is refreshed, not merged"

# --- 8. --force is the only wipe ---------------------------------------------

section "8. --force"
( cd "$R" && bash "$ROOT/install.sh" --force >/dev/null 2>&1 )
check $? "--force exits 0"
not_exists "$R/.llmcheats/stack.md" "stack.md is destroyed by --force"
grep -q 'generated by the skill' "$R/AGENTS.md" 2>/dev/null
check $? "--force still does not touch AGENTS.md"

# --- 9. outside a git repo with no --target ----------------------------------

section "9. no repo, no --target"
NOGIT="$WORK/not_a_repo"
mkdir -p "$NOGIT"
( cd "$NOGIT" && bash "$ROOT/install.sh" >/dev/null 2>&1 )
[ $? -ne 0 ]
check $? "exits non-zero outside a git repository"
not_exists "$NOGIT/.llmcheats" "and writes nothing"

R4="$(new_repo repo_target_flag)"
( cd "$NOGIT" && bash "$ROOT/install.sh" --target "$R4" >/dev/null 2>&1 )
check $? "--target works from outside a repo"
exists "$R4/.llmcheats/VERSION" "--target installed to the right place"

# --- 10. extensibility contract ----------------------------------------------
#
# Adding a workflow must be one file in cheats/workflows/ plus one routing row,
# with no change to install.sh and no change to the setup skill.

section "10. extensibility contract"
EXT="$WORK/pkg_ext"
mkdir -p "$EXT"
cp -R "$PKG/llmcheats-test" "$EXT/llmcheats-test"
cat > "$EXT/llmcheats-test/cheats/workflows/spike.md" <<'EOF'
---
name: spike
description: "spike: throwaway exploration to answer one question, deleted after."
---
# spike:
Answer the question, write down the answer, delete the code.
EOF
printf '| `spike:` | `workflows/spike.md` | asap | throwaway exploration |\n' \
  >> "$EXT/llmcheats-test/cheats/routing.md"

EXT_TAR="$WORK/payload_ext.tar.gz"
( cd "$EXT" && tar -czf "$EXT_TAR" llmcheats-test )

R5="$(new_repo repo_ext)"
( cd "$R5" && LLMCHEATS_TARBALL="file://$EXT_TAR" bash "$ROOT/install.sh" >/dev/null 2>&1 )
check $? "install with an added workflow exits 0"
exists "$R5/.claude/skills/llmcheats-spike/SKILL.md" "new workflow produced a claude stub"
exists "$R5/.agents/skills/llmcheats-spike/SKILL.md" "new workflow produced a codex stub"
grep -q 'spike:' "$R5/.claude/skills/llmcheats-spike/SKILL.md" 2>/dev/null
check $? "the stub inherited the workflow's description"
diff -q "$ROOT/install.sh" "$EXT/llmcheats-test/install.sh" >/dev/null 2>&1
check $? "install.sh was not modified to add the workflow"
diff -q "$ROOT/skills/llmcheats-setup/SKILL.md" \
        "$EXT/llmcheats-test/skills/llmcheats-setup/SKILL.md" >/dev/null 2>&1
check $? "the setup skill was not modified to add the workflow"

# --- 11. the AGENTS.md template obeys the limits it teaches ------------------
#
# F-001: under 120 lines, no section past 20. A generated file fills whatever cap
# it is given, so the template is where the cap has to bite.

section "11. template obeys F-001"
TPL="$R/.llmcheats/templates/AGENTS.md.tpl"
exists "$TPL" "template installed"

tpl_lines=$(wc -l < "$TPL" | tr -d ' ')
[ "$tpl_lines" -lt 120 ]
check $? "template is under 120 lines ($tpl_lines)"

tpl_bytes=$(wc -c < "$TPL" | tr -d ' ')
[ "$tpl_bytes" -lt 6144 ]
check $? "template is under 6 KB ($tpl_bytes bytes)"

longest=$(awk '/^## /{if(n>m){m=n;w=s}; s=$0; n=0; next} {if(s)n++} END{if(n>m){m=n;w=s}; print m}' "$TPL")
[ "$longest" -le 20 ]
check $? "no template section exceeds 20 lines (longest: $longest)"

grep -q 'llmcheats:begin' "$TPL" && grep -q 'llmcheats:end' "$TPL"
check $? "template carries both managed-block markers"

# Project memory must sit OUTSIDE the managed block, not inside it.
begin_ln=$(grep -n 'llmcheats:end' "$TPL" | head -1 | cut -d: -f1)
proj_ln=$(grep -n '^# Project' "$TPL" | head -1 | cut -d: -f1)
[ -n "$begin_ln" ] && [ -n "$proj_ln" ] && [ "$proj_ln" -gt "$begin_ln" ]
check $? "project memory sits below the closing marker"

# --- 12. a user's own llmcheats-* skill is backed up, never deleted ----------
#
# install_skills_into() removes llmcheats-* before refreshing. That is the one
# path where the installer deletes something it may not have created.

section "12. user files under llmcheats-* survive"
R7="$(new_repo repo_backup)"
( cd "$R7" && bash "$ROOT/install.sh" >/dev/null 2>&1 )

# A skill the user wrote themselves, in our namespace.
mkdir -p "$R7/.claude/skills/llmcheats-mine"
printf 'my own skill, not from the payload\n' > "$R7/.claude/skills/llmcheats-mine/SKILL.md"
# And an extra file inside a directory we DO manage.
printf 'my notes\n' > "$R7/.claude/skills/llmcheats-feature/NOTES.md"

( cd "$R7" && bash "$ROOT/install.sh" >/dev/null 2>&1 )
check $? "re-run over user files exits 0"

not_exists "$R7/.claude/skills/llmcheats-mine/SKILL.md" "the foreign skill is cleared from the live tree"
exists "$R7/.bak-llmcheats/claude/llmcheats-mine/SKILL.md" "...and was backed up, not destroyed"
grep -q 'my own skill' "$R7/.bak-llmcheats/claude/llmcheats-mine/SKILL.md" 2>/dev/null
check $? "the backup holds the user's content verbatim"
exists "$R7/.bak-llmcheats/claude/llmcheats-feature/NOTES.md" "an extra file in a managed dir is backed up too"

# An untouched install must not produce backup noise on every re-run.
R8="$(new_repo repo_nobackup)"
( cd "$R8" && bash "$ROOT/install.sh" >/dev/null 2>&1 )
( cd "$R8" && bash "$ROOT/install.sh" >/dev/null 2>&1 )
not_exists "$R8/.bak-llmcheats" "an unmodified re-run creates no backup directory"

# --- 13. payload validation ---------------------------------------------------

section "13. malformed payload is refused"
BAD="$WORK/pkg_bad"
mkdir -p "$BAD/llmcheats-test/cheats"
BAD_TAR="$WORK/payload_bad.tar.gz"
( cd "$BAD" && tar -czf "$BAD_TAR" llmcheats-test )
R6="$(new_repo repo_bad)"
( cd "$R6" && LLMCHEATS_TARBALL="file://$BAD_TAR" bash "$ROOT/install.sh" >/dev/null 2>&1 )
[ $? -ne 0 ]
check $? "a payload missing docs/ and workflows/ is rejected"

# --- 14. VERSION pins a commit when the payload is a git archive -------------
#
# codeload serves `git archive` output, whose pax global header carries the
# commit. VERSION has to record that, not the branch name it was fetched by.

section "14. VERSION records the commit, not the branch"
GA_TAR="$WORK/payload_archive.tar.gz"
( cd "$ROOT" && git archive --format=tar.gz --prefix=llmcheats-test/ HEAD -o "$GA_TAR" )
HEAD_SHA="$(cd "$ROOT" && git rev-parse HEAD)"

R9="$(new_repo repo_archive)"
( cd "$R9" && LLMCHEATS_TARBALL="file://$GA_TAR" bash "$ROOT/install.sh" >/dev/null 2>&1 )
check $? "install from a git archive exits 0"
grep -q "^ref=$HEAD_SHA\$" "$R9/.llmcheats/VERSION" 2>/dev/null
check $? "VERSION records the commit ($HEAD_SHA)"

# --- 15. a tree with no git at all -------------------------------------------
#
# ~/Projects/a/b/c/d with the knowledge base in a: one corpus at the root, the
# skills in the directory the agent is actually launched from.

section "15. no git anywhere: root + nested working directory"
A="$WORK/nogit_a"
D="$A/b/c/d"
mkdir -p "$D"

( cd "$D" && bash "$ROOT/install.sh" --target "$A" --here >/dev/null 2>&1 )
check $? "--target ROOT --here exits 0 with no git in sight"

exists     "$A/.llmcheats/VERSION"                    "corpus installed in the root"
exists     "$A/.claude/skills/llmcheats-setup/SKILL.md" "root has the skills too"
not_exists "$D/.llmcheats"                            "the working directory gets no second corpus"
exists     "$D/.claude/skills/llmcheats-feature/SKILL.md" "claude: stubs in the working directory"
exists     "$D/.agents/skills/llmcheats-feature/SKILL.md" "codex: stubs in the working directory"

diff -r "$D/.claude/skills" "$D/.agents/skills" >/dev/null 2>&1
check $? "the nested trees are byte-identical twins as well"

grep -q '`\.\./\.\./\.\./\.llmcheats/cheats/workflows/feature\.md`' \
  "$D/.claude/skills/llmcheats-feature/SKILL.md" 2>/dev/null
check $? "the nested stub reaches the root by a relative path"

grep -q '\.\./\.\./\.\./\.llmcheats/' "$D/.claude/skills/llmcheats-setup/SKILL.md" 2>/dev/null
check $? "the nested setup skill is told where the knowledge base is"

grep -q '^description:.*feature:' "$D/.claude/skills/llmcheats-feature/SKILL.md" 2>/dev/null
check $? "the nested stub keeps its routing description"

grep -q '`\.llmcheats/cheats/workflows/feature\.md`' \
  "$A/.claude/skills/llmcheats-feature/SKILL.md" 2>/dev/null
check $? "the root stub is unprefixed"

# A refresh from the working directory has to find the root by itself.
( cd "$D" && bash "$ROOT/install.sh" --here >/dev/null 2>&1 )
check $? "a later --here refresh finds the root by walking up"
exists "$D/.claude/skills/llmcheats-feature/SKILL.md" "and rewrote the nested stubs"
not_exists "$D/.llmcheats" "and still did not create a second corpus"

# The setup skill writes stack.md into the working directory, which gives it a
# .llmcheats/ of its own. That must not read as a second root on the next run,
# and the attachment must survive a refresh that does not repeat --here.
mkdir -p "$D/.llmcheats"
printf 'stack: nested sentinel\n' > "$D/.llmcheats/stack.md"
( cd "$D" && bash "$ROOT/install.sh" >/dev/null 2>&1 )
check $? "a plain re-run from an attached working directory exits 0"
not_exists "$D/.llmcheats/VERSION" "a working directory's stack.md is not mistaken for a root"
grep -q sentinel "$D/.llmcheats/stack.md" 2>/dev/null
check $? "and its stack.md is untouched"
grep -q '`\.\./\.\./\.\./\.llmcheats/cheats/workflows/feature\.md`' \
  "$D/.claude/skills/llmcheats-feature/SKILL.md" 2>/dev/null
check $? "the attachment survives a re-run without --here"

# Without --here the working directory is left alone entirely.
E="$WORK/nogit_e"
mkdir -p "$E/sub"
( cd "$E/sub" && bash "$ROOT/install.sh" --target "$E" >/dev/null 2>&1 )
check $? "--target without --here exits 0"
not_exists "$E/sub/.claude" "no --here means nothing is written to the working directory"

# --- 16. the upward search stops at a repository boundary --------------------
#
# A repo checked out below an installed root is its own project, so a plain
# install inside it must land in the repo and not refresh the root above it.

section "16. an existing .llmcheats/ above a repo does not capture it"
NESTED="$(mkdir -p "$A/b/repo" && cd "$A/b/repo" && git init -q . \
  && git config user.email t@t && git config user.name t && pwd)"
( cd "$NESTED" && bash "$ROOT/install.sh" >/dev/null 2>&1 )
check $? "install inside the nested repo exits 0"
exists "$NESTED/.llmcheats/VERSION" "it installed into the repo, not the root above"

# --- 17. every shipped markdown table is column-aligned ----------------------
#
# practices/agent-discipline.md tells the agent its tables are padded and its
# separator row is sized to match. A corpus shipping crooked tables teaches the
# opposite on every read.

section "17. shipped tables are column-aligned"

cat > "$WORK/aligned.awk" <<'EOF'
function sig(s,   i, out) {
  out = ""
  for (i = 1; i <= length(s); i++)
    if (substr(s, i, 1) == "|") out = out ":" i
  return out
}
function check(   i, want) {
  if (n < 2 || rows[1] !~ /-/ || rows[1] ~ /[^ \t|:-]/) { n = 0; return }
  if (rows[1] !~ /\| :?---/) {
    printf "%s:%d unpadded separator row\n", f, start + 1
    bad++
    n = 0
    return
  }
  want = sig(rows[0])
  for (i = 1; i < n; i++)
    if (sig(rows[i]) != want) {
      printf "%s:%d row is not aligned with its header\n", f, start + i
      bad++
      break
    }
  n = 0
}
BEGIN { n = 0; bad = 0; fence = 0 }
/^[ \t]*(```|~~~)/ { check(); fence = !fence; next }
fence { next }
/^[ \t]*\|/ { if (n == 0) start = FNR; rows[n++] = $0; next }
{ check() }
END { check(); exit bad > 0 ? 1 : 0 }
EOF

# tr collapses every multibyte character to a single byte first, so a row
# carrying an em dash is not measured as one column wider than its neighbours.
crooked=0
while IFS= read -r tbl; do
  LC_ALL=C tr -d '\200-\277' < "$tbl" | LC_ALL=C awk -v f="$tbl" -f "$WORK/aligned.awk" \
    || crooked=$((crooked + 1))
done < <(find "$R/.llmcheats" "$R/.claude/skills" "$R/.agents/skills" \
  \( -name '*.md' -o -name '*.tpl' \))
[ "$crooked" -eq 0 ]
check $? "every table in the installed corpus is padded and aligned ($crooked crooked)"

# The check has to be able to fail: neither of these may pass it.
printf '| a | bbbb |\n| --- | --- |\n| c | d |\n' > "$WORK/crooked.md"
LC_ALL=C awk -v f=crooked -f "$WORK/aligned.awk" "$WORK/crooked.md" >/dev/null 2>&1
[ $? -ne 0 ]
check $? "the alignment check rejects a crooked table"

printf '|a|b|\n|-|-|\n|c|d|\n' > "$WORK/compact.md"
LC_ALL=C awk -v f=compact -f "$WORK/aligned.awk" "$WORK/compact.md" >/dev/null 2>&1
[ $? -ne 0 ]
check $? "the alignment check rejects an unpadded table"

# --- summary ------------------------------------------------------------------

printf '\n%s\n' "-----------------------------------------"
printf 'passed %d, failed %d\n' "$pass" "$fail"
[ "$fail" -eq 0 ]

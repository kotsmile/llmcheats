#!/usr/bin/env bash
#
# Install, update or uninstall the llmcheats agents, skill and reference
# docs for Claude Code and/or Codex. Safe to re-run: a run refreshes what
# llmcheats installed earlier. Run with --help for details.
#
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  ./install.sh [claude|codex|all] [--project <dir>]
  ./install.sh uninstall [claude|codex|all] [--project <dir>]

Default target is "all"; default scope is global (~/.claude, ~/.codex).

What goes where (global):
  Claude Code:  ~/.claude/agents/<name>.md
                ~/.claude/skills/webapp-guide/SKILL.md
                ~/.claude/llmcheats/docs/{INDEX.md,webapp/,devflow/}
  Codex:        ~/.codex/llmcheats/docs/{INDEX.md,webapp/,devflow/}
                ~/.codex/AGENTS.md  <- a managed block is appended/updated

Project mode (--project <dir>) replaces the prefixes with:
  Claude Code:  <dir>/.claude/...
  Codex:        <dir>/.llmcheats/docs, managed block in <dir>/AGENTS.md
                (note: this edits <dir>/AGENTS.md in place)

An existing agent file with the same name that llmcheats did not install
is backed up to <name>.md.bak-llmcheats before being replaced, with a
warning. Everything in AGENTS.md outside the managed block is preserved.
EOF
}

# Resolve the repo dir even when install.sh is reached through a symlink.
src="${BASH_SOURCE[0]}"
while [ -L "$src" ]; do
  dir="$(cd -- "$(dirname -- "$src")" >/dev/null && pwd)"
  src="$(readlink "$src")"
  case "$src" in /*) ;; *) src="$dir/$src" ;; esac
done
SRC_DIR="$(cd -- "$(dirname -- "$src")" >/dev/null && pwd)"

MARK_BEGIN="<!-- llmcheats:begin -->"
MARK_END="<!-- llmcheats:end -->"

TMPF=""
cleanup() { [ -n "$TMPF" ] && rm -f "$TMPF" || true; }
trap cleanup EXIT

action="install"
target=""
project_dir=""

while [ $# -gt 0 ]; do
  case "$1" in
    uninstall) action="uninstall" ;;
    claude|codex|all)
      if [ -n "$target" ] && [ "$target" != "$1" ]; then
        echo "error: pick one target: claude, codex or all" >&2
        exit 1
      fi
      target="$1"
      ;;
    --project)
      shift
      [ $# -gt 0 ] || { echo "error: --project needs a directory" >&2; exit 1; }
      project_dir="$(cd -- "$1" >/dev/null && pwd)"
      ;;
    -h|--help) usage; exit 0 ;;
    *) echo "error: unknown argument: $1 (see --help)" >&2; exit 1 ;;
  esac
  shift
done
target="${target:-all}"

copy_docs() { # $1 = destination docs dir
  # The reference is split per topic so an agent reads only the file it needs.
  # Stale files from an older install would still be readable, so replace the
  # subdirectories wholesale rather than merging into them.
  mkdir -p "$1"
  rm -rf "$1/webapp" "$1/devflow"
  rm -f "$1/WEBAPP_DOC.md" "$1/DEVFLOW.md" # layout before the split
  cp -f "$SRC_DIR/docs/INDEX.md" "$1/"
  cp -R "$SRC_DIR/docs/webapp" "$SRC_DIR/docs/devflow" "$1/"
}

# Refuse to touch an AGENTS.md whose managed block is damaged: a half-present
# or misordered marker pair would otherwise truncate the user's file.
check_markers() { # $1 = file; returns 0 when safe to edit
  local file="$1" nb ne bline eline
  nb="$(grep -cF "$MARK_BEGIN" "$file" || true)"
  ne="$(grep -cF "$MARK_END" "$file" || true)"
  if [ "$nb" = "0" ] && [ "$ne" = "0" ]; then return 0; fi
  if [ "$nb" != "1" ] || [ "$ne" != "1" ]; then
    echo "error: $file has a damaged llmcheats block (markers mismatched) — file left unchanged, fix it by hand" >&2
    return 1
  fi
  bline="$(grep -nF "$MARK_BEGIN" "$file" | head -1 | cut -d: -f1)"
  eline="$(grep -nF "$MARK_END" "$file" | head -1 | cut -d: -f1)"
  if [ "$bline" -gt "$eline" ]; then
    echo "error: $file has its llmcheats markers in the wrong order — file left unchanged, fix it by hand" >&2
    return 1
  fi
  return 0
}

# Strip the managed block, preserving every other line (interior blank lines
# included); only blank runs left dangling at EOF are dropped.
strip_block() { # $1 = in, $2 = out
  awk -v b="$MARK_BEGIN" -v e="$MARK_END" '
    $0 == b { skip = 1; next }
    $0 == e { skip = 0; next }
    skip { next }
    !NF { blank++; next }
    { for (; blank > 0; blank--) print ""; print }
  ' "$1" >"$2"
}

upsert_block() { # $1 = file, $2 = docs path to reference
  local file="$1" docs="$2"
  mkdir -p "$(dirname -- "$file")"
  touch "$file"
  check_markers "$file" || return 1
  TMPF="$(mktemp)"
  strip_block "$file" "$TMPF"
  {
    [ -s "$TMPF" ] && echo ""
    echo "$MARK_BEGIN"
    echo "## Web application engineering reference (llmcheats)"
    echo ""
    echo "When designing, implementing, reviewing, or operating a web"
    echo "application, consult \`$docs\`. It is split per topic:"
    echo "\`webapp/\` (how to build) and \`devflow/\` (the delivery process and"
    echo "its gates)."
    echo ""
    echo "Read \`INDEX.md\` there to pick the file, then read **only** that"
    echo "file — one or two, never the whole tree. Filenames are self-"
    echo "describing, so skip \`INDEX.md\` when the topic is obvious"
    echo "(\`webapp/3-frontend.md\`, \`webapp/5-security.md\`,"
    echo "\`devflow/3-fast-flow.md\`). Read before acting, not from memory."
    echo "$MARK_END"
  } >>"$TMPF"
  mv "$TMPF" "$file"
  TMPF=""
}

remove_block() { # $1 = file
  local file="$1"
  [ -f "$file" ] || return 0
  check_markers "$file" || return 1
  TMPF="$(mktemp)"
  strip_block "$file" "$TMPF"
  mv "$TMPF" "$file"
  TMPF=""
  echo "removed llmcheats block from $file"
}

claude_base() {
  if [ -n "$project_dir" ]; then echo "$project_dir/.claude"; else echo "$HOME/.claude"; fi
}

install_claude() {
  local base agents_dir skills_dir docs_dir manifest name dest
  base="$(claude_base)"
  agents_dir="$base/agents"
  skills_dir="$base/skills/webapp-guide"
  docs_dir="$base/llmcheats/docs"
  manifest="$base/llmcheats/agents.list"

  mkdir -p "$agents_dir" "$skills_dir" "$base/llmcheats"

  # Drop agents a previous llmcheats install put here that no longer exist
  # in the repo, so removed agents don't linger and keep catching delegation.
  if [ -f "$manifest" ]; then
    while IFS= read -r name; do
      [ -n "$name" ] || continue
      if [ ! -f "$SRC_DIR/agents/$name" ] && [ -f "$agents_dir/$name" ]; then
        rm -f "$agents_dir/$name"
        echo "claude: removed stale agent $agents_dir/$name"
      fi
    done <"$manifest"
  fi

  : >"$manifest"
  for f in "$SRC_DIR"/agents/*.md; do
    name="$(basename -- "$f")"
    dest="$agents_dir/$name"
    # A same-named file we did not install (no llmcheats reference in it)
    # is the user's own agent: back it up instead of silently replacing it.
    if [ -e "$dest" ] && ! cmp -s "$f" "$dest" && ! grep -q "llmcheats" "$dest"; then
      cp -p -- "$dest" "$dest.bak-llmcheats"
      echo "warning: $dest existed and was not installed by llmcheats — backed up to $dest.bak-llmcheats" >&2
    fi
    cp -f -- "$f" "$dest"
    echo "$name" >>"$manifest"
  done
  cp -f "$SRC_DIR/skills/webapp-guide/SKILL.md" "$skills_dir/SKILL.md"
  copy_docs "$docs_dir"

  echo "claude: agents -> $agents_dir"
  echo "claude: skill  -> $skills_dir"
  echo "claude: docs   -> $docs_dir"
}

uninstall_claude() {
  local base agents_dir manifest name
  base="$(claude_base)"
  agents_dir="$base/agents"
  manifest="$base/llmcheats/agents.list"

  if [ -f "$manifest" ]; then
    while IFS= read -r name; do
      [ -n "$name" ] && rm -f "$agents_dir/$name"
    done <"$manifest"
  else
    for f in "$SRC_DIR"/agents/*.md; do
      rm -f "$agents_dir/$(basename -- "$f")"
    done
  fi
  rm -rf "$base/skills/webapp-guide" "$base/llmcheats"
  echo "claude: removed agents, skill and docs under $base"
}

codex_paths() { # sets docs_dir, agents_md, docs_ref
  if [ -n "$project_dir" ]; then
    docs_dir="$project_dir/.llmcheats/docs"
    agents_md="$project_dir/AGENTS.md"
    docs_ref=".llmcheats/docs" # relative: the project may be cloned anywhere
  else
    docs_dir="$HOME/.codex/llmcheats/docs"
    agents_md="$HOME/.codex/AGENTS.md"
    docs_ref="~/.codex/llmcheats/docs"
  fi
}

install_codex() {
  local docs_dir agents_md docs_ref
  codex_paths
  copy_docs "$docs_dir"
  upsert_block "$agents_md" "$docs_ref"
  echo "codex: docs    -> $docs_dir"
  echo "codex: pointer -> $agents_md (managed block)"
}

uninstall_codex() {
  local docs_dir agents_md docs_ref
  codex_paths
  rm -rf "$(dirname -- "$docs_dir")"
  remove_block "$agents_md"
  echo "codex: removed docs and pointer"
}

case "$action:$target" in
  install:claude) install_claude ;;
  install:codex)  install_codex ;;
  install:all)    install_claude; install_codex ;;
  uninstall:claude) uninstall_claude ;;
  uninstall:codex)  uninstall_codex ;;
  uninstall:all)    uninstall_claude; uninstall_codex ;;
esac

if [ "$action" = "install" ] && [ -n "$project_dir" ]; then
  echo "note: project install adds .claude/, .llmcheats/ and an AGENTS.md block — commit them or add to .gitignore, your choice."
fi

echo "done."

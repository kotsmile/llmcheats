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
  ./install.sh update [claude|codex|all] [--project <dir>]
  ./install.sh uninstall [claude|codex|all] [--project <dir>]

Default target is "all"; default scope is global (~/.claude, ~/.codex).

"update" pulls this checkout (fast-forward only, and only when it is clean)
and then installs, so one command tracks the repo.

What goes where (global):
  Claude Code:  ~/.claude/agents/<name>.md
                ~/.claude/commands/llmcheats/<name>.md   (as /llmcheats:<name>)
                ~/.claude/skills/<name>/
                ~/.claude/llmcheats/docs/{INDEX.md,webapp/,devflow/}
                ~/.claude/llmcheats/SOURCE.md            (where it came from)
  Codex:        ~/.codex/llmcheats/docs/{INDEX.md,webapp/,devflow/}
                ~/.codex/llmcheats/SOURCE.md
                ~/.codex/AGENTS.md  <- a managed block is appended/updated

Project mode (--project <dir>) replaces the prefixes with:
  Claude Code:  <dir>/.claude/...
  Codex:        <dir>/.llmcheats/docs, managed block in <dir>/AGENTS.md
                (note: this edits <dir>/AGENTS.md in place)

An existing agent, command or skill with the same name that llmcheats did
not install is backed up to a .bak-llmcheats copy before being replaced,
with a warning, and uninstall leaves behind anything edited since it was
installed. Everything in AGENTS.md outside the managed block is preserved.
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
REPO_URL="https://github.com/kotsmile/llmcheats"

TMPF=""
cleanup() { [ -n "$TMPF" ] && rm -f "$TMPF" || true; }
trap cleanup EXIT

action="install"
target=""
project_dir=""

while [ $# -gt 0 ]; do
  case "$1" in
    uninstall) action="uninstall" ;;
    update) action="update" ;;
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
      [ -d "$1" ] || { echo "error: --project directory does not exist: $1" >&2; exit 1; }
      project_dir="$(cd -- "$1" >/dev/null && pwd)"
      ;;
    -h|--help) usage; exit 0 ;;
    *) echo "error: unknown argument: $1 (see --help)" >&2; exit 1 ;;
  esac
  shift
done
target="${target:-all}"

# `update` is a pull followed by the ordinary install, so a user who cloned the
# repo months ago needs one command and no memory of which files moved since.
pull_checkout() {
  if ! git -C "$SRC_DIR" rev-parse --git-dir >/dev/null 2>&1; then
    echo "error: $SRC_DIR is not a git checkout — update it by hand, or re-clone from $REPO_URL" >&2
    exit 1
  fi
  if [ -n "$(git -C "$SRC_DIR" status --porcelain)" ]; then
    echo "error: $SRC_DIR has uncommitted changes — commit, stash or discard them, then re-run" >&2
    exit 1
  fi
  local before after
  before="$(git -C "$SRC_DIR" rev-parse --short HEAD)"
  echo "update: pulling $SRC_DIR"
  if ! git -C "$SRC_DIR" pull --ff-only; then
    echo "error: pull failed — resolve it in $SRC_DIR, then re-run" >&2
    exit 1
  fi
  after="$(git -C "$SRC_DIR" rev-parse --short HEAD)"
  if [ "$before" = "$after" ]; then
    echo "update: already current at $after — reinstalling anyway"
  else
    echo "update: $before -> $after"
  fi
}

if [ "$action" = "update" ]; then
  pull_checkout
  action="install"
fi

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

# Where this install came from, written beside the manifests rather than inside
# docs/: no agent ever reads it, so it costs nothing per task. The checkout path
# is what `update` needs when the user no longer remembers where they cloned it.
write_source_marker() { # $1 = the <base>/llmcheats dir
  local dir="$1" rev
  rev="$(git -C "$SRC_DIR" rev-parse --short HEAD 2>/dev/null || true)"
  mkdir -p "$dir"
  {
    echo "# llmcheats"
    echo
    echo "Agents, slash commands and a web-application engineering reference"
    echo "for Claude Code and Codex."
    echo
    echo "    $REPO_URL"
    echo
    echo "Installed:  $(date -u '+%Y-%m-%d')${rev:+ (${rev})}"
    echo "Checkout:   $SRC_DIR"
    echo
    echo "Update:     $SRC_DIR/install.sh update"
    echo "Uninstall:  $SRC_DIR/install.sh uninstall"
    echo
    echo "Everything under this directory is managed by install.sh and is"
    echo "replaced on update. Edit the checkout, not these copies."
  } >"$dir/SOURCE.md"
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
  # Temp next to the target and seeded from it: the rewrite stays atomic and
  # the user's AGENTS.md keeps its own mode instead of mktemp's 0600.
  TMPF="$(mktemp -- "$file.llmcheats.XXXXXX")"
  cp -p -- "$file" "$TMPF"
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
    echo ""
    echo "Source: $REPO_URL"
    echo "$MARK_END"
  } >>"$TMPF"
  mv "$TMPF" "$file"
  TMPF=""
}

remove_block() { # $1 = file
  local file="$1"
  [ -f "$file" ] || return 0
  check_markers "$file" || return 1
  TMPF="$(mktemp -- "$file.llmcheats.XXXXXX")"
  cp -p -- "$file" "$TMPF"
  strip_block "$file" "$TMPF"
  mv "$TMPF" "$file"
  TMPF=""
  echo "removed llmcheats block from $file"
  # Nothing left means the block was the whole file, so llmcheats created it.
  if [ ! -s "$file" ]; then
    rm -f -- "$file"
    echo "removed $file (empty once the block was gone)"
  fi
}

claude_base() {
  if [ -n "$project_dir" ]; then echo "$project_dir/.claude"; else echo "$HOME/.claude"; fi
}

# Mirror a repo directory of *.md into a Claude Code directory. The manifest
# records what we wrote, so a later run can drop what left the repo and
# uninstall knows exactly what is ours.
sync_md_dir() { # $1 = src dir, $2 = dest dir, $3 = manifest, $4 = label
  local src="$1" dest="$2" manifest="$3" label="$4" prev="" name f tmp
  mkdir -p "$dest" "$(dirname -- "$manifest")"
  [ -f "$manifest" ] && prev="$(cat "$manifest")"

  # Files a previous install put here that no longer exist in the repo would
  # otherwise linger and keep catching delegation.
  while IFS= read -r name; do
    [ -n "$name" ] || continue
    if [ ! -f "$src/$name" ] && [ -f "$dest/$name" ]; then
      rm -f "$dest/$name"
      echo "claude: removed stale $label $dest/$name"
    fi
  done <<<"$prev"

  # Build the list aside and move it into place: a copy that fails midway must
  # not leave the manifest shorter than what is actually installed, because
  # anything missing from it can never be updated or uninstalled again.
  tmp="$manifest.tmp$$"
  : >"$tmp"
  for f in "$src"/*.md; do
    name="$(basename -- "$f")"
    # No llmcheats reference in it: either the user's own file or their edit of
    # ours. Either way it is not reproducible from the repo — back it up.
    # Every file we ship mentions llmcheats, which is what makes this work.
    if [ -e "$dest/$name" ] && ! cmp -s "$f" "$dest/$name" &&
       ! grep -q "llmcheats" "$dest/$name"; then
      cp -p -- "$dest/$name" "$dest/$name.bak-llmcheats"
      echo "warning: $dest/$name existed and was not installed by llmcheats — backed up to $dest/$name.bak-llmcheats" >&2
    fi
    cp -f -- "$f" "$dest/$name"
    echo "$name" >>"$tmp"
  done
  mv -f -- "$tmp" "$manifest"
}

# Skills install as whole directories so a skill can grow reference files
# alongside its SKILL.md, and are manifested like agents and commands.
sync_skills() { # $1 = base
  local base="$1" manifest prev="" name d dest tmp
  manifest="$base/llmcheats/skills.list"
  mkdir -p "$base/skills" "$base/llmcheats"
  [ -f "$manifest" ] && prev="$(cat "$manifest")"

  while IFS= read -r name; do
    [ -n "$name" ] || continue
    if [ ! -d "$SRC_DIR/skills/$name" ] && [ -d "$base/skills/$name" ]; then
      rm -rf "$base/skills/$name"
      echo "claude: removed stale skill $base/skills/$name"
    fi
  done <<<"$prev"

  tmp="$manifest.tmp$$"
  : >"$tmp"
  for d in "$SRC_DIR"/skills/*/; do
    name="$(basename -- "$d")"
    dest="$base/skills/$name"
    mkdir -p "$dest"
    # The backup goes beside the skill, not inside it: uninstall removes the
    # skill directory wholesale and would take the backup with it. A loose file
    # in skills/ is not a skill, so it stays invisible to the agent.
    if [ -e "$dest/SKILL.md" ] && ! cmp -s "$d/SKILL.md" "$dest/SKILL.md" &&
       ! grep -q "llmcheats" "$dest/SKILL.md"; then
      cp -p -- "$dest/SKILL.md" "$base/skills/$name.SKILL.md.bak-llmcheats"
      echo "warning: $dest/SKILL.md existed and was not installed by llmcheats — backed up to $base/skills/$name.SKILL.md.bak-llmcheats" >&2
    fi
    cp -Rf -- "$d." "$dest/"
    echo "$name" >>"$tmp"
  done
  mv -f -- "$tmp" "$manifest"
}

remove_skills() { # $1 = base
  local base="$1" manifest name
  manifest="$base/llmcheats/skills.list"
  [ -f "$manifest" ] || return 0
  while IFS= read -r name; do
    [ -n "$name" ] || continue
    if [ -f "$base/skills/$name/SKILL.md" ] &&
       ! grep -q "llmcheats" "$base/skills/$name/SKILL.md"; then
      echo "kept $base/skills/$name — edited since install, remove it by hand" >&2
      continue
    fi
    rm -rf "$base/skills/$name"
  done <"$manifest"
}

# Before v2 the commands installed flat as /status; they now live in a
# commands/llmcheats/ subdir so Claude Code namespaces them as /llmcheats:status.
# Without this both copies would exist and both would answer. The previous
# manifest is read too: a command can leave the payload in the same release that
# moves it (llmcheats.md did), and that copy has to go as well.
drop_flat_commands() { # $1 = base, $2 = manifest written by the previous install
  local base="$1" manifest="$2" f name
  # Installing into the llmcheats checkout itself would aim this at the repo's
  # own .claude/commands/, which llmcheats never installed.
  case "$base/" in "$SRC_DIR"/*) return 0 ;; esac
  {
    if [ -f "$manifest" ]; then cat "$manifest"; fi
    for f in "$SRC_DIR"/commands/*.md; do basename -- "$f"; done
  } | sort -u | while IFS= read -r name; do
    [ -n "$name" ] || continue
    if [ -f "$base/commands/$name" ] && grep -q "llmcheats" "$base/commands/$name"; then
      rm -f "$base/commands/$name"
      echo "claude: removed flat $base/commands/$name (commands are /llmcheats:<name> now)"
    fi
  done
}
remove_md_dir() { # $1 = src dir, $2 = dest dir, $3 = manifest
  local src="$1" dest="$2" manifest="$3" name f
  if [ -f "$manifest" ]; then
    while IFS= read -r name; do
      [ -n "$name" ] || continue
      # Edited since we installed it: it is the user's file now, not ours.
      if [ -f "$dest/$name" ] && ! grep -q "llmcheats" "$dest/$name"; then
        echo "kept $dest/$name — edited since install, remove it by hand" >&2
        continue
      fi
      rm -f "$dest/$name"
    done <"$manifest"
  else
    for f in "$src"/*.md; do rm -f "$dest/$(basename -- "$f")"; done
  fi
}

install_claude() {
  local base docs_dir
  base="$(claude_base)"
  docs_dir="$base/llmcheats/docs"

  mkdir -p "$base/llmcheats"
  write_source_marker "$base/llmcheats"
  sync_md_dir "$SRC_DIR/agents" "$base/agents" "$base/llmcheats/agents.list" "agent"
  drop_flat_commands "$base" "$base/llmcheats/commands.list"
  sync_md_dir "$SRC_DIR/commands" "$base/commands/llmcheats" "$base/llmcheats/commands.list" "command"
  sync_skills "$base"
  copy_docs "$docs_dir"

  echo "claude: agents   -> $base/agents"
  echo "claude: commands -> $base/commands/llmcheats  (as /llmcheats:<name>)"
  echo "claude: skills   -> $base/skills"
  echo "claude: docs     -> $docs_dir"
}

uninstall_claude() {
  local base
  base="$(claude_base)"
  remove_md_dir "$SRC_DIR/agents" "$base/agents" "$base/llmcheats/agents.list"
  drop_flat_commands "$base" "$base/llmcheats/commands.list"
  remove_md_dir "$SRC_DIR/commands" "$base/commands/llmcheats" "$base/llmcheats/commands.list"
  rmdir "$base/commands/llmcheats" 2>/dev/null || true
  remove_skills "$base"
  rmdir "$base/skills" 2>/dev/null || true
  rm -rf "$base/llmcheats"
  echo "claude: removed agents, commands, skills and docs under $base"
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
  # Check the pointer file before writing anything: aborting on damaged markers
  # after the copy would leave docs on disk with nothing pointing at them.
  mkdir -p "$(dirname -- "$agents_md")"
  touch "$agents_md"
  check_markers "$agents_md"
  copy_docs "$docs_dir"
  write_source_marker "$(dirname -- "$docs_dir")"
  upsert_block "$agents_md" "$docs_ref"
  echo "codex: docs    -> $docs_dir"
  echo "codex: pointer -> $agents_md (managed block)"
}

uninstall_codex() {
  local docs_dir agents_md docs_ref
  codex_paths
  # Same order as install: refuse on damaged markers before deleting the docs
  # the surviving block would still point at.
  remove_block "$agents_md"
  rm -rf "$(dirname -- "$docs_dir")"
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

if [ "$action" = "install" ]; then
  echo "done. llmcheats — $REPO_URL"
else
  echo "done."
fi

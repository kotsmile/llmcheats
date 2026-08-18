#!/usr/bin/env bash
# llmcheats installer. Copies a knowledge base and one setup skill into a repo.
#
# This script is deliberately dumb: it detects no stacks, templates nothing, and
# never writes AGENTS.md. Specializing to a repo needs to read that repo, which
# is the setup skill's job (F-005: a generated command must be one that was
# actually observed).
set -euo pipefail

LLMCHEATS_REPO="${LLMCHEATS_REPO:-kotsmile/llmcheats}"
LLMCHEATS_REF="${LLMCHEATS_REF:-main}"
LLMCHEATS_TARBALL="${LLMCHEATS_TARBALL:-}"

AGENTS_ARG="both"
TARGET=""
FORCE=0
HERE=0

readonly MARKER_BEGIN='<!-- llmcheats:begin -->'
readonly MARKER_END='<!-- llmcheats:end -->'

usage() {
  cat <<'EOF'
llmcheats — bootstrap a repo so a bare prompt works in Claude Code and Codex.

USAGE
  install.sh [--agents claude|codex|both] [--ref REF] [--target DIR]
             [--here] [--force]

OPTIONS
  --agents LIST   Which agent trees to install into. Comma-separated.
                  claude -> .claude/skills/   codex -> .agents/skills/
                  Default: both
  --ref REF       Git ref to install from. Default: main
  --target DIR    Root to install the knowledge base into. Needs no git.
                  Default: the nearest .llmcheats/ at or above the current
                  directory, else the git top level, else it is an error.
  --here          Also install the skills into the current directory, pointed
                  at the knowledge base in the root. Use this when you launch
                  the agent from a subdirectory of the root, since neither
                  Claude Code nor Codex looks for skills in a parent directory.
  --force         Delete .llmcheats/ before installing. This is the only path
                  that discards generated files such as stack.md.
  --help          This text.

ENVIRONMENT
  LLMCHEATS_REPO      owner/name of the source repo. Default: kotsmile/llmcheats
  LLMCHEATS_REF       same as --ref
  LLMCHEATS_TARBALL   URL or file:// path to a payload tarball. Skips download,
                      which is how the test suite runs offline.

WHAT IT WRITES
  .llmcheats/docs/{best,flows}/   the reference corpus, verbatim
  .llmcheats/cheats/              routing table, workflows, practices
  .llmcheats/templates/           artifact templates
  .llmcheats/VERSION
  .claude/skills/llmcheats-*/     path-anchored stubs + the setup skill
  .agents/skills/llmcheats-*/     byte-identical twins of the above

  With --here the last two are written into the current directory as well,
  with every path in them rewritten to reach the root's .llmcheats/.

EXAMPLES
  install.sh                                  a git repo, agent launched at its root
  install.sh --target ~/Projects/a            no git anywhere; root is a
  install.sh --target ~/Projects/a --here     ...and you work from a/b/c/d
  install.sh --here                           a later refresh from a/b/c/d,
                                              which finds the root by walking up

WHAT IT NEVER TOUCHES
  AGENTS.md, CLAUDE.md, .llmcheats/stack.md, and anything outside the
  llmcheats:begin/llmcheats:end markers. Those belong to you and to the setup
  skill.
EOF
}

die() { printf 'llmcheats: %s\n' "$*" >&2; exit 1; }
say() { printf '  %s\n' "$*"; }

while [ $# -gt 0 ]; do
  case "$1" in
    --agents) [ $# -ge 2 ] || die "--agents needs a value"; AGENTS_ARG="$2"; shift 2 ;;
    --agents=*) AGENTS_ARG="${1#*=}"; shift ;;
    --ref) [ $# -ge 2 ] || die "--ref needs a value"; LLMCHEATS_REF="$2"; shift 2 ;;
    --ref=*) LLMCHEATS_REF="${1#*=}"; shift ;;
    --target) [ $# -ge 2 ] || die "--target needs a value"; TARGET="$2"; shift 2 ;;
    --target=*) TARGET="${1#*=}"; shift ;;
    --here) HERE=1; shift ;;
    --force) FORCE=1; shift ;;
    --help|-h) usage; exit 0 ;;
    *) die "unknown option: $1 (try --help)" ;;
  esac
done

want_claude=0
want_codex=0
_ifs="$IFS"; IFS=','
for a in $AGENTS_ARG; do
  case "$a" in
    claude) want_claude=1 ;;
    codex)  want_codex=1 ;;
    both)   want_claude=1; want_codex=1 ;;
    "")     ;;
    *) IFS="$_ifs"; die "unknown agent: $a (want claude, codex or both)" ;;
  esac
done
IFS="$_ifs"
[ "$want_claude" -eq 1 ] || [ "$want_codex" -eq 1 ] || die "--agents selected nothing"

CWD="$(pwd -P)"

# The root is wherever the knowledge base lives, and git is one way to find it
# rather than a requirement: a tree that was never a repo installs the same way.
# An existing install wins over the git top level so that a refresh lands on the
# one that is actually there, but the search never climbs out of a repository --
# a repo checked out below an installed root is its own project.
#
# The marker is VERSION, not .llmcheats/ itself: a working directory below the
# root holds a .llmcheats/ too once the setup skill writes stack.md into it, and
# that must not be mistaken for a second root.
nearest_install() {
  dir="$1"
  limit="$2"
  while :; do
    if [ -f "$dir/.llmcheats/VERSION" ]; then printf '%s' "$dir"; return 0; fi
    [ "$dir" = "$limit" ] && return 1
    [ "$dir" = "/" ] && return 1
    dir="$(dirname "$dir")"
  done
}

if [ -z "$TARGET" ]; then
  toplevel="$(git rev-parse --show-toplevel 2>/dev/null || true)"
  TARGET="$(nearest_install "$CWD" "${toplevel:-/}" || true)"
  [ -n "$TARGET" ] || TARGET="$toplevel"
  [ -n "$TARGET" ] || die "$(cat <<EOF
could not decide where to install.
  This is not a git repository, and no .llmcheats/ exists at or above
  $CWD

  Name the root explicitly. If you launch the agent from a subdirectory of it,
  add --here so the skills are installed where the agent will look:

    install.sh --target ~/Projects/a --here    knowledge base in a, skills here
    install.sh --target .                      root and working directory both here
EOF
)"
fi
[ -d "$TARGET" ] || die "target is not a directory: $TARGET"
TARGET="$(cd "$TARGET" && pwd -P)"

# A working directory that was attached once stays attached, so that a plain
# refresh cannot leave its stubs pointing at a layout that has moved on.
if [ "$HERE" -eq 0 ] && [ "$CWD" != "$TARGET" ]; then
  for existing in "$CWD/.claude/skills"/llmcheats-* "$CWD/.agents/skills"/llmcheats-*; do
    if [ -e "$existing" ]; then HERE=1; break; fi
  done
fi

# How to reach TARGET from CWD, as a path prefix ending in / (empty when they
# are the same directory). An absolute prefix is the fallback for a target that
# is not an ancestor -- correct, but it does not survive moving the tree.
PREFIX=""
if [ "$HERE" -eq 1 ] && [ "$CWD" != "$TARGET" ]; then
  case "$CWD" in
    "$TARGET"/*)
      rest="${CWD#"$TARGET"/}"
      _ifs="$IFS"; IFS='/'
      for _ in $rest; do PREFIX="$PREFIX../"; done
      IFS="$_ifs"
      ;;
    *) PREFIX="$TARGET/" ;;
  esac
fi

command -v tar >/dev/null 2>&1 || die "tar is required"

TMP="$(mktemp -d)"
cleanup() { rm -rf "$TMP"; }
trap cleanup EXIT INT TERM

# ---- fetch the payload -------------------------------------------------------

tarball="$TMP/payload.tar.gz"
if [ -n "$LLMCHEATS_TARBALL" ]; then
  case "$LLMCHEATS_TARBALL" in
    file://*) cp "${LLMCHEATS_TARBALL#file://}" "$tarball" ;;
    /*)       cp "$LLMCHEATS_TARBALL" "$tarball" ;;
    *)        command -v curl >/dev/null 2>&1 || die "curl is required"
              curl -fsSL "$LLMCHEATS_TARBALL" -o "$tarball" ;;
  esac
else
  command -v curl >/dev/null 2>&1 || die "curl is required"
  url="https://codeload.github.com/${LLMCHEATS_REPO}/tar.gz/${LLMCHEATS_REF}"
  curl -fsSL "$url" -o "$tarball" || die "download failed: $url"
fi

mkdir -p "$TMP/src"
tar -xzf "$tarball" -C "$TMP/src" || die "could not extract the payload tarball"

SRC="$(find "$TMP/src" -mindepth 1 -maxdepth 1 -type d | head -n 1)"
[ -n "$SRC" ] && [ -d "$SRC" ] || die "payload tarball had no top-level directory"

for required in docs/INDEX.md docs/devflow docs/webapp cheats/routing.md cheats/workflows skills/llmcheats-setup/SKILL.md; do
  [ -e "$SRC/$required" ] || die "payload is missing $required"
done

# ---- install -----------------------------------------------------------------

DEST="$TARGET/.llmcheats"

if [ "$FORCE" -eq 1 ] && [ -d "$DEST" ]; then
  rm -rf "$DEST"
  say "--force: removed the previous .llmcheats/ entirely"
fi

# Managed subtrees are replaced wholesale on every run. stack.md is not one of
# them, so a re-run refreshes knowledge without discarding what the skill wrote
# (F-023: a resume that cannot say what already exists is a restart).
mkdir -p "$DEST"
rm -rf "$DEST/docs" "$DEST/cheats" "$DEST/templates"
cp -R "$SRC/docs" "$DEST/docs"
cp -R "$SRC/cheats" "$DEST/cheats"
if [ -d "$SRC/templates" ]; then
  cp -R "$SRC/templates" "$DEST/templates"
else
  mkdir -p "$DEST/templates"
fi

# A codeload tarball is a git archive, and its pax global header carries the
# commit. Reading it here pins VERSION to a revision instead of a branch name
# that moves, without a second request. Falls back to the ref for a payload that
# was not produced by git archive.
sha="$(gunzip -c "$tarball" 2>/dev/null | dd bs=512 count=2 2>/dev/null | tr -d '\0' \
  | sed -n 's/.*comment=\([0-9a-f]\{7,40\}\).*/\1/p' || true)"
[ -n "$sha" ] || sha="$LLMCHEATS_REF"

printf 'repo=https://github.com/%s\nref=%s\n' "$LLMCHEATS_REPO" "$sha" > "$DEST/VERSION"

# ---- skills ------------------------------------------------------------------
#
# One stub per file in cheats/workflows/, generated from that file's own
# front-matter. Adding a workflow is therefore one file plus one routing row,
# with no edit here -- the extensibility contract, enforced rather than promised.

fm_field() {
  # fm_field <file> <key> -- read a scalar out of leading YAML front-matter.
  awk -v key="$2" '
    NR==1 && $0 != "---" { exit }
    NR==1 { next }
    $0 == "---" { exit }
    {
      k = $0; sub(/:.*/, "", k)
      if (k == key) {
        v = $0; sub(/^[^:]*:[ \t]*/, "", v)
        gsub(/^"|"$/, "", v)
        print v; exit
      }
    }
  ' "$1"
}

# base is the prefix that makes a knowledge-base path openable from the
# directory the skills are being installed into. Empty at the root; "../../" and
# the like for a working directory below it.
build_stage() {
  stage="$1"
  base="$2"

  stub_count=0
  for wf in "$SRC"/cheats/workflows/*.md; do
    [ -e "$wf" ] || continue
    slug="$(basename "$wf" .md)"
    desc="$(fm_field "$wf" description)"
    [ -n "$desc" ] || die "workflow $slug has no description in its front-matter"
    mkdir -p "$stage/llmcheats-$slug"
    {
      printf -- '---\n'
      printf 'name: llmcheats-%s\n' "$slug"
      printf 'description: %s\n' "$desc"
      printf -- '---\n\n'
      printf 'The knowledge base is `%s.llmcheats/`. Paths named inside it are relative\n' "$base"
      printf 'to `%s.llmcheats/cheats/`.\n\n' "$base"
      printf 'Read `%s.llmcheats/cheats/workflows/%s.md` and follow it exactly.\n' "$base" "$slug"
      printf 'Read every file that workflow names before acting on it.\n'
      printf 'Do not work from memory of a file you have not opened this session.\n'
    } > "$stage/llmcheats-$slug/SKILL.md"
    stub_count=$((stub_count + 1))
  done

  # The setup skill is prose, not a generated stub, so it is copied verbatim and
  # told where it is rather than rewritten line by line.
  setup_src="$SRC/skills/llmcheats-setup/SKILL.md"
  mkdir -p "$stage/llmcheats-setup"
  if [ -z "$base" ]; then
    cp "$setup_src" "$stage/llmcheats-setup/SKILL.md"
    return
  fi
  fm_end="$(awk 'NR>1 && $0 == "---" { print NR; exit }' "$setup_src")"
  [ -n "$fm_end" ] || die "the setup skill has no closing front-matter marker"
  {
    sed -n "1,${fm_end}p" "$setup_src"
    printf '\n> **You are in a working directory below the llmcheats root.** The knowledge\n'
    printf '> base is `%s.llmcheats/`, so every `.llmcheats/...` path below means\n' "$base"
    printf '> `%s.llmcheats/...` and is read from there.\n>\n' "$base"
    printf '> Write `AGENTS.md`, `CLAUDE.md` and `.llmcheats/stack.md` **here**, in the\n'
    printf '> current working directory. They describe this project, not the whole tree\n'
    printf '> above it, and the root may hold several projects that share one corpus.\n'
    sed -n "$((fm_end + 1)),\$p" "$setup_src"
  } > "$stage/llmcheats-setup/SKILL.md"
}

STAGE="$TMP/skills"
mkdir -p "$STAGE"
build_stage "$STAGE" ""

backed_up=0

# A directory matching llmcheats-* that we are not about to write, or that
# differs from what we are about to write, is somebody's own work. Copy it aside
# before the refresh rather than deleting it: this is the one place the
# installer removes a path it did not necessarily create.
install_skills_into() {
  stage="$1"
  basedir="$2"
  kind="$3"

  case "$kind" in
    claude) root="$basedir/.claude/skills" ;;
    codex)  root="$basedir/.agents/skills" ;;
  esac
  backup="$basedir/.bak-llmcheats/$kind"

  if [ -d "$root" ]; then
    for existing in "$root"/llmcheats-*; do
      [ -e "$existing" ] || continue
      name="$(basename "$existing")"
      if [ -d "$stage/$name" ] && diff -r "$stage/$name" "$existing" >/dev/null 2>&1; then
        continue
      fi
      mkdir -p "$backup"
      rm -rf "${backup:?}/$name"
      cp -R "$existing" "$backup/$name"
      backed_up=$((backed_up + 1))
    done
    rm -rf "$root"/llmcheats-*
  fi

  mkdir -p "$root"
  cp -R "$stage"/. "$root"/
}

install_both_trees() {
  [ "$want_claude" -eq 1 ] && install_skills_into "$1" "$2" claude
  [ "$want_codex" -eq 1 ] && install_skills_into "$1" "$2" codex
  return 0
}

install_both_trees "$STAGE" "$TARGET"

# --here: a second copy in the directory the agent is actually launched from,
# because neither Claude Code nor Codex looks for skills in a parent directory.
# Only the skills are duplicated -- there is still one corpus, in the root.
if [ -n "$PREFIX" ]; then
  STAGE_HERE="$TMP/skills-here"
  mkdir -p "$STAGE_HERE"
  build_stage "$STAGE_HERE" "$PREFIX"
  install_both_trees "$STAGE_HERE" "$CWD"
fi

# ---- report ------------------------------------------------------------------

echo
echo "llmcheats installed into $TARGET"
say ".llmcheats/docs/       $(find "$DEST/docs" -name '*.md' | wc -l | tr -d ' ') reference files"
say ".llmcheats/cheats/     routing table, $stub_count workflows, practices"
[ "$want_claude" -eq 1 ] && say ".claude/skills/        $((stub_count + 1)) skills"
[ "$want_codex" -eq 1 ]  && say ".agents/skills/        $((stub_count + 1)) skills"
if [ -n "$PREFIX" ]; then
  echo
  echo "Working directory $CWD"
  [ "$want_claude" -eq 1 ] && say ".claude/skills/        $((stub_count + 1)) skills, reading $PREFIX.llmcheats/"
  [ "$want_codex" -eq 1 ]  && say ".agents/skills/        $((stub_count + 1)) skills, reading $PREFIX.llmcheats/"
  say "One corpus, in the root. Launch the agent here and the skills resolve."
fi
if [ "$backed_up" -gt 0 ]; then
  echo
  say "$backed_up existing llmcheats-* skill dir(s) were not ours and were copied to"
  say ".bak-llmcheats/ before the refresh. Nothing was deleted outright."
fi
echo
echo "Next:"
echo "  1. Open the agent in this repo and run:"
echo "       /llmcheats-setup      (Claude Code)"
echo "       \$llmcheats-setup      (Codex)"
echo "     It reads your repo and writes AGENTS.md, CLAUDE.md and .llmcheats/stack.md."
echo "  2. Review the diff before committing. The setup skill does not commit,"
echo "     and every command it writes should be one that already exists here."
echo
echo "Re-running this installer refreshes the knowledge base and leaves"
echo "AGENTS.md, CLAUDE.md and .llmcheats/stack.md untouched. Only --force"
echo "discards them."

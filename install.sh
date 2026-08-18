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

readonly MARKER_BEGIN='<!-- llmcheats:begin -->'
readonly MARKER_END='<!-- llmcheats:end -->'

usage() {
  cat <<'EOF'
llmcheats — bootstrap a repo so a bare prompt works in Claude Code and Codex.

USAGE
  install.sh [--agents claude|codex|both] [--ref REF] [--target DIR] [--force]

OPTIONS
  --agents LIST   Which agent trees to install into. Comma-separated.
                  claude -> .claude/skills/   codex -> .agents/skills/
                  Default: both
  --ref REF       Git ref to install from. Default: main
  --target DIR    Repo to install into. Default: git rev-parse --show-toplevel
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
  .claude/skills/llmcheats-*/     three-line stubs + the setup skill
  .agents/skills/llmcheats-*/     byte-identical twins of the above

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

if [ -z "$TARGET" ]; then
  TARGET="$(git rev-parse --show-toplevel 2>/dev/null)" \
    || die "not inside a git repository; pass --target DIR"
  [ -n "$TARGET" ] || die "not inside a git repository; pass --target DIR"
fi
[ -d "$TARGET" ] || die "target is not a directory: $TARGET"
TARGET="$(cd "$TARGET" && pwd)"

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

STAGE="$TMP/skills"
mkdir -p "$STAGE"

stub_count=0
for wf in "$SRC"/cheats/workflows/*.md; do
  [ -e "$wf" ] || continue
  slug="$(basename "$wf" .md)"
  desc="$(fm_field "$wf" description)"
  [ -n "$desc" ] || die "workflow $slug has no description in its front-matter"
  mkdir -p "$STAGE/llmcheats-$slug"
  {
    printf -- '---\n'
    printf 'name: llmcheats-%s\n' "$slug"
    printf 'description: %s\n' "$desc"
    printf -- '---\n\n'
    printf 'Read `.llmcheats/cheats/workflows/%s.md` and follow it exactly.\n' "$slug"
    printf 'Read every file that workflow names before acting on it.\n'
    printf 'Do not work from memory of a file you have not opened this session.\n'
  } > "$STAGE/llmcheats-$slug/SKILL.md"
  stub_count=$((stub_count + 1))
done

mkdir -p "$STAGE/llmcheats-setup"
cp "$SRC/skills/llmcheats-setup/SKILL.md" "$STAGE/llmcheats-setup/SKILL.md"

BACKUP="$TARGET/.bak-llmcheats"
backed_up=0

# A directory matching llmcheats-* that we are not about to write, or that
# differs from what we are about to write, is somebody's own work. Copy it aside
# before the refresh rather than deleting it: this is the one place the
# installer removes a path it did not necessarily create.
install_skills_into() {
  root="$1"
  label="$2"

  if [ -d "$root" ]; then
    for existing in "$root"/llmcheats-*; do
      [ -e "$existing" ] || continue
      name="$(basename "$existing")"
      if [ -d "$STAGE/$name" ] && diff -r "$STAGE/$name" "$existing" >/dev/null 2>&1; then
        continue
      fi
      mkdir -p "$BACKUP/$label"
      rm -rf "${BACKUP:?}/$label/$name"
      cp -R "$existing" "$BACKUP/$label/$name"
      backed_up=$((backed_up + 1))
    done
    rm -rf "$root"/llmcheats-*
  fi

  mkdir -p "$root"
  cp -R "$STAGE"/. "$root"/
}

[ "$want_claude" -eq 1 ] && install_skills_into "$TARGET/.claude/skills" claude
[ "$want_codex" -eq 1 ] && install_skills_into "$TARGET/.agents/skills" codex

# ---- report ------------------------------------------------------------------

echo
echo "llmcheats installed into $TARGET"
say ".llmcheats/docs/       $(find "$DEST/docs" -name '*.md' | wc -l | tr -d ' ') reference files"
say ".llmcheats/cheats/     routing table, $stub_count workflows, practices"
[ "$want_claude" -eq 1 ] && say ".claude/skills/        $((stub_count + 1)) skills"
[ "$want_codex" -eq 1 ]  && say ".agents/skills/        $((stub_count + 1)) skills"
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

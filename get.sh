#!/usr/bin/env bash
#
# One-liner install, into the current directory as a project:
#
#   curl -fsSL https://raw.githubusercontent.com/kotsmile/llmcheats/main/get.sh | bash
#
# Keeps a checkout under ~/.local/share/llmcheats and fast-forwards it, so
# re-running this is also how you update. Nothing is overwritten: a file
# llmcheats did not install is backed up to a .bak-llmcheats copy first, and
# AGENTS.md keeps everything outside its managed block.
#
# Arguments pass through to install.sh:
#   ... | bash -s -- --global        install into ~/.claude and ~/.codex
#   ... | bash -s -- claude          Claude Code only
#   ... | bash -s -- uninstall       remove it again
#
set -euo pipefail

REPO_URL="https://github.com/kotsmile/llmcheats"
CHECKOUT="${LLMCHEATS_HOME:-${XDG_DATA_HOME:-$HOME/.local/share}/llmcheats}"
PROJECT="$PWD"

command -v git >/dev/null 2>&1 || {
  echo "error: git is required to install llmcheats" >&2
  exit 1
}

# Rebuild the positional parameters, pulling out the two flags this script
# owns. No arrays: macOS still ships bash 3.2.
want_global=0
has_project=0
n=$#
for ((i = 0; i < n; i++)); do
  a="$1"
  shift
  case "$a" in
    --global) want_global=1 ;;
    --project) has_project=1; set -- "$@" "$a" ;;
    *) set -- "$@" "$a" ;;
  esac
done

if [ -d "$CHECKOUT/.git" ]; then
  echo "llmcheats: updating checkout at $CHECKOUT"
  if ! git -C "$CHECKOUT" pull --ff-only --quiet; then
    echo "error: could not fast-forward $CHECKOUT" >&2
    echo "       resolve it there, or delete the directory and re-run" >&2
    exit 1
  fi
else
  if [ -e "$CHECKOUT" ]; then
    echo "error: $CHECKOUT exists but is not a git checkout — move it aside" >&2
    exit 1
  fi
  echo "llmcheats: cloning into $CHECKOUT"
  mkdir -p "$(dirname -- "$CHECKOUT")"
  git clone --quiet --depth 1 "$REPO_URL" "$CHECKOUT"
fi

if [ "$want_global" -eq 0 ] && [ "$has_project" -eq 0 ]; then
  set -- "$@" --project "$PROJECT"
  echo "llmcheats: installing into $PROJECT (pass --global for ~/.claude and ~/.codex)"
fi

exec "$CHECKOUT/install.sh" "$@"

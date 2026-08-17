#!/usr/bin/env bash
#
# Update every llmcheats install this machine has, without needing to remember
# where any of them came from. Each install leaves a SOURCE.md naming its
# checkout; this reads them, fast-forwards each checkout once, and reinstalls
# exactly the scopes it found. Run it from a project directory to catch that
# project's install too.
#
# Run with no arguments. `./install.sh update` is the equivalent when you are
# already standing in the checkout and know which scope you want.
#
set -euo pipefail

found=0
pulled=""

# Pull a checkout at most once even when several installs share it.
pull_once() { # $1 = checkout dir
  local dir="$1"
  case " $pulled " in *" $dir "*) return 0 ;; esac
  pulled="$pulled $dir"
  if ! git -C "$dir" rev-parse --git-dir >/dev/null 2>&1; then
    echo "warn: $dir is not a git checkout — reinstalling it as-is" >&2
    return 0
  fi
  if [ -n "$(git -C "$dir" status --porcelain)" ]; then
    echo "warn: $dir has uncommitted changes — reinstalling without pulling" >&2
    return 0
  fi
  echo "update: pulling $dir"
  git -C "$dir" pull --ff-only --quiet ||
    echo "warn: could not fast-forward $dir — reinstalling the current revision" >&2
}

# $1 = SOURCE.md, $2 = install.sh target, $3.. = extra install.sh args
reinstall_from() {
  local marker="$1" target="$2" checkout
  shift 2
  [ -f "$marker" ] || return 0
  checkout="$(sed -n 's/^Checkout:[[:space:]]*//p' "$marker" | head -1)"
  if [ -z "$checkout" ] || [ ! -x "$checkout/install.sh" ]; then
    echo "warn: $marker names no usable checkout — skipping" >&2
    return 0
  fi
  found=$((found + 1))
  pull_once "$checkout"
  echo "update: $target <- $checkout"
  "$checkout/install.sh" "$target" "$@"
}

reinstall_from "$HOME/.claude/llmcheats/SOURCE.md" claude
reinstall_from "$HOME/.codex/llmcheats/SOURCE.md" codex
reinstall_from "$PWD/.claude/llmcheats/SOURCE.md" claude --project "$PWD"
reinstall_from "$PWD/.llmcheats/SOURCE.md" codex --project "$PWD"

if [ "$found" -eq 0 ]; then
  echo "no llmcheats install found in ~/.claude, ~/.codex or $PWD" >&2
  echo "install it with:  curl -fsSL https://raw.githubusercontent.com/kotsmile/llmcheats/main/get.sh | bash" >&2
  exit 1
fi

echo "updated $found install(s)."

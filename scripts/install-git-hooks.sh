#!/usr/bin/env bash
# Symlink the repo's git hooks into this clone. Re-run after cloning; safe to run repeatedly.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
HOOK_DIR="$(cd "$ROOT" && git rev-parse --git-path hooks)"
HOOK_DIR="$(cd "$ROOT" && cd "$HOOK_DIR" && pwd)"

for hook in pre-commit pre-push; do
    src="$ROOT/scripts/git-hooks/$hook"
    dst="$HOOK_DIR/$hook"
    if [[ -e "$dst" && ! -L "$dst" ]]; then
        echo "refusing to overwrite existing non-symlink hook: $dst" >&2
        exit 1
    fi
    ln -sfn "$src" "$dst"
    echo "linked $hook -> $src"
done

echo "done. Bypass a hook with git --no-verify when you really need to."

#!/usr/bin/env zsh
# install-git-hooks.sh — installs repo git hooks into .git/hooks/
# Run once after git clone, or after adding new hooks.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
HOOKS_SRC="$REPO_ROOT/scripts/git-hooks"
HOOKS_DST="$REPO_ROOT/.git/hooks"

for hook in "$HOOKS_SRC"/*; do
  name="$(basename "$hook")"
  cp "$hook" "$HOOKS_DST/$name"
  chmod +x "$HOOKS_DST/$name"
  echo "✓ Installed: .git/hooks/$name"
done

echo "Git hooks installed."

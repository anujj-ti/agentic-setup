#!/usr/bin/env zsh
# install-git-hooks.sh — installs repo git hooks into .git/hooks/
# Run once after git clone, or after adding new hooks.
set -euo pipefail

# CR-03 fix: NULL_GLOB prevents "no matches found" crash when hooks dir is empty
setopt NULL_GLOB 2>/dev/null || true

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
HOOKS_SRC="$REPO_ROOT/scripts/git-hooks"
HOOKS_DST="$REPO_ROOT/.git/hooks"

# WR-02 fix: create .git/hooks/ if missing (handles git worktrees)
if [[ ! -d "$HOOKS_DST" ]]; then
  mkdir -p "$HOOKS_DST"
fi

installed=0
for hook in "$HOOKS_SRC"/*; do
  # With NULL_GLOB, the loop body is skipped entirely for an empty directory.
  # The -f guard handles any remaining edge cases (e.g., subdirectories).
  [[ -f "$hook" ]] || continue
  name="$(basename "$hook")"
  cp "$hook" "$HOOKS_DST/$name"
  chmod +x "$HOOKS_DST/$name"
  echo "✓ Installed: .git/hooks/$name"
  installed=$((installed + 1))
done

if [[ $installed -eq 0 ]]; then
  echo "No hooks found in $HOOKS_SRC — nothing installed."
else
  echo "$installed hook(s) installed."
fi

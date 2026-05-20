#!/usr/bin/env zsh
# revert-decision.sh — shell wrapper for revert-decision.js
# Usage: zsh revert-decision.sh --page-id <id> [--rollback-cmd <cmd>] [--dry-run]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
NODE="/opt/homebrew/opt/node@24/bin/node"

exec "$NODE" "$SCRIPT_DIR/revert-decision.js" "$@"

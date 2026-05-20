#!/usr/bin/env zsh
# update-decision.sh — shell wrapper for update-decision.js
# Usage: zsh update-decision.sh --page-id <id> --revert-status <active|reverted|pending_revert>
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
NODE="/opt/homebrew/opt/node@24/bin/node"

exec "$NODE" "$SCRIPT_DIR/update-decision.js" "$@"

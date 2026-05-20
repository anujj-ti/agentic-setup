#!/usr/bin/env zsh
# log-decision.sh — shell wrapper for log-decision.js (cc-openclaw json-response convention)
# Usage: echo '<json>' | zsh log-decision.sh [--dry-run]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
NODE="/opt/homebrew/opt/node@24/bin/node"

exec "$NODE" "$SCRIPT_DIR/log-decision.js" "$@"

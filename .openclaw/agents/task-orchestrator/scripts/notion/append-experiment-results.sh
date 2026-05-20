#!/usr/bin/env zsh
# append-experiment-results.sh — shell wrapper for append-experiment-results.js
# Usage: zsh append-experiment-results.sh --page-id <id> --results <text>
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
NODE="/opt/homebrew/opt/node@24/bin/node"

exec "$NODE" "$SCRIPT_DIR/append-experiment-results.js" "$@"

#!/usr/bin/env zsh
# query-decisions.sh — shell wrapper for query-decisions.js
# Usage: zsh query-decisions.sh [--since <ISO8601>]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
NODE="/opt/homebrew/opt/node@24/bin/node"

exec "$NODE" "$SCRIPT_DIR/query-decisions.js" "$@"

#!/usr/bin/env zsh
# create-experiment.sh — shell wrapper for create-experiment.js
# Usage: echo '{"hypothesis":"...","method":"...","success_criteria":"..."}' | zsh create-experiment.sh [--dry-run]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
NODE="/opt/homebrew/opt/node@24/bin/node"

exec "$NODE" "$SCRIPT_DIR/create-experiment.js" "$@"

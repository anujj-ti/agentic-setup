#!/usr/bin/env zsh
# verify-phase-10.sh — Phase 10 gate verification (8 checks)
# Usage: zsh verify-phase-10.sh
# Verifies: script existence, syntax, SECURITY.md gate rule, SOUL.md merge protocol, gate test, revert validation
set -euo pipefail

FAILURES=()

# Resolve devbot scripts path (worktree-aware)
# Check if the key files we created exist in live or in worktree
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
if [[ -f "$HOME/.openclaw/agents/devbot/scripts/devbot-merge-pr.sh" ]]; then
  DEVBOT_SCRIPTS="$HOME/.openclaw/agents/devbot/scripts"
  DEVBOT_DIR="$HOME/.openclaw/agents/devbot"
else
  # Worktree context (files not yet stowed to live)
  DEVBOT_SCRIPTS="$REPO_ROOT/.openclaw/agents/devbot/scripts"
  DEVBOT_DIR="$REPO_ROOT/.openclaw/agents/devbot"
fi

check() {
  local desc="$1"
  local result="$2"
  if [[ "$result" == "0" ]]; then
    print "PASS: $desc"
  else
    print "FAIL: $desc"
    FAILURES+=("$desc")
  fi
}

# CHECK 1 — Script files exist
check "devbot-merge-pr.sh exists" "$([[ -f "$DEVBOT_SCRIPTS/devbot-merge-pr.sh" ]] && echo 0 || echo 1)"
check "devbot-revert-merge.sh exists" "$([[ -f "$DEVBOT_SCRIPTS/devbot-revert-merge.sh" ]] && echo 0 || echo 1)"
check "notion-log-decision.js exists" "$([[ -f "$DEVBOT_SCRIPTS/notion-log-decision.js" ]] && echo 0 || echo 1)"

# CHECK 2 — Script syntax valid
check "devbot-merge-pr.sh syntax ok" "$(zsh -n "$DEVBOT_SCRIPTS/devbot-merge-pr.sh" 2>/dev/null && echo 0 || echo 1)"
check "devbot-revert-merge.sh syntax ok" "$(zsh -n "$DEVBOT_SCRIPTS/devbot-revert-merge.sh" 2>/dev/null && echo 0 || echo 1)"

# CHECK 3 — SECURITY.md contains the gate rule
check "SECURITY.md contains Notion page ID gate rule" "$(grep -q 'Notion page ID' "$DEVBOT_DIR/SECURITY.md" && echo 0 || echo 1)"

# CHECK 4 — SOUL.md contains merge protocol
check "SOUL.md contains Autonomous Merge Protocol" "$(grep -q 'Autonomous Merge Protocol' "$DEVBOT_DIR/SOUL.md" && echo 0 || echo 1)"
check "SOUL.md contains NEVER directive" "$(grep -q 'NEVER' "$DEVBOT_DIR/SOUL.md" && echo 0 || echo 1)"

# CHECK 5 — Gate test (negative): invoke devbot-merge-pr.sh without Notion env vars
# The merge script MUST exit non-zero when env vars are absent (Notion write will fail)
EXIT_CODE=0
( unset OPENCLAW_NOTION_DECISIONS_DB_ID 2>/dev/null; unset OPENCLAW_NOTION_TOKEN 2>/dev/null; zsh "$DEVBOT_SCRIPTS/devbot-merge-pr.sh" "0" 2>/dev/null ) && EXIT_CODE=0 || EXIT_CODE=$?
check "merge blocked when Notion env vars absent (exit ${EXIT_CODE})" "$([[ $EXIT_CODE -ne 0 ]] && echo 0 || echo 1)"

# CHECK 6 — Revert script arg validation
EXIT_CODE=0
( zsh "$DEVBOT_SCRIPTS/devbot-revert-merge.sh" 2>/dev/null ) && EXIT_CODE=0 || EXIT_CODE=$?
check "revert script exits non-zero without args" "$([[ $EXIT_CODE -ne 0 ]] && echo 0 || echo 1)"

# CHECK 7 — @notionhq/client installed (check in devbot scripts)
check "@notionhq/client importable from devbot scripts" "$( (cd "$DEVBOT_SCRIPTS" && /opt/homebrew/opt/node@24/bin/node -e "require('@notionhq/client')" 2>/dev/null) && echo 0 || echo 1)"

# CHECK 8 — No -m 1 flag in revert script (squash merge — single parent)
check "revert script correctly omits -m 1" "$(grep -v '^#' "$DEVBOT_SCRIPTS/devbot-revert-merge.sh" | grep -q '\-m 1' && echo 1 || echo 0)"

# --- Final summary ---
print ""
if [[ ${#FAILURES[@]} -eq 0 ]]; then
  print "=== Phase 10 PASSED (8/8 checks) ==="
  exit 0
else
  print "=== Phase 10 FAILED (${#FAILURES[@]} failures): ${FAILURES[*]} ==="
  exit 1
fi

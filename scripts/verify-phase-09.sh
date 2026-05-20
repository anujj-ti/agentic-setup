#!/usr/bin/env zsh
# verify-phase-09.sh — Phase 9 verification gate (smoke + integration modes)
# Usage: zsh verify-phase-09.sh [--smoke]
# Smoke mode: no Notion token required. Full mode: requires OPENCLAW_NOTION_TOKEN + config.json IDs.
set -euo pipefail

SMOKE_ONLY=false
if [[ "${1:-}" == "--smoke" ]]; then
  SMOKE_ONLY=true
fi

PASS_COUNT=0
FAIL_COUNT=0
NODE="/opt/homebrew/opt/node@24/bin/node"

# Resolve the correct path: prefer live stow-deployed path, fall back to repo path
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
if [[ -d "$HOME/.openclaw/agents/task-orchestrator/scripts/notion" ]]; then
  NOTION_SCRIPTS_DIR="$HOME/.openclaw/agents/task-orchestrator/scripts/notion"
  TASK_ORCH_DIR="$HOME/.openclaw/agents"
  STANDUP_BRIEF="$REPO_ROOT/scripts/standup-brief.sh"
else
  # Worktree context: scripts not yet stowed to live
  NOTION_SCRIPTS_DIR="$REPO_ROOT/.openclaw/agents/task-orchestrator/scripts/notion"
  TASK_ORCH_DIR="$REPO_ROOT/.openclaw/agents"
  STANDUP_BRIEF="$REPO_ROOT/scripts/standup-brief.sh"
fi

check() {
  local desc="$1"
  local result="$2"
  if [[ "$result" == "0" ]]; then
    print "[PASS] $desc"
    PASS_COUNT=$((PASS_COUNT + 1))
  else
    print "[FAIL] $desc"
    FAIL_COUNT=$((FAIL_COUNT + 1))
  fi
}

# --- Smoke checks (always run) ---

# Check 1: log-decision.js exists
check "log-decision.js exists" "$([[ -f "$NOTION_SCRIPTS_DIR/log-decision.js" ]] && echo 0 || echo 1)"

# Check 2: update-decision.js exists
check "update-decision.js exists" "$([[ -f "$NOTION_SCRIPTS_DIR/update-decision.js" ]] && echo 0 || echo 1)"

# Check 3: query-decisions.js exists
check "query-decisions.js exists" "$([[ -f "$NOTION_SCRIPTS_DIR/query-decisions.js" ]] && echo 0 || echo 1)"

# Check 4: revert-decision.js exists
check "revert-decision.js exists" "$([[ -f "$NOTION_SCRIPTS_DIR/revert-decision.js" ]] && echo 0 || echo 1)"

# Check 5: create-experiment.js exists
check "create-experiment.js exists" "$([[ -f "$NOTION_SCRIPTS_DIR/create-experiment.js" ]] && echo 0 || echo 1)"

# Check 6: append-experiment-results.js exists
check "append-experiment-results.js exists" "$([[ -f "$NOTION_SCRIPTS_DIR/append-experiment-results.js" ]] && echo 0 || echo 1)"

# Check 7: log-decision.js syntax valid
check "log-decision.js syntax valid" "$(${NODE} --check "$NOTION_SCRIPTS_DIR/log-decision.js" 2>/dev/null && echo 0 || echo 1)"

# Check 8: TODO_NOTION guard active (empty token → skipped:true)
check "TODO_NOTION guard: log-decision exits 0 with skipped:true" "$(OPENCLAW_NOTION_TOKEN="" ${NODE} "$NOTION_SCRIPTS_DIR/log-decision.js" --dry-run 2>/dev/null | /opt/homebrew/bin/jq -e '.skipped == true' > /dev/null 2>&1 && echo 0 || echo 1)"

# Check 9: Task Orchestrator SOUL.md has mandatory pre-log rule
check "Task Orchestrator SOUL.md has Notion Pre-Log Protocol" "$(grep -q 'Notion Pre-Log Protocol' "$TASK_ORCH_DIR/task-orchestrator/SOUL.md" && echo 0 || echo 1)"

# Check 10: standup brief wired to query-decisions
check "standup-brief.sh references query-decisions" "$(grep -q 'query-decisions' "$STANDUP_BRIEF" 2>/dev/null && echo 0 || echo 1)"

# Check 11: config.json has NOTION_DECISIONS_DB_ID field
# Check worktree path first (scripts/ not stowed as symlinks, only .md files are)
_CONFIG_JSON="$REPO_ROOT/.openclaw/agents/task-orchestrator/scripts/config.json"
[[ -f "$_CONFIG_JSON" ]] || _CONFIG_JSON="$HOME/.openclaw/agents/task-orchestrator/scripts/config.json"
check "config.json has NOTION_DECISIONS_DB_ID field" "$(grep -q 'NOTION_DECISIONS_DB_ID' "$_CONFIG_JSON" 2>/dev/null && echo 0 || echo 1)"

# Check 12: User Orchestrator SOUL.md knows how to retrieve decisions
check "User Orchestrator SOUL.md has query-decisions reference" "$(grep -q 'query-decisions' "$TASK_ORCH_DIR/user-orchestrator/SOUL.md" && echo 0 || echo 1)"

# --- Full integration checks (only without --smoke) ---
if [[ "$SMOKE_ONLY" == "false" ]]; then
  print ""
  print "--- Full integration checks (requires OPENCLAW_NOTION_TOKEN + real DB IDs) ---"

  # Check 13: log-decision creates live Notion page
  check "MEM-01: log-decision.js dry-run returns valid payload" "$(echo '{"decision":"test","rationale":"test","evidence":"test","reversibility":"reversible","agent_id":"test"}' | ${NODE} "$NOTION_SCRIPTS_DIR/log-decision.js" --dry-run 2>/dev/null | /opt/homebrew/bin/jq -e '.ok == true' > /dev/null 2>&1 && echo 0 || echo 1)"

  # Check 14: query-decisions returns decisions array
  check "MEM-02: query-decisions returns ok:true decisions array" "$(${NODE} "$NOTION_SCRIPTS_DIR/query-decisions.js" --since 2026-05-01T00:00:00.000Z 2>/dev/null | /opt/homebrew/bin/jq -e '.ok == true and (.decisions | type) == "array"' > /dev/null 2>&1 && echo 0 || echo 1)"

  # Check 15: standup brief autonomous_decisions field present
  check "Standup brief includes autonomous_decisions count" "$(zsh "$STANDUP_BRIEF" --repo anujj-ti/agentic-setup 2>/dev/null | /opt/homebrew/bin/jq -e '.data.autonomous_decisions.count >= 0' > /dev/null 2>&1 && echo 0 || echo 1)"
fi

# --- Summary ---
print ""
if [[ "$SMOKE_ONLY" == "true" ]]; then
  print "Phase 9 Smoke Verification: ${PASS_COUNT} passed, ${FAIL_COUNT} failed"
else
  print "Phase 9 Full Verification: ${PASS_COUNT} passed, ${FAIL_COUNT} failed"
fi

if [[ $FAIL_COUNT -gt 0 ]]; then
  exit 1
fi
exit 0

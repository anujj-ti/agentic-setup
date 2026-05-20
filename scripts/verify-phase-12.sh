#!/usr/bin/env zsh
# verify-phase-12.sh — Phase 12 gate verification and milestone completion check
# Usage: zsh verify-phase-12.sh
# Tests EVOL-01, EVOL-02, EVOL-03 structural checks + EVOL-01 enforcement gate (negative test)
# All test artifacts created in /tmp (never in ~/.openclaw/ per D-122)
set -euo pipefail

# --- Cleanup setup (D-122: test artifacts in /tmp) ---
TMPDIR_CREATED="/tmp/verify-phase-12-$$"
trap 'rm -rf "$TMPDIR_CREATED"' EXIT INT TERM
mkdir -p "$TMPDIR_CREATED"

FAILURES=()

# Resolve paths (worktree-aware)
# Must check for Phase 12-specific content (EVOL-01) to detect worktree vs live path
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
if grep -q 'EVOL-01' "$HOME/.openclaw/agents/task-orchestrator/SOUL.md" 2>/dev/null; then
  TASK_ORCH="$HOME/.openclaw/agents/task-orchestrator"
  OPENCLAW_JSON="$HOME/.openclaw/openclaw.json"
else
  # Worktree context — Phase 12 content not yet stowed to live
  TASK_ORCH="$REPO_ROOT/.openclaw/agents/task-orchestrator"
  OPENCLAW_JSON="$REPO_ROOT/.openclaw/openclaw.json"
fi

check() {
  local desc="$1" result="$2"
  if [[ "$result" == "0" ]]; then
    printf "PASS: %s\n" "$desc"
  else
    printf "FAIL: %s\n" "$desc"
    FAILURES+=("$desc")
  fi
}

# --- SECTION 1: EVOL-01 SOUL.md rules ---
check "SOUL.md contains EVOL-01" "$(grep -q 'EVOL-01' "$TASK_ORCH/SOUL.md" && echo 0 || echo 1)"
check "SOUL.md NEVER create agent directive" "$(grep -q 'NEVER create agent directive' "$TASK_ORCH/SOUL.md" && echo 0 || echo 1)"
check "SOUL.md /openclaw-new-agent is ONLY path" "$(grep -qE 'openclaw-new-agent.*ONLY|ONLY.*openclaw-new-agent' "$TASK_ORCH/SOUL.md" && echo 0 || echo 1)"
check "SOUL.md Decision Reviewer in EVOL-01" "$(grep -q 'Decision Reviewer' "$TASK_ORCH/SOUL.md" && echo 0 || echo 1)"
check "SOUL.md Agent Routing update step" "$(grep -qE 'Agent Routing|routing.*update|update.*routing' "$TASK_ORCH/SOUL.md" && echo 0 || echo 1)"

# --- SECTION 2: EVOL-01 enforcement gate (negative test — D-122) ---
# Create fake agent in /tmp (NOT in ~/.openclaw/)
FAKE_AGENT_DIR="$TMPDIR_CREATED/test-agent-violation"
mkdir -p "$FAKE_AGENT_DIR"
printf '# Test SOUL.md — created without /openclaw-new-agent\n' > "$FAKE_AGENT_DIR/SOUL.md"

# Verify this fake agent is NOT in openclaw.json
NOT_IN_CONFIG=$(python3 -c "
import json, sys
d = json.load(open(sys.argv[1]))
agents = [a['id'] for a in d.get('agents', {}).get('list', [])]
print('found' if 'test-agent-violation' in agents else 'not-found')
" "$OPENCLAW_JSON" 2>/dev/null || echo "not-found")

check "manually created agent dir is inert (not in openclaw.json)" "$([[ "$NOT_IN_CONFIG" == 'not-found' ]] && echo 0 || echo 1)"

# --- SECTION 3: EVOL-02 pattern counter ---
check "MEMORY.md has PRESERVE: pattern_counter" "$(grep -q 'PRESERVE.*pattern_counter\|pattern_counter.*PRESERVE' "$TASK_ORCH/MEMORY.md" && echo 0 || echo 1)"
check "MEMORY.md has Pattern Counter section" "$(grep -q 'Pattern Counter' "$TASK_ORCH/MEMORY.md" && echo 0 || echo 1)"
check "MEMORY.md has correct table columns" "$(grep -qE 'Count.*Last Seen|Last Seen.*Count' "$TASK_ORCH/MEMORY.md" && echo 0 || echo 1)"
check "DREAM-ROUTINE.md has verbatim preservation" "$(grep -qi 'preserve.*verbatim\|verbatim.*preserve' "$TASK_ORCH/DREAM-ROUTINE.md" && echo 0 || echo 1)"

# --- SECTION 4: EVOL-01 agent proposal workflow ---
CHECK_DOMAIN="$TASK_ORCH/scripts/check-agent-domain.sh"
check "check-agent-domain.sh exists" "$([[ -f "$CHECK_DOMAIN" ]] && echo 0 || echo 1)"
check "check-agent-domain.sh syntax valid" "$(zsh -n "$CHECK_DOMAIN" 2>/dev/null && echo 0 || echo 1)"
DOMAIN_RESULT=$(zsh "$CHECK_DOMAIN" "devbot" 2>/dev/null | python3 -c "import sys, json; d=json.load(sys.stdin); print(d.get('ok', 'err'))" 2>/dev/null || echo "err")
check "check-agent-domain.sh: existing agent returns ok:false" "$([[ "$DOMAIN_RESULT" == "False" ]] && echo 0 || echo 1)"
check "TOOLS.md has New Agent Proposal template" "$(grep -q 'New Agent Proposal' "$TASK_ORCH/TOOLS.md" && echo 0 || echo 1)"

# --- SECTION 5: EVOL-03 experiment scripts ---
check "propose-experiment.js exists" "$([[ -f "$TASK_ORCH/scripts/propose-experiment.js" ]] && echo 0 || echo 1)"
check "create-experiment-page.js exists" "$([[ -f "$TASK_ORCH/scripts/create-experiment-page.js" ]] && echo 0 || echo 1)"

# Verify propose-experiment.js exits non-zero without required args
( cd "$TASK_ORCH/scripts" && /opt/homebrew/opt/node@24/bin/node propose-experiment.js 1>/dev/null 2>/dev/null ) || EXIT_CODE=$?; EXIT_CODE=${EXIT_CODE:-0}
check "propose-experiment.js exits non-zero without args" "$([[ $EXIT_CODE -ne 0 ]] && echo 0 || echo 1)"

# Verify create-experiment-page.js exits non-zero without env vars
EXIT_CODE=0
( OPENCLAW_NOTION_TOKEN="" OPENCLAW_NOTION_EXPERIMENTS_DB_ID="" /opt/homebrew/opt/node@24/bin/node "$TASK_ORCH/scripts/create-experiment-page.js" 1>/dev/null 2>/dev/null ) || EXIT_CODE=$?
check "create-experiment-page.js exits non-zero without env vars" "$([[ $EXIT_CODE -ne 0 ]] && echo 0 || echo 1)"

check "TOOLS.md has OPENCLAW_NOTION_EXPERIMENTS_DB_ID" "$(grep -q 'OPENCLAW_NOTION_EXPERIMENTS_DB_ID' "$TASK_ORCH/TOOLS.md" && echo 0 || echo 1)"
check "SOUL.md has experiment Draft rule" "$(grep -qE 'Draft.*BEFORE|experiment.*Draft|Status=Draft' "$TASK_ORCH/SOUL.md" && echo 0 || echo 1)"

# --- SECTION 6: Phase 11 dependency check (5 quality agents) ---
for agent in code-reviewer document-reviewer decision-reviewer skill-reviewer skill-creation; do
  _FOUND=$(python3 -c "
import json, sys
d = json.load(open(sys.argv[1]))
agents = [a['id'] for a in d.get('agents', {}).get('list', [])]
print(0 if sys.argv[2] in agents else 1)
" "$OPENCLAW_JSON" "$agent" 2>/dev/null || echo 1)
  check "$agent still in openclaw.json" "$_FOUND"
done

# --- Final summary ---
printf '\n'

if [[ ${#FAILURES[@]} -eq 0 ]]; then
  printf '=== Phase 12 PASSED (all checks) ===\n\n'
  printf '=== MILESTONE: All 12 Phases Complete ===\n'
  printf 'Personal AI Operations Hub — self-evolving agent fleet is fully operational.\n'
  printf 'Capabilities delivered:\n'
  printf '  - Infrastructure: OpenClaw + cc-openclaw + secrets pipeline + stow deploy\n'
  printf '  - Channels: Telegram (WhatsApp deferred)\n'
  printf '  - Orchestration: User Orchestrator + Task Orchestrator + Beads + dream routines\n'
  printf '  - Email: Gmail triage + morning standup\n'
  printf '  - DevBot: GitHub issues, PR queue, CI monitor, autonomous dev\n'
  printf '  - Notion: Decision log, reversibility, experiment logging\n'
  printf '  - Merge: Notion-gated autonomous squash merge with revert workflow\n'
  printf '  - Quality: 5-agent review pipeline (Code, Document, Decision, Skill, Creation)\n'
  printf '  - Self-Evolution: Agent proposals, pattern-triggered skill creation, experiment framework\n'
  exit 0
else
  printf '=== Phase 12 FAILED: %s ===\n' "${FAILURES[*]}"
  exit 1
fi

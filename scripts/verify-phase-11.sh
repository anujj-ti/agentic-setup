#!/usr/bin/env zsh
# verify-phase-11.sh — Phase 11 structural verification covering all 8 QUAL requirements
# Usage: zsh verify-phase-11.sh
set -euo pipefail

FAILURES=()

# Resolve agent directory path (worktree-aware)
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
if [[ -d "$HOME/.openclaw/agents/code-reviewer" ]]; then
  AGENTS_DIR="$HOME/.openclaw/agents"
  OPENCLAW_JSON="$HOME/.openclaw/openclaw.json"
else
  # Worktree context (agents not yet stowed to live)
  AGENTS_DIR="$REPO_ROOT/.openclaw/agents"
  OPENCLAW_JSON="$REPO_ROOT/.openclaw/openclaw.json"
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

# --- SECTION 1: Agent directories and files ---
REVIEWER_AGENTS=(code-reviewer document-reviewer decision-reviewer skill-reviewer skill-creation)
for agent in "${REVIEWER_AGENTS[@]}"; do
  check "$agent directory exists" "$([[ -d "$AGENTS_DIR/$agent" ]] && echo 0 || echo 1)"
  check "$agent SOUL.md exists" "$([[ -f "$AGENTS_DIR/$agent/SOUL.md" ]] && echo 0 || echo 1)"
  check "$agent TOOLS.md exists" "$([[ -f "$AGENTS_DIR/$agent/TOOLS.md" ]] && echo 0 || echo 1)"
  check "$agent SECURITY.md exists" "$([[ -f "$AGENTS_DIR/$agent/SECURITY.md" ]] && echo 0 || echo 1)"
done

# --- SECTION 2: Verdict schema present in all SOUL.md files (QUAL-05) ---
for agent in "${REVIEWER_AGENTS[@]}"; do
  check "$agent SOUL.md has approved_at (D-111)" "$(grep -q 'approved_at' "$AGENTS_DIR/$agent/SOUL.md" && echo 0 || echo 1)"
  check "$agent SOUL.md has verdict" "$(grep -q 'verdict' "$AGENTS_DIR/$agent/SOUL.md" && echo 0 || echo 1)"
done

# --- SECTION 3: Task Orchestrator allowAgents (D-112) ---
ALLOWED=$(python3 -c "
import json, sys
d = json.load(open('$OPENCLAW_JSON'))
to = [a for a in d['agents']['list'] if a['id'] == 'task-orchestrator'][0]
print('\n'.join(to.get('subagents', {}).get('allowAgents', [])))
" 2>/dev/null || echo "")

for agent in "${REVIEWER_AGENTS[@]}"; do
  check "task-orchestrator allowAgents includes $agent" "$(echo "$ALLOWED" | grep -qx "$agent" && echo 0 || echo 1)"
done

# --- SECTION 4: Specific SOUL.md content checks ---
check "skill-creation NEVER stow rule" "$(grep -q 'NEVER' "$AGENTS_DIR/skill-creation/SOUL.md" && echo 0 || echo 1)"
check "skill-reviewer stow gate ownership (Task Orchestrator)" "$(grep -q 'Task Orchestrator' "$AGENTS_DIR/skill-reviewer/SOUL.md" && echo 0 || echo 1)"
check "decision-reviewer anti-circular rule" "$(grep -qiE 'Anti-Circular|pre-approved' "$AGENTS_DIR/decision-reviewer/SOUL.md" && echo 0 || echo 1)"
check "document-reviewer anti-vagueness rule" "$(grep -qi 'seems reasonable\|vague' "$AGENTS_DIR/document-reviewer/SOUL.md" && echo 0 || echo 1)"
check "code-reviewer diff-only rule" "$(grep -qi 'ONLY.*diff\|only.*diff\|ONLY the diff' "$AGENTS_DIR/code-reviewer/SOUL.md" && echo 0 || echo 1)"
check "Task Orchestrator Quality Pipeline Routing" "$(grep -q 'Quality Pipeline Routing' "$AGENTS_DIR/task-orchestrator/SOUL.md" && echo 0 || echo 1)"
check "Task Orchestrator convergence rule (3 times)" "$(grep -qE '3 times|3 consecutive' "$AGENTS_DIR/task-orchestrator/SOUL.md" && echo 0 || echo 1)"

# --- SECTION 5: Registry search script (QUAL-07) ---
SEARCH_SCRIPT="$AGENTS_DIR/skill-creation/scripts/search-skill-registries.sh"
check "search-skill-registries.sh exists" "$([[ -f "$SEARCH_SCRIPT" ]] && echo 0 || echo 1)"
check "search-skill-registries.sh syntax valid" "$(zsh -n "$SEARCH_SCRIPT" 2>/dev/null && echo 0 || echo 1)"
( zsh "$SEARCH_SCRIPT" "test-skill-pattern" 2>/dev/null 1>/dev/null ); EXIT_CODE=$?
check "search-skill-registries.sh exits 0 on test pattern" "$([[ $EXIT_CODE -eq 0 ]] && echo 0 || echo 1)"

# --- SECTION 6: openclaw.json registration for all 5 agents ---
for agent in "${REVIEWER_AGENTS[@]}"; do
  _AGENT_ID="$agent"
  _FOUND=$(python3 -c "
import json, sys
d = json.load(open('$OPENCLAW_JSON'))
agents = [a['id'] for a in d['agents']['list']]
print(0 if sys.argv[1] in agents else 1)
" "$_AGENT_ID" 2>/dev/null || echo 1)
  check "$agent registered in openclaw.json" "$_FOUND"
done

# --- Final summary ---
print ""
print "MANUAL VERIFICATION NOTE: Live feedback loop test (requires running gateway): send a known-bad diff to code-reviewer via Task Orchestrator sessions_spawn and confirm verdict='reject' is returned and routed back to DevBot. This is a manual verification step."
print ""

if [[ ${#FAILURES[@]} -eq 0 ]]; then
  print "=== Phase 11 PASSED (all checks) ==="
  exit 0
else
  print "=== Phase 11 FAILED: ${FAILURES[*]} ==="
  exit 1
fi

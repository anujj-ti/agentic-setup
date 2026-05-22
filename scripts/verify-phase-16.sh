#!/usr/bin/env zsh
# verify-phase-16.sh — Phase 16 Cross-Agent Learning Infrastructure structural verification gate
# Runs 10 structural checks covering LEARN-01 through LEARN-04.
# Exits 0 only if all 10 checks pass. Exits 1 if any check fails.
# Runtime behavior is NOT tested here (requires a live Synapse token).
set -euo pipefail

PASS=0
FAIL=0

REPO_DIR="$HOME/Documents/agentic-setup"

QUERY_SH="${REPO_DIR}/scripts/synapse-query-learnings.sh"
TASK_ORCH_AGENTS="${REPO_DIR}/.openclaw/agents/task-orchestrator/AGENTS.md"
TASK_ORCH_TOOLS="${REPO_DIR}/.openclaw/agents/task-orchestrator/TOOLS.md"
DEVBOT_AGENTS="${REPO_DIR}/.openclaw/agents/devbot/AGENTS.md"
CI_AGENTS="${REPO_DIR}/.openclaw/agents/ci-monitor/AGENTS.md"
EMAIL_AGENTS="${REPO_DIR}/.openclaw/agents/email-triage/AGENTS.md"
CI_DREAM="${REPO_DIR}/.openclaw/agents/ci-monitor/DREAM-ROUTINE.md"
DEVBOT_DREAM="${REPO_DIR}/.openclaw/agents/devbot/DREAM-ROUTINE.md"

pass() { print "CHECK $1 ($2): PASS" >&2; PASS=$(( PASS + 1 )) }
fail() { print "CHECK $1 ($2): FAIL — $3" >&2; FAIL=$(( FAIL + 1 )) }

# CHECK 1 — synapse-query-learnings.sh exists and is executable (LEARN-01 shared script)
if [[ -x "$QUERY_SH" ]]; then
  pass 1 "LEARN-01 — synapse-query-learnings.sh exists and is executable"
else
  if [[ ! -f "$QUERY_SH" ]]; then
    fail 1 "LEARN-01 — synapse-query-learnings.sh exists and is executable" "file not found at $QUERY_SH"
  else
    fail 1 "LEARN-01 — synapse-query-learnings.sh exists and is executable" "file exists but is not executable — run: chmod +x $QUERY_SH"
  fi
fi

# CHECK 2 — synapse-query-learnings.sh exits 0 with no token (non-blocking, D-304)
# An empty SYNAPSE_TOKEN triggers the token guard and exits 0 — no network call made.
SYNAPSE_TOKEN="" zsh "$QUERY_SH" project.agentic-setup openclaw 5 2>/dev/null
EXIT_CODE=$?
if [[ $EXIT_CODE -eq 0 ]]; then
  pass 2 "D-304 — synapse-query-learnings.sh exits 0 with missing token (non-blocking)"
else
  fail 2 "D-304 — synapse-query-learnings.sh exits 0 with missing token (non-blocking)" "exited with code $EXIT_CODE — script blocks on missing token (violates D-304)"
fi

# CHECK 3 — task-orchestrator AGENTS.md contains synapse-query-learnings.sh (LEARN-01)
if [[ -f "$TASK_ORCH_AGENTS" ]] && grep -q "synapse-query-learnings" "$TASK_ORCH_AGENTS"; then
  pass 3 "LEARN-01 — task-orchestrator AGENTS.md has synapse-query-learnings step"
else
  if [[ ! -f "$TASK_ORCH_AGENTS" ]]; then
    fail 3 "LEARN-01 — task-orchestrator AGENTS.md has synapse-query-learnings step" "AGENTS.md not found at $TASK_ORCH_AGENTS"
  else
    fail 3 "LEARN-01 — task-orchestrator AGENTS.md has synapse-query-learnings step" "'synapse-query-learnings' not found in task-orchestrator AGENTS.md"
  fi
fi

# CHECK 4 — devbot AGENTS.md contains synapse-query-learnings.sh (LEARN-01)
if [[ -f "$DEVBOT_AGENTS" ]] && grep -q "synapse-query-learnings" "$DEVBOT_AGENTS"; then
  pass 4 "LEARN-01 — devbot AGENTS.md has synapse-query-learnings step"
else
  if [[ ! -f "$DEVBOT_AGENTS" ]]; then
    fail 4 "LEARN-01 — devbot AGENTS.md has synapse-query-learnings step" "AGENTS.md not found at $DEVBOT_AGENTS"
  else
    fail 4 "LEARN-01 — devbot AGENTS.md has synapse-query-learnings step" "'synapse-query-learnings' not found in devbot AGENTS.md"
  fi
fi

# CHECK 5 — ci-monitor AGENTS.md contains synapse-query-learnings.sh (LEARN-01)
if [[ -f "$CI_AGENTS" ]] && grep -q "synapse-query-learnings" "$CI_AGENTS"; then
  pass 5 "LEARN-01 — ci-monitor AGENTS.md has synapse-query-learnings step"
else
  if [[ ! -f "$CI_AGENTS" ]]; then
    fail 5 "LEARN-01 — ci-monitor AGENTS.md has synapse-query-learnings step" "AGENTS.md not found at $CI_AGENTS"
  else
    fail 5 "LEARN-01 — ci-monitor AGENTS.md has synapse-query-learnings step" "'synapse-query-learnings' not found in ci-monitor AGENTS.md"
  fi
fi

# CHECK 6 — email-triage AGENTS.md contains synapse-query-learnings.sh (LEARN-01)
if [[ -f "$EMAIL_AGENTS" ]] && grep -q "synapse-query-learnings" "$EMAIL_AGENTS"; then
  pass 6 "LEARN-01 — email-triage AGENTS.md has synapse-query-learnings step"
else
  if [[ ! -f "$EMAIL_AGENTS" ]]; then
    fail 6 "LEARN-01 — email-triage AGENTS.md has synapse-query-learnings step" "AGENTS.md not found at $EMAIL_AGENTS"
  else
    fail 6 "LEARN-01 — email-triage AGENTS.md has synapse-query-learnings step" "'synapse-query-learnings' not found in email-triage AGENTS.md"
  fi
fi

# CHECK 7 — devbot AGENTS.md has ci-monitor cross-silo tag (LEARN-02)
if [[ -f "$DEVBOT_AGENTS" ]] && grep -q "ci-monitor" "$DEVBOT_AGENTS"; then
  pass 7 "LEARN-02 — devbot AGENTS.md has ci-monitor cross-silo tag"
else
  if [[ ! -f "$DEVBOT_AGENTS" ]]; then
    fail 7 "LEARN-02 — devbot AGENTS.md has ci-monitor cross-silo tag" "AGENTS.md not found at $DEVBOT_AGENTS"
  else
    fail 7 "LEARN-02 — devbot AGENTS.md has ci-monitor cross-silo tag" "'ci-monitor' cross-silo reference not found in devbot AGENTS.md"
  fi
fi

# CHECK 8 — task-orchestrator TOOLS.md has evidence_artifact_id schema reminder (LEARN-03)
if [[ -f "$TASK_ORCH_TOOLS" ]] && grep -q "evidence_artifact_id" "$TASK_ORCH_TOOLS"; then
  pass 8 "LEARN-03 — task-orchestrator TOOLS.md has evidence_artifact_id schema reminder"
else
  if [[ ! -f "$TASK_ORCH_TOOLS" ]]; then
    fail 8 "LEARN-03 — task-orchestrator TOOLS.md has evidence_artifact_id schema reminder" "TOOLS.md not found at $TASK_ORCH_TOOLS"
  else
    fail 8 "LEARN-03 — task-orchestrator TOOLS.md has evidence_artifact_id schema reminder" "'evidence_artifact_id' not found in task-orchestrator TOOLS.md"
  fi
fi

# CHECK 9 — ci-monitor DREAM-ROUTINE.md exists (LEARN-04)
if [[ -f "$CI_DREAM" ]]; then
  pass 9 "LEARN-04 — ci-monitor DREAM-ROUTINE.md exists"
else
  fail 9 "LEARN-04 — ci-monitor DREAM-ROUTINE.md exists" "DREAM-ROUTINE.md not found at $CI_DREAM"
fi

# CHECK 10 — devbot DREAM-ROUTINE.md exists (LEARN-04)
if [[ -f "$DEVBOT_DREAM" ]]; then
  pass 10 "LEARN-04 — devbot DREAM-ROUTINE.md exists"
else
  fail 10 "LEARN-04 — devbot DREAM-ROUTINE.md exists" "DREAM-ROUTINE.md not found at $DEVBOT_DREAM"
fi

print ""
print "Phase 16 verification: $((PASS))/$((PASS + FAIL)) checks passed"

if [[ $FAIL -eq 0 ]]; then
  print '{"ok":true,"data":{"pass":'"$PASS"',"total":'"$((PASS + FAIL))"'}}'
  exit 0
else
  print '{"ok":false,"data":{"pass":'"$PASS"',"total":'"$((PASS + FAIL))"',"failed":'"$FAIL"'}}'
  exit 1
fi

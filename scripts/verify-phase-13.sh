#!/usr/bin/env zsh
# verify-phase-13.sh — Phase 13 Synapse integration smoke test
# Runs 10 checks. Prints PASS/FAIL per check. Exits 1 if any fail, 0 if all pass.
set -euo pipefail

PASS_COUNT=0
FAIL_COUNT=0

pass() { print "CHECK $1: PASS — $2"; PASS_COUNT=$(( PASS_COUNT + 1 )) }
fail() { print "CHECK $1: FAIL — $2"; FAIL_COUNT=$(( FAIL_COUNT + 1 )) }

# CHECK 1: KEYCHAIN — SYNAPSE_TOKEN exists in Keychain
if security find-generic-password -s 'openclaw.synapse-token' -a 'trilogy' -w 2>/dev/null | grep -q .; then
  pass 1 "KEYCHAIN: openclaw.synapse-token exists in Keychain"
else
  fail 1 "KEYCHAIN: openclaw.synapse-token NOT found in Keychain — run: security add-generic-password -s openclaw.synapse-token -a trilogy -w '<token>'"
fi

# CHECK 2: SECRETS_SH — SYNAPSE_TOKEN in openclaw-secrets.sh (stow-deployed or source)
SECRETS_SH="${HOME}/.openclaw/scripts/openclaw-secrets.sh"
[[ ! -f "$SECRETS_SH" ]] && SECRETS_SH="${HOME}/Documents/agentic-setup/.openclaw/scripts/openclaw-secrets.sh"
if grep -q 'SYNAPSE_TOKEN' "$SECRETS_SH" 2>/dev/null; then
  pass 2 "SECRETS_SH: SYNAPSE_TOKEN found in $(basename $SECRETS_SH)"
else
  fail 2 "SECRETS_SH: SYNAPSE_TOKEN NOT in $SECRETS_SH"
fi

# CHECK 3: ENV_SH — SYNAPSE_TOKEN in openclaw-env.sh (stow-deployed or source)
ENV_SH="${HOME}/.openclaw/scripts/openclaw-env.sh"
[[ ! -f "$ENV_SH" ]] && ENV_SH="${HOME}/Documents/agentic-setup/.openclaw/scripts/openclaw-env.sh"
if grep -q 'SYNAPSE_TOKEN' "$ENV_SH" 2>/dev/null; then
  pass 3 "ENV_SH: SYNAPSE_TOKEN found in $(basename $ENV_SH)"
else
  fail 3 "ENV_SH: SYNAPSE_TOKEN NOT in $ENV_SH"
fi

# CHECK 4: SYNAPSE_URL_SECRETS — SYNAPSE_URL in openclaw-secrets.sh
if grep -q 'SYNAPSE_URL' "$SECRETS_SH" 2>/dev/null; then
  pass 4 "SYNAPSE_URL_SECRETS: SYNAPSE_URL found in $(basename $SECRETS_SH)"
else
  fail 4 "SYNAPSE_URL_SECRETS: SYNAPSE_URL NOT in $SECRETS_SH"
fi

# CHECK 5: SYNAPSE_URL_ENV — SYNAPSE_URL in openclaw-env.sh
if grep -q 'SYNAPSE_URL' "$ENV_SH" 2>/dev/null; then
  pass 5 "SYNAPSE_URL_ENV: SYNAPSE_URL found in $(basename $ENV_SH)"
else
  fail 5 "SYNAPSE_URL_ENV: SYNAPSE_URL NOT in $ENV_SH"
fi

# CHECK 6: CHECKIN_SCRIPT — synapse-checkin.sh exists and is executable
if test -x ~/Documents/agentic-setup/scripts/synapse-checkin.sh; then
  pass 6 "CHECKIN_SCRIPT: synapse-checkin.sh exists and is executable"
else
  fail 6 "CHECKIN_SCRIPT: synapse-checkin.sh missing or not executable at ~/Documents/agentic-setup/scripts/"
fi

# CHECK 7: LEARNING_SCRIPT — synapse-record-learning.sh exists and is executable
if test -x ~/Documents/agentic-setup/scripts/synapse-record-learning.sh; then
  pass 7 "LEARNING_SCRIPT: synapse-record-learning.sh exists and is executable"
else
  fail 7 "LEARNING_SCRIPT: synapse-record-learning.sh missing or not executable at ~/Documents/agentic-setup/scripts/"
fi

# CHECK 8: EXECUTION_AGENTS — all 8 execution-tier agents have Synapse (Mandatory) in TOOLS.md
AGENTS=(devbot ci-monitor email-triage code-reviewer document-reviewer decision-reviewer skill-reviewer skill-creation)
MISSING_AGENTS=()
for agent in "${AGENTS[@]}"; do
  if ! grep -q 'Synapse (Mandatory)' ~/.openclaw/agents/$agent/TOOLS.md 2>/dev/null; then
    MISSING_AGENTS+=("$agent")
  fi
done
if [[ ${#MISSING_AGENTS[@]} -eq 0 ]]; then
  pass 8 "EXECUTION_AGENTS: all 8 execution-tier agents have Synapse (Mandatory) in TOOLS.md"
else
  fail 8 "EXECUTION_AGENTS: missing Synapse section in: ${MISSING_AGENTS[*]}"
fi

# CHECK 9: TASK_ORCH — Task Orchestrator AGENTS.md references Synapse
if grep -q 'Synapse' ~/.openclaw/agents/task-orchestrator/AGENTS.md 2>/dev/null; then
  pass 9 "TASK_ORCH: task-orchestrator AGENTS.md references Synapse"
else
  fail 9 "TASK_ORCH: Synapse NOT found in ~/.openclaw/agents/task-orchestrator/AGENTS.md"
fi

# CHECK 10: USER_ORCH — User Orchestrator AGENTS.md has brief.fetch
if grep -q 'brief.fetch' ~/.openclaw/agents/user-orchestrator/AGENTS.md 2>/dev/null; then
  pass 10 "USER_ORCH: user-orchestrator AGENTS.md has brief.fetch"
else
  fail 10 "USER_ORCH: brief.fetch NOT found in ~/.openclaw/agents/user-orchestrator/AGENTS.md"
fi

# Summary
print ""
print "=== Phase 13 Verification Summary ==="
print "PASS: $PASS_COUNT / 10"
print "FAIL: $FAIL_COUNT / 10"

if [[ $FAIL_COUNT -gt 0 ]]; then
  print "RESULT: FAIL — $FAIL_COUNT check(s) need attention before Phase 13 is complete"
  exit 1
else
  print "RESULT: ALL PASS — Phase 13 Synapse integration verified"
  exit 0
fi

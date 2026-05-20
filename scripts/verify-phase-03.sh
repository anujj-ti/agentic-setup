#!/usr/bin/env zsh
# verify-phase-03.sh — smoke test runner for Phase 3 agent infrastructure
# Source: PLAN 03-02 Task 1 — validates user-orchestrator and task-orchestrator scaffolding
# Usage: zsh scripts/verify-phase-03.sh
# On success: stdout JSON {"ok":true,"data":{"checks_passed":N,"checks_total":N,"details":{...}}}
# On failure: stdout JSON {"ok":false,"error":"N checks failed","data":{...}} + exit 1
# WARN checks (task-orchestrator presence) do not count as failures — they are informational.
set -euo pipefail

PASS=0
FAIL=0
WARN=0
FAILURES=()
WARNINGS=()
DETAILS=()

JQ_BIN="/opt/homebrew/bin/jq"
CURL_BIN="/usr/bin/curl"
OPENCLAW_JSON="$HOME/.openclaw/openclaw.json"
GATEWAY_AUTH="Authorization: Bearer 2fd64cb5a158024be7e216f2c8508fa1d20fa3e422665315"
GATEWAY_URL="http://localhost:18789"

check() {
  local label="$1"
  shift
  if "$@" &>/dev/null; then
    print "  [PASS] ${label}" >&2
    (( PASS++ )) || true
    DETAILS+=("\"${label}\":\"pass\"")
  else
    print "  [FAIL] ${label}" >&2
    (( FAIL++ )) || true
    FAILURES+=("${label}")
    DETAILS+=("\"${label}\":\"fail\"")
  fi
}

warn_check() {
  local label="$1"
  shift
  if "$@" &>/dev/null; then
    print "  [PASS] ${label}" >&2
    (( PASS++ )) || true
    DETAILS+=("\"${label}\":\"pass\"")
  else
    print "  [WARN] ${label} (not yet deployed)" >&2
    (( WARN++ )) || true
    WARNINGS+=("${label}")
    DETAILS+=("\"${label}\":\"warn\"")
  fi
}

print "Phase 3 Infrastructure Verification" >&2
print "=====================================" >&2

# Check 1: Gateway health (HTTP 200)
print "Checking gateway health..." >&2
check "gateway-health" \
  bash -c "${CURL_BIN} -s -o /dev/null -w '%{http_code}' '${GATEWAY_URL}/health' -H '${GATEWAY_AUTH}' | grep -q '200'"

# Check 2: user-orchestrator in agents.list
print "Checking user-orchestrator registration..." >&2
check "user-orch-registered" \
  bash -c "${JQ_BIN} -e '.agents.list[] | select(.id == \"user-orchestrator\")' '${OPENCLAW_JSON}'"

# Check 3: task-orchestrator in agents.list (WARN if missing — may not be deployed yet)
print "Checking task-orchestrator registration (warn if missing)..." >&2
warn_check "task-orch-registered" \
  bash -c "${JQ_BIN} -e '.agents.list[] | select(.id == \"task-orchestrator\")' '${OPENCLAW_JSON}'"

# Check 4: Telegram binding points to user-orchestrator
print "Checking Telegram binding..." >&2
check "telegram-binding" \
  bash -c "${JQ_BIN} -e '.bindings[] | select(.match.channel == \"telegram\" and .match.accountId == \"main\") | select(.agentId == \"user-orchestrator\")' '${OPENCLAW_JSON}'"

# Check 5: user-orchestrator workspace directory exists
print "Checking user-orchestrator workspace..." >&2
check "user-orch-workspace" \
  bash -c "[[ -d '$HOME/.openclaw/workspace-user-orchestrator' ]]"

# Check 6: task-orchestrator workspace directory (WARN if missing)
print "Checking task-orchestrator workspace (warn if missing)..." >&2
warn_check "task-orch-workspace" \
  bash -c "[[ -d '$HOME/.openclaw/workspace-task-orchestrator' ]]"

# Check 7: user-orchestrator sessions directory exists
print "Checking user-orchestrator sessions directory..." >&2
check "user-orch-sessions" \
  bash -c "[[ -d '$HOME/.openclaw/agents/user-orchestrator/sessions' ]]"

# Check 8: task-orchestrator sessions directory (WARN if missing)
print "Checking task-orchestrator sessions directory (warn if missing)..." >&2
warn_check "task-orch-sessions" \
  bash -c "[[ -d '$HOME/.openclaw/agents/task-orchestrator/sessions' ]]"

# Check 9: user-orchestrator SOUL.md is a stow symlink (not a plain file)
print "Checking user-orchestrator stow symlink..." >&2
check "user-orch-stowed" \
  bash -c "[[ -L '$HOME/.openclaw/agents/user-orchestrator/SOUL.md' ]]"

# Assemble result
TOTAL=$(( PASS + FAIL ))
print "" >&2
print "Results: ${PASS} passed, ${FAIL} failed, ${WARN} warnings (of $(( TOTAL + WARN )) total checks)" >&2

# Build details JSON
DETAILS_STR=$(IFS=','; echo "${DETAILS[*]}")

if (( FAIL == 0 )); then
  print "{\"ok\":true,\"data\":{\"checks_passed\":${PASS},\"checks_warned\":${WARN},\"checks_total\":$(( PASS + FAIL + WARN )),\"details\":{${DETAILS_STR}}}}"
else
  FAILED_STR=$(printf '"%s",' "${FAILURES[@]}" | sed 's/,$//')
  print "{\"ok\":false,\"error\":\"${FAIL} checks failed\",\"data\":{\"checks_passed\":${PASS},\"checks_failed\":${FAIL},\"checks_warned\":${WARN},\"checks_total\":$(( PASS + FAIL + WARN )),\"failures\":[${FAILED_STR}],\"details\":{${DETAILS_STR}}}}"
  exit 1
fi

#!/usr/bin/env zsh
# verify-phase-04.sh — smoke test runner for Phase 4 Beads + Task Orchestrator
# Source: PLAN 04-01 Task 2 — validates INFRA-05, ORCH-03, ORCH-04
# Usage: zsh scripts/verify-phase-04.sh
# On success: stdout JSON {"ok":true,"data":{"checks_passed":6,"checks_total":6}}
# On failure: stdout JSON {"ok":false,"error":"N checks failed","data":{...}} + exit 1
set -euo pipefail

BD="/opt/homebrew/opt/node@24/bin/bd"
BEADS_DIR_PATH="$HOME/.openclaw/beads"

PASS=0
FAIL=0
FAILURES=()
DETAILS=()

check() {
  local label="$1"
  shift
  if "$@" &>/dev/null 2>&1; then
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

print "Phase 4 Beads Infrastructure Verification" >&2
print "===========================================" >&2

# Check 1: dolt installed (INFRA-05 prerequisite)
print "Checking dolt installed..." >&2
check "dolt-installed" \
  brew list dolt

# Check 2: bd 1.0.4 at the canonical node@24 path (INFRA-05)
print "Checking bd version at /opt/homebrew/opt/node@24/bin/bd..." >&2
check "bd-version" \
  bash -c '"/opt/homebrew/opt/node@24/bin/bd" --version 2>&1 | grep -q "1.0.4"'

# Check 3: BEADS_DIR initialized with embeddeddolt/ subdirectory (INFRA-05)
print "Checking beads-dir initialized..." >&2
check "beads-dir-initialized" \
  test -d "${BEADS_DIR_PATH}/embeddeddolt"

# Check 4: BEADS_DIR export present in openclaw-secrets.sh (INFRA-05)
print "Checking beads-dir in openclaw-secrets.sh..." >&2
check "beads-dir-in-secrets-sh" \
  zsh -c 'grep -v "^#" "$HOME/.openclaw/scripts/openclaw-secrets.sh" | grep -q "BEADS_DIR"'

# Check 5: bd ready --json runs without error using BEADS_DIR (ORCH-03)
print "Checking bd ready --json works..." >&2
check "bd-ready-works" \
  bash -c "BEADS_DIR=\"${BEADS_DIR_PATH}\" \"/opt/homebrew/opt/node@24/bin/bd\" ready --json"

# Check 6: Task Orchestrator SOUL.md has Beads mandatory rule (ORCH-04)
# Looks for sessions_spawn in the context of Beads contract language
print "Checking soul-has-beads-rule in SOUL.md..." >&2
check "soul-has-beads-rule" \
  zsh -c 'grep -q "sessions_spawn" "$HOME/.openclaw/agents/task-orchestrator/SOUL.md" && grep -q "Beads\|BEADS\|beads" "$HOME/.openclaw/agents/task-orchestrator/SOUL.md"'

# Summary line
TOTAL=6
print "" >&2
print "Results: ${PASS} passed, ${FAIL} failed, 0 warnings (of ${TOTAL} total checks)" >&2

# Build details JSON fragment
DETAILS_JSON=""
for entry in "${DETAILS[@]}"; do
  if [[ -n "$DETAILS_JSON" ]]; then
    DETAILS_JSON="${DETAILS_JSON},${entry}"
  else
    DETAILS_JSON="${entry}"
  fi
done

# Output JSON to stdout
if [[ $FAIL -eq 0 ]]; then
  print "{\"ok\":true,\"data\":{\"checks_passed\":${PASS},\"checks_total\":${TOTAL},\"details\":{${DETAILS_JSON}}}}"
  exit 0
else
  FAIL_LIST=""
  for f in "${FAILURES[@]}"; do
    if [[ -n "$FAIL_LIST" ]]; then
      FAIL_LIST="${FAIL_LIST},\"${f}\""
    else
      FAIL_LIST="\"${f}\""
    fi
  done
  print "{\"ok\":false,\"error\":\"${FAIL} checks failed\",\"data\":{\"checks_passed\":${PASS},\"checks_total\":${TOTAL},\"failed\":[${FAIL_LIST}],\"details\":{${DETAILS_JSON}}}}"
  exit 1
fi

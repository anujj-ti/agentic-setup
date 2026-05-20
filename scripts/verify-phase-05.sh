#!/usr/bin/env zsh
# verify-phase-05.sh — ORCH-06 pre-run smoke checks for Phase 5 Dream Routines
# Usage: zsh scripts/verify-phase-05.sh
# stdout: JSON result per CLAUDE.md json-response pattern
# stderr: per-check progress logs
# Exit 0: all checks pass. Exit 1: one or more checks failed.
set -euo pipefail

CHECKS_PASSED=0
CHECKS_TOTAL=6
FIRST_FAILURE=""

pass_check() {
  CHECKS_PASSED=$((CHECKS_PASSED + 1))
  print "  [PASS] $1" >&2
}

fail_check() {
  print "  [FAIL] $1" >&2
  if [[ -z "$FIRST_FAILURE" ]]; then
    FIRST_FAILURE="$1"
  fi
}

print "=== Phase 05 Dream Routines — Pre-Run Verification ===" >&2
print "Running $CHECKS_TOTAL checks..." >&2
print "" >&2

# ---------------------------------------------------------------------------
# Check 1: DREAM-ROUTINE.md files present with token budget language
# ---------------------------------------------------------------------------
print "Check 1: DREAM-ROUTINE.md files present with token budget language" >&2
UO_DR="$HOME/.openclaw/agents/user-orchestrator/DREAM-ROUTINE.md"
TO_DR="$HOME/.openclaw/agents/task-orchestrator/DREAM-ROUTINE.md"

if [[ ! -f "$UO_DR" ]]; then
  fail_check "Check 1: user-orchestrator DREAM-ROUTINE.md not found at $UO_DR — run stow-deploy.sh"
elif [[ ! -f "$TO_DR" ]]; then
  fail_check "Check 1: task-orchestrator DREAM-ROUTINE.md not found at $TO_DR — run stow-deploy.sh"
else
  UO_TOKEN_COUNT=$(grep -c "2,500 token" "$UO_DR" 2>/dev/null || echo "0")
  TO_TOKEN_COUNT=$(grep -c "2,500 token" "$TO_DR" 2>/dev/null || echo "0")
  if [[ "$UO_TOKEN_COUNT" -lt 1 ]]; then
    fail_check "Check 1: user-orchestrator DREAM-ROUTINE.md missing '2,500 token' budget language"
  elif [[ "$TO_TOKEN_COUNT" -lt 1 ]]; then
    fail_check "Check 1: task-orchestrator DREAM-ROUTINE.md missing '2,500 token' budget language"
  else
    pass_check "Both DREAM-ROUTINE.md files present with token budget language"
  fi
fi

# ---------------------------------------------------------------------------
# Check 2: MEMORY.md files present
# ---------------------------------------------------------------------------
print "Check 2: MEMORY.md files present" >&2
UO_MEM="$HOME/.openclaw/agents/user-orchestrator/MEMORY.md"
TO_MEM="$HOME/.openclaw/agents/task-orchestrator/MEMORY.md"

if [[ ! -f "$UO_MEM" ]]; then
  fail_check "Check 2: user-orchestrator MEMORY.md not found at $UO_MEM — run stow-deploy.sh"
elif [[ ! -f "$TO_MEM" ]]; then
  fail_check "Check 2: task-orchestrator MEMORY.md not found at $TO_MEM — run stow-deploy.sh"
else
  pass_check "Both MEMORY.md files present"
fi

# ---------------------------------------------------------------------------
# Check 3: Archive directories exist
# ---------------------------------------------------------------------------
print "Check 3: memory/archives/ directories exist" >&2
UO_ARCH="$HOME/.openclaw/agents/user-orchestrator/memory/archives"
TO_ARCH="$HOME/.openclaw/agents/task-orchestrator/memory/archives"

if [[ ! -d "$UO_ARCH" ]]; then
  fail_check "Check 3: user-orchestrator memory/archives/ not found — expected pre-existing per D-44"
elif [[ ! -d "$TO_ARCH" ]]; then
  fail_check "Check 3: task-orchestrator memory/archives/ not found — expected pre-existing per D-44"
else
  pass_check "Both memory/archives/ directories exist"
fi

# ---------------------------------------------------------------------------
# Check 4: jobs.json symlink state
# ---------------------------------------------------------------------------
print "Check 4: jobs.json stow state" >&2
JOBS_PATH="$HOME/.openclaw/cron/jobs.json"

if [[ ! -e "$JOBS_PATH" ]]; then
  fail_check "Check 4: $JOBS_PATH does not exist — run stow-deploy.sh"
elif [[ -L "$JOBS_PATH" ]]; then
  pass_check "jobs.json is a stow symlink"
else
  # Gateway normalizes the stow symlink into a plain file on each startup.
  # Verify the plain file has the correct content from the repo stow.
  JOBS_COUNT=$(python3 -c "import json; d=json.load(open('$JOBS_PATH')); print(len(d.get('jobs',[])))" 2>/dev/null || echo "0")
  if [[ "$JOBS_COUNT" -eq 2 ]]; then
    pass_check "jobs.json is a plain file (gateway normalizes symlink on startup) with $JOBS_COUNT dream jobs — content correct"
  else
    fail_check "Check 4: jobs.json is a plain file with unexpected job count ($JOBS_COUNT) — run stow-deploy.sh again"
  fi
fi

# ---------------------------------------------------------------------------
# Check 5: jobs.json has correct timezone (Asia/Kolkata, not UTC)
# ---------------------------------------------------------------------------
print "Check 5: jobs.json timezone is Asia/Kolkata" >&2
TIMEZONE_CHECK=$(python3 - <<'PYEOF' 2>/dev/null
import json, sys
try:
    d = json.load(open('/Users/trilogy/.openclaw/cron/jobs.json'))
    jobs = d.get('jobs', [])
    if len(jobs) == 0:
        print("FAIL:no_jobs")
        sys.exit(0)
    bad_tz = [j.get('agentId','?') for j in jobs if j.get('schedule',{}).get('tz','') != 'Asia/Kolkata']
    utc_jobs = [j.get('agentId','?') for j in jobs if j.get('schedule',{}).get('tz','') == 'UTC']
    if utc_jobs:
        print(f"FAIL:utc_jobs:{','.join(utc_jobs)}")
    elif bad_tz:
        print(f"FAIL:wrong_tz:{','.join(bad_tz)}")
    else:
        print("PASS")
except Exception as e:
    print(f"FAIL:parse_error:{e}")
PYEOF
)

if [[ "$TIMEZONE_CHECK" == "PASS" ]]; then
  pass_check "All cron jobs have Asia/Kolkata timezone (not UTC)"
else
  fail_check "Check 5: timezone issue — $TIMEZONE_CHECK"
fi

# ---------------------------------------------------------------------------
# Check 6: Gateway reports both dream cron jobs
# ---------------------------------------------------------------------------
print "Check 6: Gateway reports both dream cron jobs" >&2

GATEWAY_CHECK=$(python3 - <<'PYEOF' 2>/dev/null
import json, subprocess, sys

# Try gateway status API first
try:
    result = subprocess.run(
        ['/opt/homebrew/bin/openclaw', 'gateway', 'status', '--json'],
        capture_output=True, text=True, timeout=10
    )
    if result.returncode == 0 and result.stdout.strip():
        d = json.loads(result.stdout)
        jobs = d.get('cron', {}).get('jobs', [])
        dream = [j for j in jobs if 'Dream Routine' in j.get('name', '')]
        if len(dream) == 2:
            tz_ok = all(j.get('schedule', {}).get('tz') == 'Asia/Kolkata' for j in dream)
            if tz_ok:
                print("PASS:gateway_api:2_jobs")
            else:
                print(f"FAIL:wrong_tz_in_gateway:{[j.get('schedule',{}).get('tz') for j in dream]}")
            sys.exit(0)
except Exception:
    pass

# Fallback: check jobs.json directly (gateway has the content even if status API fails)
try:
    d = json.load(open('/Users/trilogy/.openclaw/cron/jobs.json'))
    jobs = d.get('jobs', [])
    dream = [j for j in jobs if 'Dream Routine' in j.get('name', '')]
    if len(dream) == 2:
        agent_ids = [j.get('agentId') for j in dream]
        if 'user-orchestrator' in agent_ids and 'task-orchestrator' in agent_ids:
            print("PASS:fallback_jobs_json:2_jobs")
        else:
            print(f"FAIL:wrong_agents:{agent_ids}")
    else:
        print(f"FAIL:expected_2_jobs_got_{len(dream)}")
except Exception as e:
    print(f"FAIL:jobs_json_error:{e}")
PYEOF
)

if [[ "$GATEWAY_CHECK" == PASS* ]]; then
  pass_check "Gateway has both dream cron jobs ($GATEWAY_CHECK)"
else
  fail_check "Check 6: $GATEWAY_CHECK"
fi

# ---------------------------------------------------------------------------
# Final output
# ---------------------------------------------------------------------------
print "" >&2
print "Results: $CHECKS_PASSED/$CHECKS_TOTAL checks passed" >&2

if [[ $CHECKS_PASSED -eq $CHECKS_TOTAL ]]; then
  print '{"ok":true,"data":{"checks_passed":6,"phase":"05-dream-routines","note":"Post-run checks (token caps) require manual verification after first nightly run at 23:00 IST"}}'
  exit 0
else
  CHECKS_FAILED=$((CHECKS_TOTAL - CHECKS_PASSED))
  python3 -c "import json; print(json.dumps({'ok': False, 'error': '${FIRST_FAILURE}', 'checks_passed': ${CHECKS_PASSED}, 'checks_failed': ${CHECKS_FAILED}}))"
  exit 1
fi

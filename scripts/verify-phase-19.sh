#!/usr/bin/env zsh
# verify-phase-19.sh — Phase 19 DevBot Autonomous Issue Pickup: Verification Gate
# Runs 10 checks. Exits 0 if all pass, exits 1 if any fail.
# GH_TOKEN check (10) uses SKIP if Keychain entry is absent.
set -euo pipefail

PASS_COUNT=0
SKIP_COUNT=0
FAIL_COUNT=0

REPO_DIR="/Users/trilogy/Documents/agentic-setup"
DEVBOT_SCRIPTS="$REPO_DIR/.openclaw/agents/devbot/scripts"
JOBS_JSON="$REPO_DIR/.openclaw/cron/jobs.json"
SOUL_MD="$REPO_DIR/.openclaw/agents/devbot/SOUL.md"
AGENTS_MD="$REPO_DIR/.openclaw/agents/devbot/AGENTS.md"

pass() { print "  CHECK $1: PASS — $2"; PASS_COUNT=$(( PASS_COUNT + 1 )) }
skip() { print "  CHECK $1: SKIP — $2"; SKIP_COUNT=$(( SKIP_COUNT + 1 )) }
fail() { print "  CHECK $1: FAIL — $2"; FAIL_COUNT=$(( FAIL_COUNT + 1 )) }

print "Phase 19 — DevBot Autonomous Issue Pickup: Verification"
print "========================================================="
print ""

# CHECK 1 — devbot-setup-labels.sh exists and passes syntax check (D-212)
if [[ -f "$DEVBOT_SCRIPTS/devbot-setup-labels.sh" ]] && zsh -n "$DEVBOT_SCRIPTS/devbot-setup-labels.sh" 2>/dev/null; then
  pass 1 "devbot-setup-labels.sh exists + syntax OK (D-212)"
else
  fail 1 "devbot-setup-labels.sh missing or syntax error — Plan 19-01 not complete"
fi

# CHECK 2 — devbot-issue-monitor.sh exists and passes syntax check (D-201)
if [[ -f "$DEVBOT_SCRIPTS/devbot-issue-monitor.sh" ]] && zsh -n "$DEVBOT_SCRIPTS/devbot-issue-monitor.sh" 2>/dev/null; then
  pass 2 "devbot-issue-monitor.sh exists + syntax OK (D-201)"
else
  fail 2 "devbot-issue-monitor.sh missing or syntax error — Plan 19-02 not complete"
fi

# CHECK 3 — devbot-stale-claim-guard.sh exists and passes syntax check (D-205)
if [[ -f "$DEVBOT_SCRIPTS/devbot-stale-claim-guard.sh" ]] && zsh -n "$DEVBOT_SCRIPTS/devbot-stale-claim-guard.sh" 2>/dev/null; then
  pass 3 "devbot-stale-claim-guard.sh exists + syntax OK (D-205)"
else
  fail 3 "devbot-stale-claim-guard.sh missing or syntax error — Plan 19-03 not complete"
fi

# CHECK 4 — all three new scripts are executable
if [[ -x "$DEVBOT_SCRIPTS/devbot-setup-labels.sh" && \
      -x "$DEVBOT_SCRIPTS/devbot-issue-monitor.sh" && \
      -x "$DEVBOT_SCRIPTS/devbot-stale-claim-guard.sh" ]]; then
  pass 4 "all three scripts are executable"
else
  fail 4 "one or more scripts not executable — run: chmod +x $DEVBOT_SCRIPTS/devbot-*.sh"
fi

# CHECK 5 — DevBot Issue Monitor cron job in jobs.json with */5 expression (D-201)
if [[ -f "$JOBS_JSON" ]]; then
  MONITOR_EXPR=$(python3 -c "
import json, sys
with open('$JOBS_JSON') as f:
  d = json.load(f)
j = next((x for x in d.get('jobs', []) if x.get('name') == 'DevBot Issue Monitor'), None)
print(j['schedule']['expr'] if j else '')
" 2>/dev/null) || MONITOR_EXPR=""
  if [[ "$MONITOR_EXPR" == "*/5 * * * *" ]]; then
    pass 5 "DevBot Issue Monitor cron: */5 * * * * (D-201)"
  else
    fail 5 "DevBot Issue Monitor cron missing or wrong expr (got: '$MONITOR_EXPR', expected: '*/5 * * * *') — Plan 19-04 not complete"
  fi
else
  fail 5 "jobs.json not found at $JOBS_JSON"
fi

# CHECK 6 — DevBot Stale Claim Guard cron job in jobs.json with 0 * * * * expression (D-205)
if [[ -f "$JOBS_JSON" ]]; then
  GUARD_EXPR=$(python3 -c "
import json, sys
with open('$JOBS_JSON') as f:
  d = json.load(f)
j = next((x for x in d.get('jobs', []) if x.get('name') == 'DevBot Stale Claim Guard'), None)
print(j['schedule']['expr'] if j else '')
" 2>/dev/null) || GUARD_EXPR=""
  if [[ "$GUARD_EXPR" == "0 * * * *" ]]; then
    pass 6 "DevBot Stale Claim Guard cron: 0 * * * * (D-205)"
  else
    fail 6 "DevBot Stale Claim Guard cron missing or wrong expr (got: '$GUARD_EXPR', expected: '0 * * * *') — Plan 19-04 not complete"
  fi
else
  fail 6 "jobs.json not found at $JOBS_JSON"
fi

# CHECK 7 — SOUL.md contains Autonomous Issue Pickup section
if grep -q 'Autonomous Issue Pickup' "$SOUL_MD" 2>/dev/null; then
  pass 7 "SOUL.md has Autonomous Issue Pickup section"
else
  fail 7 "SOUL.md missing Autonomous Issue Pickup section — Plan 19-04 not complete"
fi

# CHECK 8 — AGENTS.md contains pickup-queue check
if grep -q 'pickup-queue' "$AGENTS_MD" 2>/dev/null; then
  pass 8 "AGENTS.md has pickup-queue startup check"
else
  fail 8 "AGENTS.md missing pickup-queue reference — Plan 19-04 not complete"
fi

# CHECK 9 — issue monitor contains all required decision implementations
MONITOR_SCRIPT="$DEVBOT_SCRIPTS/devbot-issue-monitor.sh"
REQUIRED_PATTERNS=(
  "add-assignee"
  "issue develop"
  "pr create"
  "--auto"
  "Resolves"
  "automation:hold"
  "last-issue-timestamp"
)
ALL_PRESENT=0
MISSING_PATTERNS=()
for pattern in "${REQUIRED_PATTERNS[@]}"; do
  if ! grep -qF -- "$pattern" "$MONITOR_SCRIPT" 2>/dev/null; then
    ALL_PRESENT=1
    MISSING_PATTERNS+=("$pattern")
  fi
done

if [[ "$ALL_PRESENT" -eq 0 ]]; then
  pass 9 "issue monitor contains all D-204/D-207/D-208/D-209/D-210 patterns"
else
  fail 9 "issue monitor missing patterns: ${MISSING_PATTERNS[*]} — Plan 19-02 incomplete"
fi

# CHECK 10 — GH_TOKEN Keychain entry readable (non-empty check; value never echoed to stdout — T-19-13)
GH_TOKEN_VAL=$(security find-generic-password -s 'openclaw.github-bot-token' -a 'trilogy' -w 2>/dev/null || print "")
if [[ -n "$GH_TOKEN_VAL" ]]; then
  pass 10 "openclaw.github-bot-token readable from Keychain (DEV-08/DEV-09 prerequisite)"
else
  skip 10 "openclaw.github-bot-token not in Keychain — run: security add-generic-password -s openclaw.github-bot-token -a trilogy -w <token>"
fi

# --- Summary ---
print ""
print "========================================================="
print "=== Phase 19 Verification ==="
print "PASSED:  $PASS_COUNT"
print "SKIPPED: $SKIP_COUNT (require human action)"
print "FAILED:  $FAIL_COUNT"
print ""
if [[ "$FAIL_COUNT" -eq 0 ]]; then
  print "RESULT: PHASE 19 COMPLETE (${SKIP_COUNT} check(s) pending human action if any)"
  exit 0
else
  print "RESULT: PHASE 19 INCOMPLETE — fix $FAIL_COUNT failing check(s) above"
  exit 1
fi

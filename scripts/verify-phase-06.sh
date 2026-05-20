#!/usr/bin/env zsh
# verify-phase-06.sh — Smoke tests for Phase 06 (CHAN-03: Email Triage, CHAN-04: Morning Standup)
# Run from the agentic-setup repo root or any directory.
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
FAILED=0

echo "=== Phase 06 Smoke Checks ==="
echo "Repo dir: $REPO_DIR"
echo ""

# --- CHECK 1 (CHAN-03): email-triage agent in openclaw.json ---
if python3 -c "import json; d=json.load(open('$REPO_DIR/.openclaw/openclaw.json')); ids=[a['id'] for a in d['agents']['list']]; exit(0 if 'email-triage' in ids else 1)" 2>/dev/null; then
  echo "PASS [CHAN-03] email-triage in openclaw.json"
else
  echo "FAIL [CHAN-03] email-triage missing from openclaw.json"
  FAILED=1
fi

# --- CHECK 2 (CHAN-03): All 6 email-triage directive files exist ---
MISSING_FILES=0
for f in SOUL IDENTITY USER AGENTS TOOLS SECURITY; do
  if [[ ! -f "$REPO_DIR/.openclaw/agents/email-triage/$f.md" ]]; then
    echo "FAIL [CHAN-03] missing $f.md"
    MISSING_FILES=1
    FAILED=1
  fi
done
if [[ "$MISSING_FILES" == "0" ]]; then
  echo "PASS [CHAN-03] all 6 directive files exist (SOUL, IDENTITY, USER, AGENTS, TOOLS, SECURITY)"
fi

# --- CHECK 3 (CHAN-03): gmail-triage.js exists and contains setCredentials ---
if [[ -f "$REPO_DIR/.openclaw/agents/email-triage/scripts/gmail-triage.js" ]] && \
   grep -q "setCredentials" "$REPO_DIR/.openclaw/agents/email-triage/scripts/gmail-triage.js"; then
  echo "PASS [CHAN-03] gmail-triage.js exists with setCredentials"
else
  echo "FAIL [CHAN-03] gmail-triage.js missing or missing setCredentials"
  FAILED=1
fi

# --- CHECK 4 (CHAN-03): googleapis installed in agent scripts dir ---
if [[ -d "$REPO_DIR/.openclaw/agents/email-triage/scripts/node_modules/googleapis" ]]; then
  echo "PASS [CHAN-03] googleapis installed in agent scripts/"
else
  echo "FAIL [CHAN-03] googleapis not installed — run: cd .openclaw/agents/email-triage/scripts && npm install"
  FAILED=1
fi

# --- CHECK 5 (CHAN-03): Gmail Keychain export lines in openclaw-secrets.sh ---
if grep -q "OPENCLAW_GMAIL_CLIENT_ID" "$REPO_DIR/.openclaw/scripts/openclaw-secrets.sh" && \
   grep -q "OPENCLAW_GMAIL_TRIAGE_REFRESH_TOKEN" "$REPO_DIR/.openclaw/scripts/openclaw-secrets.sh"; then
  echo "PASS [CHAN-03] Gmail Keychain exports in openclaw-secrets.sh"
else
  echo "FAIL [CHAN-03] Gmail Keychain exports missing from openclaw-secrets.sh"
  FAILED=1
fi

# --- CHECK 6 (CHAN-03): TOOLS.md contains OAuth2 re-auth runbook ---
if grep -q "Re-Auth Runbook" "$REPO_DIR/.openclaw/agents/email-triage/TOOLS.md"; then
  echo "PASS [CHAN-03] OAuth2 re-auth runbook in email-triage TOOLS.md"
else
  echo "FAIL [CHAN-03] re-auth runbook missing from email-triage TOOLS.md"
  FAILED=1
fi

# --- CHECK 7 (CHAN-04): Morning Standup Brief cron job in jobs.json with Asia/Kolkata ---
if python3 -c "
import json, sys
d = json.load(open('$REPO_DIR/.openclaw/cron/jobs.json'))
standup = [j for j in d['jobs'] if j.get('name') == 'Morning Standup Brief']
exit(0 if standup and standup[0]['schedule']['tz'] == 'Asia/Kolkata' else 1)
" 2>/dev/null; then
  echo "PASS [CHAN-04] Morning Standup Brief cron job with Asia/Kolkata tz"
else
  echo "FAIL [CHAN-04] standup cron job missing or wrong timezone"
  FAILED=1
fi

# --- CHECK 8 (CHAN-04): standup-brief.sh is executable and syntax-valid ---
if [[ -x "$REPO_DIR/scripts/standup-brief.sh" ]] && \
   zsh -n "$REPO_DIR/scripts/standup-brief.sh" 2>/dev/null; then
  echo "PASS [CHAN-04] standup-brief.sh executable and syntax-valid"
else
  echo "FAIL [CHAN-04] standup-brief.sh not executable or has syntax error"
  FAILED=1
fi

echo ""
echo "=== Phase 06 Smoke Check Summary ==="
echo "CHAN-03 (Email Triage): structural checks above"
echo "CHAN-04 (Morning Standup): structural checks above"
echo ""
echo "NOTE: The following success criteria require HUMAN ACTION before they can be verified:"
echo "  - SC#1: Gmail OAuth2 refresh token in Keychain (run oauth2-setup.js on return — see 06-02-PLAN.md)"
echo "  - SC#3: Standup cron fires on schedule (verify after 08:00 IST next morning)"
echo "  - SC#4: OAuth2 re-auth runbook verified working (test with oauth2-setup.js)"
echo ""
echo "These are marked PENDING in the phase SUMMARY."

if [[ "$FAILED" == "0" ]]; then
  echo ""
  echo "ALL STRUCTURAL CHECKS PASSED"
  exit 0
else
  echo ""
  echo "SOME CHECKS FAILED — see FAIL lines above"
  exit 1
fi

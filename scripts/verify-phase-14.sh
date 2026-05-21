#!/usr/bin/env zsh
# verify-phase-14.sh — Phase 14 gogcli / Google Suite CLI verification gate
# Runs 9 checks. Auth check (3) uses SKIP instead of FAIL.
# Exits 0 if FAIL_COUNT=0 (SKIPs are acceptable). Exits 1 if any FAIL.
set -euo pipefail

PASS_COUNT=0
SKIP_COUNT=0
FAIL_COUNT=0

pass() { print "CHECK $1: PASS — $2"; PASS_COUNT=$(( PASS_COUNT + 1 )) }
skip() { print "CHECK $1: SKIP — $2"; SKIP_COUNT=$(( SKIP_COUNT + 1 )) }
fail() { print "CHECK $1: FAIL — $2"; FAIL_COUNT=$(( FAIL_COUNT + 1 )) }

# CHECK 1 — gog binary installed
if [[ -x /opt/homebrew/bin/gog ]]; then
  pass 1 "gog binary present at /opt/homebrew/bin/gog"
else
  fail 1 "gog not installed — run: brew install gogcli"
fi

# CHECK 2 — gog version is 0.17.x
if /opt/homebrew/bin/gog --version 2>&1 | grep -q '0\.17'; then
  pass 2 "gog version is 0.17.x"
else
  fail 2 "gog version unexpected (expected 0.17.x) — $((/opt/homebrew/bin/gog --version 2>&1 || echo 'gog not found'))"
fi

# CHECK 3 — gog auth check (auto-skip if not done)
if [[ ! -x /opt/homebrew/bin/gog ]]; then
  skip 3 "gog not installed — skipping auth check"
elif /opt/homebrew/bin/gog auth doctor --check --account echo.sys.bot@gmail.com --no-input >/dev/null 2>&1; then
  pass 3 "gog auth valid for echo.sys.bot@gmail.com"
else
  skip 3 "TODO: run 'gog auth add echo.sys.bot@gmail.com --services gmail,calendar' — auth not yet completed"
fi

# CHECK 4 — email-triage.sh exists and is executable
if [[ -x /Users/trilogy/Documents/agentic-setup/scripts/email-triage.sh ]]; then
  pass 4 "email-triage.sh exists and is executable"
else
  fail 4 "email-triage.sh missing — Plan 14-02 not complete"
fi

# CHECK 5 — email-triage.sh uses --no-input --non-interactive
if grep -q 'no-input' /Users/trilogy/Documents/agentic-setup/scripts/email-triage.sh && \
   grep -q 'non-interactive' /Users/trilogy/Documents/agentic-setup/scripts/email-triage.sh; then
  pass 5 "email-triage.sh includes --no-input --non-interactive flags"
else
  fail 5 "email-triage.sh missing agent-safe flags (--no-input --non-interactive)"
fi

# CHECK 6 — standup-brief.sh has calendar_events
if grep -q 'calendar_events' /Users/trilogy/Documents/agentic-setup/scripts/standup-brief.sh; then
  pass 6 "standup-brief.sh contains calendar_events field"
else
  fail 6 "standup-brief.sh missing calendar_events — Plan 14-03 not complete"
fi

# CHECK 7 — standup-brief.sh has overnight_email
if grep -q 'overnight_email' /Users/trilogy/Documents/agentic-setup/scripts/standup-brief.sh; then
  pass 7 "standup-brief.sh contains overnight_email field"
else
  fail 7 "standup-brief.sh missing overnight_email — Plan 14-03 not complete"
fi

# CHECK 8 — TOOLS.md updated to reference email-triage.sh
if grep -q 'email-triage.sh' /Users/trilogy/Documents/agentic-setup/.openclaw/agents/email-triage/TOOLS.md; then
  pass 8 "TOOLS.md references email-triage.sh as primary invocation"
else
  fail 8 "TOOLS.md not updated — Plan 14-04 not complete"
fi

# CHECK 9 — .gitignore has gogcli credentials guard
if grep -q '\.config/gogcli' /Users/trilogy/Documents/agentic-setup/.gitignore; then
  pass 9 ".gitignore contains .config/gogcli guard"
else
  fail 9 ".gitignore missing gogcli guard — Plan 14-01 not complete"
fi

# --- Summary ---
print ""
print "=== Phase 14 Verification ==="
print "PASSED: $PASS_COUNT"
print "SKIPPED: $SKIP_COUNT (require human auth step)"
print "FAILED: $FAIL_COUNT"
if [[ "$FAIL_COUNT" -eq 0 ]]; then
  print "RESULT: PHASE 14 READY (${SKIP_COUNT} auth checks pending human action)"
else
  print "RESULT: PHASE 14 INCOMPLETE — fix $FAIL_COUNT failing checks above"
  exit 1
fi

#!/usr/bin/env zsh
# verify-phase-08.sh — Phase 8 automated smoke checks (DEV-03 + DEV-04)
# Runs all checks and reports pass/fail per check. Exits non-zero if any fail.
# NOTE: set -uo pipefail (NOT set -e) — must run all checks before exiting
set -uo pipefail

# ── Constants ──────────────────────────────────────────────────────────────────
# REPO_DIR: source repository with the agent files (worktree-aware)
# Scripts are checked from repo source (not deployed ~/.openclaw/) so checks work
# before or after stow-deploy.
REPO_DIR="${REPO_DIR:-/Users/trilogy/Documents/agentic-setup}"

# Resolve actual repo location: check if running from a worktree
_GIT_TOPLEVEL=$(git rev-parse --show-toplevel 2>/dev/null || echo "$REPO_DIR")
# Use git toplevel if it contains the expected .openclaw directory
if [[ -d "$_GIT_TOPLEVEL/.openclaw" ]]; then
  REPO_DIR="$_GIT_TOPLEVEL"
fi

CI_AGENT_DIR="$REPO_DIR/.openclaw/agents/ci-monitor"
DEVBOT_DIR="$REPO_DIR/.openclaw/agents/devbot"
OC_BIN="/opt/homebrew/bin/openclaw"

# ── Counters ───────────────────────────────────────────────────────────────────
PASS=0
FAIL=0
SKIP=0

# ── Helper ─────────────────────────────────────────────────────────────────────
check() {
  local id="$1"
  local description="$2"
  shift 2

  if eval "$@" &>/dev/null 2>&1; then
    print "[PASS] ${id}: ${description}"
    (( PASS++ ))
  else
    print "[FAIL] ${id}: ${description}"
    (( FAIL++ ))
  fi
}

print "Using REPO_DIR: $REPO_DIR" >&2

# ── DEV-03 Checks ─────────────────────────────────────────────────────────────

# DEV-03a: CI Monitor agent appears in openclaw status
# NOTE: requires stow-deploy + gateway restart from main branch to pass
check "DEV-03a" "CI Monitor agent in openclaw status (requires deployed gateway)" \
  "PATH='/opt/homebrew/opt/node@24/bin:\$PATH' '$OC_BIN' status 2>/dev/null | grep -q 'ci-monitor'"

# DEV-03b: CI Monitor cron job appears in openclaw status
# NOTE: requires stow-deploy + gateway restart from main branch to pass
check "DEV-03b" "CI Monitor cron job (CI Monitor Poll) in openclaw status (requires deployed gateway)" \
  "PATH='/opt/homebrew/opt/node@24/bin:\$PATH' '$OC_BIN' status 2>/dev/null | grep -q 'CI Monitor Poll'"

# DEV-03c: poll-ci.sh syntax check + executable (uses repo source path)
check "DEV-03c" "poll-ci.sh syntax clean and executable" \
  "zsh -n '$CI_AGENT_DIR/scripts/poll-ci.sh' && [[ -x '$CI_AGENT_DIR/scripts/poll-ci.sh' ]]"

# DEV-03d: state/last-seen-runs.json is a valid JSON object (uses repo source path)
check "DEV-03d" "state/last-seen-runs.json is initialized as valid JSON object" \
  "python3 -c \"import json; d=json.load(open('$CI_AGENT_DIR/state/last-seen-runs.json')); assert isinstance(d, dict)\""

# ── DEV-04 Checks ─────────────────────────────────────────────────────────────

# DEV-04a: devbot-intake-issue.sh --dry-run returns ok:true (uses repo source path)
check "DEV-04a" "devbot-intake-issue.sh --dry-run returns ok:true" \
  "zsh '$DEVBOT_DIR/scripts/devbot-intake-issue.sh' anujj-ti/agentic-setup 1 --dry-run 2>/dev/null | python3 -c 'import json,sys; d=json.load(sys.stdin); exit(0 if d.get(\"ok\") else 1)'"

# DEV-04b: devbot-create-epic.sh and devbot-execute-cycle.sh pass syntax checks (uses repo source path)
check "DEV-04b" "devbot-create-epic.sh and devbot-execute-cycle.sh syntax clean" \
  "zsh -n '$DEVBOT_DIR/scripts/devbot-create-epic.sh' && zsh -n '$DEVBOT_DIR/scripts/devbot-execute-cycle.sh'"

# DEV-04c: merge guard — gh pr merge must NOT appear in devbot-execute-cycle.sh
check "DEV-04c" "merge guard: gh pr merge absent from devbot-execute-cycle.sh" \
  "! grep -q 'pr merge' '$DEVBOT_DIR/scripts/devbot-execute-cycle.sh' 2>/dev/null"

# ── Summary ───────────────────────────────────────────────────────────────────
print ""
print "─────────────────────────────────────────"
print "Phase 8 Verification Summary"
print "─────────────────────────────────────────"
print "PASS: $PASS  FAIL: $FAIL  SKIP: $SKIP"
print ""

if [[ $FAIL -gt 0 ]]; then
  print "RESULT: FAIL ($FAIL check(s) failed)"
  print ""
  print "Common causes:"
  print "  DEV-03a/DEV-03b: Run stow-deploy.sh + gateway restart from main branch after merge"
  print "  DEV-03c/03d: Files may be missing (check .openclaw/agents/ci-monitor/)"
  print "  DEV-04a/04b: Check .openclaw/agents/devbot/scripts/"
  print ""
  print "Manual verification still required (regardless of automated results):"
  print "  M-01: Trigger a CI failure on anujj-ti/agentic-setup and verify Telegram alert"
  print "        (requires OPENCLAW_ANUJ_CHAT_ID to be set in Keychain first)"
  print "  M-02: Run devbot-execute-cycle.sh design mode on a test Beads task"
  exit 1
else
  print "RESULT: PASS (all automated checks passed)"
  print ""
  print "Manual verification still required:"
  print "  M-01: Trigger a CI failure on anujj-ti/agentic-setup and verify Telegram alert"
  print "        (requires OPENCLAW_ANUJ_CHAT_ID to be set in Keychain first)"
  print "  M-02: Run devbot-execute-cycle.sh design mode on a test Beads task"
  exit 0
fi

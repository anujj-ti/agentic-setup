#!/usr/bin/env zsh
# chan-verify.sh — smoke test runner for CHAN-01 assertions
# Source: PLAN 02-01 Task 1 + PATTERNS.md §chan-verify.sh
# Usage: zsh scripts/chan-verify.sh
# On success: stdout JSON {"ok":true,"data":{"passed":5,"failed":0}}
# On failure: stdout JSON {"ok":false,"error":"smoke_tests_failed","data":{...}} + exit 1
set -euo pipefail

SCRIPT_DIR="${0:a:h}"
source "${SCRIPT_DIR}/lib/json-response.sh"

PASS=0
FAIL=0
FAILURES=()

check() {
  local label="$1"
  shift
  if "$@" &>/dev/null; then
    print "[PASS] ${label}" >&2
    # (( PASS++ )) alone would exit under set -e when PASS==0 (arithmetic 0 = false).
    # The || true guards against that.
    (( PASS++ )) || true
  else
    print "[FAIL] ${label}" >&2
    (( FAIL++ )) || true
    FAILURES+=("${label}")
  fi
}

# CHAN-01 Check 1: Token is in Keychain (non-empty)
# A real Telegram bot token is ~46 chars; empty string + newline = 1
check "Token in Keychain (openclaw.telegram-main-bot-token)" \
  bash -c 'count=$(security find-generic-password -s "openclaw.telegram-main-bot-token" -w 2>/dev/null | wc -c | tr -d " "); [[ "$count" != "1" ]] && [[ -n "$count" ]] && [[ "$count" -gt 1 ]]'

# CHAN-01 Check 2: openclaw.json uses env var ref, NOT literal token
# Must contain the env var reference AND must NOT contain a literal token (numeric_id:AA... pattern)
check "openclaw.json uses env var ref (not literal token)" \
  bash -c 'grep -q "OPENCLAW_TELEGRAM_MAIN_BOT_TOKEN" "$HOME/.openclaw/openclaw.json" && ! grep -qE "botToken.*[0-9]{10}:AA" "$HOME/.openclaw/openclaw.json"'

# CHAN-01 Check 3: openclaw-secrets.sh has the export
check "openclaw-secrets.sh has OPENCLAW_TELEGRAM_MAIN_BOT_TOKEN export" \
  grep -q "OPENCLAW_TELEGRAM_MAIN_BOT_TOKEN" "$HOME/.openclaw/scripts/openclaw-secrets.sh"

# CHAN-01 Check 4: secrets.sh has the disaster-recovery entry
# Detect the repo root via the stow symlink (resolve relative path to absolute)
# readlink returns ../Documents/agentic-setup/.openclaw/openclaw.json (relative to ~/.openclaw/)
# Resolving: cd ~/.openclaw && strip /.openclaw/openclaw.json + replace leading .. with $HOME
check "secrets.sh has telegram recovery entry" \
  bash -c 'OPENCLAW_REPO=$(cd "$HOME/.openclaw" && readlink openclaw.json 2>/dev/null | sed "s|/.openclaw/openclaw.json||" | sed "s|^\.\.|$HOME|"); grep -q "openclaw.telegram-main-bot-token" "${OPENCLAW_REPO}/secrets.sh"'

# CHAN-01 Check 5: Pre-stow backup files are gone (no plaintext token on disk)
check "Pre-stow backup files shredded" \
  bash -c '[[ ! -f "$HOME/.openclaw/openclaw.json.pre-stow" ]]'

# Emit result JSON (stdout only — stderr has the pass/fail lines above)
if (( FAIL == 0 )); then
  json_ok "{\"passed\":${PASS},\"failed\":0}"
else
  failed_json=$(printf '"%s",' "${FAILURES[@]}" | sed 's/,$//')
  print "{\"ok\":false,\"error\":\"smoke_tests_failed\",\"data\":{\"passed\":${PASS},\"failed\":${FAIL},\"failures\":[${failed_json}]}}" >&1
  exit 1
fi

#!/usr/bin/env zsh
# email-triage.sh — Gmail triage via gogcli (replaces gmail-triage.js for Email Triage agent)
# Usage: zsh scripts/email-triage.sh [--dry-run]
# stdout: JSON with threads array + count (json_ok envelope)
# stderr: human-readable progress logs
# Source: CLAUDE.md shell scripting conventions + D-141 (GOG_AUTH guard), D-142 (--no-input), D-143 (explicit path)
set -euo pipefail

source "$(dirname "$0")/lib/json-response.sh"

# --- Constants ---
GOG=/opt/homebrew/bin/gog
JQ=/opt/homebrew/bin/jq
ACCOUNT="${OPENCLAW_GMAIL_ACCOUNT:-echo.sys.bot@gmail.com}"
MAX="${GMAIL_TRIAGE_MAX:-20}"
DRY_RUN="${1:-}"

# --- Guard section: fail fast with actionable errors ---
[[ -x "$GOG" ]] || json_fail "gog-not-found" "gog not at $GOG — run: brew install gogcli"
[[ -x "$JQ"  ]] || json_fail "jq-not-found"  "jq not at $JQ — run: brew install jq"

# Check gog auth status (D-141: exit 0 with warning if not authed)
if ! $GOG auth doctor --check --no-input --account "$ACCOUNT" >/dev/null 2>&1; then
  print "WARN: gog auth check failed for $ACCOUNT — run: gog auth add $ACCOUNT --services gmail,calendar" >&2
  json_fail "gog-auth-failed" "gog auth check failed for $ACCOUNT — run: gog auth add $ACCOUNT --services gmail,calendar"
fi

print "Fetching unread Gmail threads for $ACCOUNT (max $MAX)" >&2

# --- Gmail search: unread in last 24h ---
RAW=$($GOG gmail search 'is:unread newer_than:1d' \
  --account "$ACCOUNT" \
  --max "$MAX" \
  --json \
  --no-input \
  --non-interactive 2>/dev/null) || RAW='{}'

# Extract threads array (D-146: --json returns {"results":[...]} envelope)
THREADS=$(printf '%s' "$RAW" | $JQ '.results // []' 2>/dev/null || echo '[]')
COUNT=$(printf '%s' "$THREADS" | $JQ 'length' 2>/dev/null || echo 0)

print "Found $COUNT unread threads for $ACCOUNT" >&2

if [[ "$DRY_RUN" == "--dry-run" ]]; then
  print "DRY RUN: skipping mark-read step" >&2
fi

# --- Output structured JSON to stdout ---
json_ok "{\"threads\": $THREADS, \"count\": $COUNT}"

#!/usr/bin/env zsh
# email-triage.sh — Gmail triage via gogcli (replaces gmail-triage.js for Email Triage agent)
# Usage: zsh scripts/email-triage.sh [--dry-run]
# stdout: JSON with threads array + count (json_ok envelope)
# stderr: human-readable progress logs
# Source: CLAUDE.md shell scripting conventions + D-141 (GOG_AUTH guard), D-142 (--no-input), D-143 (explicit path)
# Phase 15: D-161 (mark-read), D-162 (processed-ids.jsonl skip + append), D-163 (500-entry trim)
set -euo pipefail

source "$(dirname "$0")/lib/json-response.sh"

# --- Constants ---
GOG=/opt/homebrew/bin/gog
JQ=/opt/homebrew/bin/jq
ACCOUNT="${OPENCLAW_GMAIL_ACCOUNT:-echo.sys.bot@gmail.com}"
MAX="${GMAIL_TRIAGE_MAX:-20}"
DRY_RUN="${1:-}"
PROCESSED_IDS_FILE="/Users/trilogy/.openclaw/agents/email-triage/memory/processed-ids.jsonl"
LOG_STDERR="/dev/stderr"

# --- Guard section: fail fast with actionable errors ---
[[ -x "$GOG" ]] || json_fail "gog-not-found" "gog not at $GOG — run: brew install gogcli"
[[ -x "$JQ"  ]] || json_fail "jq-not-found"  "jq not at $JQ — run: brew install jq"

# Check gog auth status (D-141: exit 0 with warning if not authed)
if ! $GOG auth doctor --check --no-input --account "$ACCOUNT" >/dev/null 2>&1; then
  print "WARN: gog auth check failed for $ACCOUNT — run: gog auth add $ACCOUNT --services gmail,calendar" >&2
  json_fail "gog-auth-failed" "gog auth check failed for $ACCOUNT — run: gog auth add $ACCOUNT --services gmail,calendar"
fi

# --- Check if processed-ids file exists (D-162) ---
if [[ ! -f "$PROCESSED_IDS_FILE" ]]; then
  print "INFO: processed-ids.jsonl not found — skip set is empty" >&2
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

# --- Filter out already-processed IDs (D-162) ---
# Build a jq-compatible set of skip IDs and filter threads array
if [[ -f "$PROCESSED_IDS_FILE" ]]; then
  SKIP_ARRAY=$(${JQ} --slurp -r '[.[].id]' "$PROCESSED_IDS_FILE" 2>/dev/null || echo '[]')
  THREADS_FILTERED=$(printf '%s' "$THREADS" | $JQ --argjson skip "$SKIP_ARRAY" '[.[] | select(.id as $id | ($skip | index($id)) == null)]' 2>/dev/null || printf '%s' "$THREADS")
  FILTERED_COUNT=$(printf '%s' "$THREADS_FILTERED" | $JQ 'length' 2>/dev/null || echo "$COUNT")
  SKIPPED_COUNT=$(( COUNT - FILTERED_COUNT ))
  if [[ "$SKIPPED_COUNT" -gt 0 ]]; then
    print "Skipped $SKIPPED_COUNT already-processed thread(s) (processed-ids.jsonl guard)" >&2
  fi
  THREADS="$THREADS_FILTERED"
  COUNT="$FILTERED_COUNT"
fi

if [[ "$DRY_RUN" == "--dry-run" ]]; then
  print "DRY RUN: skipping processed-ids append and mark-read step" >&2
  json_ok "{\"threads\": $THREADS, \"count\": $COUNT}"
  exit 0
fi

# --- Append newly-processed IDs to processed-ids.jsonl (D-162) ---
# Only append if we have threads to process
if [[ "$COUNT" -gt 0 ]]; then
  PROCESSED_AT=$(date -u +"%Y-%m-%dT%H:%M:%S.000Z")
  NEWLY_PROCESSED_IDS=$(printf '%s' "$THREADS" | $JQ -r '.[].id' 2>/dev/null || echo "")
  if [[ -n "$NEWLY_PROCESSED_IDS" ]]; then
    while IFS= read -r ID; do
      [[ -z "$ID" ]] && continue
      print "{\"id\":\"${ID}\",\"processedAt\":\"${PROCESSED_AT}\"}" >> "$PROCESSED_IDS_FILE"
    done <<< "$NEWLY_PROCESSED_IDS"
    print "Appended $COUNT ID(s) to processed-ids.jsonl" >&2
  fi

  # --- Trim processed-ids.jsonl to last 500 entries (D-163) ---
  ENTRY_COUNT=$(wc -l < "$PROCESSED_IDS_FILE" 2>/dev/null | tr -d ' ' || echo 0)
  if [[ "$ENTRY_COUNT" -gt 500 ]]; then
    TMPFILE=$(mktemp -p "$(dirname "$PROCESSED_IDS_FILE")")
    tail -500 "$PROCESSED_IDS_FILE" > "$TMPFILE"
    mv "$TMPFILE" "$PROCESSED_IDS_FILE"
    print "Trimmed processed-ids.jsonl to 500 entries (was $ENTRY_COUNT)" >&2
  fi
fi

# --- Mark processed messages as read (D-161) ---
# Non-fatal: processed-ids.jsonl guard handles duplicates if mark-read fails
$GOG gmail mark-read \
  --account "$ACCOUNT" \
  --query "is:unread newer_than:1d" \
  --no-input --non-interactive 2>>"$LOG_STDERR" || \
  print "[warn] mark-read failed — processed-ids.jsonl guard will catch duplicates next run" >&2

# --- Output structured JSON to stdout ---
json_ok "{\"threads\": $THREADS, \"count\": $COUNT}"

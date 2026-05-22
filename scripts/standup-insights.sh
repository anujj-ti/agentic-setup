#!/usr/bin/env zsh
# standup-insights.sh — Classify standup-brief.sh JSON output into Blocked/At Risk/On Track
# Usage: standup-brief.sh --repo OWNER/REPO | standup-insights.sh
# Input:  standup-brief.sh JSON on stdin
# Output: enhanced JSON with insights.classified_items, insights.tackle_first, insights.patterns
# Source: CLAUDE.md shell scripting conventions (macOS only, BSD date)
set -euo pipefail

source "$(dirname "$0")/lib/json-response.sh"

# --- Explicit binary paths (per CLAUDE.md — protect against PATH shadowing) ---
JQ=/opt/homebrew/bin/jq

[[ -x "$JQ" ]] || { print "ERROR: jq not found at $JQ — run: brew install jq" >&2; exit 1; }

# --- Read all stdin ---
RAW_INPUT=""
if [[ -t 0 ]]; then
  json_fail "no-input" "No standup JSON on stdin — pipe from standup-brief.sh"
fi
RAW_INPUT=$(cat)

if [[ -z "$RAW_INPUT" ]]; then
  json_fail "no-input" "No standup JSON on stdin — pipe from standup-brief.sh"
fi

# --- Validate JSON and extract fields ---
if ! printf '%s' "$RAW_INPUT" | $JQ -e '.' >/dev/null 2>&1; then
  json_fail "invalid-json" "Could not parse standup JSON from stdin"
fi

CI_FAILURES=$(printf '%s' "$RAW_INPUT" | $JQ '.data.ci_failures // []') || \
  json_fail "invalid-json" "Could not parse standup JSON from stdin"
STALE_PRS=$(printf '%s' "$RAW_INPUT" | $JQ '.data.stale_prs // []')
MERGED_PRS=$(printf '%s' "$RAW_INPUT" | $JQ '.data.merged_prs // []')

# --- Time computations (BSD date — macOS) ---
NOW_EPOCH=$(date +%s)
TWO_H_AGO_EPOCH=$((NOW_EPOCH - 7200))
TWENTY_FOUR_H_AGO_EPOCH=$((NOW_EPOCH - 86400))

print "Classifying standup items..." >&2

# --- Helper: parse ISO8601 to epoch (BSD date, macOS) ---
# Input: ISO8601 string like "2026-05-22T01:00:00Z"
# Output: epoch integer
# Uses TZ=UTC to ensure UTC timestamps are parsed correctly regardless of machine locale
iso_to_epoch() {
  local ts="$1"
  # Strip fractional seconds and trailing Z for BSD date parsing
  local clean="${ts%%.*}"
  clean="${clean%Z}"
  # BSD date: -j -f format input. TZ=UTC required — GitHub timestamps are UTC
  TZ=UTC date -j -f '%Y-%m-%dT%H:%M:%S' "${clean}" '+%s' 2>/dev/null || echo "0"
}

# --- Classification arrays (built as jq-compatible JSON arrays) ---
CLASSIFIED_JSON="[]"

# --- Classify ci_failures (D-401: Blocked if createdAt > 2h ago) ---
CI_COUNT=$(printf '%s' "$CI_FAILURES" | $JQ 'length')
# Apply T-17-03: limit to first 20 elements
if (( CI_COUNT > 20 )); then
  CI_FAILURES=$(printf '%s' "$CI_FAILURES" | $JQ '.[0:20]')
  CI_COUNT=20
fi

IDX=0
while (( IDX < CI_COUNT )); do
  ITEM=$(printf '%s' "$CI_FAILURES" | $JQ ".[${IDX}]")
  CREATED_AT=$(printf '%s' "$ITEM" | $JQ -r '.createdAt // ""')
  HEAD_BRANCH=$(printf '%s' "$ITEM" | $JQ -r '.headBranch // "unknown"')
  TITLE=$(printf '%s' "$ITEM" | $JQ -r '.name // "CI failure"')

  CREATED_EPOCH=$(iso_to_epoch "$CREATED_AT")
  STATUS="On Track"
  REASON="Recent activity — monitoring"

  if (( CREATED_EPOCH > 0 && CREATED_EPOCH < TWO_H_AGO_EPOCH )); then
    STATUS="Blocked"
    REASON="CI failure on branch ${HEAD_BRANCH} — not updated in over 2h"
  fi

  SOURCE_FIELD="ci_failures[${IDX}]"
  NEW_ITEM=$($JQ -n \
    --arg title "$TITLE" \
    --arg status "$STATUS" \
    --arg source_field "$SOURCE_FIELD" \
    --arg reason "$REASON" \
    '{title: $title, status: $status, source_field: $source_field, reason: $reason}')

  CLASSIFIED_JSON=$(printf '%s\n%s' "$CLASSIFIED_JSON" "$NEW_ITEM" | $JQ -s '.[0] + [.[1]]')
  IDX=$((IDX + 1))
done

# --- Classify stale_prs (D-402: At Risk if updatedAt > 24h ago) ---
STALE_COUNT=$(printf '%s' "$STALE_PRS" | $JQ 'length')

IDX=0
while (( IDX < STALE_COUNT )); do
  ITEM=$(printf '%s' "$STALE_PRS" | $JQ ".[${IDX}]")
  UPDATED_AT=$(printf '%s' "$ITEM" | $JQ -r '.updatedAt // ""')
  PR_NUMBER=$(printf '%s' "$ITEM" | $JQ -r '.number // 0')
  PR_TITLE=$(printf '%s' "$ITEM" | $JQ -r '.title // "Stale PR"')
  REVIEW_DECISION=$(printf '%s' "$ITEM" | $JQ -r '.reviewDecision // ""')

  UPDATED_EPOCH=$(iso_to_epoch "$UPDATED_AT")
  STATUS="On Track"
  REASON="Recent activity — monitoring"

  if (( UPDATED_EPOCH > 0 && UPDATED_EPOCH < TWENTY_FOUR_H_AGO_EPOCH )); then
    STATUS="At Risk"
    REASON="PR #${PR_NUMBER} has ${REVIEW_DECISION} and has not been updated in over 24h"
  fi

  SOURCE_FIELD="stale_prs[${IDX}]"
  NEW_ITEM=$($JQ -n \
    --arg title "$PR_TITLE" \
    --arg status "$STATUS" \
    --arg source_field "$SOURCE_FIELD" \
    --arg reason "$REASON" \
    '{title: $title, status: $status, source_field: $source_field, reason: $reason}')

  CLASSIFIED_JSON=$(printf '%s\n%s' "$CLASSIFIED_JSON" "$NEW_ITEM" | $JQ -s '.[0] + [.[1]]')
  IDX=$((IDX + 1))
done

# --- Classify merged_prs (D-403: always On Track — completed work) ---
MERGED_COUNT=$(printf '%s' "$MERGED_PRS" | $JQ 'length')

IDX=0
while (( IDX < MERGED_COUNT )); do
  ITEM=$(printf '%s' "$MERGED_PRS" | $JQ ".[${IDX}]")
  PR_TITLE=$(printf '%s' "$ITEM" | $JQ -r '.title // "Merged PR"')

  SOURCE_FIELD="merged_prs[${IDX}]"
  NEW_ITEM=$($JQ -n \
    --arg title "$PR_TITLE" \
    --arg status "On Track" \
    --arg source_field "$SOURCE_FIELD" \
    --arg reason "Merged overnight — no action needed" \
    '{title: $title, status: $status, source_field: $source_field, reason: $reason}')

  CLASSIFIED_JSON=$(printf '%s\n%s' "$CLASSIFIED_JSON" "$NEW_ITEM" | $JQ -s '.[0] + [.[1]]')
  IDX=$((IDX + 1))
done

# --- Build tackle_first (D-405: Blocked → At Risk → ci_failure On Track → rest, cap 5) ---
# Assign rank: Blocked=0, At Risk=1, ci_failure On Track=2, other On Track=3
TACKLE_FIRST=$(printf '%s' "$CLASSIFIED_JSON" | $JQ '
  [
    .[] |
    . as $item |
    (if .status == "Blocked" then 0
     elif .status == "At Risk" then 1
     elif (.status == "On Track" and (.source_field | startswith("ci_failures"))) then 2
     else 3
     end) as $rank |
    $item + {_rank: $rank}
  ] |
  sort_by(._rank) |
  .[0:5] |
  map(del(._rank))
')

# --- Build patterns (D-408: fire when 3+ items share same signal type) ---
# Group by source_field prefix (ci_failures, stale_prs, merged_prs)
PATTERNS=$(printf '%s' "$CLASSIFIED_JSON" | $JQ '
  group_by(.source_field | split("[")[0]) |
  map(select(length >= 3) |
    {
      type: (.[0].source_field | split("[")[0]),
      count: length,
      label: ("\(length) \(.[0].source_field | split("[")[0]) overnight — possible systemic issue")
    }
  )
')

print "Classification complete." >&2

# --- Assemble output ---
INSIGHTS=$($JQ -n \
  --argjson classified "$CLASSIFIED_JSON" \
  --argjson tackle "$TACKLE_FIRST" \
  --argjson patterns "$PATTERNS" \
  '{insights: {classified_items: $classified, tackle_first: $tackle, patterns: $patterns}}')

json_ok "$INSIGHTS"

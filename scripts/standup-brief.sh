#!/usr/bin/env zsh
# standup-brief.sh — Aggregate overnight GitHub activity for morning standup brief
# Usage: standup-brief.sh --repo OWNER/REPO
# Output: JSON to stdout, logs to stderr
# Source: CLAUDE.md shell scripting conventions (macOS only, BSD date)
set -euo pipefail

source "$(dirname "$0")/lib/json-response.sh"

# --- Argument parsing ---
REPO=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo)
      REPO="$2"
      shift 2
      ;;
    *)
      json_fail "unknown-arg" "Unknown argument: $1. Usage: standup-brief.sh --repo OWNER/REPO"
      ;;
  esac
done

if [[ -z "$REPO" ]]; then
  json_fail "missing-arg" "Usage: standup-brief.sh --repo OWNER/REPO"
fi

# --- Explicit binary paths (per CLAUDE.md — protect against nvm/PATH shadowing) ---
GH=/opt/homebrew/bin/gh
JQ=/opt/homebrew/bin/jq
GOG=/opt/homebrew/bin/gog
GCAL_ACCOUNT="${OPENCLAW_GMAIL_ACCOUNT:-echo.sys.bot@gmail.com}"
GOG_AVAILABLE=false
[[ -x "$GOG" ]] && GOG_AVAILABLE=true

# --- Verify dependencies ---
[[ -x "$GH" ]] || json_fail "gh-not-found" "gh not found at $GH — run: brew install gh"
[[ -x "$JQ" ]] || json_fail "jq-not-found" "jq not found at $JQ — run: brew install jq"

print "Fetching GitHub data for repo: $REPO" >&2

# --- 1. PRs merged overnight (last 24h, macOS BSD date format) ---
# BSD date: date -u -v-24H '+%Y-%m-%dT%H:%M:%SZ'
MERGED_PRS='[]'
MERGED_PRS=$($GH pr list \
  --state merged \
  --search "merged:>$(date -u -v-24H '+%Y-%m-%dT%H:%M:%SZ')" \
  --json number,title,mergedAt,mergedBy \
  --limit 20 \
  --repo "$REPO" 2>/dev/null) || MERGED_PRS='[]'

# --- 2. CI failures ---
CI_FAILURES='[]'
CI_FAILURES=$($GH run list \
  --status failure \
  --json name,conclusion,headBranch,url,createdAt \
  --limit 10 \
  --repo "$REPO" 2>/dev/null) || CI_FAILURES='[]'

# --- 3. Stale PRs (open with review requests or CHANGES_REQUESTED) ---
STALE_PRS='[]'
STALE_PRS=$($GH pr list \
  --state open \
  --json number,title,updatedAt,reviewDecision,reviewRequests \
  --limit 30 \
  --repo "$REPO" 2>/dev/null | \
  $JQ '[.[] | select((.reviewRequests | length) > 0 or .reviewDecision == "CHANGES_REQUESTED") | {number, title, updatedAt, reviewDecision}]' 2>/dev/null) || STALE_PRS='[]'

print "Data aggregation complete." >&2

# --- 4. Autonomous decisions since last session (Phase 9 Notion integration) ---
# Wrapped in subshell with fallback so standup always completes regardless of Notion status
DECISIONS_RAW=$(zsh /Users/trilogy/.openclaw/agents/task-orchestrator/scripts/notion/query-decisions.sh 2>/dev/null || echo '{"ok":false,"error":"query failed"}')
DECISION_COUNT=$($JQ '.count // 0' <<< "$DECISIONS_RAW" 2>/dev/null || echo "0")
DECISION_SKIPPED=$($JQ '.skipped // false' <<< "$DECISIONS_RAW" 2>/dev/null || echo "false")
DECISION_SINCE=$($JQ -r '.since // ""' <<< "$DECISIONS_RAW" 2>/dev/null || echo "")
NOTION_CONFIGURED="true"

if [[ "$DECISION_SKIPPED" == "true" ]]; then
  NOTION_CONFIGURED="false"
  DECISION_SUMMARY='["Notion not configured — run /openclaw-add-secret notion-token"]'
elif [[ "$($JQ '.ok // false' <<< "$DECISIONS_RAW" 2>/dev/null || echo 'false')" != "true" ]]; then
  NOTION_CONFIGURED="false"
  DECISION_SUMMARY='["Could not retrieve decisions from Notion"]'
elif [[ "$DECISION_COUNT" -gt "0" ]]; then
  DECISION_SUMMARY=$($JQ '[.decisions[:3][].decision] // []' <<< "$DECISIONS_RAW" 2>/dev/null || echo '[]')
else
  DECISION_SUMMARY='[]'
fi

AUTONOMOUS_DECISIONS="{\"count\":${DECISION_COUNT},\"since\":\"${DECISION_SINCE}\",\"summary\":${DECISION_SUMMARY},\"notion_configured\":${NOTION_CONFIGURED}}"

print "Autonomous decisions query complete." >&2

# --- 5. Overnight email summary (via gogcli — degrades gracefully if unavailable) ---
OVERNIGHT_EMAIL_THREADS='[]'
OVERNIGHT_EMAIL_COUNT=0
if [[ "$GOG_AVAILABLE" == "true" ]]; then
  print "Fetching overnight email for $GCAL_ACCOUNT" >&2
  RAW_EMAIL=$($GOG gmail search 'is:unread newer_than:12h' \
    --account "$GCAL_ACCOUNT" \
    --max 20 \
    --json \
    --no-input \
    --non-interactive 2>/dev/null) || RAW_EMAIL='{}'
  OVERNIGHT_EMAIL_THREADS=$(printf '%s' "$RAW_EMAIL" | $JQ '.results // []' 2>/dev/null || echo '[]')
  OVERNIGHT_EMAIL_COUNT=$(printf '%s' "$OVERNIGHT_EMAIL_THREADS" | $JQ 'length' 2>/dev/null || echo 0)
fi
OVERNIGHT_EMAIL="{\"count\":${OVERNIGHT_EMAIL_COUNT},\"threads\":${OVERNIGHT_EMAIL_THREADS},\"gog_available\":${GOG_AVAILABLE}}"

# --- 6. Today's calendar events (via gogcli — degrades gracefully if unavailable) ---
CALENDAR_EVENTS='[]'
if [[ "$GOG_AVAILABLE" == "true" ]]; then
  print "Fetching calendar events for $GCAL_ACCOUNT" >&2
  CALENDAR_EVENTS=$($GOG calendar events \
    --account "$GCAL_ACCOUNT" \
    --today \
    --json \
    --no-input \
    --non-interactive \
    --results-only 2>/dev/null) || CALENDAR_EVENTS='[]'
fi

# --- Output structured JSON to stdout ---
json_ok "{\"repo\":\"$REPO\",\"as_of\":\"$(date -u '+%Y-%m-%dT%H:%M:%SZ')\",\"merged_prs\":$MERGED_PRS,\"ci_failures\":$CI_FAILURES,\"stale_prs\":$STALE_PRS,\"autonomous_decisions\":$AUTONOMOUS_DECISIONS,\"overnight_email\":$OVERNIGHT_EMAIL,\"calendar_events\":$CALENDAR_EVENTS}"

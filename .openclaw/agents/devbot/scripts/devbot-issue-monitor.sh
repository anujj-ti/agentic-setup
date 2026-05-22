#!/usr/bin/env zsh
# devbot-issue-monitor.sh — DevBot autonomous issue pickup loop (DEV-07, DEV-08, DEV-09)
# Usage: devbot-issue-monitor.sh [OWNER/REPO]
#
# Decisions implemented:
#   D-201: Polls every 5 min via launchd cron (wired in Plan 04)
#   D-202: Tracks last-seen in state/last-issue-timestamp
#   D-203: Writes pending JSON + queue file for session pickup
#   D-204: Claim = gh issue edit N --add-assignee echosysbot --add-label status:in-progress
#   D-205: Stale-claim guard is a SEPARATE script (devbot-stale-claim-guard.sh)
#   D-206: automation:hold kill switch — skip issue if label present
#   D-207: gh issue develop N --checkout for branch creation
#   D-208: gh pr create --fill --body "Resolves #N" --draft
#   D-209: gh pr merge --auto --squash --delete-branch
#   D-210: PR body includes "Resolves #N" for auto-close
#
# stdout: JSON only (cc-openclaw json-response.sh convention)
# stderr: human-readable progress logs (cron redirects to LOG_FILE)
set -euo pipefail

source "$(dirname "$0")/lib/json-response.sh"

# --- Constants ---
AGENT_DIR="$HOME/.openclaw/agents/devbot"
STATE_DIR="$AGENT_DIR/state"
PENDING_DIR="$STATE_DIR/pending-issues"
LOGS_DIR="$AGENT_DIR/logs"
TIMESTAMP_FILE="$STATE_DIR/last-issue-timestamp"
GH="/opt/homebrew/bin/gh"
REPO="${1:-anujj-ti/agentic-setup}"
LOG_DATE=$(date '+%Y-%m-%d')
LOG_FILE="$LOGS_DIR/issue-monitor-${LOG_DATE}.log"

# --- Ensure runtime dirs exist ---
mkdir -p "$STATE_DIR" "$PENDING_DIR" "$LOGS_DIR"

# --- Load GH_TOKEN from Keychain (D-213 / T-19-03 mitigation) ---
export GH_TOKEN=$(security find-generic-password -s 'openclaw.github-bot-token' -a 'trilogy' -w 2>/dev/null)
if [[ -z "$GH_TOKEN" ]]; then
  print "[$(date -u '+%Y-%m-%dT%H:%M:%SZ')] issue-monitor: ERROR — GH_TOKEN not found in Keychain (openclaw.github-bot-token)" >&2
  json_err "GH_TOKEN not found in Keychain — run: security add-generic-password -s openclaw.github-bot-token -a trilogy -w <token>"
fi

# --- Read last-seen timestamp (D-202) ---
# Default to epoch start on first run so all existing issues are candidates
LAST_SEEN=$( [[ -f "$TIMESTAMP_FILE" ]] && cat "$TIMESTAMP_FILE" || print "1970-01-01T00:00:00Z" )

print "[$(date -u '+%Y-%m-%dT%H:%M:%SZ')] issue-monitor: polling $REPO (last_seen=$LAST_SEEN)" >&2

# --- Poll for candidate issues (D-201) ---
# Single gh call: automation:safe label, no assignee, open state
# --limit 20 cap (T-19-05 mitigation: DoS prevention)
ISSUES=$("$GH" issue list \
  --repo "$REPO" \
  --label "automation:safe" \
  --assignee "@none" \
  --state open \
  --json number,title,labels,createdAt,assignees \
  --limit 20 \
  2>/dev/null) || ISSUES="[]"

print "[$(date -u '+%Y-%m-%dT%H:%M:%SZ')] issue-monitor: fetched $(print "$ISSUES" | jq 'length') automation:safe issues" >&2

# --- Filter: newer than LAST_SEEN AND no automation:hold label (D-202, D-206) ---
NEW_ISSUES=$(print "$ISSUES" | jq --arg since "$LAST_SEEN" '[
  .[] | select(
    .createdAt > $since and
    ([.labels[].name] | map(select(. == "automation:hold")) | length) == 0
  )
] | sort_by(.createdAt)')

COUNT=$(print "$NEW_ISSUES" | jq 'length')

if [[ "$COUNT" -eq 0 ]]; then
  print "[$(date -u '+%Y-%m-%dT%H:%M:%SZ')] issue-monitor: no new issues to process" >&2
  json_ok '{"picked_up":0}'
  exit 0
fi

print "[$(date -u '+%Y-%m-%dT%H:%M:%SZ')] issue-monitor: $COUNT new issue(s) to process" >&2

# --- Process each candidate issue ---
# zsh while-read loop is safe under set -euo pipefail when inner commands handle their own errors
PROCESSED=0
print "$NEW_ISSUES" | jq -c '.[]' | while IFS= read -r issue; do
  ISSUE_NUM=$(print "$issue" | jq -r '.number')
  ISSUE_TITLE=$(print "$issue" | jq -r '.title')

  print "[$(date -u '+%Y-%m-%dT%H:%M:%SZ')] issue-monitor: processing issue #${ISSUE_NUM}: ${ISSUE_TITLE}" >&2

  # STEP 1 — Notion pre-log (SOUL.md mandatory requirement — T-19-06 mitigation: repudiation)
  # Pre-log before ANY GitHub mutation so all autonomous actions are auditable
  PAGE_ID=""
  PRE_LOG=$(node "$AGENT_DIR/scripts/notion-log-decision.js" \
    "Autonomous pickup of issue #${ISSUE_NUM}" \
    "Issue labeled automation:safe, no assignee, no automation:hold — matches pickup criteria" \
    "gh issue list confirmed: #${ISSUE_NUM} ${ISSUE_TITLE}" \
    "reversible: unassign + remove status:in-progress label to cancel" \
    2>/dev/null) || PRE_LOG=""

  if [[ -n "$PRE_LOG" ]]; then
    PAGE_ID=$(print "$PRE_LOG" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('pageId',''))" 2>/dev/null || print "")
  fi

  if [[ -n "$PAGE_ID" ]]; then
    print "[$(date -u '+%Y-%m-%dT%H:%M:%SZ')] issue-monitor: Notion pre-log OK (pageId=${PAGE_ID})" >&2
  else
    print "[$(date -u '+%Y-%m-%dT%H:%M:%SZ')] issue-monitor: WARNING — Notion pre-log failed or returned no pageId (non-blocking, continuing pickup)" >&2
  fi

  # STEP 2 — Claim the issue (D-204)
  # Assigns echosysbot + adds status:in-progress label
  print "[$(date -u '+%Y-%m-%dT%H:%M:%SZ')] issue-monitor: claiming issue #${ISSUE_NUM} (assignee=echosysbot, label=status:in-progress)" >&2
  "$GH" issue edit "$ISSUE_NUM" \
    --repo "$REPO" \
    --add-assignee "echosysbot" \
    --add-label "status:in-progress" \
    2>&1 >&2 || {
    print "[$(date -u '+%Y-%m-%dT%H:%M:%SZ')] issue-monitor: WARNING — failed to claim issue #${ISSUE_NUM}, skipping" >&2
    continue
  }

  # STEP 3 — Create branch (D-207)
  # gh issue develop creates a linked branch and checks it out
  print "[$(date -u '+%Y-%m-%dT%H:%M:%SZ')] issue-monitor: creating branch for issue #${ISSUE_NUM}" >&2
  "$GH" issue develop "$ISSUE_NUM" \
    --repo "$REPO" \
    --checkout \
    2>&1 >&2 || true

  # Derive branch name from gh issue develop --list or fall back to slug
  BRANCH=$("$GH" issue develop "$ISSUE_NUM" --repo "$REPO" --list 2>/dev/null | head -1 | awk '{print $1}') || BRANCH=""
  if [[ -z "$BRANCH" ]]; then
    BRANCH="${ISSUE_NUM}-$(print "$ISSUE_TITLE" | tr '[:upper:]' '[:lower:]' | tr ' ' '-' | tr -cd 'a-z0-9-' | cut -c1-40)"
  fi
  print "[$(date -u '+%Y-%m-%dT%H:%M:%SZ')] issue-monitor: branch=${BRANCH}" >&2

  # STEP 4 — Write issue JSON to pending-issues/ (D-203)
  print "$NEW_ISSUES" | jq --argjson num "$ISSUE_NUM" '.[] | select(.number == $num)' \
    > "$PENDING_DIR/${ISSUE_NUM}.json" || true

  # STEP 5 — Enqueue for DevBot session pickup (D-203)
  # The monitor runs outside OpenClaw sessions (invoked by launchd cron).
  # Write issue number to queue file; DevBot AGENTS.md startup check reads this queue.
  print "$ISSUE_NUM" >> "$STATE_DIR/pickup-queue.txt"
  print "[$(date -u '+%Y-%m-%dT%H:%M:%SZ')] issue-monitor: queued issue #${ISSUE_NUM} in pickup-queue.txt" >&2

  # STEP 6 — Open draft PR (D-208 + D-210)
  # Best-effort at monitor time — if branch has no commits yet, gh pr create will fail and we skip.
  # devbot-execute-cycle.sh handles the full PR lifecycle after code work is done.
  PR_URL=$("$GH" pr create \
    --repo "$REPO" \
    --head "$BRANCH" \
    --base main \
    --fill \
    --body "Resolves #${ISSUE_NUM}" \
    --draft \
    2>/dev/null) || PR_URL=""

  if [[ -n "$PR_URL" ]]; then
    print "[$(date -u '+%Y-%m-%dT%H:%M:%SZ')] issue-monitor: draft PR created: ${PR_URL}" >&2

    # STEP 7 — Enable auto-merge (D-209)
    # Sets auto-merge flag; CI gate still applies before merge executes
    "$GH" pr merge "$PR_URL" \
      --auto \
      --squash \
      --delete-branch \
      --repo "$REPO" \
      2>&1 >&2 || true
    print "[$(date -u '+%Y-%m-%dT%H:%M:%SZ')] issue-monitor: auto-merge enabled for ${PR_URL}" >&2
  else
    print "[$(date -u '+%Y-%m-%dT%H:%M:%SZ')] issue-monitor: PR creation skipped (no commits on branch yet — devbot-execute-cycle.sh will open PR after code work)" >&2
  fi

  PROCESSED=$((PROCESSED + 1))
done

# --- Update last-seen timestamp (D-202) ---
NEW_LAST_SEEN=$(print "$NEW_ISSUES" | jq -r 'last | .createdAt')
print "$NEW_LAST_SEEN" > "$TIMESTAMP_FILE"
print "[$(date -u '+%Y-%m-%dT%H:%M:%SZ')] issue-monitor: updated last-issue-timestamp to ${NEW_LAST_SEEN}" >&2

# --- Final JSON output ---
json_ok "{\"picked_up\":$COUNT,\"repo\":\"$REPO\",\"last_seen\":\"$NEW_LAST_SEEN\"}"

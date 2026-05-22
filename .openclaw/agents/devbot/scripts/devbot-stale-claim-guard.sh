#!/usr/bin/env zsh
# devbot-stale-claim-guard.sh — Hourly stale claim guard (D-205)
# Usage: devbot-stale-claim-guard.sh [OWNER/REPO]
# Finds issues stuck in status:in-progress with no branch activity in >2h and unassigns them.
# stdout: JSON only (cc-openclaw json-response.sh convention)
# stderr: human-readable progress logs
set -euo pipefail

source "$(dirname "$0")/lib/json-response.sh"

# --- Load GH_TOKEN from Keychain ---
export GH_TOKEN=$(security find-generic-password -s 'openclaw.github-bot-token' -a 'trilogy' -w 2>/dev/null)

# --- Constants ---
GH="/opt/homebrew/bin/gh"
REPO="${1:-anujj-ti/agentic-setup}"
STALE_HOURS=2
CUTOFF_ISO=$(date -u -v"-${STALE_HOURS}H" '+%Y-%m-%dT%H:%M:%SZ')

print "[$(date -u '+%Y-%m-%dT%H:%M:%SZ')] stale-claim-guard: checking $REPO (cutoff=$CUTOFF_ISO)" >&2

# --- List all open issues with status:in-progress label ---
IN_PROGRESS=$("$GH" issue list \
  --repo "$REPO" \
  --label "status:in-progress" \
  --state open \
  --json number,title,assignees,createdAt \
  --limit 50 \
  2>/dev/null)

COUNT=$(print "$IN_PROGRESS" | jq 'length')
print "[$(date -u '+%Y-%m-%dT%H:%M:%SZ')] stale-claim-guard: found $COUNT in-progress issues" >&2

if [[ "$COUNT" -eq 0 ]]; then
  json_ok '{"stale_unclaimed":0}'
  exit 0
fi

# --- Temp file to accumulate UNCLAIMED count across pipeline subshell ---
UNCLAIMED_FILE=$(mktemp)
trap 'rm -f "$UNCLAIMED_FILE"' EXIT
print "0" > "$UNCLAIMED_FILE"

# --- Process each in-progress issue ---
print "$IN_PROGRESS" | jq -c '.[]' | while IFS= read -r issue; do
  ISSUE_NUM=$(print "$issue" | jq -r '.number')
  ISSUE_TITLE=$(print "$issue" | jq -r '.title')
  print "checking issue #$ISSUE_NUM: $ISSUE_TITLE" >&2

  # Find linked branch via gh issue develop --list
  BRANCH=$("$GH" issue develop "$ISSUE_NUM" --repo "$REPO" --list 2>/dev/null | head -1 | awk '{print $1}' || print "")

  LAST_COMMIT_TIME=""
  if [[ -n "$BRANCH" ]]; then
    # Get last commit time on the branch
    LAST_COMMIT_TIME=$("$GH" api "repos/$REPO/branches/$BRANCH" --jq '.commit.commit.committer.date' 2>/dev/null || print "")
  fi

  # Determine staleness:
  # - Branch doesn't exist → stale (issue was claimed but branch never created)
  # - Branch exists but last commit is older than cutoff → stale
  # - Branch exists and last commit is newer than cutoff → not stale
  IS_STALE=false

  if [[ -z "$BRANCH" || -z "$LAST_COMMIT_TIME" ]]; then
    IS_STALE=true
    print "issue #$ISSUE_NUM stale: no branch or no commits" >&2
  elif [[ "$LAST_COMMIT_TIME" < "$CUTOFF_ISO" ]]; then
    IS_STALE=true
    print "issue #$ISSUE_NUM stale: last commit $LAST_COMMIT_TIME < cutoff $CUTOFF_ISO" >&2
  else
    print "issue #$ISSUE_NUM active: last commit $LAST_COMMIT_TIME" >&2
  fi

  if [[ "$IS_STALE" == "true" ]]; then
    # Unclaim: remove assignee and label
    "$GH" issue edit "$ISSUE_NUM" \
      --repo "$REPO" \
      --remove-assignee "echosysbot" \
      --remove-label "status:in-progress" \
      2>&1 >&2 || true

    # Add comment per D-205
    "$GH" issue comment "$ISSUE_NUM" \
      --repo "$REPO" \
      --body "echosysbot: timed out, unclaiming (no branch activity in ${STALE_HOURS}h — issue is available for pickup again)" \
      2>&1 >&2 || true

    print "unclaimed issue #$ISSUE_NUM" >&2
    UNCLAIMED=$(( $(cat "$UNCLAIMED_FILE") + 1 ))
    print "$UNCLAIMED" > "$UNCLAIMED_FILE"
  fi
done

UNCLAIMED=$(cat "$UNCLAIMED_FILE")

# --- Output structured JSON result ---
json_ok "{\"stale_unclaimed\":$UNCLAIMED,\"repo\":\"$REPO\",\"cutoff\":\"$CUTOFF_ISO\"}"

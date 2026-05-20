#!/usr/bin/env zsh
# devbot-merge-pr.sh — Notion-gated squash merge for DevBot (DEV-05)
# Usage: devbot-merge-pr.sh <PR_NUMBER>
# Requires: OPENCLAW_NOTION_TOKEN, OPENCLAW_NOTION_DECISIONS_DB_ID in environment
# Output: JSON to stdout; errors/logs to stderr
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
NODE="/opt/homebrew/opt/node@24/bin/node"
GH="/opt/homebrew/bin/gh"

if [[ $# -lt 1 ]]; then
  print '{"ok":false,"error":"usage: devbot-merge-pr.sh <PR_NUMBER>"}'
  exit 1
fi

PR_NUMBER="$1"

# --- Step 1: CI check ---
print "Checking CI status for PR #${PR_NUMBER}..." >&2
CI_RAW=$("$GH" pr view "$PR_NUMBER" --json statusCheckRollup 2>/dev/null || echo '{"statusCheckRollup":[]}')
CI_ALL_PASS=$(print "$CI_RAW" | /opt/homebrew/bin/jq -r '
  if .statusCheckRollup == null or (.statusCheckRollup | length) == 0 then "empty"
  elif [.statusCheckRollup[] | .state // .conclusion] | all(. == "SUCCESS") then "pass"
  else "fail"
  end' 2>/dev/null || echo "fail")

if [[ "$CI_ALL_PASS" != "pass" ]]; then
  print "{\"ok\":false,\"error\":\"CI checks not all passing (status: ${CI_ALL_PASS})\",\"prNumber\":\"${PR_NUMBER}\"}"
  exit 1
fi
print "CI check: PASS" >&2

# --- Step 2: Notion pre-log (MUST succeed before merge — D-100) ---
print "Logging decision to Notion before merge..." >&2
PAGE_ID=$("$NODE" "$SCRIPT_DIR/notion-log-decision.js" \
  --action "merge PR #${PR_NUMBER}" \
  --rationale "CI passing, quality review passed, autonomous merge authorized" \
  --reversibility "reversible via devbot-revert-merge.sh: git revert <sha> + gh pr reopen" \
  --evidence "statusCheckRollup: all SUCCESS on PR #${PR_NUMBER}" 2>/dev/null) || {
    print "{\"ok\":false,\"error\":\"Notion pre-log failed — merge blocked per D-100\",\"prNumber\":\"${PR_NUMBER}\"}"
    exit 1
  }

# Guard: PAGE_ID must be non-empty (set -e already catches non-zero exit above)
if [[ -z "$PAGE_ID" ]]; then
  print "{\"ok\":false,\"error\":\"Notion pre-log failed — empty page ID returned — merge blocked per D-100\",\"prNumber\":\"${PR_NUMBER}\"}"
  exit 1
fi
print "Notion pre-log: PASS (page ID: ${PAGE_ID})" >&2

# --- Step 3: Squash merge (per D-101) — only reachable after PAGE_ID confirmed ---
print "Squash merging PR #${PR_NUMBER}..." >&2
"$GH" pr merge "$PR_NUMBER" --squash --delete-branch
print "Merge complete." >&2

# --- Step 4: Capture merge commit SHA (per D-102) and update Notion page ---
MERGE_SHA=$("$GH" pr view "$PR_NUMBER" --json mergeCommit --jq '.mergeCommit.oid' 2>/dev/null || echo "")
if [[ -n "$MERGE_SHA" ]]; then
  print "Updating Notion page with merge SHA: ${MERGE_SHA}..." >&2
  "$NODE" "$SCRIPT_DIR/notion-update-page.js" --pageId "$PAGE_ID" --mergeCommitSha "$MERGE_SHA" 2>/dev/null || print "Warning: Notion SHA update failed (non-fatal)" >&2
fi

# --- Output success JSON ---
print "{\"ok\":true,\"pageId\":\"${PAGE_ID}\",\"mergeCommitSha\":\"${MERGE_SHA:-unknown}\",\"prNumber\":\"${PR_NUMBER}\"}"

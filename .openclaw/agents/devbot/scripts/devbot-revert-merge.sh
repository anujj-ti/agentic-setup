#!/usr/bin/env zsh
# devbot-revert-merge.sh — revert a squash merge commit (DEV-05)
# Usage: devbot-revert-merge.sh <MERGE_SHA> <PR_NUMBER> <ORIGINAL_PAGE_ID>
# Squash merge creates a SINGLE regular commit — git revert <sha> --no-edit works directly.
# Do NOT use -m 1 flag: that is only for true merge commits with two parents (per D-103).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
NODE="/opt/homebrew/opt/node@24/bin/node"
GH="/opt/homebrew/bin/gh"

# --- Validate positional args ---
if [[ $# -lt 3 ]]; then
  print '{"ok":false,"error":"usage: devbot-revert-merge.sh <merge_sha> <pr_number> <original_page_id>"}'
  exit 1
fi

MERGE_SHA="$1"
PR_NUMBER="$2"
ORIGINAL_PAGE_ID="$3"

if [[ -z "$MERGE_SHA" || -z "$PR_NUMBER" || -z "$ORIGINAL_PAGE_ID" ]]; then
  print '{"ok":false,"error":"usage: devbot-revert-merge.sh <merge_sha> <pr_number> <original_page_id>"}'
  exit 1
fi

# --- Step 1: Create revert commit (no -m flag — squash commits are single-parent per D-103) ---
print "Creating revert commit for ${MERGE_SHA}..." >&2
if ! git revert "$MERGE_SHA" --no-edit; then
  print '{"ok":false,"error":"git revert failed — SHA may be incorrect or working tree is dirty"}'
  exit 1
fi
print "Revert commit created." >&2

# --- Step 2: Push revert commit ---
print "Pushing revert commit..." >&2
if ! git push origin HEAD; then
  print '{"ok":false,"error":"git push failed"}'
  exit 1
fi
print "Push complete." >&2

# --- Step 3: Reopen PR (non-fatal if fails — revert commit already pushed) ---
print "Reopening PR #${PR_NUMBER}..." >&2
"$GH" pr reopen "$PR_NUMBER" \
  --comment "Merge reverted. Squash commit: ${MERGE_SHA}. See original Notion decision: ${ORIGINAL_PAGE_ID}. Note: head branch was deleted at merge time — recreate branch to push new commits." \
  2>/dev/null || print "Warning: gh pr reopen failed — PR may already be open or merged into another branch. Revert commit is the source of truth." >&2

# --- Step 4: Log revert to Notion (non-fatal) ---
print "Logging revert to Notion..." >&2
REVERT_PAGE_ID=""
REVERT_PAGE_ID=$("$NODE" "$SCRIPT_DIR/notion-log-decision.js" \
  --action "revert merge PR #${PR_NUMBER}" \
  --rationale "User requested revert via Notion decision log" \
  --reversibility "permanent — creates new revert commit ${MERGE_SHA}-revert; cannot be un-reverted automatically" \
  --evidence "originalPageId:${ORIGINAL_PAGE_ID}, mergeCommitSha:${MERGE_SHA}" \
  2>/dev/null) || print "Warning: Notion revert log failed — revert commit is already pushed and is the source of truth." >&2

# --- Output success JSON ---
print "{\"ok\":true,\"revertedSha\":\"${MERGE_SHA}\",\"prNumber\":\"${PR_NUMBER}\",\"originalPageId\":\"${ORIGINAL_PAGE_ID}\",\"revertNotionPageId\":\"${REVERT_PAGE_ID:-not-logged}\"}"

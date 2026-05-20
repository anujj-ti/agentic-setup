#!/usr/bin/env zsh
# devbot-issue-create.sh — DevBot GitHub issue creation script (DEV-01)
# Usage: devbot-issue-create.sh --repo OWNER/REPO --title "..." --body "..."
#        [--label "bug"] [--milestone "v1.0"] [--project "Board Title"] [--assignee "@me"]
# stdout: JSON only (cc-openclaw json-response.sh convention)
# stderr: human-readable progress logs
set -euo pipefail

source "$(dirname "$0")/lib/json-response.sh"

GH=/opt/homebrew/bin/gh

# --- Argument parsing ---
REPO=""
TITLE=""
BODY=""
LABEL=""
MILESTONE=""
PROJECT=""
ASSIGNEE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo)      REPO="$2";      shift 2 ;;
    --title)     TITLE="$2";     shift 2 ;;
    --body)      BODY="$2";      shift 2 ;;
    --label)     LABEL="$2";     shift 2 ;;
    --milestone) MILESTONE="$2"; shift 2 ;;
    --project)   PROJECT="$2";   shift 2 ;;
    --assignee)  ASSIGNEE="$2";  shift 2 ;;
    *) json_err "Unknown argument: $1" ;;
  esac
done

# --- Validate required args ---
[[ -z "$REPO" ]]  && json_err "Missing required argument: --repo OWNER/REPO"
[[ -z "$TITLE" ]] && json_err "Missing required argument: --title"
[[ -z "$BODY" ]]  && json_err "Missing required argument: --body"

# --- Duplicate check (MANDATORY per SECURITY.md rule 3) ---
echo "Checking for duplicates in $REPO..." >&2
DUPES=$($GH issue list --repo "$REPO" --search "$TITLE" --state open --json number,title,url --limit 5 2>/dev/null || echo "[]")
DUPE_COUNT=$(printf '%s' "$DUPES" | jq 'length')
if [[ "$DUPE_COUNT" -gt 0 ]]; then
  DUPE_URL=$(printf '%s' "$DUPES" | jq -r '.[0].url')
  json_err "Possible duplicate issue found: $DUPE_URL — review before creating"
fi
echo "No duplicates found. Proceeding with issue creation." >&2

# --- Build gh issue create args ---
GH_ARGS=(issue create --repo "$REPO" --title "$TITLE" --body "$BODY")
[[ -n "${LABEL:-}" ]]     && GH_ARGS+=(--label "$LABEL")
[[ -n "${MILESTONE:-}" ]] && GH_ARGS+=(--milestone "$MILESTONE")
[[ -n "${PROJECT:-}" ]]   && GH_ARGS+=(--project "$PROJECT")
[[ -n "${ASSIGNEE:-}" ]]  && GH_ARGS+=(--assignee "$ASSIGNEE")

echo "Creating issue in $REPO: $TITLE" >&2

# --- Create the issue ---
ISSUE_URL=$($GH "${GH_ARGS[@]}" 2>/dev/null)

if [[ -z "$ISSUE_URL" ]]; then
  json_err "gh issue create returned empty output — check gh auth status and repo access"
fi

ISSUE_NUMBER=$(basename "$ISSUE_URL")
echo "Issue created: $ISSUE_URL" >&2

# --- Output structured JSON result ---
json_ok "{\"issue_url\": \"$ISSUE_URL\", \"issue_number\": $ISSUE_NUMBER, \"repo\": \"$REPO\"}"

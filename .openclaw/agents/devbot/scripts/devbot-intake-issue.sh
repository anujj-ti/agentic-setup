#!/usr/bin/env zsh
# devbot-intake-issue.sh — DevBot issue intake script (DEV-04)
# Usage: zsh devbot-intake-issue.sh OWNER/REPO ISSUE_NUM [--dry-run]
# stdout: structured JSON for Task Orchestrator delegation
# stderr: human-readable progress logs
# cc-openclaw convention: set -euo pipefail, JSON stdout only, explicit binary paths
set -euo pipefail

# ── Parse arguments ────────────────────────────────────────────────────────────
# Support --dry-run flag anywhere in args (before or after positional args)
DRY_RUN=false
POSITIONAL=()
for arg in "$@"; do
  if [[ "$arg" == "--dry-run" ]]; then
    DRY_RUN=true
  else
    POSITIONAL+=("$arg")
  fi
done

REPO="${POSITIONAL[1]:?repo required (OWNER/REPO)}"
ISSUE_NUM="${POSITIONAL[2]:?issue number required}"

GH="/opt/homebrew/bin/gh"

# ── Dry-run mode (smoke test — no network calls) ───────────────────────────────
if [[ "$DRY_RUN" == "true" ]]; then
  print "dry-run mode — returning canned response" >&2
  python3 -c "
import json
result = {
    'ok': True,
    'repo': 'OWNER/REPO',
    'dry_run': True,
    'issue': {
        'number': 0,
        'title': 'dry-run test issue',
        'body': 'This is a dry-run response for smoke testing.',
        'labels': ['test'],
        'milestone': None,
        'assignees': [],
        'url': 'https://github.com/OWNER/REPO/issues/0'
    }
}
print(json.dumps(result))
"
  exit 0
fi

# ── Live mode — fetch issue via gh CLI ────────────────────────────────────────
print "fetching issue #$ISSUE_NUM from $REPO..." >&2

# Capture stderr to detect failures
TMP_STDERR=$(mktemp)
trap 'rm -f "$TMP_STDERR"' EXIT

issue_raw=$("$GH" issue view "$ISSUE_NUM" \
  -R "$REPO" \
  --json title,body,labels,milestone,assignees,number,url \
  2>"$TMP_STDERR") || {
  err=$(cat "$TMP_STDERR" | head -1 | tr '"' "'")
  print "{\"ok\":false,\"error\":\"gh issue view failed: ${err}\"}"
  exit 1
}

# ── Parse and structure with python3 ──────────────────────────────────────────
TMP_RAW=$(mktemp)
trap 'rm -f "$TMP_STDERR" "$TMP_RAW"' EXIT
print "$issue_raw" > "$TMP_RAW"

python3 - "$TMP_RAW" "$REPO" <<'PYEOF'
import sys, json

raw_file = sys.argv[1]
repo     = sys.argv[2]

with open(raw_file) as f:
    data = json.load(f)

# Extract and normalize fields
number    = data.get('number', 0)
title     = data.get('title', '') or ''
body      = data.get('body', '') or ''
url       = data.get('url', '') or ''

# Labels: [{name, color}] -> [name]
labels = [l.get('name', '') for l in (data.get('labels') or []) if l.get('name')]

# Milestone: {title: ...} | null -> string | null
milestone_raw = data.get('milestone')
milestone = milestone_raw.get('title') if milestone_raw else None

# Assignees: [{login: ...}] -> [login]
assignees = [a.get('login', '') for a in (data.get('assignees') or []) if a.get('login')]

# Body truncation to 2000 chars (SECURITY.md rule — prevent injection via long issue bodies)
if len(body) > 2000:
    body = body[:2000] + '...[truncated]'

result = {
    'ok': True,
    'repo': repo,
    'issue': {
        'number': number,
        'title': title,
        'body': body,
        'labels': labels,
        'milestone': milestone,
        'assignees': assignees,
        'url': url
    }
}

print(json.dumps(result))
PYEOF

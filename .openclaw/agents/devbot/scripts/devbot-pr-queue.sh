#!/usr/bin/env zsh
# devbot-pr-queue.sh — DevBot PR review queue scanner (DEV-02)
# Usage: devbot-pr-queue.sh OWNER/REPO [stale-hours]
# stdout: JSON only (cc-openclaw json-response.sh convention)
# stderr: human-readable progress logs
#
# NOTE: jq .updatedAt < $cutoff is ISO 8601 string comparison.
# Valid only because both strings are RFC 3339 UTC with Z suffix.
# GitHub gh pr list --json updatedAt always returns this format (as of 2026-05).
# Phase 8+: upgrade to jq (now - STALE_SEC | todate) for pure-jq timestamp math.
set -euo pipefail

source "$(dirname "$0")/lib/json-response.sh"

# DevBot acts as echosysbot — load its GitHub token from Keychain
export GH_TOKEN=$(security find-generic-password -s 'openclaw.github-bot-token' -a 'trilogy' -w 2>/dev/null)
GH=/opt/homebrew/bin/gh

# --- Argument parsing ---
REPO="${1:?$(json_err "Usage: devbot-pr-queue.sh OWNER/REPO [stale-hours]")}"
STALE_HOURS="${2:-24}"

# --- Compute staleness cutoff (macOS BSD date — note: NOT GNU date) ---
CUTOFF_ISO=$(date -u -v"-${STALE_HOURS}H" '+%Y-%m-%dT%H:%M:%SZ')
echo "Scanning PRs in $REPO (stale threshold: ${STALE_HOURS}h, cutoff: $CUTOFF_ISO)" >&2

# --- Single gh pr list call for all PR data (per D-72 — one call, not N per PR) ---
ALL_PRS=$($GH pr list \
  --repo "$REPO" \
  --state open \
  --json number,title,createdAt,updatedAt,author,reviewDecision,reviewRequests,latestReviews,statusCheckRollup,url \
  --limit 50 \
  2>/dev/null)

echo "Fetched $(printf '%s' "$ALL_PRS" | jq 'length') open PRs" >&2

# --- Stale PR filter: pending review OR CHANGES_REQUESTED and not updated within threshold ---
STALE_PRS=$(printf '%s' "$ALL_PRS" | jq --arg cutoff "$CUTOFF_ISO" '[
  .[] | select(
    ((.reviewRequests | length) > 0 or .reviewDecision == "CHANGES_REQUESTED") and
    .updatedAt < $cutoff
  ) | {number, title, updatedAt, reviewDecision, url}
]')

# --- CI failure filter — CRITICAL: null-guard on statusCheckRollup ---
# PRs from repos with no GitHub Actions return null for statusCheckRollup.
# Without null-guard, jq errors on null and the script exits non-zero.
FAILING_CI=$(printf '%s' "$ALL_PRS" | jq '[
  .[] | select(
    .statusCheckRollup != null and
    (.statusCheckRollup | map(select(.state == "FAILURE")) | length) > 0
  ) | {number, title, url, failing_checks: [.statusCheckRollup[] | select(.state == "FAILURE") | .context]}
]')

echo "Stale PRs: $(printf '%s' "$STALE_PRS" | jq 'length'), Failing CI: $(printf '%s' "$FAILING_CI" | jq 'length')" >&2

# --- Output structured JSON result ---
json_ok "{\"stale_prs\": $STALE_PRS, \"failing_ci\": $FAILING_CI, \"repo\": \"$REPO\", \"stale_threshold_hours\": $STALE_HOURS}"

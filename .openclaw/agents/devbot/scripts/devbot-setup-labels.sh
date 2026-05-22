#!/usr/bin/env zsh
# devbot-setup-labels.sh — Idempotent GitHub label setup for DevBot autonomous issue pickup (D-212)
# Usage: devbot-setup-labels.sh [OWNER/REPO]
# Defaults to anujj-ti/agentic-setup if no repo argument provided.
# stdout: JSON only (cc-openclaw json-response.sh convention)
# stderr: human-readable progress logs
set -euo pipefail

source "$(dirname "$0")/lib/json-response.sh"

# DevBot acts as echosysbot — load its GitHub token from Keychain
export GH_TOKEN=$(security find-generic-password -s 'openclaw.github-bot-token' -a 'trilogy' -w 2>/dev/null)
GH=/opt/homebrew/bin/gh

# --- Constants ---
REPO="${1:-anujj-ti/agentic-setup}"

echo "Setting up DevBot automation labels in $REPO..." >&2

# --- Label creation helper (idempotent via --force per D-212) ---
create_label() {
  local name="$1"
  local color="$2"
  local desc="$3"
  echo "  Creating label: $name" >&2
  "$GH" label create "$name" --repo "$REPO" --color "$color" --description "$desc" --force 2>&1 >&2 || true
}

# --- Create all 7 required labels per D-211 ---
create_label "automation:safe"    "0e8a16" "DevBot may autonomously pick up this issue"
create_label "automation:hold"    "b60205" "Kill switch — DevBot must not pick up this issue"
create_label "status:in-progress" "fbca04" "DevBot has claimed this issue and is working on it"
create_label "e1"                 "0075ca" "Effort: small (< 1h)"
create_label "e2"                 "0075ca" "Effort: medium (1–4h)"
create_label "e3"                 "0075ca" "Effort: large (4h+)"
create_label "agent:echosysbot"   "cfd3d7" "Assigned to echosysbot automation account"

echo "All 7 label create calls completed. Verifying..." >&2

# --- Verify all 7 labels are present ---
PRESENT=$("$GH" label list --repo "$REPO" --json name | jq '[.[] | .name] | map(select(. == "automation:safe" or . == "automation:hold" or . == "status:in-progress" or . == "e1" or . == "e2" or . == "e3" or . == "agent:echosysbot")) | length')

echo "Labels verified: $PRESENT/7" >&2

if [[ "$PRESENT" -eq 7 ]]; then
  json_ok "{\"labels_created\":7,\"repo\":\"$REPO\"}"
else
  json_err "only $PRESENT/7 labels verified in $REPO"
fi

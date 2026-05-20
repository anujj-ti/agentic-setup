#!/usr/bin/env zsh
set -euo pipefail
# install-prereqs.sh — installs node@24, stow, and jq via Homebrew
# Decisions implemented: D-12, D-13, D-14, D-15
# Source: .planning/phases/01-infrastructure/01-PATTERNS.md + 01-RESEARCH.md

# D-14: Fail immediately if Homebrew is not installed
if ! command -v brew &>/dev/null; then
  print "ERROR: Homebrew is required but not installed." >&2
  print "Install it: https://brew.sh" >&2
  print '{"ok":false,"error":"homebrew_required"}'
  exit 1
fi

# D-12: Idempotent installs — install only if not already present
print "Checking/installing node@24..." >&2
brew list node@24 &>/dev/null || brew install node@24

print "Checking/installing stow..." >&2
brew list stow &>/dev/null || brew install stow

print "Checking/installing jq..." >&2
brew list jq &>/dev/null || brew install jq

# D-13 + Pitfall 5: Architecture-aware PATH for keg-only node@24
if [[ "$(uname -m)" == "arm64" ]]; then
  NODE24_BIN="/opt/homebrew/opt/node@24/bin"
else
  NODE24_BIN="/usr/local/opt/node@24/bin"
fi
export PATH="${NODE24_BIN}:${PATH}"

# D-13: Verify node@24 is now active
node_version="$(node --version 2>/dev/null || true)"
if [[ "${node_version}" != v24* ]]; then
  print "ERROR: node@24 not active after PATH update. Got: ${node_version}" >&2
  print "Check that node@24 is correctly installed at: ${NODE24_BIN}" >&2
  print '{"ok":false,"error":"node24_not_active"}'
  exit 1
fi
print "node@24 active: ${node_version}" >&2

# D-13: Conditional pin in openclaw-secrets.sh (launchd surface)
# Only appends if file exists AND doesn't already contain the node@24 pin
SECRETS_SH="$HOME/Documents/agentic-setup/.openclaw/scripts/openclaw-secrets.sh"
if [[ -f "$SECRETS_SH" ]]; then
  if ! grep -q "node@24" "$SECRETS_SH"; then
    print "export PATH=\"${NODE24_BIN}:\$PATH\"" >> "$SECRETS_SH"
    print "Pinned node@24 PATH in openclaw-secrets.sh (launchd)" >&2
  else
    print "node@24 already pinned in openclaw-secrets.sh" >&2
  fi
else
  print "openclaw-secrets.sh not found — pin will be added after Task 3 creates it" >&2
fi

# D-13: Parallel conditional pin in openclaw-env.sh (shell session surface)
# Per D-13: BOTH files must have the node@24 pin so launchd AND interactive shells both see Node 24
ENV_SH="$HOME/Documents/agentic-setup/.openclaw/scripts/openclaw-env.sh"
if [[ -f "$ENV_SH" ]]; then
  if ! grep -q "node@24" "$ENV_SH"; then
    print "export PATH=\"${NODE24_BIN}:\$PATH\"" >> "$ENV_SH"
    print "Pinned node@24 PATH in openclaw-env.sh (shell sessions)" >&2
  else
    print "node@24 already pinned in openclaw-env.sh" >&2
  fi
else
  print "openclaw-env.sh not found — pin will be added after Task 3 creates it" >&2
fi

# D-15: This script MUST NOT run the OpenClaw curl installer
# OpenClaw installation is a separate interactive step (Task 4 checkpoint)

# Success output: JSON with node version and architecture
print "{\"ok\":true,\"data\":{\"node\":\"${node_version}\",\"arch\":\"$(uname -m)\"}}"

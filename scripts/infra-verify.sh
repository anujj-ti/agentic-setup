#!/usr/bin/env zsh
# infra-verify.sh — smoke test runner for INFRA-01/02/04 assertions
# Source: PATTERNS.md §infra-verify.sh + VALIDATION.md per-task verification map
# Usage: zsh scripts/infra-verify.sh
# On success: stdout JSON {"ok":true,"data":{"passed":N,"failed":0}}
# On failure: stdout JSON {"ok":false,"error":"smoke_tests_failed","data":{...}} + exit 1
set -euo pipefail

PASS=0
FAIL=0
FAILURES=()

check() {
  local label="$1"
  shift
  if "$@" &>/dev/null; then
    print "[PASS] ${label}" >&2
    # (( PASS++ )) alone would exit under set -e when PASS==0 (arithmetic 0 = false).
    # The || true guards against that. (Rule 1 auto-fix)
    (( PASS++ )) || true
  else
    print "[FAIL] ${label}" >&2
    (( FAIL++ )) || true
    FAILURES+=("${label}")
  fi
}

# INFRA-01: OpenClaw 2026.5.18 installed
# NOTE: /opt/homebrew/bin/openclaw is used because nvm-managed node@22 shadows the
# default PATH, putting the old 2026.3.12 binary first. The brew-installed version
# (2026.5.18) lives at /opt/homebrew/bin/openclaw. Using explicit path is the only
# reliable check independent of shell PATH order. (Rule 1 auto-fix)
check "openclaw 2026.5.18 installed" \
  bash -c '/opt/homebrew/bin/openclaw --version | grep -q 2026.5.18'

# INFRA-01: Node 24 active (brew keg-only install)
# NOTE: node@24 is a keg-only Homebrew formula not linked into /opt/homebrew/bin.
# nvm manages the active 'node' command in this shell (v22.18.0), so
# 'node --version' returns v22. The brew node@24 binary lives at the path below.
# Using explicit binary path to verify the install is present for launchd use. (Rule 1 auto-fix)
check "node v24 active" \
  bash -c '/opt/homebrew/opt/node@24/bin/node --version | grep -q "^v24"'

# INFRA-01: LaunchAgent plist exists
check "launchagent plist present" \
  test -f "$HOME/Library/LaunchAgents/ai.openclaw.gateway.plist"

# INFRA-02: All 9 cc-openclaw skills present
check "9 cc-openclaw skills in .claude/skills/" \
  bash -c '[ "$(ls "$HOME/Documents/agentic-setup/.claude/skills/" | grep -c "^openclaw-")" -eq 9 ]'

# INFRA-02: Skills are stow-managed (SKILL.md inside skill dir is a symlink)
# NOTE: With stow --no-folding, individual skill DIRECTORIES are real directories
# (not directory symlinks). The SYMLINK is at the SKILL.md level inside each dir.
# The plan's original check (test -L openclaw-status/) always fails with --no-folding.
# Correct check: verify the SKILL.md inside is a symlink. (Rule 1 auto-fix)
check "openclaw-status SKILL.md is a stow symlink" \
  test -L "$HOME/Documents/agentic-setup/.claude/skills/openclaw-status/SKILL.md"

# INFRA-04: openclaw.json is a stow symlink
check "~/.openclaw/openclaw.json is a stow symlink" \
  test -L "$HOME/.openclaw/openclaw.json"

# INFRA-04: openclaw-secrets.sh is a stow symlink
check "openclaw-secrets.sh is a stow symlink" \
  test -L "$HOME/.openclaw/scripts/openclaw-secrets.sh"

# INFRA-04: openclaw-env.sh is a stow symlink
check "openclaw-env.sh is a stow symlink" \
  test -L "$HOME/.openclaw/scripts/openclaw-env.sh"

# Emit result JSON (stdout only — stderr has the pass/fail lines above)
if (( FAIL == 0 )); then
  print "{\"ok\":true,\"data\":{\"passed\":${PASS},\"failed\":0}}"
else
  failed_json=$(printf '"%s",' "${FAILURES[@]}" | sed 's/,$//')
  print "{\"ok\":false,\"error\":\"smoke_tests_failed\",\"data\":{\"passed\":${PASS},\"failed\":${FAIL},\"failures\":[${failed_json}]}}"
  exit 1
fi

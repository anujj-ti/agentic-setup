#!/usr/bin/env zsh
# openclaw-env.sh — source this in your shell profile for CLI access to OpenClaw secrets
# Add to ~/.zshrc: source ~/.openclaw/scripts/openclaw-env.sh
# DO NOT edit manually. Use /openclaw-add-secret to add new secrets.
# Source: cc-openclaw openclaw-add-secret SKILL.md + CONTEXT.md canonical refs

# node@24 PATH (same as openclaw-secrets.sh — keeps launchd and shell sessions in sync per D-13)
# (architecture-aware; set by install-prereqs.sh conditional append per D-13)
# export PATH="/opt/homebrew/opt/node@24/bin:$PATH"   # Apple Silicon — appended by install-prereqs.sh
# export PATH="/usr/local/opt/node@24/bin:$PATH"      # Intel — appended by install-prereqs.sh if needed

# Secrets appended below by /openclaw-add-secret:
export OPENCLAW_TEST_SECRET="$(security find-generic-password -s 'openclaw.test-secret' -w 2>/dev/null || true)"

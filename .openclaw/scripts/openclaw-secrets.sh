#!/usr/bin/env zsh
# openclaw-secrets.sh — sourced by launchd at ai.openclaw.gateway startup
# DO NOT edit manually. Use /openclaw-add-secret to add new secrets.
# Source: cc-openclaw openclaw-add-secret SKILL.md + CONTEXT.md canonical refs

# node@24 PATH pin — required because launchd does not source ~/.zshrc
# (architecture-aware; set by install-prereqs.sh conditional append per D-13)
# export PATH="/opt/homebrew/opt/node@24/bin:$PATH"   # Apple Silicon — appended by install-prereqs.sh
# export PATH="/usr/local/opt/node@24/bin:$PATH"      # Intel — appended by install-prereqs.sh if needed

# Secrets are appended below by /openclaw-add-secret:
export OPENCLAW_TEST_SECRET="$(security find-generic-password -s 'openclaw.test-secret' -w 2>/dev/null || true)"
export PATH="/opt/homebrew/opt/node@24/bin:$PATH"

# Appended by /openclaw-add-channel (Phase 2, Plan 02-01) — DO NOT edit manually
export OPENCLAW_TELEGRAM_MAIN_BOT_TOKEN=$(security find-generic-password -s 'openclaw.telegram-main-bot-token' -w 2>/dev/null)

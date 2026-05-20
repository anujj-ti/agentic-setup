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

# Beads shared task graph database — Phase 4 (D-50, D-54)
export BEADS_DIR="$HOME/.openclaw/beads"

# Gmail OAuth2 credentials for Email Triage agent — Phase 6 (D-63)
export OPENCLAW_GMAIL_CLIENT_ID="$(security find-generic-password -s 'openclaw.gmail-client-id' -w 2>/dev/null || true)"
export OPENCLAW_GMAIL_CLIENT_SECRET="$(security find-generic-password -s 'openclaw.gmail-client-secret' -w 2>/dev/null || true)"
export OPENCLAW_GMAIL_TRIAGE_REFRESH_TOKEN="$(security find-generic-password -s 'openclaw.gmail-triage-refresh-token' -w 2>/dev/null || true)"

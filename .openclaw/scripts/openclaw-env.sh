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
export PATH="/opt/homebrew/opt/node@24/bin:$PATH"

# Appended by /openclaw-add-channel (Phase 2, Plan 02-01) — DO NOT edit manually
export OPENCLAW_TELEGRAM_MAIN_BOT_TOKEN=$(security find-generic-password -s 'openclaw.telegram-main-bot-token' -w 2>/dev/null || true)

# Beads shared task graph database — Phase 4 (D-50, D-54)
export BEADS_DIR="$HOME/.openclaw/beads"

# Gmail OAuth2 credentials for Email Triage agent — Phase 6 (D-63)
export OPENCLAW_GMAIL_CLIENT_ID="$(security find-generic-password -s 'openclaw.gmail-client-id' -w 2>/dev/null || true)"
export OPENCLAW_GMAIL_CLIENT_SECRET="$(security find-generic-password -s 'openclaw.gmail-client-secret' -w 2>/dev/null || true)"
export OPENCLAW_GMAIL_TRIAGE_REFRESH_TOKEN="$(security find-generic-password -s 'openclaw.gmail-triage-refresh-token' -w 2>/dev/null || true)"

# Telegram chat ID for CI Monitor alerts — Phase 8 (D-84)
export OPENCLAW_ANUJ_CHAT_ID="${OPENCLAW_ANUJ_CHAT_ID:-}"

# Notion integration token — Phase 9 (D-92)
export OPENCLAW_NOTION_TOKEN=$(security find-generic-password -s openclaw.notion-token -w 2>/dev/null || echo "")

# Synapse org memory token
export SYNAPSE_TOKEN="$(security find-generic-password -s 'openclaw.synapse-token' -w 2>/dev/null || true)"
export SYNAPSE_URL="https://cnu.synapse-os.ai"

# GitHub bot token for echosysbot — DevBot uses GH_TOKEN; global gh CLI stays as anujj-ti
export GH_TOKEN="$(security find-generic-password -s 'openclaw.github-bot-token' -w 2>/dev/null || true)"

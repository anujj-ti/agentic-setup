#!/usr/bin/env zsh
# secrets.sh — disaster recovery: re-provision all Keychain secrets on a fresh machine
# Run this after git clone + stow-deploy.sh on a new machine.
# For each entry: security add-generic-password prompts securely for the value.
# Source: cc-openclaw openclaw-add-secret SKILL.md + CONTEXT.md canonical refs
# Location: repo root — NOT stowed (excluded in .stow-ignore per D-03)
set -euo pipefail

# Format: "keychain-service-name|OPENCLAW_ENV_VAR_NAME|human-readable description"
# Entries are appended below by /openclaw-add-secret
SECRETS=(
  # "openclaw.example-token|OPENCLAW_EXAMPLE_TOKEN|Example secret (replace with real entries)"
  "openclaw.test-secret|OPENCLAW_TEST_SECRET|Phase 1 INFRA-03 verification secret — safe to delete"
  "openclaw.telegram-main-bot-token|OPENCLAW_TELEGRAM_MAIN_BOT_TOKEN|Telegram bot token for @echo_sys_bot (main agent)"
  # Gmail OAuth2 credentials — Phase 6 (D-63)
  "openclaw.gmail-client-id|OPENCLAW_GMAIL_CLIENT_ID|Gmail OAuth2 Desktop App Client ID for echo.sys.bot@gmail.com"
  "openclaw.gmail-client-secret|OPENCLAW_GMAIL_CLIENT_SECRET|Gmail OAuth2 Desktop App Client Secret for echo.sys.bot@gmail.com"
  "openclaw.gmail-triage-refresh-token|OPENCLAW_GMAIL_TRIAGE_REFRESH_TOKEN|Gmail API refresh token for email-triage agent (generate via oauth2-setup.js)"
)

for entry in "${SECRETS[@]}"; do
  service="${entry%%|*}"
  rest="${entry#*|}"
  envvar="${rest%%|*}"
  description="${rest##*|}"

  print "Provisioning: ${description} (${service})" >&2
  security add-generic-password \
    -s "${service}" \
    -a "$USER" \
    -U \
    -w  # prompts securely — value is never echoed or stored in this file
done

print '{"ok":true,"data":{"provisioned":'"${#SECRETS[@]}"'}}'

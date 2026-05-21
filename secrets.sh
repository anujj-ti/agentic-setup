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
  # CI Monitor Telegram chat ID — Phase 8 (D-84)
  # Get your chat ID: send a DM to your bot and run: openclaw logs --follow | grep chat_id
  "openclaw.anuj-chat-id|OPENCLAW_ANUJ_CHAT_ID|Your Telegram chat ID (get from @userinfobot or openclaw logs --follow | grep chat_id)"
  # Synapse org memory token — shared by all agents for coordination + learning recording
  "openclaw.synapse-token|SYNAPSE_TOKEN|Synapse org memory token (project.edullm-sat-math + project.agentic-setup). Get from Synapse dashboard at https://cnu.synapse-os.ai"
  # Notion integration token — Phase 9 (D-92)
  # Service: openclaw.notion-token | Env var: OPENCLAW_NOTION_TOKEN
  # Create at: https://www.notion.so/my-integrations
  # Run: /openclaw-add-secret notion-token <integration_token>
  # GitHub bot token for echosysbot — DevBot agent identity (separate from personal anujj-ti)
  "openclaw.github-bot-token|GH_TOKEN|GitHub PAT for echosysbot account (DevBot agent — scopes: repo, read:org, workflow, project)"
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

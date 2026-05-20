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
    -w  # prompts securely — value is never echoed or stored in this file
done

print '{"ok":true,"data":{"provisioned":'"${#SECRETS[@]}"'}}'

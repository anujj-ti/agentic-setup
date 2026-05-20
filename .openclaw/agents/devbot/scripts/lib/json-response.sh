#!/usr/bin/env zsh
# lib/json-response.sh — cc-openclaw output convention
# Source this file; call json_ok '{"key":"val"}' or json_err "message"
# Do NOT add set -euo pipefail here — sourcing scripts set their own strict mode.

json_ok() {
  local default_payload='{}'
  local payload="${1:-$default_payload}"
  printf '{"ok":true,"data":%s}\n' "$payload"
}

json_err() {
  local message="${1:-unknown error}"
  printf '{"ok":false,"error":"%s"}\n' "$message" >&2
  printf '{"ok":false,"error":"%s"}\n' "$message"
  exit 1
}

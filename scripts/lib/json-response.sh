#!/usr/bin/env zsh
# json-response.sh — sourced by other scripts, never executed directly
# Source: CLAUDE.md "Shell Scripting Conventions" + cc-openclaw json-response.sh pattern
# DO NOT set set -euo pipefail here — this file is sourced; strict mode lives in the calling script.

# Usage: json_ok '{"key":"value"}'
# Prints {"ok":true,"data":<data>} to stdout
json_ok() {
  local data="${1}"
  [[ -z "$data" ]] && data="{}"
  print "{\"ok\":true,\"data\":${data}}"
}

# Usage: json_fail "error_code" "human message"
# Prints {"ok":false,"error":"<code>"} to stdout AND "ERROR: <message>" to stderr
json_fail() {
  local code="$1"
  local msg="$2"
  print "{\"ok\":false,\"error\":\"${code}\"}"
  print "ERROR: ${msg}" >&2
  exit 1
}

#!/usr/bin/env zsh
# check-agent-domain.sh — domain coverage check for EVOL-01 agent proposal workflow
# Usage: check-agent-domain.sh "<proposed_domain_keyword>"
# Returns: {"ok":true,"action":"proceed_to_proposal",...} or {"ok":false,"reason":"...","action":"do_not_create"}
# Both outcomes exit 0 — "domain exists" is a valid signal, not an error.
set -euo pipefail

if [[ $# -lt 1 || -z "${1:-}" ]]; then
  printf '{"ok":false,"error":"usage: check-agent-domain.sh \"<proposed_domain_keyword>\""}\n'
  exit 1
fi

PROPOSED_DOMAIN="$1"

OPENCLAW_CONFIG="$HOME/.openclaw/openclaw.json"
if [[ ! -f "$OPENCLAW_CONFIG" ]]; then
  # Fallback to repo config (worktree context)
  REPO_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
  OPENCLAW_CONFIG="$REPO_ROOT/.openclaw/openclaw.json"
fi

if [[ ! -f "$OPENCLAW_CONFIG" ]]; then
  printf '{"ok":false,"error":"openclaw.json not found at expected path"}\n'
  exit 1
fi

AGENT_IDS=$(python3 -c "
import json, sys
d = json.load(open(sys.argv[1]))
print('\n'.join(a['id'] for a in d.get('agents', {}).get('list', [])))
" "$OPENCLAW_CONFIG" 2>/dev/null | sort)

MATCH=$(printf '%s' "$AGENT_IDS" | grep -i "$PROPOSED_DOMAIN" || true)

if [[ -n "$MATCH" ]]; then
  python3 -c "
import sys, json
domain = sys.argv[1]
match = sys.argv[2]
result = {'ok': False, 'reason': f\"Agent already exists for domain '{domain}': {match}\", 'action': 'do_not_create'}
print(json.dumps(result))
" "$PROPOSED_DOMAIN" "$MATCH"
  exit 0
fi

EXISTING_JSON=$(printf '%s' "$AGENT_IDS" | python3 -c "
import sys, json
ids = [l for l in sys.stdin.read().splitlines() if l]
print(json.dumps(ids))
")

python3 -c "
import sys, json
domain = sys.argv[1]
existing = json.loads(sys.argv[2])
result = {'ok': True, 'action': 'proceed_to_proposal', 'checkedDomain': domain, 'existingAgents': existing}
print(json.dumps(result))
" "$PROPOSED_DOMAIN" "$EXISTING_JSON"
exit 0

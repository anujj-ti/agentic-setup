#!/usr/bin/env zsh
# synapse-checkin.sh — check in to Synapse workflow
# Usage: zsh scripts/synapse-checkin.sh <project_id> <bd_id> <status> <current_task>
# status: start|progress|blocked|complete|failed
# Outputs JSON to stdout. All human-readable logs go to stderr.
# Exit 0 always — Synapse failure must never break agent execution (D-133).
set -euo pipefail

if [[ $# -lt 4 ]]; then
  print "Usage: $0 <project_id> <bd_id> <status> <current_task>" >&2
  print "  status: start|progress|blocked|complete|failed" >&2
  exit 1
fi

PROJECT_ID="$1"
BD_ID="$2"
STATUS="$3"
CURRENT_TASK="$4"

# TODO_SYNAPSE guard (D-133): if token absent, warn and exit 0 — never block agents
if [[ -z "${SYNAPSE_TOKEN:-}" ]]; then
  print "synapse-checkin: SYNAPSE_TOKEN not set — skipping (set openclaw.synapse-token in Keychain)" >&2
  print '{"ok":true,"data":{"skipped":true}}'
  exit 0
fi

SYNAPSE_URL="${SYNAPSE_URL:-https://cnu.synapse-os.ai}"

BODY=$(python3 -c "
import sys, json
p, b, s, t = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4]
body = {'project_id': p, 'bd_id': b, 'status': s, 'current_task': t}
print(json.dumps(body))
" "$PROJECT_ID" "$BD_ID" "$STATUS" "$CURRENT_TASK")

RESULT=$(/usr/bin/curl -sS -X POST "${SYNAPSE_URL}/v1/intent/synapse.checkin" \
  -H "Authorization: Bearer $SYNAPSE_TOKEN" \
  -H "Content-Type: application/json" \
  -d "$BODY" 2>/dev/null) || {
  print "synapse-checkin: curl failed — Synapse unreachable or auth error" >&2
  print '{"ok":false,"error":"curl failed"}'
  exit 0
}

print "$RESULT"

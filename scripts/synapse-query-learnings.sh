#!/usr/bin/env zsh
# synapse-query-learnings.sh — query Synapse org memory for learnings by domain tag
# Usage: zsh scripts/synapse-query-learnings.sh <project_id> <applies_to_tag> [limit]
# limit: number of learnings to retrieve (default: 5, per D-305)
# Outputs formatted bullet list to stdout — agents inject as session context.
# All human-readable logs go to stderr.
# Exit 0 always on non-arg errors — Synapse failure must never block agent startup (D-304).
set -euo pipefail

if [[ $# -lt 2 ]]; then
  print "Usage: $0 <project_id> <applies_to_tag> [limit]" >&2
  print "  applies_to_tag: single domain tag e.g. \"openclaw\" or \"email-triage\"" >&2
  print "  limit: max learnings to return (default: 5)" >&2
  exit 1
fi

PROJECT_ID="$1"
TAG="$2"
LIMIT="${3:-5}"

# D-304: if token absent, warn and exit 0 — never block agents
if [[ -z "${SYNAPSE_TOKEN:-}" ]]; then
  print "synapse-query-learnings: SYNAPSE_TOKEN not set — skipping" >&2
  exit 0
fi

SYNAPSE_URL="${SYNAPSE_URL:-https://cnu.synapse-os.ai}"

# Build JSON body with python3 json.dumps — safe quoting (matches synapse-record-learning.sh pattern)
BODY=$(python3 -c "
import sys, json
p, t, lim = sys.argv[1], sys.argv[2], int(sys.argv[3])
body = {
  'project_id': p,
  'applies_to': [t],
  'limit': lim
}
print(json.dumps(body))
" "$PROJECT_ID" "$TAG" "$LIMIT")

RESULT=$(/usr/bin/curl -sS -X POST "${SYNAPSE_URL}/v1/intent/synapse.learning.query" \
  -H "Authorization: Bearer $SYNAPSE_TOKEN" \
  -H "Content-Type: application/json" \
  -d "$BODY" 2>/dev/null) || {
  print "synapse-query-learnings: curl failed — Synapse unreachable or auth error" >&2
  print "# Synapse Learnings: ${TAG}"
  print "(unavailable)"
  exit 0
}

# Parse response with python3 — extract learnings and format as bullets (D-303)
python3 -c "
import sys, json

tag = sys.argv[1]
raw = sys.argv[2]

try:
  resp = json.loads(raw)
except json.JSONDecodeError:
  print('# Synapse Learnings: ' + tag)
  print('(unavailable)')
  sys.exit(0)

if not resp.get('ok'):
  print('# Synapse Learnings: ' + tag)
  print('(unavailable)')
  sys.exit(0)

learnings = resp.get('data', {}).get('learnings', [])

print('# Synapse Learnings: ' + tag)
if not learnings:
  print('- (no learnings found for this domain)')
  sys.exit(0)

for l in learnings:
  claim = l.get('claim', '(no claim)')
  confidence = l.get('confidence', 'low')
  print('- ' + claim + ' [confidence: ' + confidence + ']')
" "$TAG" "$RESULT"

#!/usr/bin/env zsh
# synapse-query-learnings.sh — query Synapse org memory for learnings by domain tag
# Usage: zsh scripts/synapse-query-learnings.sh <project_id> <applies_to_tag> [limit]
# Outputs formatted bullet list to stdout — agents inject as session context.
# Exit 0 always on non-arg errors — never blocks agent startup (D-304).
set -euo pipefail

if [[ $# -lt 2 ]]; then
  print "Usage: $0 <project_id> <applies_to_tag> [limit]" >&2
  exit 1
fi

PROJECT_ID="$1"
TAG="$2"
LIMIT="${3:-5}"

# D-304: token absent → exit 0, never block
if [[ -z "${SYNAPSE_TOKEN:-}" ]]; then
  print "synapse-query-learnings: SYNAPSE_TOKEN not set — skipping" >&2
  exit 0
fi

SYNAPSE_URL="${SYNAPSE_URL:-https://cnu.synapse-os.ai}"

# CR-02 fix: validate LIMIT is an integer before passing to python3
if ! [[ "$LIMIT" =~ ^[0-9]+$ ]]; then
  LIMIT=5
fi

# CR-02 fix: wrap python3 body-build with fallback — python3 unavailable = exit 0
BODY=$(python3 -c "
import sys, json
p, t, lim = sys.argv[1], sys.argv[2], int(sys.argv[3])
print(json.dumps({'project_id': p, 'applies_to': [t], 'limit': lim}))
" "$PROJECT_ID" "$TAG" "$LIMIT" 2>/dev/null) || {
  print "synapse-query-learnings: python3 failed — skipping" >&2
  exit 0
}

RESULT=$(/usr/bin/curl -sS -X POST "${SYNAPSE_URL}/v1/intent/synapse.learning.query" \
  -H "Authorization: Bearer $SYNAPSE_TOKEN" \
  -H "Content-Type: application/json" \
  -d "$BODY" 2>/dev/null) || {
  print "# Synapse Learnings: ${TAG}\n(unavailable)" >&2
  exit 0
}

# CR-02 fix: wrap parsing python3 with fallback — pipe RESULT via stdin (not argv)
printf '%s' "$RESULT" | python3 -c "
import sys, json
tag = sys.argv[1]
try:
  resp = json.loads(sys.stdin.read())
except Exception:
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
  conf = l.get('confidence', 'low')
  print('- ' + claim + ' [confidence: ' + conf + ']')
" "$TAG" 2>/dev/null || {
  print "# Synapse Learnings: ${TAG}" >&2
  print "(unavailable)" >&2
  exit 0
}

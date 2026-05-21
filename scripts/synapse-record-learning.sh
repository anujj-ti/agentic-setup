#!/usr/bin/env zsh
# synapse-record-learning.sh — record a learning to Synapse org memory
# Usage: zsh scripts/synapse-record-learning.sh <project_id> <bd_id> <claim> <applies_to_tags_csv>
# applies_to_tags_csv: comma-separated tags e.g. "openclaw,infrastructure"
# Confidence is always "low" (D-132) — no evidence_artifact_id required.
# Outputs JSON to stdout. All human-readable logs go to stderr.
# Exit 0 always — Synapse failure must never break agent execution (D-133).
set -euo pipefail

if [[ $# -lt 4 ]]; then
  print "Usage: $0 <project_id> <bd_id> <claim> <applies_to_tags_csv>" >&2
  print "  applies_to_tags_csv: comma-separated tags e.g. \"openclaw,infrastructure\"" >&2
  exit 1
fi

PROJECT_ID="$1"
BD_ID="$2"
CLAIM="$3"
TAGS_CSV="$4"

# TODO_SYNAPSE guard (D-133): if token absent, warn and exit 0 — never block agents
if [[ -z "${SYNAPSE_TOKEN:-}" ]]; then
  print "synapse-record-learning: SYNAPSE_TOKEN not set — skipping (set openclaw.synapse-token in Keychain)" >&2
  print '{"ok":true,"data":{"skipped":true}}'
  exit 0
fi

SYNAPSE_URL="${SYNAPSE_URL:-https://cnu.synapse-os.ai}"

# Build JSON body with python3 json.dumps — safe handling of quotes in claim text (T-13-02)
BODY=$(python3 -c "
import sys, json
p, b, c, t = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4]
tags = [tag.strip() for tag in t.split(',')]
body = {
  'project_id': p,
  'bd_id': b,
  'learnings': [{
    'claim': c,
    'applies_to': tags,
    'confidence': 'low'
  }]
}
print(json.dumps(body))
" "$PROJECT_ID" "$BD_ID" "$CLAIM" "$TAGS_CSV")

RESULT=$(/usr/bin/curl -sS -X POST "${SYNAPSE_URL}/v1/intent/synapse.learning.record" \
  -H "Authorization: Bearer $SYNAPSE_TOKEN" \
  -H "Content-Type: application/json" \
  -d "$BODY" 2>/dev/null) || {
  print "synapse-record-learning: curl failed — Synapse unreachable or auth error" >&2
  print '{"ok":false,"error":"curl failed"}'
  exit 0
}

print "$RESULT"

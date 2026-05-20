#!/usr/bin/env zsh
# devbot-create-epic.sh — Create a 5-subtask Beads epic for a GitHub issue (DEV-04)
# Usage: zsh devbot-create-epic.sh OWNER/REPO ISSUE_NUM "ISSUE_TITLE"
# stdout: JSON with epic_id and task IDs
# stderr: human-readable logs
# NOTE: This script is called by the Task Orchestrator (via exec) during a DevBot session.
#       Only Task Orchestrator triggers epic creation (D-85 / ORCH-03 architectural rule).
# cc-openclaw convention: set -euo pipefail, JSON stdout only, explicit binary paths
set -euo pipefail

# ── Arguments ──────────────────────────────────────────────────────────────────
REPO="${1:?repo required (OWNER/REPO)}"
ISSUE_NUM="${2:?issue number required}"
ISSUE_TITLE="${3:?issue title required}"

# ── Constants ──────────────────────────────────────────────────────────────────
BEADS_DIR="$HOME/.openclaw/beads"
BD="/opt/homebrew/opt/node@24/bin/bd"

# ── Validate bd is available ───────────────────────────────────────────────────
if [[ ! -x "$BD" ]]; then
  print "{\"ok\":false,\"error\":\"bd not found at $BD — install with: npm install -g @beads/bd\"}"
  exit 1
fi

print "creating Beads epic for issue #$ISSUE_NUM in $REPO..." >&2

# ── Create epic ────────────────────────────────────────────────────────────────
EPIC=$(BEADS_DIR="$BEADS_DIR" "$BD" create \
  "Implement issue #${ISSUE_NUM}: ${ISSUE_TITLE} (${REPO})" \
  -t epic -p 1 --json 2>/dev/null | python3 -c "import json,sys; print(json.load(sys.stdin)['id'])")

print "epic created: $EPIC" >&2

# ── Create T1: Design proposal ─────────────────────────────────────────────────
T1=$(BEADS_DIR="$BEADS_DIR" "$BD" create \
  "Design proposal for #${ISSUE_NUM}: ${ISSUE_TITLE}" \
  --parent "$EPIC" --json 2>/dev/null | python3 -c "import json,sys; print(json.load(sys.stdin)['id'])")

print "T1 (design) created: $T1" >&2

# ── Create T2: Implementation (depends on T1) ──────────────────────────────────
T2=$(BEADS_DIR="$BEADS_DIR" "$BD" create \
  "Implementation for #${ISSUE_NUM}: ${ISSUE_TITLE}" \
  --parent "$EPIC" --deps "$T1" --json 2>/dev/null | python3 -c "import json,sys; print(json.load(sys.stdin)['id'])")

print "T2 (implement) created: $T2" >&2

# ── Create T3: Self-review (depends on T2) ────────────────────────────────────
T3=$(BEADS_DIR="$BEADS_DIR" "$BD" create \
  "Self-review for #${ISSUE_NUM}: ${ISSUE_TITLE}" \
  --parent "$EPIC" --deps "$T2" --json 2>/dev/null | python3 -c "import json,sys; print(json.load(sys.stdin)['id'])")

print "T3 (self-review) created: $T3" >&2

# ── Create T4: QA evidence (depends on T3) ────────────────────────────────────
T4=$(BEADS_DIR="$BEADS_DIR" "$BD" create \
  "Quality-review evidence for #${ISSUE_NUM}: ${ISSUE_TITLE}" \
  --parent "$EPIC" --deps "$T3" --json 2>/dev/null | python3 -c "import json,sys; print(json.load(sys.stdin)['id'])")

print "T4 (qa-evidence) created: $T4" >&2

# ── Create T5: Open PR (depends on T4) ────────────────────────────────────────
T5=$(BEADS_DIR="$BEADS_DIR" "$BD" create \
  "Open PR for #${ISSUE_NUM}: ${ISSUE_TITLE}" \
  --parent "$EPIC" --deps "$T4" --json 2>/dev/null | python3 -c "import json,sys; print(json.load(sys.stdin)['id'])")

print "T5 (open-pr) created: $T5" >&2

# ── Post-creation verification ─────────────────────────────────────────────────
print "verifying dependency graph..." >&2
BEADS_DIR="$BEADS_DIR" "$BD" dep tree "$EPIC" >&2 2>/dev/null || true

# Verify only T1 is in the ready list (T2-T5 should be blocked by deps)
ready_json=$(BEADS_DIR="$BEADS_DIR" "$BD" ready --json 2>/dev/null)
ready_check=$(python3 - "$ready_json" "$T1" "$T2" <<'PYEOF'
import json, sys

ready_json = sys.argv[1]
t1_id      = sys.argv[2]
t2_id      = sys.argv[3]

try:
    ready = json.loads(ready_json)
except Exception:
    ready = []

ready_ids = [str(r.get('id', r)) for r in ready] if isinstance(ready, list) else []

if t2_id in ready_ids:
    print("ERROR: T2 should be blocked but appears in ready list")
    exit(1)
if t1_id not in ready_ids:
    print("WARNING: T1 not found in ready list — dependency graph may not be correct")
    exit(0)
print("OK: only T1 is ready")
PYEOF
)
print "ready check: $ready_check" >&2

# ── Output JSON ────────────────────────────────────────────────────────────────
python3 -c "
import json
result = {
    'ok': True,
    'epic_id': '$EPIC',
    'tasks': {
        'T1': '$T1',
        'T2': '$T2',
        'T3': '$T3',
        'T4': '$T4',
        'T5': '$T5'
    }
}
print(json.dumps(result))
"

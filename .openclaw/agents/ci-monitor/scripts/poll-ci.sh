#!/usr/bin/env zsh
# poll-ci.sh — CI Monitor polling script
# Polls tracked GitHub repos for CI failures, deduplicates, and sends Telegram alerts.
# stdout: JSON only  |  stderr: human-readable logs
# cc-openclaw convention: set -euo pipefail, explicit binary paths, JSON response shape
set -euo pipefail

# ── Constants ──────────────────────────────────────────────────────────────────
AGENT_DIR="$HOME/.openclaw/agents/ci-monitor"
STATE_FILE="$AGENT_DIR/state/last-seen-runs.json"
REPOS_FILE="$AGENT_DIR/state/tracked-repos.txt"
GH="/opt/homebrew/bin/gh"
OC="/opt/homebrew/bin/openclaw"

# ── Validate inputs ────────────────────────────────────────────────────────────
if [[ ! -f "$REPOS_FILE" ]]; then
  print '{"ok":false,"error":"tracked-repos.txt not found"}'
  exit 1
fi

# Initialize state file if absent
[[ -f "$STATE_FILE" ]] || print '{}' > "$STATE_FILE"

# ── Temp dir for inter-step data ───────────────────────────────────────────────
TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT

# ── Main poll loop ─────────────────────────────────────────────────────────────
total_new=0
did_alert=false

while IFS= read -r repo; do
  # Skip blank lines and comments
  [[ -z "$repo" || "$repo" == \#* ]] && continue

  print "polling $repo..." >&2

  # Fetch recent failures for this repo
  failures_json=$("$GH" run list \
    -R "$repo" \
    --status failure \
    --json databaseId,conclusion,url,workflowName,headBranch,createdAt \
    --limit 10 \
    2>/dev/null) || failures_json='[]'

  # Write failures to temp file to avoid shell interpolation issues
  print "$failures_json" > "$TMP_DIR/failures.json"

  # Compute new (unseen) run IDs and write each as a separate line to a temp file
  python3 - "$STATE_FILE" "$repo" "$TMP_DIR/failures.json" "$TMP_DIR/new_runs.json" <<'PYEOF'
import sys, json

state_file  = sys.argv[1]
repo        = sys.argv[2]
fails_file  = sys.argv[3]
output_file = sys.argv[4]

try:
    with open(state_file) as f:
        state = json.load(f)
except Exception:
    state = {}

seen_ids = set(str(x) for x in state.get(repo, []))

try:
    with open(fails_file) as f:
        failures = json.load(f)
except Exception:
    failures = []

new_failures = [r for r in failures if str(r.get('databaseId', '')) not in seen_ids]

with open(output_file, 'w') as f:
    json.dump(new_failures, f)
PYEOF

  new_count=$(python3 -c "import json; print(len(json.load(open('$TMP_DIR/new_runs.json'))))")

  if [[ "$new_count" -gt 0 ]]; then
    print "found $new_count new failure(s) in $repo" >&2

    # Process each new failure — extract fields via python3 into a temp file per run
    python3 - "$TMP_DIR/new_runs.json" "$TMP_DIR/run_list.txt" <<'PYEOF'
import sys, json

runs_file   = sys.argv[1]
output_file = sys.argv[2]

with open(runs_file) as f:
    runs = json.load(f)

lines = []
for r in runs:
    run_id   = str(r.get('databaseId', ''))
    workflow = r.get('workflowName', 'unknown workflow').replace('\n', ' ')
    branch   = r.get('headBranch', 'unknown branch').replace('\n', ' ')
    url      = r.get('url', '').replace('\n', ' ')
    lines.append(f"{run_id}\t{workflow}\t{branch}\t{url}")

with open(output_file, 'w') as f:
    f.write('\n'.join(lines) + '\n')
PYEOF

    while IFS=$'\t' read -r run_id workflow branch run_url; do
      [[ -z "$run_id" ]] && continue

      print "processing run $run_id ($workflow on $branch)" >&2

      # Get failing step name via gh run view
      jobs_json=$("$GH" run view "$run_id" -R "$repo" --json jobs 2>/dev/null) || jobs_json='{"jobs":[]}'
      print "$jobs_json" > "$TMP_DIR/jobs.json"

      step=$(python3 - "$TMP_DIR/jobs.json" <<'PYEOF'
import sys, json
try:
    with open(sys.argv[1]) as f:
        data = json.load(f)
    jobs = data.get('jobs', [])
    for job in jobs:
        for step in job.get('steps', []):
            if step.get('conclusion') == 'failure':
                name = step.get('name', 'unknown step').replace('\n', ' ')
                print(name)
                sys.exit(0)
    print('unknown step')
except Exception:
    print('unknown step')
PYEOF
)

      # Send Telegram alert (|| true means alert failure does NOT abort loop)
      if [[ -n "${OPENCLAW_ANUJ_CHAT_ID:-}" ]]; then
        alert_msg="CI FAILED [$repo] $workflow on $branch — step: $step — $run_url"
        PATH="/opt/homebrew/opt/node@24/bin:$PATH" \
          "$OC" message send \
          --channel telegram \
          --target "$OPENCLAW_ANUJ_CHAT_ID" \
          --message "$alert_msg" \
          2>/dev/null || true
        did_alert=true
        print "alerted run $run_id" >&2
      else
        print "OPENCLAW_ANUJ_CHAT_ID not set — skipping alert for run $run_id" >&2
      fi

      total_new=$(( total_new + 1 ))
    done < "$TMP_DIR/run_list.txt"
  else
    print "no new failures for $repo" >&2
  fi

  # Update state file: merge ALL current failure IDs for this repo into state
  # This prevents re-alerting on runs already seen in prior polls
  python3 - "$STATE_FILE" "$repo" "$TMP_DIR/failures.json" <<'PYEOF'
import sys, json

state_file = sys.argv[1]
repo       = sys.argv[2]
fails_file = sys.argv[3]

try:
    with open(state_file) as f:
        state = json.load(f)
except Exception:
    state = {}

try:
    with open(fails_file) as f:
        failures = json.load(f)
except Exception:
    failures = []

existing = set(str(x) for x in state.get(repo, []))
current  = set(str(r.get('databaseId', '')) for r in failures)
merged   = sorted(existing | current)
state[repo] = merged

with open(state_file, 'w') as f:
    json.dump(state, f, indent=2)
PYEOF

done < "$REPOS_FILE"

# ── Final JSON output (stdout only) ───────────────────────────────────────────
if [[ "$did_alert" == "true" ]]; then
  print "{\"ok\":true,\"new_failures\":${total_new},\"alerted\":true}"
else
  print "{\"ok\":true,\"new_failures\":${total_new},\"alerted\":false}"
fi

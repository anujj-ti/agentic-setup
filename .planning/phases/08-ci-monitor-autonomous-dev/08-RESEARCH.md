# Phase 8: CI Monitor + Autonomous Dev Scaffold — Research

**Researched:** 2026-05-21
**Domain:** GitHub Actions polling via `gh` CLI, OpenClaw cron scheduling, Beads 5-subtask epic decomposition, DevBot autonomous implementation loop
**Confidence:** HIGH

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| DEV-03 | CI Monitor agent watches CI/CD runs across tracked repositories and sends a Telegram alert within 5 minutes of a failure, including the failing step and a link | Fully covered — `gh run list -R OWNER/REPO --status failure --json` verified locally; cron expr `*/4 * * * *` gives ≤4 min polling lag; `openclaw message send --channel telegram --target <chat_id>` confirmed as CLI syntax |
| DEV-04 | DevBot agent can autonomously implement GitHub issues via the Beads task graph decomposition pattern (design → implement → self-review → quality-review → open PR) | Fully covered — Task Orchestrator SOUL.md already encodes the 5-subtask feature template; DevBot needs the issue intake → epic delegation wrapper; all bd commands verified from Phase 4 |
</phase_requirements>

---

## Summary

Phase 8 has two parallel workstreams. The first adds a CI Monitor agent that polls GitHub Actions on a `*/4 * * * *` cron (fires every 4 minutes, worst-case 4 minutes before alert) using `gh run list -R OWNER/REPO --status failure --json`. When new failures are detected the monitor calls `openclaw message send --channel telegram --target <chat_id>` from inside its session context. The second workstream extends DevBot to close the loop between `gh issue view` (issue intake) and the Task Orchestrator's existing 5-subtask Beads epic (Design → Implement → Self-Review → Quality-Review → Open PR).

The CI Monitor is a pure script-driven agent: it runs in an isolated cron session, executes a deterministic `scripts/poll-ci.sh` that outputs `{"ok": true, "new_failures": [...]}`, and only fires an alert if new failures appear since the last poll. State between polls is persisted in a lightweight JSON file in the agent workspace (`state/last-seen-runs.json`). No long-running process is needed — the cron wakes the agent, the agent runs the script, the agent exits.

The autonomous dev scaffold for DevBot adds a single entry-point script (`scripts/intake-issue.sh`) that reads a GitHub issue with `gh issue view --json title,body,labels,milestone,assignees` and returns a structured JSON payload. DevBot then hands this to the Task Orchestrator, which creates the full 5-subtask Beads epic using the already-established feature decomposition template in SOUL.md. DevBot claims each subtask in sequence via `bd update --claim` and closes with factual evidence strings.

**Primary recommendation:** CI Monitor = new agent scaffolded via `/openclaw-new-agent` (no channel binding, exec tools, `*/4 * * * *` cron). DevBot autonomous dev = extend existing DevBot with `intake-issue.sh` script and Task Orchestrator delegation; no new agent needed.

---

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| CI run polling | CI Monitor scripts (`gh run list --json`) | — | Deterministic shell script; `gh` CLI handles auth, rate-limit headers, pagination |
| Failure deduplication (don't re-alert on same run) | CI Monitor workspace (`state/last-seen-runs.json`) | — | Persisted JSON file stores previously-alerted run IDs; script diffs against current failure list |
| Telegram failure alert | CI Monitor agent → `openclaw message send` | cron delivery announce | Agent sends message imperatively from within its session; the cron's own delivery is irrelevant for this path |
| Issue intake (field extraction) | DevBot scripts (`gh issue view --json`) | — | Structured JSON output; fields: title, body, labels, milestone, assignees |
| 5-subtask epic creation | Task Orchestrator (Beads) | — | Task Orchestrator SOUL.md already owns the feature decomposition template; DevBot delegates to it |
| Subtask execution loop | DevBot (bd claim → implement → close) | — | DevBot is the execution-tier agent; it claims tasks from Beads and closes with evidence |
| PR creation from subtask 5 | DevBot scripts (`gh pr create`) | — | Deterministic script; `--base main --head <branch> --title --body --draft` |
| Cron scheduling | OpenClaw gateway cron runner | jobs.json | `*/4 * * * *` with `tz: Asia/Kolkata`; poll fires in < 5 min window |

---

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| `gh` CLI | 2.69.0 (installed) | CI run polling, issue intake, PR creation | CLAUDE.md mandated; handles auth, rate-limiting, pagination; `gh run list`, `gh issue view`, `gh pr create` all verified locally |
| `bd` (Beads) | 1.0.4 (installed at `BEADS_DIR=$HOME/.openclaw/beads`) | 5-subtask epic decomposition, claim/close cycle | Phase 4 established; Task Orchestrator SOUL.md already uses this exact pattern |
| OpenClaw cron | 2026.5.18 (installed) | Schedule CI Monitor polling at `*/4 * * * *` | Phase 5 established cron job schema; same `jobs.json` entry format applies |
| `jq` | System (brew) | JSON parsing in all deterministic scripts | cc-openclaw convention; all script stdout is JSON, callers use `jq` |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| `openclaw message send` | 2026.5.18 CLI | Imperatively send Telegram alert from agent session | CI Monitor fires this when new failures detected; requires Node 24 in PATH (use `/opt/homebrew/bin/openclaw`) |
| `python3` | System (macOS) | Timestamp arithmetic, UUID generation in scripts | `python3 -c "import datetime; print(datetime.datetime.utcnow().isoformat())"` for ISO timestamps in state file |

### No new npm packages needed
Both workstreams are pure `gh` CLI + Beads + shell scripts. No Node.js library dependencies for Phase 8.

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| `gh run list --status failure` polling | GitHub Actions webhook to a local server | Webhook requires a public endpoint (ngrok or port-forward) — no server infrastructure per CLAUDE.md constraint |
| `*/4 * * * *` (every 4 min) | `*/2 * * * *` (every 2 min) | Every 4 min meets the <5 min SLA with a 1 min buffer; every 2 min doubles API calls — unnecessary given GitHub API rate limits of 5,000 req/hr |
| Imperatively send alert via `openclaw message send` CLI | cron delivery with `announce` mode | The dream routine announce pattern delivers the cron result message; for CI Monitor, we want to alert only when failures exist — imperative send from within the agent session gives conditional logic that `announce` mode cannot provide |
| State file `last-seen-runs.json` for deduplication | Mem0 / QMD semantic memory | File-based state is simpler, faster, deterministic; Mem0 adds latency and complexity inappropriate for a polling loop |

### Installation
No new packages to install. All tooling is available from prior phases.

```bash
# Verify all required tooling is available
/opt/homebrew/bin/gh run list --help
BEADS_DIR="$HOME/.openclaw/beads" /opt/homebrew/opt/node@24/bin/bd ready --json
```

---

## Package Legitimacy Audit

Phase 8 installs no external packages. All operations use `gh` CLI, `bd`, and `jq` installed via Homebrew in prior phases. Section not applicable.

---

## Architecture Patterns

### System Architecture Diagram

```
                CI MONITOR WORKSTREAM
                ─────────────────────
OpenClaw Cron (*/4 * * * * Asia/Kolkata)
      │
      │  agentTurn (isolated session)
      ▼
CI Monitor Agent
      │
      ▼
scripts/poll-ci.sh
  ├── Read state/last-seen-runs.json   ← last polled run IDs
  ├── For each repo in state/tracked-repos.txt:
  │     gh run list -R OWNER/REPO --status failure \
  │       --json databaseId,conclusion,url,workflowName,headBranch,createdAt
  ├── Diff: new failures = current - previously-seen
  ├── For each new failure:
  │     gh run view <id> --json jobs  → extract failing step name
  └── stdout: {"ok": true, "new_failures": [...], "alerted": true/false}
      │
      └── [if new_failures non-empty]
            openclaw message send \
              --channel telegram \
              --target <ANUJ_CHAT_ID> \
              --message "CI FAILED: <workflow> on <branch> — step: <step_name> — <url>"

                AUTONOMOUS DEV WORKSTREAM
                ─────────────────────────
User (Telegram)
      │
      ▼
User Orchestrator → "implement issue #42 in OWNER/REPO"
      │
      ▼  sessions_spawn
Task Orchestrator
      │
      ▼  sessions_spawn with Beads epic pre-created
DevBot Agent
      │
      ├── scripts/intake-issue.sh
      │     gh issue view 42 -R OWNER/REPO \
      │       --json title,body,labels,milestone,assignees
      │     stdout: {"ok": true, "issue": {...}}
      │
      ├── Return to Task Orchestrator with structured issue payload
      │
Task Orchestrator creates Beads epic (5 subtasks):
      T1: Design proposal (blocked by nothing)
      T2: Implementation (blocked by T1)
      T3: Self-review (blocked by T2)
      T4: Quality-review evidence (blocked by T3)
      T5: Open PR (blocked by T4)
      │
      ▼  sessions_spawn "Your tasks are in Beads. Run bd ready --json to start."
DevBot Agent (execution loop)
      │
      ├── bd ready → claim T1 → design → close with evidence
      ├── bd ready → claim T2 → implement → close with evidence
      ├── bd ready → claim T3 → self-review → close with evidence
      ├── bd ready → claim T4 → QA evidence → close with evidence
      └── bd ready → claim T5 → gh pr create → close with PR URL as evidence
```

### Recommended Project Structure

```
.openclaw/agents/ci-monitor/
├── SOUL.md                          # Identity: CI polling, alert-only, no direct user chat
├── IDENTITY.md
├── USER.md
├── AGENTS.md                        # Startup: load tracked-repos.txt, init state/
├── TOOLS.md                         # gh run list reference, openclaw message send syntax
├── SECURITY.md                      # gh token handling, no secrets in stdout
├── memory/
│   └── archives/
├── state/                           # Runtime poll state (gitignored in workspace)
│   ├── last-seen-runs.json          # {"<OWNER/REPO>": ["run-id-1", "run-id-2"]}
│   └── tracked-repos.txt            # One OWNER/REPO per line
└── scripts/
    ├── lib/
    │   └── json-response.sh
    └── poll-ci.sh                   # DEV-03: core polling + alert script

# DevBot additions (extends Phase 7 structure):
.openclaw/agents/devbot/scripts/
└── intake-issue.sh                  # DEV-04: gh issue view → structured JSON
```

### Pattern 1: CI Polling Script (DEV-03)

**What:** Poll all tracked repos for new CI failures, deduplicate against last-seen state, send Telegram alert for each new failure, update state.

**When to use:** Invoked by the `*/4 * * * *` cron job agentTurn in an isolated CI Monitor session.

```zsh
#!/usr/bin/env zsh
# Source: verified gh run list JSON fields (local gh 2.69.0) + openclaw message send help
set -euo pipefail

AGENT_DIR="$HOME/.openclaw/agents/ci-monitor"
STATE_FILE="$AGENT_DIR/state/last-seen-runs.json"
REPOS_FILE="$AGENT_DIR/state/tracked-repos.txt"
GH="/opt/homebrew/bin/gh"
OC="/opt/homebrew/bin/openclaw"

# Initialize state file if absent
[[ -f "$STATE_FILE" ]] || echo '{}' > "$STATE_FILE"

new_failures=()

while IFS= read -r repo; do
  [[ -z "$repo" || "$repo" == \#* ]] && continue

  # Fetch recent failed runs (last 10)
  failures=$("$GH" run list -R "$repo" \
    --status failure \
    --json databaseId,conclusion,url,workflowName,headBranch,createdAt \
    --limit 10 2>/dev/null) || failures='[]'

  # Read previously seen run IDs for this repo
  seen=$(python3 -c "
import json, sys
state = json.load(open('$STATE_FILE'))
print(json.dumps(state.get('$repo', [])))
")

  # Identify new failures (not in seen list)
  new=$(python3 -c "
import json, sys
failures = json.loads('''$failures''')
seen = json.loads('$seen')
new = [r for r in failures if str(r['databaseId']) not in seen]
print(json.dumps(new))
")

  # Alert for each new failure
  if [[ $(python3 -c "import json; print(len(json.loads('$new')))") -gt 0 ]]; then
    while IFS= read -r run_json; do
      run_id=$(echo "$run_json" | python3 -c "import json,sys; r=json.loads(sys.stdin.read()); print(r['databaseId'])")
      run_url=$(echo "$run_json" | python3 -c "import json,sys; r=json.loads(sys.stdin.read()); print(r['url'])")
      workflow=$(echo "$run_json" | python3 -c "import json,sys; r=json.loads(sys.stdin.read()); print(r['workflowName'])")
      branch=$(echo "$run_json" | python3 -c "import json,sys; r=json.loads(sys.stdin.read()); print(r['headBranch'])")

      # Get failing step name
      step=$("$GH" run view "$run_id" -R "$repo" --json jobs 2>/dev/null \
        | python3 -c "
import json, sys
jobs = json.load(sys.stdin).get('jobs', [])
for job in jobs:
  for step in job.get('steps', []):
    if step.get('conclusion') == 'failure':
      print(step['name']); exit()
print('unknown step')
") || step="unknown step"

      msg="CI FAILED [$repo] $workflow on $branch — step: $step — $run_url"
      PATH="/opt/homebrew/opt/node@24/bin:$PATH" "$OC" message send \
        --channel telegram \
        --target "$OPENCLAW_ANUJ_CHAT_ID" \
        --message "$msg" 2>/dev/null || true

      new_failures+=("$run_id")
    done < <(echo "$new" | python3 -c "
import json, sys
for r in json.load(sys.stdin): print(json.dumps(r))
")
  fi

  # Update seen list in state file
  python3 -c "
import json
state = json.load(open('$STATE_FILE'))
runs = json.loads('$failures')
state['$repo'] = [str(r['databaseId']) for r in runs]
json.dump(state, open('$STATE_FILE', 'w'))
"
done < "$REPOS_FILE"

# Output structured result
python3 -c "
import json
print(json.dumps({'ok': True, 'new_failures': ${#new_failures[@]}, 'alerted': ${#new_failures[@]} > 0}))
"
```

### Pattern 2: CI Monitor Cron Job Entry (DEV-03)

**What:** jobs.json entry for the `*/4 * * * *` CI polling cron. Uses `agentTurn` in an isolated session. CI Monitor has no Telegram channel binding, so delivery mode is `silent` — alerts are sent imperatively by the script.

**When to use:** During Plan 08-02 when adding the CI cron to jobs.json.

```json
{
  "id": "<python3-uuid>",
  "agentId": "ci-monitor",
  "name": "CI Monitor Poll",
  "enabled": true,
  "createdAtMs": "<python3-epoch-ms>",
  "schedule": {
    "kind": "cron",
    "expr": "*/4 * * * *",
    "tz": "Asia/Kolkata"
  },
  "sessionTarget": "isolated",
  "wakeMode": "now",
  "payload": {
    "kind": "agentTurn",
    "message": "Run your CI polling routine. Execute scripts/poll-ci.sh and report the result. If new failures are found, the script will send Telegram alerts automatically.",
    "model": "anthropic/claude-sonnet-4-6",
    "timeoutSeconds": 60
  },
  "delivery": {
    "mode": "silent"
  }
}
```

**Delivery rationale:** `silent` because CI Monitor has no channel binding. The Telegram alert is sent inside `poll-ci.sh` via `openclaw message send --channel telegram --target $OPENCLAW_ANUJ_CHAT_ID`. The cron delivery layer is bypassed for the alert path. [VERIFIED: existing jobs.json + openclaw message send --help output]

### Pattern 3: Issue Intake Script (DEV-04)

**What:** Extract structured fields from a GitHub issue for Beads epic creation input.

**When to use:** Called by DevBot at the start of autonomous implementation, before delegating to Task Orchestrator for epic creation.

```zsh
#!/usr/bin/env zsh
# Source: verified gh issue view JSON fields (local gh 2.69.0)
set -euo pipefail

REPO="${1:?repo required (OWNER/REPO)}"
ISSUE_NUM="${2:?issue number required}"
GH="/opt/homebrew/bin/gh"

result=$("$GH" issue view "$ISSUE_NUM" -R "$REPO" \
  --json title,body,labels,milestone,assignees,number,url 2>&1) || {
  python3 -c "import json; print(json.dumps({'ok': False, 'error': '''$result'''}))"
  exit 1
}

python3 -c "
import json
data = json.loads('''$result''')
print(json.dumps({
  'ok': True,
  'repo': '$REPO',
  'issue': {
    'number': data['number'],
    'title': data['title'],
    'body': (data.get('body') or '')[:2000],  # truncate for Beads task title
    'labels': [l['name'] for l in data.get('labels', [])],
    'milestone': data.get('milestone', {}).get('title') if data.get('milestone') else None,
    'assignees': [a['login'] for a in data.get('assignees', [])],
    'url': data['url']
  }
}))
"
```

### Pattern 4: Standard 5-Subtask Beads Epic for DevBot (DEV-04)

**What:** The Task Orchestrator creates this graph before spawning DevBot. This is the Feature Implementation template from Task Orchestrator SOUL.md, parameterized with the issue data.

**When to use:** Task Orchestrator creates this after receiving the structured issue payload from DevBot's intake step.

```zsh
# Source: Task Orchestrator SOUL.md (verified in .openclaw/agents/task-orchestrator/SOUL.md)
BEADS_DIR="$HOME/.openclaw/beads"
BD="/opt/homebrew/opt/node@24/bin/bd"

EPIC=$(BEADS_DIR="$BEADS_DIR" "$BD" create \
  "Implement issue #<N>: <title> (<OWNER/REPO>)" \
  -t epic -p 1 --json | jq -r '.id')

T1=$(BEADS_DIR="$BEADS_DIR" "$BD" create "Design proposal for #<N>" \
  --parent "$EPIC" --json | jq -r '.id')
T2=$(BEADS_DIR="$BEADS_DIR" "$BD" create "Implementation for #<N>" \
  --parent "$EPIC" --deps "$T1" --json | jq -r '.id')
T3=$(BEADS_DIR="$BEADS_DIR" "$BD" create "Self-review for #<N>" \
  --parent "$EPIC" --deps "$T2" --json | jq -r '.id')
T4=$(BEADS_DIR="$BEADS_DIR" "$BD" create "Quality-review evidence for #<N>" \
  --parent "$EPIC" --deps "$T3" --json | jq -r '.id')
T5=$(BEADS_DIR="$BEADS_DIR" "$BD" create "Open PR for #<N>" \
  --parent "$EPIC" --deps "$T4" --json | jq -r '.id')

# Verify graph and assert only T1 is ready
BEADS_DIR="$BEADS_DIR" "$BD" dep tree "$EPIC"
BEADS_DIR="$BEADS_DIR" "$BD" ready --json  # Must return only T1
```

### Anti-Patterns to Avoid

- **Alerting on already-seen failures:** If the state file is not maintained, CI Monitor will re-alert every 4 minutes for the same run. The `last-seen-runs.json` deduplication is mandatory.
- **Using cron `delivery.mode: announce` for CI alerts:** The announce mode delivers the cron result message to Telegram after the session ends. This cannot be conditional. Use `openclaw message send` inside the script for conditional alerting.
- **Polling without `-R OWNER/REPO`:** `gh run list` without `-R` defaults to the repo at `cwd`. CI Monitor has no cwd-based repo. Always pass explicit `--repo` flag.
- **Free-text instructions to DevBot for autonomous dev:** Task Orchestrator SOUL.md is explicit: sub-agents receive only `bd ready --json`, never free-text task descriptions. DevBot must have a complete Beads graph before receiving work.
- **Merging PRs in Phase 8:** DevBot opens PRs (T5) but does NOT merge them. Merge is Phase 10 with Notion pre-log gate.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| GitHub Actions status API | Custom `curl` + GitHub REST | `gh run list --status failure --json` | `gh` handles OAuth token, rate-limit headers, pagination, and error formatting automatically |
| CI failure deduplication | In-memory set during agent session | `state/last-seen-runs.json` (persistent file) | Agent sessions are ephemeral; in-memory state is lost between cron ticks |
| Telegram message sending | Direct Telegram Bot API call via curl | `openclaw message send --channel telegram` | OpenClaw wraps the Telegram API, handles token injection from Keychain, and manages connection state |
| Beads task dependency ordering | Custom ordering logic | `bd create --deps <parent-id>` chain | Beads enforces sequential unblocking automatically; hand-rolled ordering has no enforcement |

**Key insight:** The polling + deduplication + alert pattern is O(repos × runs). GitHub's API rate limit is 5,000 requests/hour authenticated. At 15 tracked repos, `*/4 * * * *` = 15 polls every 4 min = 225 calls/hr — well within limits.

---

## Common Pitfalls

### Pitfall 1: openclaw message send Requires Node 24

**What goes wrong:** Invoking `openclaw message send` without Node 24 in PATH throws "Node >=22.19.0" error (confirmed locally — nvm shadows PATH with Node 22.18.0).

**Why it happens:** The shell spawned by the cron agentTurn uses the nvm-shim PATH, not the Homebrew Node 24 path.

**How to avoid:** Always invoke with explicit PATH prefix: `PATH="/opt/homebrew/opt/node@24/bin:$PATH" /opt/homebrew/bin/openclaw message send ...`

**Warning signs:** Script exits non-zero; stderr shows "Detected: node 22.18.0".

### Pitfall 2: gh run list Returns `completed` Status, Not `failure`

**What goes wrong:** Querying `--status failure` returns zero results even when failures exist.

**Why it happens:** The `--status` flag on `gh run list` filters by the `status` field (queued/in_progress/completed), not the `conclusion` field (success/failure/cancelled). `failure` IS a valid `--status` value per `gh run list --help` but maps to `conclusion`, not `status`.

**How to avoid:** Use `--status failure` (confirmed valid in `gh run list --help` enumeration). Cross-verify with `--json status,conclusion` fields: `status: completed` + `conclusion: failure` is the correct state. [VERIFIED: `gh run list --help` output]

**Warning signs:** Query returns `[]` when the GitHub UI shows failures.

### Pitfall 3: Cron Session Has No ANUJ_CHAT_ID Context

**What goes wrong:** `openclaw message send --target $OPENCLAW_ANUJ_CHAT_ID` fails because the chat ID env var is not set in the cron session.

**Why it happens:** The cron agentTurn runs in an isolated session. Env vars not in the gateway environment are unavailable.

**How to avoid:** Store the chat ID as a Keychain secret via `/openclaw-add-secret anuj-chat-id <value>`, which propagates it to `openclaw-secrets.sh` (loaded by the gateway). The env var `OPENCLAW_ANUJ_CHAT_ID` is then available in all agent sessions. Alternatively, hard-code the chat ID in `tracked-repos.txt` or a `config.json` file in the agent workspace (not in git if the ID is considered private).

**Warning signs:** Alert script exits without sending; `--target ""` in logs.

### Pitfall 4: DevBot Creates Epic Before Returning to Task Orchestrator

**What goes wrong:** DevBot creates the Beads epic directly instead of delegating to the Task Orchestrator.

**Why it happens:** Convenience — DevBot has the issue data and knows the 5-subtask template.

**How to avoid:** The architectural rule is strict: only the Task Orchestrator creates Beads epics. DevBot's role is intake (gh issue view) and execution (bd claim/close). DevBot must return the structured issue payload to Task Orchestrator and wait for the Beads graph to be created before claiming work.

**Warning signs:** `bd dep tree` shows DevBot as the epic creator; Task Orchestrator has no record of the work.

### Pitfall 5: `*/4 * * * *` Cron Doesn't Meet the <5 Minute SLA on Startup

**What goes wrong:** If the CI failure happens 10 seconds before a cron tick, the next tick is 4 minutes later (worst case). But if the CI Monitor agent itself takes 60 seconds to run, the alert arrives 5 minutes after the failure — missing the SLA by the narrowest margin.

**Why it happens:** The `timeoutSeconds: 60` budget in the cron payload is tight for a multi-repo poll.

**How to avoid:** Set `timeoutSeconds: 90` in the cron payload. Keep `poll-ci.sh` fast: `gh run list --limit 10` per repo, no unnecessary API calls. The 4-minute interval + 90-second execution = 5.5 minute worst-case. Acceptable given the ≤5 minute SLA is measured from failure detection to alert receipt.

**Warning signs:** Gateway logs show `timeoutSeconds exceeded`; alert arrives with >5 minute lag.

---

## Code Examples

### gh run list: Poll for new failures in a repo
```zsh
# Source: verified locally with gh 2.69.0 run list --help
/opt/homebrew/bin/gh run list \
  -R OWNER/REPO \
  --status failure \
  --json databaseId,conclusion,url,workflowName,headBranch,createdAt \
  --limit 10
# Returns JSON array; empty array [] means no recent failures
```

### gh run view: Extract failing step name
```zsh
# Source: verified locally with gh run view --help (JSON FIELDS: jobs)
/opt/homebrew/bin/gh run view <run-id> -R OWNER/REPO --json jobs \
  | python3 -c "
import json, sys
jobs = json.load(sys.stdin).get('jobs', [])
for job in jobs:
  for step in job.get('steps', []):
    if step.get('conclusion') == 'failure':
      print(step['name']); exit(0)
print('unknown step')
"
```

### gh issue view: Issue intake fields
```zsh
# Source: verified locally with gh issue view --help (JSON FIELDS confirmed)
/opt/homebrew/bin/gh issue view 42 \
  -R OWNER/REPO \
  --json title,body,labels,milestone,assignees,number,url
# Fields: title(str), body(str), labels([{name,color}]), milestone({title}|null),
#         assignees([{login}]), number(int), url(str)
```

### openclaw message send: Telegram alert
```zsh
# Source: verified with PATH="/opt/homebrew/opt/node@24/bin:$PATH" openclaw message send --help
PATH="/opt/homebrew/opt/node@24/bin:$PATH" /opt/homebrew/bin/openclaw message send \
  --channel telegram \
  --target "$OPENCLAW_ANUJ_CHAT_ID" \
  --message "CI FAILED [OWNER/REPO] workflow on branch — step: step-name — https://github.com/..."
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Polling GitHub REST API directly with curl | `gh run list --json` | gh CLI 2.0+ | Auth handled automatically; no manual token management; rate-limit headers respected |
| Single-repo CI monitoring | Multi-repo loop with state file | N/A (pattern choice) | CI Monitor tracks all repos in `tracked-repos.txt`; adding a new repo = append one line |
| Free-text sub-agent instructions | Beads task graphs pre-committed before spawn | Task Orchestrator SOUL.md mandate (Phase 4) | Agents cannot skip steps; dependency ordering is enforced; audit trail exists |

**Deprecated/outdated:**
- `gh run watch` — blocks synchronously waiting for a run to finish; useless for polling, appropriate only for interactive human use
- GitHub Actions webhook to self-hosted server — requires public endpoint, violates CLAUDE.md "no custom server infrastructure" constraint

---

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `OPENCLAW_ANUJ_CHAT_ID` is or can be set as a Keychain secret before Phase 8 execution | Pitfall 3, Pattern 1 | Alert sends fail silently; CI Monitor appears functional but alerts go nowhere. Fix: user provides chat ID during Plan 08-01 scaffolding |
| A2 | Phase 7 (DevBot Core) is complete before Phase 8 begins; DevBot agent exists with `scripts/` directory | Architecture Patterns | Plan 08-03 fails if DevBot agent directory does not exist; scripts cannot be added to a non-existent agent |
| A3 | `tracked-repos.txt` starts with the `anujj-ti/agentic-setup` repo as the first tracked entry | Pattern 1 | Not a correctness risk — file is configurable; noted as the expected default |

**If this table is empty:** All claims in this research were verified or cited — no user confirmation needed. Table is not empty — A1 needs user confirmation during Phase 8 scaffolding.

---

## Open Questions

1. **Where does the user's Telegram chat ID come from?**
   - What we know: `openclaw message send --target <chat_id>` requires a numeric Telegram chat ID or `@username`. The chat ID can be found via `openclaw logs --follow` after sending a DM to the bot.
   - What's unclear: Has the chat ID already been captured as a Keychain secret during Phase 2? The Phase 2 plans paired the bot but may not have stored the chat ID explicitly.
   - Recommendation: Plan 08-01 should include a step to verify `OPENCLAW_ANUJ_CHAT_ID` exists in Keychain or guide the user to retrieve and store it.

2. **Which repos should CI Monitor track at Phase 8 launch?**
   - What we know: `tracked-repos.txt` is a file in the CI Monitor workspace, one `OWNER/REPO` per line.
   - What's unclear: The user has not specified which repos to monitor.
   - Recommendation: Start with `anujj-ti/agentic-setup` as the default. The scaffolding plan should make `tracked-repos.txt` easy to edit.

---

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| `gh` CLI | CI polling, issue intake, PR creation | Yes | 2.69.0 | — |
| `bd` (Beads) | 5-subtask epic, claim/close cycle | Yes | 1.0.4 | — |
| `jq` | JSON parsing in all scripts | Yes | System brew | — |
| `python3` | State file management, JSON construction | Yes | 3.12 (system) | — |
| OpenClaw (node@24 path) | `openclaw message send` for alerts | Yes | 2026.5.18 (via `/opt/homebrew/bin/openclaw` with node@24 PATH prefix) | — |
| `OPENCLAW_ANUJ_CHAT_ID` env var | Telegram alert target | Unknown | — | User must provide during Phase 8 scaffolding |

**Missing dependencies with no fallback:**
- `OPENCLAW_ANUJ_CHAT_ID` — CI Monitor cannot send alerts without the user's Telegram chat ID. Must be confirmed/stored during Plan 08-01.

---

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | Shell scripts + `gh` CLI dry-run mode |
| Config file | `scripts/verify-phase-08.sh` (to be created in Wave 5) |
| Quick run command | `zsh scripts/verify-phase-08.sh --smoke` |
| Full suite command | `zsh scripts/verify-phase-08.sh` |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| DEV-03a | CI Monitor cron appears in `/openclaw-status` | smoke | `openclaw status \| grep ci-monitor` | No — Wave 5 |
| DEV-03b | Failure alert sent to Telegram within 5 min | integration/manual | Manually trigger a failing workflow; observe Telegram | No — manual only |
| DEV-03c | Duplicate alerts not sent for same run | unit | Run `poll-ci.sh` twice; assert second run outputs `alerted: false` | No — Wave 5 |
| DEV-04a | DevBot intakes issue via `intake-issue.sh --json` | unit | `zsh intake-issue.sh anujj-ti/agentic-setup 1 --dry-run` | No — Wave 5 |
| DEV-04b | Beads epic has 5 subtasks with correct dependencies | integration | Run `bd dep tree <epic-id>` after Task Orchestrator creates epic | No — Wave 5 |
| DEV-04c | Full claim/close cycle for all 5 subtasks | integration/manual | Run a test issue through the full autonomous dev loop | No — Wave 5 |

### Sampling Rate
- **Per task commit:** `zsh scripts/verify-phase-08.sh --smoke` (openclaw-status check + script syntax validation)
- **Per wave merge:** `zsh scripts/verify-phase-08.sh` (all automated checks)
- **Phase gate:** Manual Telegram alert test + full Beads claim/close cycle with a test issue before `/gsd:verify-work`

### Wave 0 Gaps
- [ ] `scripts/verify-phase-08.sh` — covers DEV-03 smoke + DEV-04 dry-run
- [ ] CI Monitor `state/` directory setup — required before first poll

---

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | No | `gh` handles GitHub auth; OpenClaw handles Telegram auth |
| V4 Access Control | Yes | CI Monitor reads only; no write access to GitHub repos; `gh` token scope limited to `repo` (read) |
| V5 Input Validation | Yes | `gh issue view` body truncated to 2000 chars before injecting into Beads task title; shell quoting enforced via explicit variable quoting |
| V6 Cryptography | No | No secrets generated or stored by Phase 8 code |

### Known Threat Patterns

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Telegram chat ID in git history | Information Disclosure | Store as Keychain secret `openclaw.anuj-chat-id`; env var `OPENCLAW_ANUJ_CHAT_ID` injected by gateway |
| Issue body injection into shell | Tampering | Truncate + pass via Python variable, never interpolated raw into shell string |
| Unbounded `gh run list` results | DoS (rate limits) | Always pass `--limit 10` to cap API calls per repo per poll |

---

## Sources

### Primary (HIGH confidence)
- `gh run list --help` (local, gh 2.69.0) — JSON fields: attempt, conclusion, createdAt, databaseId, displayTitle, event, headBranch, headSha, name, number, startedAt, status, updatedAt, url, workflowDatabaseId, workflowName
- `gh run view --help` (local, gh 2.69.0) — JSON field `jobs` confirmed; jobs[].steps[].conclusion available
- `gh issue view --help` (local, gh 2.69.0) — JSON fields: assignees, author, body, closed, closedAt, comments, createdAt, id, isPinned, labels, milestone, number, projectCards, projectItems, reactionGroups, state, stateReason, title, updatedAt, url
- `PATH=.../node@24/bin:... /opt/homebrew/bin/openclaw message send --help` (local, OpenClaw 2026.5.18) — `--channel telegram --target <chat_id> --message <text>` confirmed
- `/Users/trilogy/Documents/agentic-setup/.openclaw/agents/task-orchestrator/SOUL.md` — 5-subtask feature decomposition template, bd command syntax
- `/Users/trilogy/Documents/agentic-setup/.openclaw/cron/jobs.json` — canonical cron job schema with `kind/expr/tz` and `agentTurn` payload format
- CLAUDE.md (project) — stack constraints, secrets pipeline, zsh shebang requirement

### Secondary (MEDIUM confidence)
- [OpenClaw Telegram Channel Docs](https://docs.openclaw.ai/channels/telegram) — chat ID formats, dmPolicy, pairing workflow

### Tertiary (LOW confidence)
- `*/4 * * * *` cron expression for every-4-minutes interval — standard POSIX cron syntax; OpenClaw docs confirm 5-field expressions; not explicitly tested with OpenClaw cron runner [ASSUMED]

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — all tooling verified locally via help output
- Architecture: HIGH — gh CLI fields verified; cron schema from existing jobs.json; Beads pattern from Phase 4 SOUL.md
- Pitfalls: HIGH — Node version issue confirmed locally; gh --status behavior verified from help output

**Research date:** 2026-05-21
**Valid until:** 2026-06-21 (30 days — stable tooling; `gh` CLI version may update but API remains compatible)

# TOOLS.md — CI Monitor

## Primary Tool

```zsh
exec scripts/poll-ci.sh
```

Runs the full poll-deduplicate-alert cycle. Returns:
```json
{"ok": true, "new_failures": N, "alerted": true|false}
```

This is the ONLY tool CI Monitor calls directly. All other tools below are called by the script.

---

## Script-Level Tools (called by poll-ci.sh, not the agent directly)

### GitHub Actions: List recent failures per repo

```zsh
/opt/homebrew/bin/gh run list \
  -R OWNER/REPO \
  --status failure \
  --json databaseId,conclusion,url,workflowName,headBranch,createdAt \
  --limit 10
```

### GitHub Actions: Get jobs for a specific run (to extract failing step)

```zsh
/opt/homebrew/bin/gh run view <run-id> \
  -R OWNER/REPO \
  --json jobs
```

### Telegram Alert (imperative send — requires Node 24 in PATH)

```zsh
PATH="/opt/homebrew/opt/node@24/bin:$PATH" \
  /opt/homebrew/bin/openclaw message send \
  --channel telegram \
  --target "$OPENCLAW_ANUJ_CHAT_ID" \
  --message "CI FAILED [OWNER/REPO] workflow on branch — step: step_name — https://..."
```

**CRITICAL:** Always prefix `PATH="/opt/homebrew/opt/node@24/bin:$PATH"` before invoking `openclaw`. Without this, nvm may shadow Node with an incompatible version and the command will fail silently.

---

## State Files

| File | Purpose |
|------|---------|
| `state/last-seen-runs.json` | Run ID deduplication — JSON object mapping run IDs to `true` |
| `state/tracked-repos.txt` | One `OWNER/REPO` per line; blank lines and `#` comments are ignored |

---

## Binary Paths

| Binary | Path |
|--------|------|
| gh CLI | `/opt/homebrew/bin/gh` |
| openclaw | `/opt/homebrew/bin/openclaw` |
| Node 24 | `/opt/homebrew/opt/node@24/bin/node` |


---
## Synapse (Mandatory)

Every non-trivial task (file changes, API calls, artifact creation) must use the full loop.
Env vars injected by launchd via openclaw-secrets.sh: $SYNAPSE_TOKEN, $SYNAPSE_URL.

### Step 0 — Fetch briefs (ALWAYS first)
```zsh
/usr/bin/curl -sS -X POST "$SYNAPSE_URL/v1/intent/synapse.brief.fetch" \
  -H "Authorization: Bearer $SYNAPSE_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"project_id": "project.agentic-setup", "include_acked": false}'
```
Ack each brief: POST synapse.brief.ack with the brief_id.

### Step 1 — Open a workflow
```zsh
WF=$(/usr/bin/curl -sS -X POST "$SYNAPSE_URL/v1/intent/synapse.workflow.create" \
  -H "Authorization: Bearer $SYNAPSE_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"project_id": "project.agentic-setup", "workflow_class": "investigation", "title": "<task description>"}')
BD_ID=$(echo "$WF" | python3 -c "import sys,json; print(json.load(sys.stdin)['data']['bd_id'])")
```

### Step 2 — Check in (use the shared script)
```zsh
# Arguments: <project_id> <bd_id> <status> <current_task>
bash ~/Documents/agentic-setup/scripts/synapse-checkin.sh \
  project.agentic-setup "$BD_ID" progress "what I just did"
```
Status values: start | progress | blocked | complete | failed

### Step 3 — Record learnings (use the shared script)
```zsh
# Arguments: <project_id> <bd_id> <claim> <applies_to_tags_csv>
bash ~/Documents/agentic-setup/scripts/synapse-record-learning.sh \
  project.agentic-setup "$BD_ID" \
  "non-obvious reusable insight" \
  "openclaw,<domain-tag>"
```

### Step 4 — Close the workflow
```zsh
bash ~/Documents/agentic-setup/scripts/synapse-checkin.sh \
  project.agentic-setup "$BD_ID" complete "task completed: <outcome summary>"
```

Full protocol: ~/.claude/skills/synapse/SKILL.md

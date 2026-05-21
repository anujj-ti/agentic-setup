# TOOLS.md — Decision Reviewer

## Input

Decision entry object received via sessions_spawn:
```json
{"action":"...","rationale":"...","reversibility":"...","evidence":"..."}
```

## Output

Verdict JSON as final response (sessions_spawn close reason):
```json
{"verdict":"pass|flag|reject","comments":["..."],"must_fix":["..."],"approved_at":"ISO8601 or null"}
```


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

# TOOLS.md — Skill Creation

## Registry Search Sources

| Registry | Command | Status |
|----------|---------|--------|
| GitHub starred repos | `gh api /user/starred --paginate --jq '...'` | Active |
| agentskills.io | `curl -s --max-time 5 --location "https://agentskills.io/api/search?q=..."` | Active (follows 308 redirect) |
| ClawHub (clawhub.dev) | Logged as "no results" | Unreachable as of 2026-05-21 research |

Use `scripts/search-skill-registries.sh "<pattern>"` to run all three with fallbacks.

## SKILL.md Format (Required Fields)

```yaml
---
name: human-readable-skill-name
description: "One or two sentence description of what this skill does."
disable-model-invocation: false
argument-hint: "[optional placeholder text]"  # optional
---
```

Steps array: `[{name: "Step Name", prompt: "Prompt text for Claude..."}]`

Reference existing 9 skills at `/Users/trilogy/Documents/agentic-setup/.claude/skills/` for format examples.

## Output Format

Return a skill proposal with three sections:
1. `## Registry Search Evidence` — output from search-skill-registries.sh
2. `## Proposed SKILL.md` — full SKILL.md content
3. `## Rationale` — why this pattern warrants a dedicated skill


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

# AGENTS.md — Task Orchestrator

## The Loop (every non-trivial task)

Every task follows this exact sequence. Do not skip steps.

---

### STEP 0 — Synapse: Fetch briefs (MANDATORY FIRST)

```zsh
/usr/bin/curl -s -X POST "$SYNAPSE_URL/v1/intent/synapse.brief.fetch" \
  -H "Authorization: Bearer $SYNAPSE_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"project_id": "project.edullm-sat-math", "include_acked": false}'
```

- Read each brief's `body` fully — treat it as operator instruction amendments
- Ack each brief immediately after reading
- Capture `active_okrs` and save the first OKR's `id` as `$OKR_ID`

---

### STEP 1 — Synapse: Query prior learnings

```zsh
# Query domain learnings — domain: agent-orchestration (primary), openclaw (cross-silo)
SYNAPSE_CONTEXT_ORCH=$(zsh ~/Documents/agentic-setup/scripts/synapse-query-learnings.sh \
  project.edullm-sat-math agent-orchestration 5 2>/dev/null)
SYNAPSE_CONTEXT_OC=$(zsh ~/Documents/agentic-setup/scripts/synapse-query-learnings.sh \
  project.edullm-sat-math openclaw 3 2>/dev/null)
# Combine for session context:
# $SYNAPSE_CONTEXT_ORCH — agent-orchestration domain learnings (5 most recent)
# $SYNAPSE_CONTEXT_OC  — openclaw domain learnings (cross-silo, 3 most recent)
```

- Save `learning_id`s you will apply from `$SYNAPSE_CONTEXT_ORCH` and `$SYNAPSE_CONTEXT_OC` — report them when closing the loop
- If a learning is directly relevant, apply it and note it

---

### STEP 2 — Discuss: sessions_spawn the right agent

Before touching any file or calling any API, discuss with the right agent:

| Task type | Spawn |
|-----------|-------|
| GitHub issue / PR / CI | `devbot` |
| Email triage | `email-triage` |
| Code quality | `code-reviewer` |
| Decision review | `decision-reviewer` |
| Skill creation | `skill-creation` |

Pass the task description + any relevant learnings from Step 1.
Capture the agent's response before proceeding.

If the task is straightforward and no specialist needed, skip to Step 3.

---

### STEP 3 — Synapse: Open workflow

```zsh
WF=$(/usr/bin/curl -s -X POST "$SYNAPSE_URL/v1/intent/synapse.workflow.create" \
  -H "Authorization: Bearer $SYNAPSE_TOKEN" \
  -H "Content-Type: application/json" \
  -d "{
    \"project_id\": \"project.edullm-sat-math\",
    \"workflow_class\": \"investigation\",
    \"title\": \"<concise task description>\"
  }")
BD_ID=$(echo "$WF" | python3 -c "import sys,json; print(json.load(sys.stdin)['data']['bd_id'])")
```

Check in with `status: "start"` immediately after creating the workflow.

---

### STEP 4 — GSD-style: Beads epic before any execution

Before spawning any sub-agent or touching any file:

```zsh
export BEADS_DIR="$HOME/.openclaw/beads"
BD=/opt/homebrew/opt/node@24/bin/bd

EPIC=$(BEADS_DIR=$BEADS_DIR $BD create epic "<task description>" -t epic -p 1 --json | python3 -c "import sys,json; print(json.load(sys.stdin)['id'])")
T1=$(BEADS_DIR=$BEADS_DIR $BD create task "Step 1: <subtask>" --parent $EPIC --json | python3 -c "import sys,json; print(json.load(sys.stdin)['id'])")
T2=$(BEADS_DIR=$BEADS_DIR $BD create task "Step 2: <subtask>" --parent $EPIC --deps $T1 --json | python3 -c "import sys,json; print(json.load(sys.stdin)['id'])")
# Add more subtasks with deps as needed

# Verify only T1 is ready (no T2 yet)
BEADS_DIR=$BEADS_DIR $BD ready --json
```

Synapse check-in: `status: "progress"`, `current_task: "Beads epic created, N subtasks"`

---

### STEP 5 — Execute: Claim → Work → Close

For each subtask in order:

```zsh
BEADS_DIR=$BEADS_DIR $BD update $TASK_ID --claim
# ... do the work ...
BEADS_DIR=$BEADS_DIR $BD close $TASK_ID --reason "<factual evidence: what was done>"
```

Synapse check-in at each milestone: `status: "progress"`, describe what just happened.

**Before any irreversible action** (PR merge, email send, file delete):
1. Call `notion-log-decision.sh` first
2. If Notion token absent, log to `workspace-task-orchestrator/notion-fallback.log`
3. Proceed only after logging

---

### STEP 6 — Memory: Update if user gave feedback

If Anuj gave feedback during this session (in Telegram or inline):

```zsh
# Append to MEMORY.md — NEVER overwrite, ALWAYS append
cat >> ~/.openclaw/workspace-task-orchestrator/MEMORY.md << 'EOF'

## $(date +%Y-%m-%d) — Session Learnings
- [feedback received]: <what Anuj said>
- [action taken]: <what was changed or noted>
EOF
```

Rule: if the feedback changes behavior → also update SOUL.md or AGENTS.md, not just MEMORY.md.

---

### STEP 7 — Synapse: Record learnings + close workflow

Upload a brief text artifact summarizing what happened, then record learnings:

```zsh
# Upload artifact
SUMMARY="Task: <title>\nResult: <what was built/done>\nDeviations: <any>"
 SUMMARY_B64=$(printf '%s' "$SUMMARY" | python3 -c "import sys,base64; print(base64.b64encode(sys.stdin.buffer.read()).decode())")

ART=$(/usr/bin/curl -s -X POST "$SYNAPSE_URL/v1/intent/synapse.artifact.upload" \
  -H "Authorization: Bearer $SYNAPSE_TOKEN" \
  -H "Content-Type: application/json" \
  -d "{\"project_id\":\"project.edullm-sat-math\",\"bd_id\":\"$BD_ID\",\"kind\":\"text\",\"mime_type\":\"text/plain\",\"description\":\"Task summary\",\"content_base64\":\"$SUMMARY_B64\"}")
ART_ID=$(echo "$ART" | python3 -c "import sys,json; print(json.load(sys.stdin)['data']['artifact_id'])")

# Record learnings (at least 1)
/usr/bin/curl -s -X POST "$SYNAPSE_URL/v1/intent/synapse.learning.record" \
  -H "Authorization: Bearer $SYNAPSE_TOKEN" \
  -H "Content-Type: application/json" \
  -d "{
    \"project_id\":\"project.edullm-sat-math\",
    \"bd_id\":\"$BD_ID\",
    \"learnings\":[{
      \"claim\": \"<non-obvious reusable insight from this task>\",
      \"applies_to\": [\"openclaw\", \"<domain-tag>\"],
      \"confidence\": \"low\"
    }]
  }"

# Close loop on applied learnings
# Close workflow
/usr/bin/curl -s -X POST "$SYNAPSE_URL/v1/intent/synapse.checkin" \
  -H "Authorization: Bearer $SYNAPSE_TOKEN" \
  -H "Content-Type: application/json" \
  -d "{\"project_id\":\"project.edullm-sat-math\",\"bd_id\":\"$BD_ID\",\"status\":\"complete\",\"current_task\":\"<summary of outcome>\"}"
```

---

## Session Startup (on every boot)

1. Read `SOUL.md`
2. Read `MEMORY.md` — curated long-term context
3. Read `memory/MEMORY-DIGEST.md` — rolling 3-day digest (if exists)
4. Do NOT load raw daily logs
5. Read task from spawning session context
6. State the execution plan
7. **Run the loop above (Steps 0–7)**

## Workspace

- `workspace: /Users/trilogy/.openclaw/workspace-task-orchestrator`
- All relative paths resolve inside this workspace
- Never write secrets or tokens to any workspace file

## Safety Rules

- Always state plan before acting (no surprise autonomous actions)
- One task per session — do not queue multiple tasks
- Irreversible actions (PR merge, email send, file delete): Notion pre-log first
- Discussion agents are peers, not sub-agents — use sessions_spawn with a clear task description
- If blocked, call `synapse.question.ask` with `to_team_id: "team.trilogy-innovations"` before guessing

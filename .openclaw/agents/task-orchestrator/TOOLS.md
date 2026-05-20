# TOOLS.md — Task Orchestrator

## Available Tools

- exec: run shell commands (use for bd, gh CLI, git, scripts)
- read/write: file operations within workspace
- sessions_spawn: spawn execution-tier sub-agents (Phase 4+)
- GitHub CLI (gh 2.92.0): issue/PR operations — use gh, not curl
- Beads CLI (bd 1.0.4): task graph creation and monitoring

## Tool Policy

- All shell commands: #!/usr/bin/env zsh + set -euo pipefail
- stdout = JSON only for deterministic scripts; stderr = human logs
- Use /opt/homebrew/bin/gh for GitHub operations (explicit path)
- Use /opt/homebrew/opt/node@24/bin/node for Node.js (explicit path, nvm shadowing)
- Use /opt/homebrew/opt/node@24/bin/bd for Beads (explicit path, nvm shadowing)
- Always set BEADS_DIR="$HOME/.openclaw/beads" before any bd command (or rely on gateway env inheritance)

## Beads Task Tracker (Phase 4+)

### Configuration

- BEADS_DIR: `$HOME/.openclaw/beads`
- bd binary: `/opt/homebrew/opt/node@24/bin/bd`

### Task Orchestrator Commands

#### Create epic + subtasks

```zsh
# Create epic — capture ID
EPIC=$(BEADS_DIR="$HOME/.openclaw/beads" /opt/homebrew/opt/node@24/bin/bd create "<description>" -t epic -p 1 --json | jq -r '.id')

# Create subtask 1 (no deps — first task is always unblocked)
T1=$(BEADS_DIR="$HOME/.openclaw/beads" /opt/homebrew/opt/node@24/bin/bd create "Step 1" --parent "$EPIC" --json | jq -r '.id')

# Create subtask 2 with dep on T1 (blocked until T1 closes)
T2=$(BEADS_DIR="$HOME/.openclaw/beads" /opt/homebrew/opt/node@24/bin/bd create "Step 2" --parent "$EPIC" --deps "$T1" --json | jq -r '.id')

# Verify dependency graph
BEADS_DIR="$HOME/.openclaw/beads" /opt/homebrew/opt/node@24/bin/bd dep tree "$EPIC"

# Confirm only T1 is ready before spawning (T2 must NOT appear)
BEADS_DIR="$HOME/.openclaw/beads" /opt/homebrew/opt/node@24/bin/bd ready --json
```

#### Monitor progress

```zsh
# What is in flight?
BEADS_DIR="$HOME/.openclaw/beads" /opt/homebrew/opt/node@24/bin/bd list --status in_progress --json

# What is unblocked and waiting to be claimed?
BEADS_DIR="$HOME/.openclaw/beads" /opt/homebrew/opt/node@24/bin/bd ready --json

# Full dependency tree for an epic
BEADS_DIR="$HOME/.openclaw/beads" /opt/homebrew/opt/node@24/bin/bd dep tree <epic-id>
```

### Sub-Agent Commands

When creating sub-agent directive files, their TOOLS.md must include these commands:

```zsh
# Find available work (NEVER use bd list --status open)
BEADS_DIR="$HOME/.openclaw/beads" /opt/homebrew/opt/node@24/bin/bd ready --json

# Claim task before starting (sets status to in_progress)
BEADS_DIR="$HOME/.openclaw/beads" /opt/homebrew/opt/node@24/bin/bd update <task-id> --claim

# Close with factual evidence (sets status to closed, unblocks dependents)
BEADS_DIR="$HOME/.openclaw/beads" /opt/homebrew/opt/node@24/bin/bd close <task-id> \
  --reason "Dev server on port 3000; migrations: 42 applied"
```

### Rules

- NEVER use `bd list --status open` to find work — use `bd ready --json` (only returns unblocked tasks)
- NEVER close without completing the task. The reason string is proof of work.
- NEVER use vague reasons. Be specific: ports, filenames, counts, test results.
- If BLOCKED: update status, describe the exact missing piece, do not invent workarounds.

## Environment

- OpenClaw gateway: http://localhost:18789
- Binary: /opt/homebrew/bin/openclaw

## Quality Pipeline Tools

- `gh pr diff <number>`: get PR diff for Code Reviewer payload
- `jq -r '.verdict' <verdict-json>`: extract verdict from reviewer response
- Pipeline: `sessions_spawn(<reviewer-id>, <payload>)` → read close reason as verdict JSON

### Reviewer Agent IDs
- `code-reviewer`: PR diff review (before PR opens)
- `document-reviewer`: documentation, Notion pages
- `decision-reviewer`: every autonomous action (pre-Notion-log gate)
- `skill-reviewer`: SKILL.md format/safety review (post skill-creation)
- `skill-creation`: author new SKILL.md files with registry search evidence

## Agent Proposal Workflow (EVOL-01)

### Step-by-step EVOL-01 workflow:

1. **Domain coverage check**: run `scripts/check-agent-domain.sh "<proposed-domain-keyword>"`
   - If `ok==false`: agent already exists — do not proceed
   - If `ok==true`: proceed to proposal

2. **Evidence threshold**: MUST have 2+ Beads epics where no existing agent covered the domain as evidence. One occurrence is not sufficient.

3. **Author proposal document** using this template:
   ```
   ## New Agent Proposal
   **Proposed agent ID:** <lowercase-hyphens>
   **Domain:** <1-2 sentence description>
   **Evidence of need:**
   - Beads epic <bd-id>: "<task description>" — no matching agent; Task Orchestrator handled directly
   - Beads epic <bd-id>: "<task description>" — no matching agent; DevBot was used but lacks domain context
   **Pattern count:** <N> epics in <timespan> with no domain-matched agent
   **Proposed SOUL.md focus:** <concise focus>
   **Model:** anthropic/claude-sonnet-4-6
   **Sub-agent of:** task-orchestrator
   **Channel:** none (execution-tier; sessions_spawn only)
   **Reversibility:** Agent can be removed: delete ~/.openclaw/agents/<id>/ + remove from openclaw.json + run /openclaw-stow
   **Rationale:** <specific, evidence-based reason>
   ```

4. **Decision Reviewer gate**: send proposal text to Decision Reviewer via sessions_spawn
   - If verdict == "reject": do NOT proceed; log must_fix items for later revision
   - If verdict == "pass": proceed to `/openclaw-new-agent`

5. **Invoke `/openclaw-new-agent`** with proposed agent configuration

6. **MANDATORY final step**: Update Task Orchestrator SOUL.md "## Agent Routing" section (create if absent) with:
   - New agent ID: `<id>`
   - Domain keywords: `<comma-separated>`
   - When to delegate: `<condition>`
   Without this step, the new agent will never receive delegations.

### Required env vars for check-agent-domain.sh:
None — reads live openclaw.json from `$HOME/.openclaw/openclaw.json` directly

## Experiment Framework Scripts (EVOL-03)

### Required env vars:
- `OPENCLAW_NOTION_TOKEN` — Notion API auth (from Keychain: `security find-generic-password -s openclaw.notion-token -w`)
- `OPENCLAW_NOTION_EXPERIMENTS_DB_ID` — experiments Notion database ID
  - Setup: `security add-generic-password -s openclaw.notion-experiments-db-id -a openclaw -w <db-id>`
  - Then add `OPENCLAW_NOTION_EXPERIMENTS_DB_ID=$(...)` to `openclaw-secrets.sh`, `openclaw-env.sh`, `secrets.sh`

### Experiment lifecycle — mandatory order:

**Stage 1** (BEFORE any agent spawn):
```zsh
node scripts/propose-experiment.js --title "<name>" --hypothesis "<statement>" --method "<steps>" --successCriteria "<measurable outcome>"
# If ok:true → run:
node scripts/create-experiment-page.js --title "<name>" --hypothesis "<statement>" --method "<steps>" --successCriteria "<measurable outcome>"
# Returns: bare Notion page ID string. Store as EXPERIMENT_PAGE_ID.
# Embed EXPERIMENT_PAGE_ID in the Beads epic description.
```

**Stage 2**: Create Beads epic and subtasks (standard `bd create` pattern)

**Stage 3**: Sub-agents execute; each closes their task with factual evidence

**Stage 4** (AFTER Beads epic closes):
```zsh
# Write results section: update Notion page with results text using @notionhq/client pages.update
# Send to Document Reviewer: sessions_spawn("document-reviewer", full_page_content)
# If verdict pass: update Status to Final via notion.pages.update()
# If verdict reject: revise results and resubmit (max 3 cycles)
```

### Known limitations:
- `OPENCLAW_NOTION_EXPERIMENTS_DB_ID` must be manually provisioned if Phase 9 did not create the experiments database
- The experiments DB schema differs from the decisions DB — it cannot be substituted

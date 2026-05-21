# TOOLS.md — DevBot gh CLI Reference

## gh CLI Setup

Binary: `/opt/homebrew/bin/gh`
Required scope: `project` (for board assignment)
Auth check: `/opt/homebrew/bin/gh auth status 2>&1 | grep "token scopes"`
Add project scope: `/opt/homebrew/bin/gh auth refresh -s project` (requires browser)

## Issue Creation (DEV-01)

```zsh
/opt/homebrew/bin/gh issue create \
  --repo OWNER/REPO \
  --title "..." \
  --body "..." \
  --label "feature" \
  --milestone "v1.0" \
  --project "Board Title" \
  --assignee "@me"
# Returns: https://github.com/OWNER/REPO/issues/NN
```

**Note:** `--project` requires the `project` OAuth scope. Without it, the issue is created but NOT added to the board.

### Retroactive board assignment (when --project was skipped)

```zsh
/opt/homebrew/bin/gh project item-add PROJECT_NUMBER \
  --owner "@me" \
  --url ISSUE_URL
```

### Duplicate check before issue creation (MANDATORY)

```zsh
/opt/homebrew/bin/gh issue list \
  --repo OWNER/REPO \
  --search "keywords from title" \
  --state open \
  --json number,title,url \
  --limit 5
```

If results.length > 0: return BLOCKED with the first result URL.

## PR Review Queue (DEV-02)

Single call for all PR data — do NOT loop per-PR:

```zsh
/opt/homebrew/bin/gh pr list \
  --repo OWNER/REPO \
  --state open \
  --json number,title,createdAt,updatedAt,author,reviewDecision,reviewRequests,latestReviews,statusCheckRollup,url \
  --limit 50
```

### Stale PR filter (jq — string comparison, ISO 8601)

```zsh
CUTOFF=$(date -u -v"-24H" '+%Y-%m-%dT%H:%M:%SZ')  # macOS BSD date
jq --arg cutoff "$CUTOFF" '[
  .[] | select(
    ((.reviewRequests | length) > 0 or .reviewDecision == "CHANGES_REQUESTED") and
    .updatedAt < $cutoff
  ) | {number, title, updatedAt, reviewDecision, url}
]'
```

### CI failure filter (jq — with null-guard)

```zsh
jq '[
  .[] | select(
    .statusCheckRollup != null and
    (.statusCheckRollup | map(select(.state == "FAILURE")) | length) > 0
  ) | {number, title, url, failing_checks: [.statusCheckRollup[] | select(.state == "FAILURE") | .context]}
]'
```

**CRITICAL:** Always null-guard `statusCheckRollup` — repos with no GitHub Actions return null.

### Per-PR CI drill-down (for reporting — not for queue scanning)

```zsh
/opt/homebrew/bin/gh pr checks PR_NUMBER \
  --repo OWNER/REPO \
  --json name,state,startedAt,completedAt,link
```

## Script Locations

All scripts: `/Users/trilogy/.openclaw/agents/devbot/scripts/`
Shared library: `scripts/lib/json-response.sh` (cc-openclaw json-response convention)
Issue creation: `scripts/devbot-issue-create.sh`
PR queue: `scripts/devbot-pr-queue.sh`
Verification: `scripts/devbot-verify.sh`

## Per-Repo Context File

Location: `/Users/trilogy/.openclaw/workspace-devbot/repos/<owner>-<repo>/CONTEXT.md`
Template: `/Users/trilogy/.openclaw/workspace-devbot/repos/CONTEXT-TEMPLATE.md`

### Naming convention
- `anujj-ti/agentic-setup` → `anujj-ti-agentic-setup/CONTEXT.md`
- Replace `/` with `-` and lowercase everything

## Label and Milestone Queries

```zsh
# List available labels
/opt/homebrew/bin/gh label list --repo OWNER/REPO --json name,color

# List milestones
/opt/homebrew/bin/gh api repos/OWNER/REPO/milestones | jq '.[].title'

# List project boards (for project board assignment)
/opt/homebrew/bin/gh project list --owner "@me" --format json | jq '.[].title'

# Check default branch
/opt/homebrew/bin/gh api repos/OWNER/REPO | jq .default_branch
```

---

## Autonomous Dev Tools (DEV-04)

### Issue Intake

```zsh
# Live issue intake — returns structured JSON for Task Orchestrator
exec scripts/devbot-intake-issue.sh OWNER/REPO ISSUE_NUM

# Smoke test (no network) — use for verification and testing
exec scripts/devbot-intake-issue.sh OWNER/REPO ISSUE_NUM --dry-run
```

### Beads Task Graph Commands

```zsh
# List unblocked (ready) tasks
BEADS_DIR="$HOME/.openclaw/beads" /opt/homebrew/opt/node@24/bin/bd ready --json

# Claim a task (MUST claim before executing)
BEADS_DIR="$HOME/.openclaw/beads" /opt/homebrew/opt/node@24/bin/bd update <task-id> --claim --json

# Close with factual evidence
BEADS_DIR="$HOME/.openclaw/beads" /opt/homebrew/opt/node@24/bin/bd close <task-id> --reason "<evidence>" --json

# View the full dependency graph for an epic
BEADS_DIR="$HOME/.openclaw/beads" /opt/homebrew/opt/node@24/bin/bd dep tree <epic-id>
```

### Draft PR (T5 — open-pr subtask only)

```zsh
# Open a draft PR — Phase 8 only (no merge allowed — merge is Phase 10)
/opt/homebrew/bin/gh pr create \
  -R OWNER/REPO \
  --base main \
  --head <branch-name> \
  --title "feat: <issue title> (closes #N)" \
  --body "Implements #N. Changes: <summary>." \
  --draft
```

### 5-Subtask Feature Implementation Template (for reference)

The Task Orchestrator creates Beads epics with this exact structure. DevBot does NOT create these — it only executes the tasks.

| Subtask | Name | Depends On |
|---------|------|------------|
| T1 | Design proposal for #N: {title} | (none — ready at epic creation) |
| T2 | Implementation for #N: {title} | T1 |
| T3 | Self-review for #N: {title} | T2 |
| T4 | Quality-review evidence for #N: {title} | T3 |
| T5 | Open PR for #N: {title} | T4 |

The dep chain (T1 → T2 → T3 → T4 → T5) means only T1 is `ready` initially. After closing T1, T2 becomes ready. And so on.

---

## Merge and Revert Commands (Phase 10)

### Required env vars (sourced from Keychain via openclaw-secrets.sh)
- `OPENCLAW_NOTION_TOKEN` — Notion API auth
- `OPENCLAW_NOTION_DECISIONS_DB_ID` — ID of the decisions database (set by Phase 9 prerequisite)

### Merge
```zsh
scripts/devbot-merge-pr.sh <PR_NUMBER>
```
Returns: `{"ok":true,"pageId":"<id>","mergeCommitSha":"<sha>","prNumber":"<n>"}`
Fails fast with `{"ok":false,"error":"..."}` if CI not passing or Notion write fails.

### Revert (after merge)
```zsh
scripts/devbot-revert-merge.sh <MERGE_SHA> <PR_NUMBER> <ORIGINAL_PAGE_ID>
```
Returns: `{"ok":true,"revertedSha":"<sha>","prNumber":"<n>"}`
Note: `gh pr reopen` reopens the PR state. The head branch is NOT recreated — if `--delete-branch` was used during merge, the user must recreate the branch manually to push new commits.

### Notion log entry fields written per merge
Action, Timestamp, Rationale, Evidence, Reversibility, Status, MergeCommitSha (added post-merge)


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

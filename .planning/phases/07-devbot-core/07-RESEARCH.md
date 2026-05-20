# Phase 7: DevBot Core — Research

**Researched:** 2026-05-21
**Domain:** GitHub CLI operations, OpenClaw sub-agent scaffolding, per-repo context management
**Confidence:** HIGH

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| DEV-01 | DevBot agent can create GitHub issues from natural language descriptions, assign them to the project board, and set appropriate labels and milestones | Fully covered — `gh issue create` flags `--label`, `--milestone`, `--project`, `--assignee` verified locally on gh 2.69.0; `gh project item-add` verified for board addition |
| DEV-02 | DevBot agent can read and summarize open PRs, flag those with failing CI or review requests unaddressed >24h, and surface the review queue to the user | Fully covered — `gh pr list --json` with `reviewRequests`, `statusCheckRollup`, `updatedAt` fields verified locally; `gh pr checks` for per-PR CI status verified |
| DEV-06 | DevBot agent maintains project context per repository (stack, conventions, open work) and can switch context when delegated a task in a different repo | Covered — file-based context pattern fits the OpenClaw model; context file format defined in Architecture Patterns |
</phase_requirements>

---

## Summary

Phase 7 scaffolds DevBot as an execution-tier sub-agent of the Task Orchestrator. DevBot is a GitHub operations specialist — it never talks directly to Anuj via Telegram; it receives structured task descriptions from the Task Orchestrator via `sessions_spawn` and returns structured results. DevBot holds a `--json` first, deterministic-scripts-first philosophy: every GitHub operation produces structured JSON to stdout, human logs to stderr, matching the cc-openclaw convention.

Issue creation is straightforward with the `gh` CLI: `gh issue create --title --body --label --milestone --project --assignee` covers DEV-01 completely. The `--project` flag adds the issue to a GitHub Projects (v2) board by title; the `project` OAuth scope must be added to `gh auth`. Per-repository context (DEV-06) is file-based — a `repos/<owner-repo>/CONTEXT.md` file per tracked repo in DevBot's workspace, loaded by the agent at the start of each task for that repo. Context switching is a file read, not a state machine.

PR review queue staleness detection (DEV-02) uses `gh pr list --json` with `updatedAt`, `reviewRequests`, `reviewDecision`, and `statusCheckRollup` fields — all confirmed available in gh 2.69.0. Staleness threshold is >24h since last update with open review requests. The CI check status per PR comes from the `statusCheckRollup` field in `gh pr list --json` (summary) or `gh pr checks --json` (per-check detail).

**Primary recommendation:** Plan 07-01 = scaffold DevBot via `/openclaw-new-agent` as Task Orchestrator sub-agent (no Telegram binding, `exec` tool access, model: sonnet-4-6). Plan 07-02 = issue creation scripts. Plan 07-03 = PR review queue script. Plan 07-04 = per-repo context store and context switching.

---

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Issue creation from natural language | DevBot agent (LLM extracts structured fields) | `gh issue create` script (execution) | LLM parses intent → structured fields; deterministic script executes API call |
| Issue → project board assignment | DevBot scripts (`gh project item-add`) | GitHub Projects v2 API | One `gh issue create --project` call handles both issue creation and board assignment atomically |
| PR staleness detection | DevBot scripts (`gh pr list --json` + `jq`) | — | Pure data query — no LLM needed for detection; LLM formats the summary |
| CI status per PR | DevBot scripts (`gh pr list --json statusCheckRollup`) | — | `statusCheckRollup` aggregates all checks; `gh pr checks` for per-check detail if needed |
| Per-repo context | File system (DevBot workspace `repos/<owner-repo>/CONTEXT.md`) | Agent memory | Simple file read at session start; context is human-readable Markdown loaded into agent context window |
| Task receipt | Task Orchestrator → sessions_spawn | DevBot agent | DevBot never receives direct Telegram messages; all work arrives via Task Orchestrator delegation |
| Result delivery | DevBot → sessions_spawn result | Task Orchestrator | DevBot returns JSON evidence strings; Task Orchestrator summarizes for User Orchestrator → Telegram |

---

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| `gh` CLI | 2.69.0 (installed), 2.92.0 (available via `brew upgrade gh`) | All GitHub API operations — issues, PRs, project board, CI runs | Official GitHub CLI; handles auth, rate-limiting, pagination; CLAUDE.md mandated over raw curl |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| `jq` | System (brew) | JSON parsing in all DevBot shell scripts | Every `gh` CLI call piped through jq for extraction and filtering |
| `python3` | System (macOS) | UUID generation, date arithmetic in scripts | `python3 -c "import uuid; print(uuid.uuid4())"` for script IDs; `python3` for complex date math if `date(1)` insufficient |

### No npm packages needed
DevBot is a pure shell-script + `gh` CLI agent. No Node.js dependencies. All GitHub API operations use `gh`. No separate GitHub API client library needed.

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| `gh issue create --project` | `gh project item-add` (post-creation) | `--project` flag on `gh issue create` adds to project atomically; `gh project item-add` is needed for issues created without `--project` or for adding existing issues retroactively |
| File-based per-repo context | Memory-based (OpenClaw QMD / Mem0) | File-based is simpler, version-controllable, human-editable; QMD/Mem0 adds Phase 5+ infrastructure requirement; file approach is Phase 7-safe |
| `gh pr list --json statusCheckRollup` | `gh pr checks` per PR | `statusCheckRollup` in `pr list` gives a summary (pass/fail/pending) for all PRs in one call; `gh pr checks` gives per-check detail but requires N calls for N PRs — use `pr list` for queue scanning, `pr checks` for drill-down |

### Installation
No new packages to install. All tooling is available from prior phases.

```bash
# If gh CLI needs upgrade (optional for this phase):
brew upgrade gh
# Then re-auth for project scope:
/opt/homebrew/bin/gh auth refresh -s project
```

---

## Package Legitimacy Audit

*Phase 7 installs no external packages. All operations use the `gh` CLI and `jq` installed via Homebrew in prior phases. Section not applicable.*

---

## Architecture Patterns

### System Architecture Diagram

```
User (Telegram)
      │
      ▼
User Orchestrator
      │  sessions_spawn (structured task description)
      ▼
Task Orchestrator
      │  sessions_spawn (structured task description)
      ▼
DevBot Agent (no Telegram binding)
      │
      ├── DEV-01: Issue Creation
      │     │
      │     ▼
      │  scripts/create-issue.sh
      │  gh issue create --title --body --label --milestone --project
      │  gh project item-add (if not added at creation time)
      │     │
      │     └── stdout: {"ok": true, "issue_url": "...", "issue_number": 42}
      │
      ├── DEV-02: PR Review Queue
      │     │
      │     ▼
      │  scripts/pr-review-queue.sh
      │  gh pr list --json ... | jq stale filter
      │  gh pr list --json statusCheckRollup | jq ci-failure filter
      │     │
      │     └── stdout: {"ok": true, "stale_prs": [...], "failing_ci": [...]}
      │
      └── DEV-06: Repo Context
            │
            ▼
        workspace/repos/<owner-repo>/CONTEXT.md
        (loaded at task start, cached for session)
```

### Recommended Project Structure
```
.openclaw/agents/devbot/
├── SOUL.md             # Identity, GitHub ops scope, per-repo context rules
├── IDENTITY.md         # name, role, model, emoji
├── USER.md             # Anuj's preferences, repo conventions
├── AGENTS.md           # Startup checklist, context load sequence, workspace hygiene
├── TOOLS.md            # gh CLI reference, project scope auth, context file format
├── SECURITY.md         # Credential rules, gh auth isolation, PR merge gate
├── memory/
│   └── archives/
└── scripts/
    ├── lib/
    │   └── json-response.sh         # cc-openclaw output convention
    ├── create-issue.sh              # DEV-01: issue creation
    ├── pr-review-queue.sh           # DEV-02: PR staleness + CI scan
    └── context-load.sh              # DEV-06: load/update repo context

# Per-repo context stored in DevBot workspace at runtime:
~/.openclaw/agents/devbot/repos/
└── <owner>-<repo>/
    └── CONTEXT.md                   # stack, conventions, open work
```

### Pattern 1: DevBot SOUL.md structure

**What:** The 6 core directive files for DevBot. SOUL.md follows the sub-agent pattern: no channel binding, structured output, sessions_spawn result delivery.

**When to use:** During Plan 07-01 `/openclaw-new-agent` execution.

```markdown
# SOUL.md — DevBot

## Identity
You are DevBot, the GitHub operations specialist for Anuj's Personal AI Operations Hub.
You receive structured task descriptions from the Task Orchestrator and execute GitHub operations.

## Responsibilities
- Create GitHub issues from natural language descriptions with correct labels, milestones, project assignment
- Summarize and flag stale PRs (failing CI or review requests >24h unaddressed)
- Load and maintain per-repository context (stack, conventions, open work)
- Return structured JSON evidence strings as results — never narrative summaries

## Operational Rules
- NEVER start executing without first loading per-repo CONTEXT.md for the target repo
- Use deterministic scripts (set -euo pipefail, JSON stdout) for ALL GitHub API calls
- Begin every response with: STARTED | IN_PROGRESS | COMPLETED | BLOCKED
- On BLOCKED: describe exactly what is missing and return control to Task Orchestrator
- All gh CLI calls use --repo OWNER/REPO explicitly — never rely on cwd-based detection
- gh binary: /opt/homebrew/bin/gh (explicit path — nvm PATH shadowing)

## Boundaries
- No direct Telegram channel — you receive and respond only via sessions_spawn
- No PR merges in Phase 7 — that is Phase 10 with Notion pre-log gate
- Do not call GitHub API directly with curl — use gh CLI exclusively
- Do not create issues without first checking for duplicates via gh issue list --search

## Tone
- Structured and factual — output is parsed by Task Orchestrator
- Results as JSON evidence strings: {"ok": true, "issue_number": 42, "url": "..."}
- Status first, then facts

## Model Policy
- Primary: anthropic/claude-sonnet-4-6
- Never change model without Anuj's explicit instruction
```

### Pattern 2: Issue creation with project board assignment

**What:** Atomic issue creation with label, milestone, and project board assignment using the `gh issue create` `--project` flag. Produces structured JSON output.

**Key discovery:** `gh issue create --project` requires `gh auth refresh -s project` first (project scope is not included in the default gh auth scope set). This is a MUST-HAVE step in Plan 07-01.

```zsh
#!/usr/bin/env zsh
# Source: [VERIFIED: gh issue create --help, local gh 2.69.0]
# File: scripts/create-issue.sh
# Usage: create-issue.sh --repo OWNER/REPO --title "..." --body "..." --label "bug" --milestone "v1.0" --project "My Project"

set -euo pipefail
source "$(dirname "$0")/lib/json-response.sh"

GH=/opt/homebrew/bin/gh

# Parse args
while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo) REPO="$2"; shift 2 ;;
    --title) TITLE="$2"; shift 2 ;;
    --body) BODY="$2"; shift 2 ;;
    --label) LABEL="$2"; shift 2 ;;
    --milestone) MILESTONE="$2"; shift 2 ;;
    --project) PROJECT="$2"; shift 2 ;;
    --assignee) ASSIGNEE="$2"; shift 2 ;;
    *) echo "Unknown arg: $1" >&2; exit 1 ;;
  esac
done

# Build gh args array
GH_ARGS=(issue create --repo "$REPO" --title "$TITLE" --body "$BODY")
[[ -n "${LABEL:-}" ]]     && GH_ARGS+=(--label "$LABEL")
[[ -n "${MILESTONE:-}" ]] && GH_ARGS+=(--milestone "$MILESTONE")
[[ -n "${PROJECT:-}" ]]   && GH_ARGS+=(--project "$PROJECT")
[[ -n "${ASSIGNEE:-}" ]]  && GH_ARGS+=(--assignee "$ASSIGNEE")

# Create the issue; gh issue create returns the URL on stdout
ISSUE_URL=$($GH "${GH_ARGS[@]}" 2>/dev/null)
ISSUE_NUMBER=$(basename "$ISSUE_URL")

json_ok "{\"issue_url\": \"$ISSUE_URL\", \"issue_number\": $ISSUE_NUMBER, \"repo\": \"$REPO\"}"
```

### Pattern 3: PR review queue with staleness detection

**What:** Single `gh pr list --json` call fetches all open PRs with review request and CI status fields. jq filter identifies stale PRs (pending reviews, not updated in >24h or with failing CI).

**Key discovery:** `statusCheckRollup` is a field in `gh pr list --json` output. It summarizes all check runs for the PR head commit. Each item in the array has `state` (`SUCCESS`, `FAILURE`, `PENDING`, etc.) and `context`. This eliminates the need for N separate `gh pr checks` calls for queue scanning.

```zsh
#!/usr/bin/env zsh
# Source: [VERIFIED: gh pr list --json x 2>&1 field list, local gh 2.69.0]
# File: scripts/pr-review-queue.sh

set -euo pipefail
source "$(dirname "$0")/lib/json-response.sh"

GH=/opt/homebrew/bin/gh
REPO="${1:?Usage: pr-review-queue.sh OWNER/REPO}"
STALE_HOURS="${2:-24}"

# Unix timestamp for cutoff (macOS BSD date)
CUTOFF_ISO=$(date -u -v"-${STALE_HOURS}H" '+%Y-%m-%dT%H:%M:%SZ')

# Fetch open PRs with all fields needed for staleness + CI detection
ALL_PRS=$($GH pr list \
  --repo "$REPO" \
  --state open \
  --json number,title,createdAt,updatedAt,author,reviewDecision,reviewRequests,latestReviews,statusCheckRollup,url \
  --limit 50 \
  2>/dev/null)

# Stale: has review requests AND not updated in threshold period
STALE_PRS=$(echo "$ALL_PRS" | jq --arg cutoff "$CUTOFF_ISO" '[
  .[] | select(
    ((.reviewRequests | length) > 0 or .reviewDecision == "CHANGES_REQUESTED") and
    .updatedAt < $cutoff
  ) | {number, title, updatedAt, reviewDecision, url}
]')

# Failing CI: any statusCheckRollup entry with state FAILURE
FAILING_CI=$(echo "$ALL_PRS" | jq '[
  .[] | select(
    .statusCheckRollup != null and
    (.statusCheckRollup | map(select(.state == "FAILURE")) | length) > 0
  ) | {number, title, url, failing_checks: [.statusCheckRollup[] | select(.state == "FAILURE") | .context]}
]')

json_ok "{\"stale_prs\": $STALE_PRS, \"failing_ci\": $FAILING_CI, \"repo\": \"$REPO\", \"stale_threshold_hours\": $STALE_HOURS}"
```

### Pattern 4: Per-repo context store and context switching

**What:** Each tracked repository has a `CONTEXT.md` file in DevBot's workspace at `repos/<owner>-<repo>/CONTEXT.md`. The agent loads this file at the start of any task involving that repo. "Context switching" is simply loading a different file.

**Why file-based (not memory/QMD):** QMD requires Phase 5 infrastructure. Mem0 is not in the stack. File-based context is version-controllable, human-editable, and immediately readable by the agent without additional tool calls.

```markdown
# Context: <owner>/<repo>

**Last updated:** YYYY-MM-DD by DevBot
**Loaded by:** DevBot — read at task start before any GitHub operations

## Stack
- Language: TypeScript, Node.js 24
- Framework: (e.g., Next.js 15)
- Package manager: npm

## Conventions
- Branch naming: feat/<issue-number>-<slug>
- PR title format: [#<issue>] Title
- Labels: bug, feature, docs, infra
- Milestones: v1.0, v1.1, backlog

## Open Work
- Issue #42: Implement standup aggregation (in progress, assigned @anujj-ti)
- Issue #38: Fix OAuth2 token refresh race condition (open)

## Project Boards
- Board: "AI Ops Hub" (owner: @me, project number: 1)

## Notes
- Main branch: main (protected, requires 1 review)
- CI: GitHub Actions — .github/workflows/ci.yml
```

**Context loading step (DevBot AGENTS.md must include):**
```markdown
## Session Startup
1. Read SOUL.md
2. Read MEMORY.md (if present)
3. If task specifies a repo: read repos/<owner>-<repo>/CONTEXT.md before any GitHub operation
4. If CONTEXT.md absent for the target repo: acknowledge gap, proceed with defaults, create a stub after first interaction
```

### Pattern 5: DevBot openclaw.json registration

**What:** DevBot is registered as a sub-agent of Task Orchestrator. No channel binding. `exec` tool access required for running shell scripts.

```json
{
  "id": "devbot",
  "name": "DevBot",
  "workspace": "/Users/trilogy/.openclaw/workspace-devbot",
  "agentDir": "/Users/trilogy/.openclaw/agents/devbot",
  "model": {"primary": "anthropic/claude-sonnet-4-6"},
  "tools": {
    "alsoAllow": ["exec"]
  }
}
```

**Parent agent update (task-orchestrator entry in openclaw.json):**
```json
"subagents": {
  "allowAgents": ["devbot"],
  "delegationMode": "prefer"
}
```

### Anti-Patterns to Avoid
- **DevBot talks directly to Telegram:** DevBot has no channel binding. It receives and returns via sessions_spawn only. Any plan that adds a Telegram binding to DevBot violates the architecture.
- **Using `gh` without `--repo` flag:** `gh` defaults to the repo of the current working directory. In cron or agent contexts, cwd is unpredictable. Always pass `--repo OWNER/REPO` explicitly.
- **Raw curl to GitHub API instead of `gh`:** CLAUDE.md mandates `gh` for GitHub operations. Raw curl requires manual token management, rate-limit handling, and pagination — all handled by `gh`.
- **`gh issue create` without `project` scope auth:** `gh issue create --project` silently succeeds but the issue is NOT added to the board if the `project` OAuth scope is absent. Verify with `gh auth status` before running.
- **`jq` select without null-guard on `statusCheckRollup`:** Some PRs have no CI configured — `statusCheckRollup` is `null`. The jq filter must guard with `select(.statusCheckRollup != null)` to avoid null dereference errors.
- **Storing per-repo CONTEXT.md in the repo (not agent workspace):** The context file contains operational state (open issues, current milestones) that changes frequently and is agent-runtime data, not source code. It belongs in `~/.openclaw/agents/devbot/repos/` (not in `~/Documents/agentic-setup`).
- **No duplicate issue check:** LLMs are prone to creating duplicate issues if not instructed to check first. DevBot SOUL.md must include: "Before creating an issue, run `gh issue list --search '<title keywords>' --repo REPO` to check for duplicates."

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| GitHub API pagination | Custom loop over Link headers | `gh issue list --limit 100` (gh handles pagination) | gh CLI handles paginated responses automatically; custom pagination breaks on rate limits |
| CI check status aggregation | Parse individual workflow run events | `gh pr list --json statusCheckRollup` | `statusCheckRollup` is pre-aggregated per-PR by GitHub; single call returns pass/fail/pending for all checks |
| PR staleness logic | Custom date comparison in bash | `jq --arg cutoff "$CUTOFF_ISO" '.[] \| select(.updatedAt < $cutoff)'` | jq handles ISO 8601 string comparison correctly; bash date arithmetic is error-prone |
| Project board assignment | GraphQL API call with ProjectV2 mutation | `gh issue create --project "Board Title"` | `--project` flag handles the GraphQL mutation internally; requires project OAuth scope |
| Per-repo context storage | Database, Notion, or vector store | Flat `CONTEXT.md` file in agent workspace | Simple, readable, editable, version-safe; no infrastructure dependency in Phase 7 |

**Key insight:** The `gh` CLI eliminates the entire class of GitHub API auth and pagination problems. Every operation that seems to need raw GitHub API access can be satisfied by `gh` CLI flags already verified in this phase.

---

## Common Pitfalls

### Pitfall 1: `gh issue create --project` requires project OAuth scope
**What goes wrong:** `gh auth login` (the default login flow) does not include the `project` scope. When DevBot tries to run `gh issue create --project "Board Name"`, the issue is created but silently NOT added to the project board. No error is returned.
**Why it happens:** GitHub's `project` scope is an optional add-on scope not included in gh's default login. The `gh issue create` docs note: "Adding an issue to projects requires authorization with the `project` scope."
**How to avoid:** Plan 07-01 must include a step: `gh auth refresh -s project` to add the project scope. Verify with `gh auth status` — output should list `project` in the scopes line.
**Warning signs:** Issues appear in the repo but not in the project board view. `gh auth status` shows scope list without `project`.

### Pitfall 2: `statusCheckRollup` is null for PRs on repos with no CI
**What goes wrong:** Calling `jq '.[] | .statusCheckRollup | map(select(.state == "FAILURE"))'` on a PR from a repo with no GitHub Actions workflows throws a `null` error in jq.
**Why it happens:** `statusCheckRollup` is `null` when no CI checks are configured for the repo or the PR head commit.
**How to avoid:** Always guard: `select(.statusCheckRollup != null and ...)` before accessing `statusCheckRollup` array elements. The PR queue script (Pattern 3) already includes this guard.
**Warning signs:** `pr-review-queue.sh` exits with a jq error mentioning `null` iteration.

### Pitfall 3: Task Orchestrator is Phase 3 stub — no sub-agent support yet
**What goes wrong:** DevBot is registered as a Task Orchestrator sub-agent, but the Task Orchestrator SOUL.md currently says "Do not spawn sub-agents in Phase 3" and lacks `sessions_spawn` tool access. Registering DevBot in openclaw.json without updating the Task Orchestrator's `subagents.allowAgents` config and SOUL.md means DevBot is never actually called.
**Why it happens:** Phase 7 depends on Phase 4 (Beads + Task Orchestrator upgrade) being complete. DevBot scaffolding can be done in Phase 7, but full wiring requires the Phase 4 Task Orchestrator upgrade.
**How to avoid:** Plan 07-01 must update Task Orchestrator's config in openclaw.json to add `"allowAgents": ["devbot"]` and `sessions_spawn` in `tools.alsoAllow`. Also update Task Orchestrator SOUL.md to remove the Phase 3 "no sub-agents" restriction.
**Warning signs:** Task Orchestrator logs show "agent not in allowAgents" when attempting DevBot delegation.

### Pitfall 4: DevBot workspace directory not created before stow
**What goes wrong:** openclaw.json references `workspace: "/Users/trilogy/.openclaw/workspace-devbot"`. If this directory doesn't exist at gateway startup, the agent may fail to initialize or have no writable workspace for the `repos/` context files.
**Why it happens:** `/openclaw-new-agent` creates the `~/.openclaw/agents/devbot/` directory structure, but the workspace directory (`workspace-devbot`) is separate and must be explicitly created.
**How to avoid:** Plan 07-01 step 1 must `mkdir -p ~/.openclaw/workspace-devbot` and `mkdir -p ~/.openclaw/workspace-devbot/repos` alongside the agent dir creation.
**Warning signs:** Gateway logs show workspace directory not found for devbot agent.

### Pitfall 5: jq ISO 8601 date comparison is string comparison, not timestamp comparison
**What goes wrong:** `jq` `.updatedAt < $cutoff` compares ISO 8601 strings lexicographically. This works correctly ONLY if both strings use the same format (UTC, Z-suffix, zero-padded). If GitHub returns `updatedAt` with a different timezone offset or format, the comparison silently fails.
**Why it happens:** GitHub `gh pr list --json updatedAt` always returns RFC 3339 in UTC with Z suffix. The macOS `date -u -v-24H '+%Y-%m-%dT%H:%M:%SZ'` also produces UTC with Z suffix. The formats match — but this is fragile if GitHub ever changes the format.
**How to avoid:** Document this assumption in the script. For Phase 7 MVP this is sufficient. Phase 8+ can upgrade to `(now - 86400 | todate)` for a pure-jq approach that doesn't depend on macOS `date`.
**Warning signs:** `STALE_PRS` returns empty array even when PRs have clearly not been updated in 24+ hours.

---

## Code Examples

Verified patterns from official sources:

### gh issue create with all DEV-01 flags (verified locally on gh 2.69.0)
```bash
# Source: [VERIFIED: gh issue create --help, local gh 2.69.0]
/opt/homebrew/bin/gh issue create \
  --repo OWNER/REPO \
  --title "Add morning standup cron job" \
  --body "Implement the standup cron following CHAN-04 requirements." \
  --label "feature" \
  --milestone "v1.0" \
  --project "AI Ops Hub" \
  --assignee "@me"
# Returns: https://github.com/OWNER/REPO/issues/42
```

### gh project item-add for retroactive board assignment (verified locally)
```bash
# Source: [VERIFIED: gh project item-add --help, local gh 2.69.0]
/opt/homebrew/bin/gh project item-add 1 \
  --owner "@me" \
  --url https://github.com/OWNER/REPO/issues/42
```

### gh pr list with all DEV-02 JSON fields (verified locally)
```bash
# Source: [VERIFIED: gh pr list --json x 2>&1 field list, local gh 2.69.0]
/opt/homebrew/bin/gh pr list \
  --repo OWNER/REPO \
  --state open \
  --json number,title,createdAt,updatedAt,author,reviewDecision,reviewRequests,latestReviews,statusCheckRollup,url \
  --limit 50
```

### gh pr checks for per-PR CI detail (verified locally)
```bash
# Source: [VERIFIED: gh pr checks --help, local gh 2.69.0]
/opt/homebrew/bin/gh pr checks 42 \
  --repo OWNER/REPO \
  --json name,state,startedAt,completedAt,link
# state values: pass | fail | pending | skipping | cancel (--json bucket field)
```

### gh auth refresh for project scope
```bash
# Source: [VERIFIED: gh issue create --help note + gh auth refresh --help]
/opt/homebrew/bin/gh auth refresh -s project
# Prompts user once; adds project scope to stored token
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Raw curl + GitHub REST API | `gh` CLI | 2021+ | gh handles auth, pagination, rate limits; no token management |
| GitHub Projects (v1, columns-based) | GitHub Projects v2 (items, fields, workflows) | 2022 | `gh project item-add` works with Projects v2; the old `gh project column` commands are deprecated |
| Per-agent memory via vector DB | File-based `CONTEXT.md` per repo | Phase 7 design | Simpler for Phase 7; vector/QMD approach is Phase 9+ after Notion layer is in place |

**Deprecated/outdated:**
- `gh project column`: Projects v1 API — deprecated; `gh project item-add` is the current approach for Projects v2.
- `GitHub GraphQL API direct curl for Projects v2`: still works but `gh project` CLI wraps it completely.

---

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | Task Orchestrator will have `sessions_spawn` and `allowAgents: ["devbot"]` config by the time Phase 7 executes (requires Phase 4 completion) | Pitfall 3, Pattern 5 | HIGH — if Task Orchestrator is still Phase 3 stub, DevBot cannot be called. Phase 7 plan must include Task Orchestrator config update. |
| A2 | `gh pr list --json statusCheckRollup` field is populated for PRs on repos with GitHub Actions CI (confirmed from --help field listing) | Pattern 3 | LOW — field existence confirmed via `--help`; content behavior assumed from documented `gh pr checks --json bucket` semantics |
| A3 | `gh issue create --project "Board Title"` matches the project by exact title | Pattern 2, Code Examples | MEDIUM — if the project board title has different casing or trailing spaces, the flag silently fails. Recommend `--project` matching to be case-exact in SOUL.md instructions. |
| A4 | Per-repo CONTEXT.md files are created and maintained by DevBot autonomously (initial population is a task, not hardcoded) | Pattern 4 | LOW — design intent; documented in SOUL.md and AGENTS.md |

---

## Open Questions

1. **gh CLI version: upgrade to 2.92.0 now or defer?**
   - What we know: gh 2.69.0 is installed (CLAUDE.md specifies 2.92.0); `brew upgrade gh` brings it to 2.92.0; all verified commands work on 2.69.0
   - What's unclear: Whether 2.92.0 has any relevant new flags for DEV-01/02/06
   - Recommendation: Plan 07-01 should include `brew upgrade gh` as a prerequisite step — align the installed version with CLAUDE.md's specification

2. **Which repos does DevBot track by default?**
   - What we know: DEV-06 says "per-repository context" but doesn't specify the initial repo list
   - What's unclear: Does DevBot start with zero repos and create context files on demand, or does the plan pre-populate known repos?
   - Recommendation: DevBot starts with zero pre-populated repos; SOUL.md instructs it to create a `repos/<owner>-<repo>/CONTEXT.md` stub on first interaction with any new repo; planner does not need to list repos in advance

3. **How does Task Orchestrator know to delegate to DevBot specifically (vs other future sub-agents)?**
   - What we know: Task Orchestrator SOUL.md currently says "delegate to sub-agents" generically
   - What's unclear: Phase 4 will define the Beads task graph routing pattern; by Phase 7 the Task Orchestrator may have explicit routing rules
   - Recommendation: Plan 07-01 adds a DevBot routing hint to Task Orchestrator SOUL.md: "GitHub issues, PRs, CI status → delegate to DevBot"

---

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| `gh` CLI | All DEV-01/02/06 scripts | ✓ | 2.69.0 (upgrade to 2.92.0 available) | None — required |
| `jq` | Script JSON parsing | ✓ (assumed from Phase 1) | — | `python3 -c "import json,sys; ..."` |
| `gh auth` with project scope | DEV-01 project board assignment | Requires `gh auth refresh -s project` | — | Without project scope, issue creates but board assignment silently fails |
| OpenClaw sessions_spawn for Task Orchestrator | DevBot delegation | Requires Phase 4 completion | — | Phase 7 scaffolding is autonomous; full delegation wiring requires Phase 4 |

**Missing dependencies with no fallback:**
- None — all Phase 7 scripts can be built and tested autonomously; DevBot-in-production requires Phase 4 Task Orchestrator upgrade

**Missing dependencies with fallback:**
- `gh` project scope: without it, `--project` flag silently fails; workaround is `gh project item-add` post-creation (two commands instead of one)

---

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | zsh smoke tests (established pattern from Phases 1-5) |
| Config file | `scripts/verify-phase-07.sh` (Wave 4 or dedicated plan) |
| Quick run command | `zsh scripts/verify-phase-07.sh` |
| Full suite command | `zsh scripts/verify-phase-07.sh` |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| DEV-01 | DevBot agent registered in openclaw.json | smoke | `grep -q '"id": "devbot"' .openclaw/openclaw.json` | ❌ Wave 0 |
| DEV-01 | `create-issue.sh` is executable and syntax-valid | smoke | `zsh -n .openclaw/agents/devbot/scripts/create-issue.sh` | ❌ Wave 0 |
| DEV-01 | gh auth has project scope | smoke | `/opt/homebrew/bin/gh auth status 2>&1 \| grep -q project` | ❌ Wave 0 |
| DEV-02 | `pr-review-queue.sh` is executable and syntax-valid | smoke | `zsh -n .openclaw/agents/devbot/scripts/pr-review-queue.sh` | ❌ Wave 0 |
| DEV-02 | `pr-review-queue.sh` outputs valid JSON on dry-run | smoke | `zsh .openclaw/agents/devbot/scripts/pr-review-queue.sh anujj-ti/agentic-setup \| jq .ok` | ❌ Wave 0 |
| DEV-06 | repos/ directory exists in devbot workspace | smoke | `test -d ~/.openclaw/workspace-devbot/repos` | ❌ Wave 0 |
| DEV-06 | AGENTS.md includes context load step | smoke | `grep -q "CONTEXT.md" .openclaw/agents/devbot/AGENTS.md` | ❌ Wave 0 |

### Sampling Rate
- **Per task commit:** `zsh -n` syntax check on modified scripts
- **Per wave merge:** `zsh scripts/verify-phase-07.sh`
- **Phase gate:** Full verify suite green before `/gsd:verify-work`

### Wave 0 Gaps
- [ ] `scripts/verify-phase-07.sh` — covers all DEV-01, DEV-02, DEV-06 smoke checks above

*(No existing test infrastructure covers Phase 7 requirements)*

---

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | yes | `gh auth` OAuth token stored by gh's own keychain integration; no separate secret management needed |
| V3 Session Management | no | No user sessions |
| V4 Access Control | yes | DevBot has no channel binding; receives work only via sessions_spawn from Task Orchestrator; cannot be triggered by external input |
| V5 Input Validation | yes | All natural language task descriptions treated as untrusted input; DevBot extracts structured fields (title, label, etc.) before passing to `gh issue create` |
| V6 Cryptography | no | No custom crypto; gh token stored by gh's keychain integration |

### Known Threat Patterns for gh CLI + DevBot

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Issue creation spam via prompt injection | Tampering | DevBot SOUL.md: "Before creating any issue, require explicit confirmation from Task Orchestrator that issue creation was authorized by Anuj" |
| Wrong repo targeting | Tampering | Always pass `--repo OWNER/REPO` explicitly; never use cwd-based detection; validate repo value against allowed-repos list in SOUL.md |
| Accidental PR merge (premature) | Elevation of Privilege | DevBot SOUL.md: "Do not merge PRs in Phase 7 — merges are Phase 10 with Notion pre-log gate; return BLOCKED if asked to merge" |
| Per-repo CONTEXT.md containing secrets | Information Disclosure | SECURITY.md: "Never store tokens, API keys, or credentials in repo CONTEXT.md files; credentials go to Keychain only" |
| Duplicate issue creation | Denial of Service | SOUL.md rule: "Always run `gh issue list --search '<keywords>' --repo REPO` before creating any issue; return BLOCKED if a likely duplicate is found" |

---

## Sources

### Primary (HIGH confidence)
- cc-openclaw/.claude/skills/openclaw-new-agent/SKILL.md — 6-file scaffold structure, tools.alsoAllow pattern, sub-agent registration (read directly)
- `gh issue create --help` — all DEV-01 flags verified locally on gh 2.69.0
- `gh pr list --json x` error output — full JSON field list including `statusCheckRollup`, `reviewRequests`, `reviewDecision`, `updatedAt` (verified locally)
- `gh pr checks --help` — JSON fields including `name`, `state`, `bucket` (verified locally)
- `gh project item-add --help` and `gh project item-create --help` — project board operations (verified locally)
- `.openclaw/agents/task-orchestrator/SOUL.md` — Phase 3 stub constraints to remove in Plan 07-01 (read directly)
- `.openclaw/openclaw.json` — current agents.list format and structure (read directly)

### Secondary (MEDIUM confidence)
- `gh auth refresh -s project` — project scope requirement noted in `gh issue create --help` ("Adding an issue to projects requires authorization with the `project` scope. To authorize, run `gh auth refresh -s project`.") — VERIFIED in local help output

### Tertiary (LOW confidence)
- None

---

## Metadata

**Confidence breakdown:**
- Standard stack (gh CLI flags): HIGH — verified locally via --help on installed 2.69.0
- Architecture (sub-agent pattern): HIGH — read from existing SOUL.md + SKILL.md patterns
- Per-repo context design: MEDIUM — file-based approach ASSUMED as the right Phase 7 approach; no existing precedent in this codebase
- Staleness detection jq filter: MEDIUM — jq ISO 8601 string comparison behavior ASSUMED consistent with GitHub's date format

**Research date:** 2026-05-21
**Valid until:** 2026-06-20 (30 days — stable gh CLI, slow-moving GitHub API)

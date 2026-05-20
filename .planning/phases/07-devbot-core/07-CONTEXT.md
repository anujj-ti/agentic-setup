# Phase 7: DevBot Core — Context

**Created:** 2026-05-21
**Phase:** 07-devbot-core
**Mode:** mvp
**Requirements:** DEV-01, DEV-02, DEV-06

---

## Decisions

### D-70: gh CLI Version — Upgrade to 2.92.0
**Decision:** Upgrade gh CLI from currently installed 2.69.0 to 2.92.0 via `brew upgrade gh` as the first step in Plan 07-01.
**Rationale:** CLAUDE.md specifies gh 2.92.0 as the standard version. All verified commands work on 2.69.0 but we align with the documented stack.
**Implementation:** `brew upgrade gh` in Plan 07-01, Task 1. Verify with `/opt/homebrew/bin/gh --version`.

### D-71: Project OAuth Scope — gh auth refresh Required
**Decision:** `gh auth refresh -s project` is a mandatory prerequisite step in Plan 07-01. Without it, `gh issue create --project` silently creates the issue but does NOT add it to the project board.
**Rationale:** Verified in research: `gh issue create --help` states "Adding an issue to projects requires authorization with the `project` scope." Default gh auth login does not include this scope.
**Implementation:** Run `/opt/homebrew/bin/gh auth refresh -s project` in Plan 07-01 as a `checkpoint:human-action` (browser auth required). Verify with `gh auth status 2>&1 | grep project`.

### D-72: statusCheckRollup Field — Single-Call CI Status
**Decision:** Use `gh pr list --json statusCheckRollup` for PR CI status — one call for all PRs, not N calls via `gh pr checks`.
**Rationale:** Research confirmed `statusCheckRollup` in `gh pr list --json` aggregates all check states per PR head commit. `gh pr checks` is reserved for per-PR drill-down, not queue scanning.
**Implementation:** devbot-pr-queue.sh uses `gh pr list --json number,title,...,statusCheckRollup` and extracts failing PRs via jq `select(.statusCheckRollup != null and ...)`.

### D-73: Per-Repo Context Location — Agent Workspace Only
**Decision:** Per-repo context files live at `~/.openclaw/workspace-devbot/repos/<owner>-<repo>/CONTEXT.md` (agent workspace), NOT in the agentic-setup repo.
**Rationale:** Context files contain operational runtime state (open issues, current milestones) that changes frequently. They are not source code. Storing in the repo would pollute git history with runtime data.
**Implementation:** Plan 07-04 creates `~/.openclaw/workspace-devbot/repos/` and a CONTEXT-TEMPLATE.md. DevBot creates `<owner>-<repo>/CONTEXT.md` stubs on first contact with each repo.

### D-74: Task Orchestrator allowAgents — Must Include "devbot"
**Decision:** Update task-orchestrator entry in openclaw.json to add `"allowAgents": ["devbot"]` and `sessions_spawn` in `tools.alsoAllow`.
**Rationale:** Research pitfall 3: Task Orchestrator currently has no `allowAgents` list and no `sessions_spawn` tool. Without this update, DevBot is registered but never delegated to.
**Implementation:** Plan 07-01, Task 2 updates openclaw.json task-orchestrator entry. Also adds DevBot routing hint to Task Orchestrator SOUL.md ("GitHub issues, PRs, CI status → delegate to DevBot").

### D-75: DevBot Communication — sessions_spawn Only, No Telegram
**Decision:** DevBot has no Telegram channel binding. It receives work exclusively via sessions_spawn from the Task Orchestrator and returns JSON evidence strings as results.
**Rationale:** Architecture mandate from RESEARCH.md. Direct Telegram binding would bypass the Task Orchestrator orchestration layer and break the dual-orchestrator pattern.
**Implementation:** DevBot openclaw.json entry has no `bindings` entry. SOUL.md explicitly states "No direct Telegram channel — receive and respond only via sessions_spawn."

### D-76: DevBot Script Convention — JSON stdout, logs to stderr
**Decision:** All DevBot scripts follow the cc-openclaw json-response.sh convention: stdout = JSON only, stderr = human-readable logs, exit code is law.
**Rationale:** CLAUDE.md mandate. Agents parse stdout; stderr corruption breaks JSON parsing. All scripts use `#!/usr/bin/env zsh` + `set -euo pipefail`.
**Implementation:** All scripts in `.openclaw/agents/devbot/scripts/` source `lib/json-response.sh` and use `json_ok` / `json_err` helpers. Never echo to stdout except final JSON.

---

## Deferred Ideas

- DevBot directly merging PRs — deferred to Phase 10 (requires Notion pre-log gate)
- CI Monitor polling cron — deferred to Phase 8
- Beads task graph decomposition in DevBot — deferred to Phase 8 (requires Phase 8 Beads integration)
- WhatsApp notifications for DevBot — deferred (CHAN-02 deferred per D-20)
- Pre-populated repo context files — DevBot creates stubs on first contact; no hardcoded repo list

---

## Claude's Discretion

- Script naming: using `devbot-issue-create.sh`, `devbot-pr-queue.sh`, `devbot-verify.sh` (prefixed with devbot- for clarity in scripts/ directory)
- jq date comparison: ISO 8601 string comparison via `select(.updatedAt < $cutoff)` is sufficient for Phase 7 MVP; Python-based timestamp comparison is Phase 8+
- CONTEXT-TEMPLATE.md format: use the exact template structure from RESEARCH.md Pattern 4
- gh binary path: use `/opt/homebrew/bin/gh` explicitly in all scripts (nvm PATH shadowing prevention, established pattern from prior phases)
- openclaw.json workspace path: use literal `/Users/trilogy/...` never `~` (established pattern from Phases 3-5)

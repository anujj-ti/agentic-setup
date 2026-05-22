# Phase 19: DevBot Autonomous Issue Pickup — Context

**Gathered:** 2026-05-22
**Status:** Ready for planning
**Research session:** Sherlock e3a9661d (12/12 beads, 4 spot-checks)

<domain>
## Phase Boundary

Add autonomous issue pickup to DevBot. DevBot currently only acts when delegated via Telegram. After this phase it proactively polls for `automation:safe` issues every 5 minutes, claims them, branches, executes the existing Beads task graph (already built in Phase 8), opens a PR, and auto-merges when CI passes. Issue closes automatically via "Resolves #N" in PR body.

No new agents. No Kanban board. Labels are the state machine.

</domain>

<decisions>
## Implementation Decisions

### Polling mechanism (ISSUE-MONITOR)
- **D-201:** `devbot-issue-monitor.sh` — new script, runs every 5 min via launchd cron (same pattern as CI Monitor). Polls `gh issue list --label automation:safe --assignee @none --state open --json number,title,labels`.
- **D-202:** Tracks last-seen issue timestamp in `~/.openclaw/agents/devbot/state/last-issue-timestamp`. Only processes issues newer than last-seen to avoid reprocessing.
- **D-203:** On new issue found → write issue JSON to `~/.openclaw/agents/devbot/state/pending-issues/` → trigger DevBot OpenClaw session via `openclaw sessions spawn devbot`.

### Claim convention (LABELS)
- **D-204:** On claim: `gh issue edit N --add-assignee echosysbot --add-label "status:in-progress"`. On completion: auto-removed when PR closes issue. No manual cleanup needed.
- **D-205:** Stale-claim guard: separate cron check (hourly) — any issue with `status:in-progress` + no commit on its branch in >2h → unassign + remove label + add comment "echosysbot: timed out, unclaiming".
- **D-206:** Label `automation:hold` blocks pickup even if `automation:safe` is present. Check for absence of `automation:hold` before claiming.

### Branch + PR loop (EXECUTION)
- **D-207:** `gh issue develop N --checkout` — creates and checks out the branch linked to the issue. Branch name auto-generated as `N-issue-title-slug`.
- **D-208:** `gh pr create --fill --body "Resolves #N" --draft` — draft PR until agent self-review passes.
- **D-209:** `gh pr merge --auto --squash --delete-branch` — auto-merge when CI passes. PR requires echosysbot to have write access to repo (already the case via github-bot-token scope).
- **D-210:** PR body must include `Resolves #N` for auto-close. `--fill` uses commit message as PR title; the body must be explicitly set.

### GitHub label setup (GOVERNANCE)
- **D-211:** Labels to create in anujj-ti/agentic-setup repo: `automation:safe` (green), `automation:hold` (red), `status:in-progress` (yellow), `e1` (blue), `e2` (blue), `e3` (blue), `agent:echosysbot` (grey).
- **D-212:** Label creation script: `devbot-setup-labels.sh` — idempotent, uses `gh label create --force`.

### echosysbot self-assignment (CONFIRMED)
- **D-213:** echosysbot is a regular user account (PAT, not GitHub App). It CAN self-assign issues if it has collaborator/push access to the repo. PAT scope `repo` already provisioned. Verified against GitHub REST API docs.

### Claude's Discretion
- Whether to also add `agent:echosysbot` label on claim or just use assignee field (assignee is sufficient)
- Exact timeout threshold for stale-claim guard (2h is reasonable default)
- Whether monitor writes to a queue file or triggers sessions directly

</decisions>

<canonical_refs>
## Canonical References

### Existing DevBot infrastructure (must read before planning)
- `.openclaw/agents/devbot/SOUL.md` — Beads execution contract, Notion pre-log protocol
- `.openclaw/agents/devbot/TOOLS.md` — GH_TOKEN pattern, existing script reference
- `.openclaw/agents/devbot/AGENTS.md` — startup checklist, execution flow
- `.openclaw/agents/devbot/scripts/devbot-issue-create.sh` — existing gh CLI pattern
- `.openclaw/agents/devbot/scripts/devbot-pr-queue.sh` — existing gh CLI polling pattern (adapt for issue monitor)
- `.openclaw/agents/devbot/scripts/devbot-execute-cycle.sh` — existing Beads task graph execution

### CI Monitor (polling pattern to copy)
- `.openclaw/agents/ci-monitor/` — existing 4-min cron polling pattern; issue monitor follows same structure

### Research (Sherlock session)
- `~/.sherlock/sessions/e3a9661d/` — full research report with all source citations
- `docs/HOW-TO-USE-DEVBOT.md` — human-readable label instructions

### Phase decisions
- `.planning/phases/08-ci-monitor-autonomous-dev-scaffold/08-CONTEXT.md` — DevBot Beads task graph decisions from Phase 8

### Requirements
- `.planning/REQUIREMENTS.md` — Phase 19 maps to new DEV-07 through DEV-10 requirements (to be added)

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `devbot-pr-queue.sh` — already polls gh CLI with `--json` output + jq filtering; adapt for issue list polling
- `devbot-issue-create.sh` — gh CLI pattern with GH_TOKEN prefix; issue monitor follows same pattern
- `devbot-execute-cycle.sh` — Beads claim/close cycle; this becomes the execution half of the loop
- `scripts/lib/json-response.sh` — json_ok / json_err; use in all new scripts
- CI Monitor cron entry in `openclaw.json` — template for adding issue-monitor cron

### Established Patterns
- GH_TOKEN from Keychain prefix on every `gh` call (D-213 in Phase 15 wiring)
- `set -euo pipefail` + JSON stdout + stderr logs — all new scripts follow this
- Notion pre-log before any autonomous action (SOUL.md requirement)
- Beads epic creation before spawning sub-agents (mandatory per task-orchestrator SOUL.md)

### Integration Points
- `openclaw.json` → add cron entry for devbot-issue-monitor (5-min interval)
- `openclaw.json` → add cron entry for devbot-stale-claim-guard (60-min interval)
- DevBot AGENTS.md → add startup check for pending-issues/ directory
- DevBot SOUL.md → add autonomous pickup section after existing Beads contract

</code_context>

<specifics>
## Specific Ideas

- `docs/HOW-TO-USE-DEVBOT.md` already written — reference it from DevBot USER.md so the agent knows the label contract
- Issue monitor should log to `~/.openclaw/agents/devbot/logs/issue-monitor-YYYY-MM-DD.log` (stderr) for debugging
- `automation:hold` as a kill switch — important safety feature given autonomous operation

</specifics>

<deferred>
## Deferred Ideas

- GitHub Projects / Kanban board integration — user will create board later; DevBot can add issues to project board via `gh project item-add` once created
- Multi-repo monitoring — Phase 19 covers `anujj-ti/agentic-setup` only; expand later
- Priority scoring (RICE/effort) — Phase 19 uses simple `e1` first; scoring algorithm is a v2.1 enhancement
- OpenHands-style `@echosysbot` mention trigger in issue comments — interesting but needs webhook; defer until public URL available

</deferred>

---

*Phase: 19-DevBot Autonomous Issue Pickup*
*Context gathered: 2026-05-22*

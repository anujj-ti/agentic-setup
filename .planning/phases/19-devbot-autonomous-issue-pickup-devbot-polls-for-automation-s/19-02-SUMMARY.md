---
phase: 19-devbot-autonomous-issue-pickup-devbot-polls-for-automation-s
plan: 02
subsystem: infra
tags: [devbot, gh-cli, automation, issue-monitor, shell-scripting, zsh, notion]

# Dependency graph
requires:
  - phase: 19-01
    provides: GitHub label setup (automation:safe, automation:hold, status:in-progress) in anujj-ti/agentic-setup

provides:
  - devbot-issue-monitor.sh: complete autonomous issue pickup loop (poll → filter → claim → branch → PR → auto-merge)
  - state/.gitkeep: state/ directory tracked in git for last-issue-timestamp and pending-issues/

affects:
  - 19-03-PLAN.md (stale-claim guard — D-205 companion script)
  - 19-04-PLAN.md (launchd cron wiring for this script, 5-min interval)
  - DevBot AGENTS.md startup check (reads pickup-queue.txt)

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "gh issue develop N --checkout for linked branch creation (D-207)"
    - "gh pr merge --auto --squash for CI-gated auto-merge (D-209)"
    - "Notion pre-log before every autonomous GitHub mutation (SOUL.md / T-19-06)"
    - "last-issue-timestamp file for idempotent polling (D-202)"
    - "automation:hold as kill switch checked before any claim action (D-206)"

key-files:
  created:
    - .openclaw/agents/devbot/scripts/devbot-issue-monitor.sh
    - .openclaw/agents/devbot/state/.gitkeep
  modified: []

key-decisions:
  - "D-202: last-issue-timestamp prevents reprocessing across 5-min poll cycles"
  - "D-206: automation:hold kill switch — jq filter excludes label at query time, before claim"
  - "D-207: gh issue develop --checkout creates GitHub-linked branch automatically"
  - "D-209: gh pr merge --auto set at PR creation time; CI gate enforced by GitHub before merge executes"
  - "SOUL.md: Notion pre-log is non-blocking on failure — pickup continues with warning if Notion is down"
  - "D-203: pickup-queue.txt queue file decouples monitor (cron shell) from DevBot session (OpenClaw agent)"

patterns-established:
  - "Issue monitor pattern: single gh issue list call → jq filter → per-issue loop (no N+1 calls)"
  - "GH_TOKEN fail-fast: script errors immediately if Keychain lookup returns empty (T-19-03)"
  - "Best-effort PR at monitor time: gh pr create skipped if branch has no commits; devbot-execute-cycle.sh handles full PR lifecycle"

requirements-completed:
  - DEV-07
  - DEV-08
  - DEV-09

# Metrics
duration: 2min
completed: 2026-05-22
---

# Phase 19 Plan 02: DevBot Issue Monitor Summary

**devbot-issue-monitor.sh: full autonomous pickup loop — poll automation:safe issues, filter by timestamp + hold label, claim via echosysbot assignment, branch via gh issue develop, draft PR with Resolves #N, and set auto-merge with CI gate**

## Performance

- **Duration:** 2 min
- **Started:** 2026-05-22T08:33:04Z
- **Completed:** 2026-05-22T08:35:02Z
- **Tasks:** 1
- **Files modified:** 2

## Accomplishments

- Created `devbot-issue-monitor.sh` — the core polling script implementing D-201 through D-210
- Implemented `automation:hold` kill switch (D-206) via jq filter before any claim action
- Implemented `last-issue-timestamp` dedup guard (D-202) preventing reprocessing on every 5-min poll
- Implemented Notion pre-log (non-blocking) before every GitHub mutation per SOUL.md requirement
- Created `state/.gitkeep` so the runtime state directory is tracked in git

## Task Commits

Each task was committed atomically:

1. **Task 1: Create state directory placeholder and devbot-issue-monitor.sh** - `bbf4df2` (feat)

**Plan metadata:** (pending docs commit)

## Files Created/Modified

- `.openclaw/agents/devbot/scripts/devbot-issue-monitor.sh` — Main polling + claim + branch + PR + auto-merge loop (185 lines, chmod +x)
- `.openclaw/agents/devbot/state/.gitkeep` — Ensures state/ directory exists in git

## Decisions Made

- Notion pre-log failure is non-blocking: warning logged to stderr, pickup continues. Notion outage must not halt autonomous issue intake.
- `pickup-queue.txt` queue file chosen over direct `openclaw sessions spawn` because the monitor runs outside OpenClaw session context (invoked by launchd cron shell). DevBot AGENTS.md startup check (Plan 04) reads the queue at next session start.
- PR creation is best-effort at monitor time: `gh issue develop --checkout` creates the branch but adds no commits, so `gh pr create` will often fail on first poll. The script handles this gracefully; `devbot-execute-cycle.sh` opens the full PR after code work.
- GH_TOKEN fail-fast: if Keychain lookup returns empty the script exits immediately with `json_err`. Silent empty token would produce confusing 401s.

## Deviations from Plan

None — plan executed exactly as written.

## Issues Encountered

None.

## User Setup Required

None — no external service configuration required. GH_TOKEN and Notion token are expected in Keychain as pre-existing prerequisites from Phase 10 and Phase 15.

## Next Phase Readiness

- `devbot-issue-monitor.sh` is ready to be wired into launchd cron (Plan 04, 5-min interval)
- `state/.gitkeep` is committed; state/ directory will exist after git clone + stow
- Plan 03 (stale-claim guard) can proceed independently — D-205 is explicitly scoped out of this script
- Plan 04 (cron wiring) depends on this script path: `.openclaw/agents/devbot/scripts/devbot-issue-monitor.sh`

## Threat Flags

No new threat surface beyond the plan's `<threat_model>`. All STRIDE items from the plan are mitigated in the implementation:
- T-19-03: GH_TOKEN from Keychain only (openclaw.github-bot-token), never in files
- T-19-04: automation:hold checked in jq filter before claim
- T-19-05: --limit 20 cap on gh issue list
- T-19-06: Notion pre-log before every claim action (PAGE_ID logged to stderr)

---
*Phase: 19-devbot-autonomous-issue-pickup-devbot-polls-for-automation-s*
*Completed: 2026-05-22*

---
phase: 19-devbot-autonomous-issue-pickup-devbot-polls-for-automation-s
plan: 03
subsystem: infra
tags: [gh-cli, devbot, cron, issue-management, automation]

# Dependency graph
requires:
  - phase: 19-devbot-autonomous-issue-pickup-devbot-polls-for-automation-s
    provides: devbot-issue-monitor.sh and devbot-setup-labels.sh (plans 01 and 02)
provides:
  - devbot-stale-claim-guard.sh — hourly cron script that detects and unassigns stale in-progress issues (D-205)
affects:
  - plan 19-04 (cron wiring — this script needs to be registered as hourly launchd job)

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Temp file pattern for accumulating counters across pipeline subshells in zsh"
    - "macOS BSD date -v-NH flag for computing ISO 8601 cutoff timestamps"
    - "gh issue develop --list for linked branch discovery"
    - "gh api repos/OWNER/REPO/branches/BRANCH for last commit timestamp"

key-files:
  created:
    - .openclaw/agents/devbot/scripts/devbot-stale-claim-guard.sh
  modified: []

key-decisions:
  - "2h staleness threshold: issues with status:in-progress and no branch commit in >2h are stale"
  - "Branch absence counts as stale: if no linked branch found, issue is treated as stale (claimed but never executed)"
  - "automation:hold is NOT removed by guard: it is a user-managed kill switch (D-206)"
  - "Temp file pattern used for UNCLAIMED counter to survive zsh pipeline subshell"
  - "unclaim comment text: 'echosysbot: timed out, unclaiming (no branch activity in Xh)' per D-205"

patterns-established:
  - "Stale guard pattern: gh issue list --label status:in-progress → branch check → gh api commit date → ISO 8601 string compare"

requirements-completed:
  - DEV-10

# Metrics
duration: 8min
completed: 2026-05-22
---

# Phase 19 Plan 03: DevBot Stale Claim Guard Summary

**Hourly stale-claim guard that detects issues stuck in status:in-progress with no branch activity in >2h, unassigns echosysbot, and comments "echosysbot: timed out, unclaiming" per D-205**

## Performance

- **Duration:** 8 min
- **Started:** 2026-05-22T09:00:00Z
- **Completed:** 2026-05-22T09:08:00Z
- **Tasks:** 1
- **Files modified:** 1

## Accomplishments

- Created devbot-stale-claim-guard.sh — the self-healing queue guard that prevents permanently stuck issues
- Implements D-205: hourly stale detection via linked branch + last commit timestamp check
- Respects D-206: does not remove automation:hold (user-managed kill switch is preserved)
- Uses zsh-safe temp file pattern for accumulating unclaimed counter across pipeline subshell
- Script is idempotent — running on a clean repo (no in-progress issues) outputs `{"ok":true,"data":{"stale_unclaimed":0}}`

## Task Commits

Each task was committed atomically:

1. **Task 1: Create devbot-stale-claim-guard.sh** - `8276235` (feat)

**Plan metadata:** (docs commit follows)

## Files Created/Modified

- `.openclaw/agents/devbot/scripts/devbot-stale-claim-guard.sh` — Hourly cron script (D-205) that lists open status:in-progress issues, checks linked branch last commit time via gh API, and unassigns/uncomments stale ones

## Decisions Made

- 2h staleness threshold chosen (Claude's Discretion from CONTEXT.md) — reasonable window for an automated execution cycle
- Branch absence treated as stale: if `gh issue develop --list` returns empty, the issue was claimed but no branch was ever created, so it's stale by definition
- automation:hold label explicitly NOT removed — preserving D-206 user kill switch

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None

## User Setup Required

None - no external service configuration required. Script will be wired to hourly launchd cron in Plan 04.

## Next Phase Readiness

- devbot-stale-claim-guard.sh is ready to be wired as hourly cron in Plan 04 (openclaw.json cron entry)
- Plan 04 will register both devbot-issue-monitor.sh (5-min) and devbot-stale-claim-guard.sh (60-min) as launchd jobs

## Self-Check: PASSED

- [x] `.openclaw/agents/devbot/scripts/devbot-stale-claim-guard.sh` exists and is executable
- [x] Commit `8276235` exists in git log
- [x] `zsh -n` syntax check passes
- [x] All required patterns present (status:in-progress, remove-assignee, timed out unclaiming, STALE_HOURS)

---
*Phase: 19-devbot-autonomous-issue-pickup-devbot-polls-for-automation-s*
*Completed: 2026-05-22*

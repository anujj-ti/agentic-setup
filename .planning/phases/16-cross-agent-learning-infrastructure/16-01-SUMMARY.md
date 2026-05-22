---
phase: 16-cross-agent-learning-infrastructure
plan: "01"
subsystem: infra
tags: [synapse, zsh, shell-script, cross-agent-learning, openclaw]

# Dependency graph
requires:
  - phase: 13-synapse-integration
    provides: "synapse-record-learning.sh pattern and Synapse API integration"
provides:
  - "scripts/synapse-query-learnings.sh — shared Synapse learning query script for all execution-tier agents"
  - "Non-blocking entry point for cross-silo learning retrieval at agent session start"
affects:
  - 16-02-agent-wiring
  - 16-03-ci-monitor-agents-md
  - 16-04-dream-routine-updates

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "exit-0-always pattern for non-blocking Synapse integration (D-304)"
    - "python3 safe JSON quoting for API payloads (matches synapse-record-learning.sh)"
    - "stdout = formatted bullets, stderr = human logs convention"

key-files:
  created:
    - scripts/synapse-query-learnings.sh
  modified: []

key-decisions:
  - "Script exits 0 on all failure paths (token missing, curl failure, non-ok response) per D-304 — never blocks agent startup"
  - "Default limit of 5 learnings per D-305 — balances context utility with token budget"
  - "Outputs formatted bullet list (not JSON) per D-303 — agents inject as plain context, no parsing needed"
  - "python3 used for both JSON body construction and response parsing — safe quoting, no jq dependency"

patterns-established:
  - "Synapse query pattern: same set-euo-pipefail + stderr-logs + exit-0-always as synapse-record-learning.sh"
  - "API payload uses applies_to as JSON array with single tag string per D-301"

requirements-completed:
  - LEARN-01
  - LEARN-02

# Metrics
duration: 1min
completed: "2026-05-22"
---

# Phase 16 Plan 01: Cross-Agent Learning Infrastructure Summary

**Shared `synapse-query-learnings.sh` script created — queries Synapse `learning.query` API by domain tag and outputs formatted bullets for agent context injection, with non-blocking exit-0-always design**

## Performance

- **Duration:** 1 min
- **Started:** 2026-05-22T11:45:12Z
- **Completed:** 2026-05-22T11:46:13Z
- **Tasks:** 1
- **Files modified:** 1

## Accomplishments
- Created `scripts/synapse-query-learnings.sh` following exact pattern of `synapse-record-learning.sh`
- Script takes `<project_id> <applies_to_tag> [limit]` args with limit defaulting to 5
- Verified non-blocking: exits 0 on token missing, curl failure, and non-ok Synapse response
- Verified usage guard: exits 1 on too-few args (developer error, not runtime error)
- Live test against Synapse API confirmed graceful fallback when no learnings returned

## Task Commits

Each task was committed atomically:

1. **Task 1: Create synapse-query-learnings.sh** - `d239d02` (feat)

**Plan metadata:** (docs commit below)

## Files Created/Modified
- `scripts/synapse-query-learnings.sh` - Shared Synapse learning query script; queries `synapse.learning.query` endpoint and outputs `# Synapse Learnings: <tag>` formatted bullet list to stdout

## Decisions Made
- Outputs formatted bullets to stdout (not JSON) per D-303 — agents read as plain context, no parsing
- python3 used for response parsing alongside body construction — avoids jq dependency, consistent with existing pattern
- `(unavailable)` output on non-ok Synapse response — agents see a section header with graceful fallback, never a blank line that could cause confusion

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
None. Script worked on first attempt. Live Synapse test returned `(unavailable)` as expected (no learnings recorded for `openclaw` tag yet in `project.agentic-setup`) and exited 0.

## User Setup Required
None - no external service configuration required. SYNAPSE_TOKEN already configured in Keychain from Phase 13.

## Next Phase Readiness
- `synapse-query-learnings.sh` is ready to be wired into all four execution-tier agents (plan 16-02)
- Script location: `scripts/synapse-query-learnings.sh`
- Usage: `SYNAPSE_TOKEN="..." zsh scripts/synapse-query-learnings.sh <project_id> <tag> [limit]`

---
*Phase: 16-cross-agent-learning-infrastructure*
*Completed: 2026-05-22*

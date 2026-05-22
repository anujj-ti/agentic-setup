---
phase: 16-cross-agent-learning-infrastructure
plan: "04"
subsystem: devbot
tags: [synapse, devbot, cross-agent-learning, dream-routine, openclaw, github]

# Dependency graph
requires:
  - phase: 16-01
    provides: "scripts/synapse-query-learnings.sh shared script"
provides:
  - "devbot AGENTS.md Step 0 — mandatory Synapse learning query with cross-silo CI Monitor tags (LEARN-02)"
  - "devbot DREAM-ROUTINE.md — nightly distillation at 23:15 IST with cross-silo MEMORY.md merge"
affects:
  - .openclaw/agents/devbot/AGENTS.md
  - .openclaw/agents/devbot/DREAM-ROUTINE.md

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Step 0 (pre-startup) Synapse query pattern — queries both own domain and cross-silo tags before session init"
    - "Dream routine cross-silo merge with 500-token cap (D-311)"
    - "Staggered cron timing: task-orchestrator 23:05, ci-monitor 23:10, devbot 23:15"

key-files:
  created:
    - .openclaw/agents/devbot/DREAM-ROUTINE.md
  modified:
    - .openclaw/agents/devbot/AGENTS.md

key-decisions:
  - "Step 0 inserted before Session Startup (not numbered step 1) — makes Synapse query the absolute first action"
  - "Cross-silo query uses ci-monitor tag (limit 3) alongside github tag (limit 5) per D-307/LEARN-02"
  - "DREAM-ROUTINE.md triggers at 23:15 IST — staggered to avoid concurrent LLM load with task-orchestrator and ci-monitor"
  - "500-token cap on Synapse cross-silo section per D-311 — stays within 2,500-token daily distillation budget"
  - "Delivery silent (no Telegram) — DevBot uses sessions_spawn only, has no channel binding"

requirements-completed:
  - LEARN-01
  - LEARN-02
  - LEARN-04

# Metrics
duration: 4min
completed: "2026-05-22"
---

# Phase 16 Plan 04: DevBot Synapse Wiring and Dream Routine Summary

**DevBot AGENTS.md updated with mandatory Step 0 cross-silo Synapse query (github + ci-monitor tags); new DREAM-ROUTINE.md created with nightly distillation at 23:15 IST, 500-token Synapse cross-silo merge, and silent delivery**

## Performance

- **Duration:** 4 min
- **Started:** 2026-05-22T11:48:37Z
- **Completed:** 2026-05-22T11:52:37Z
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments

- Updated `.openclaw/agents/devbot/AGENTS.md` with a new "Step 0 — Query Synapse Learnings (MANDATORY)" section inserted before "## Session Startup"
- Step 0 queries `github` tag (limit 5) for own-domain learnings and `ci-monitor` tag (limit 3) for cross-silo CI failure patterns (LEARN-02 / D-307)
- Cross-silo purpose is clearly explained in AGENTS.md: CI Monitor failure pattern learnings inform PR triage decisions
- Non-blocking design confirmed: proceeds if Synapse is unavailable (D-304)
- Created `.openclaw/agents/devbot/DREAM-ROUTINE.md` from scratch (file did not exist)
- Dream routine triggers at 23:15 Asia/Kolkata — staggered after task-orchestrator (23:05) and ci-monitor (23:10)
- Queries both `github` and `ci-monitor` Synapse tags (limit 5 each) for cross-silo learnings
- Merges top Synapse content into `memory/MEMORY.md` under `## Cross-Silo Learnings` section with 500-token cap (D-311)
- Full 6-section distillation format: GitHub Activity, PR Patterns, Per-Repo Context Updates, Blockers, Cross-Silo Learnings

## Task Commits

Each task was committed atomically:

1. **Task 1: Update devbot AGENTS.md with Synapse learning query startup step** — `51ae8f5` (feat)
2. **Task 2: Create devbot DREAM-ROUTINE.md** — `6e92f43` (feat)

**Plan metadata:** (docs commit below)

## Files Created/Modified

- `.openclaw/agents/devbot/AGENTS.md` — New "Step 0 — Query Synapse Learnings (MANDATORY)" section added before "## Session Startup"; queries `github` (5) and `ci-monitor` (3) learnings; non-blocking; LEARN-02 cross-silo purpose documented
- `.openclaw/agents/devbot/DREAM-ROUTINE.md` — New file; nightly distillation at 23:15 IST; cross-silo Synapse query for github+ci-monitor tags; MEMORY.md merge with 500-token cap; silent delivery (no Telegram)

## Decisions Made

- Step 0 placed as a named section header ("## Step 0") rather than a numbered list item — makes it visually distinct and unambiguously the first action before the numbered Session Startup steps
- ci-monitor cross-silo limit set to 3 (vs 5 for own-domain) — CI failure patterns are advisory context, fewer bullets keep triage focused per D-307

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None. Both tasks completed on first attempt. All 6 plan verification checks passed.

## Threat Mitigations Applied

- T-16-08 (DoS — startup blocked by Synapse): mitigated via non-blocking design (`2>/dev/null` + proceed-if-empty comment)
- T-16-09 (Tampering — malicious learning influences PR merge): accepted per plan — Synapse claims are advisory only; DevBot still requires Notion pre-log gate before any merge action

## Known Stubs

None.

## Self-Check: PASSED

- `.openclaw/agents/devbot/AGENTS.md` — FOUND
- `.openclaw/agents/devbot/DREAM-ROUTINE.md` — FOUND
- Commit `51ae8f5` — FOUND
- Commit `6e92f43` — FOUND
- `synapse-query-learnings.sh` count in AGENTS.md — 2 (matches both github and ci-monitor queries)
- `23:15` timing in DREAM-ROUTINE.md — FOUND
- `500 token` cap in DREAM-ROUTINE.md — FOUND (7 matches)
- `LEARN-02` in AGENTS.md — FOUND

---
*Phase: 16-cross-agent-learning-infrastructure*
*Completed: 2026-05-22*

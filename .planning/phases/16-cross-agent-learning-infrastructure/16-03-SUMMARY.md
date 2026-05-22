---
phase: 16-cross-agent-learning-infrastructure
plan: "03"
subsystem: infra
tags: [synapse, openclaw, agent-orchestration, cross-silo-learning, dream-routine, memory]

# Dependency graph
requires:
  - phase: 16-cross-agent-learning-infrastructure
    plan: "01"
    provides: "scripts/synapse-query-learnings.sh — shared query script used in STEP 1 and DREAM-ROUTINE"
provides:
  - "task-orchestrator AGENTS.md STEP 1 queries agent-orchestration (5) and openclaw (3) domain learnings via synapse-query-learnings.sh"
  - "task-orchestrator DREAM-ROUTINE.md step 3.5 merges cross-silo Synapse learnings into MEMORY.md with 500-token cap"
  - "task-orchestrator TOOLS.md Learning Schema (LEARN-03) 4-field reminder table for manual learning records"
affects:
  - 16-04-devbot-dream-routine
  - 16-05-ci-monitor-agents-md

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "synapse-query-learnings.sh exec pattern for domain-specific context injection at AGENTS.md session start"
    - "D-311: 500-token cap on cross-silo learnings merge per dream cycle"
    - "T-16-06 mitigation: empty SYNAPSE_NEW check — skip merge step if Synapse unavailable"

key-files:
  created: []
  modified:
    - .openclaw/agents/task-orchestrator/AGENTS.md
    - .openclaw/agents/task-orchestrator/DREAM-ROUTINE.md
    - .openclaw/agents/task-orchestrator/TOOLS.md

key-decisions:
  - "STEP 1 uses two separate synapse-query-learnings.sh calls (agent-orchestration limit 5, openclaw limit 3) per D-307"
  - "project_id remains project.edullm-sat-math in task-orchestrator per pre-existing CONTEXT.md note — not changed"
  - "DREAM-ROUTINE step 3.5 placed between existing steps 3 and 4; does not alter numbering of steps 4 and 5"
  - "500-token cap on cross-silo content deduplicates prior section (replace, not append) to avoid unbounded growth"
  - "TOOLS.md schema reminder scoped to manual curl recordings only — synapse-record-learning.sh users already compliant per D-309"

patterns-established:
  - "Two-domain learning query at session start: primary domain (5 results) + cross-silo domain (3 results)"
  - "Dream routine non-blocking guard: check SYNAPSE_NEW empty before writing to MEMORY.md"

requirements-completed:
  - LEARN-01
  - LEARN-03
  - LEARN-04

# Metrics
duration: 5min
completed: "2026-05-22"
---

# Phase 16 Plan 03: Task-Orchestrator Learning Wiring Summary

**task-orchestrator wired for cross-agent learning: STEP 1 upgraded to use synapse-query-learnings.sh for agent-orchestration and openclaw domains, DREAM-ROUTINE.md gains a 500-token-capped cross-silo merge step, and TOOLS.md gains a 4-field learning schema reminder**

## Performance

- **Duration:** 5 min
- **Started:** 2026-05-22T11:44:00Z
- **Completed:** 2026-05-22T11:49:31Z
- **Tasks:** 2
- **Files modified:** 3

## Accomplishments

- Upgraded AGENTS.md STEP 1 from inline curl to `synapse-query-learnings.sh` with agent-orchestration (5) and openclaw (3) domain queries, producing `$SYNAPSE_CONTEXT_ORCH` and `$SYNAPSE_CONTEXT_OC` variables
- Added DREAM-ROUTINE.md step 3.5 to merge Synapse learnings into MEMORY.md with 500-token cap (D-311), non-blocking if Synapse unavailable (T-16-06 mitigation)
- Added TOOLS.md Learning Schema (LEARN-03) table listing all 4 required fields with evidence_artifact_id rules for medium/high confidence

## Task Commits

Each task was committed atomically:

1. **Task 1: Upgrade AGENTS.md STEP 1 to use synapse-query-learnings.sh** - `d24847c` (feat)
2. **Task 2: Add DREAM-ROUTINE.md step 3.5 and TOOLS.md schema reminder** - `2f45f83` (feat)

**Plan metadata:** (docs commit below)

## Files Created/Modified

- `.openclaw/agents/task-orchestrator/AGENTS.md` — STEP 1 replaced inline curl with two synapse-query-learnings.sh calls (agent-orchestration:5, openclaw:3); prose updated to reference combined variables
- `.openclaw/agents/task-orchestrator/DREAM-ROUTINE.md` — step 3.5 inserted between steps 3 and 4; merges up to 500 tokens of Synapse learnings into MEMORY.md; skips gracefully if SYNAPSE_NEW empty
- `.openclaw/agents/task-orchestrator/TOOLS.md` — Learning Schema (LEARN-03) subsection added under Synapse Quick Reference with 4-field table and medium/high confidence evidence rules

## Decisions Made

- Used two separate script calls (not one) for STEP 1 to maintain distinct `$SYNAPSE_CONTEXT_ORCH` and `$SYNAPSE_CONTEXT_OC` variables, giving the agent clear provenance for each learning source
- Retained `project.edullm-sat-math` project_id per CONTEXT.md note — task-orchestrator predates project.agentic-setup unification, intentional holdover
- DREAM-ROUTINE step 3.5 replaces (not appends) any prior Cross-Silo Learnings section to prevent unbounded growth across dream cycles

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None.

## User Setup Required

None — no external service configuration required. SYNAPSE_TOKEN already configured in Keychain from Phase 13.

## Next Phase Readiness

- task-orchestrator is fully wired for cross-agent learning (LEARN-01, LEARN-03, LEARN-04 complete)
- Ready for 16-04 (devbot dream-routine updates) and 16-05 (ci-monitor AGENTS.md creation)
- Pattern established in this plan (two-domain query, 500-token cap, non-blocking guard) is the template for other agents in the phase

## Known Stubs

None — all wiring references the real `synapse-query-learnings.sh` script created in plan 16-01. No placeholder text or TODO markers.

## Threat Flags

No new trust boundaries introduced. T-16-06 (Synapse unavailable during DREAM-ROUTINE merge) mitigated by empty-check guard per plan threat model.

---
*Phase: 16-cross-agent-learning-infrastructure*
*Completed: 2026-05-22*

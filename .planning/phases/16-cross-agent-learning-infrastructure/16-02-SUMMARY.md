---
phase: 16-cross-agent-learning-infrastructure
plan: "02"
subsystem: infra
tags: [synapse, ci-monitor, cross-silo-learning, dream-routine, openclaw]

# Dependency graph
requires:
  - phase: 16-cross-agent-learning-infrastructure
    provides: synapse-query-learnings.sh script (created in plan 16-01)
provides:
  - ci-monitor AGENTS.md updated with mandatory pre-polling Synapse query step (ci + github tags)
  - ci-monitor DREAM-ROUTINE.md created with nightly cross-silo learnings merge
affects:
  - cross-agent-learning-infrastructure
  - ci-monitor agent behavior
  - synapse-query-learnings integration

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Step 0 Synapse query pattern: mandatory non-blocking query before agent action begins"
    - "Cross-silo tag pattern: ci-monitor queries github tag (written by DevBot) for cross-domain insights"
    - "Dream routine Synapse merge: 500-token cap on new Synapse content per nightly cycle"

key-files:
  created:
    - .openclaw/agents/ci-monitor/DREAM-ROUTINE.md
  modified:
    - .openclaw/agents/ci-monitor/AGENTS.md

key-decisions:
  - "D-307: ci-monitor queries ci and github domain tags (cross-silo read of DevBot learnings)"
  - "D-304: Synapse unavailability is non-blocking — empty context proceeds CI polling normally"
  - "D-311: 500-token cap on new Synapse content per dream cycle; top 3 by recency if over cap"
  - "D-312: ci-monitor DREAM-ROUTINE.md minimal — distills CI failure patterns + merges Synapse learnings"

patterns-established:
  - "Cross-silo query: agents query tags from other agents' domains (ci-monitor queries github from DevBot)"
  - "Dream routine merge: nightly Synapse content merge into MEMORY.md with token budget cap"

requirements-completed: [LEARN-01, LEARN-04]

# Metrics
duration: 8min
completed: 2026-05-22
---

# Phase 16 Plan 02: CI Monitor Synapse Wiring Summary

**ci-monitor AGENTS.md updated with mandatory Step 0 Synapse query (ci + github cross-silo tags); DREAM-ROUTINE.md created with nightly failure pattern distillation and 500-token Synapse merge cap**

## Performance

- **Duration:** ~8 min
- **Started:** 2026-05-22T11:45:19Z
- **Completed:** 2026-05-22T11:53:00Z
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments

- Updated ci-monitor AGENTS.md: inserted Step 0 before Startup Sequence — mandatory Synapse learning query using `ci` and `github` tags via `synapse-query-learnings.sh`
- Implemented cross-silo pattern: ci-monitor reads `github`-tagged learnings written by DevBot, surfacing CI-relevant patterns from the GitHub domain
- Created ci-monitor DREAM-ROUTINE.md: nightly distillation at 23:10 IST, queries Synapse for ci + github learnings, merges up to 500 tokens of new content per cycle into `memory/MEMORY.md`
- All original AGENTS.md sections (Startup Sequence, Session Lifecycle, No Sub-Agents, No Channel Binding) preserved unchanged

## Task Commits

Each task was committed atomically:

1. **Task 1: Update ci-monitor AGENTS.md with Synapse query step** - `dfacbd9` (feat)
2. **Task 2: Create ci-monitor DREAM-ROUTINE.md** - `a7efc65` (feat)

**Plan metadata:** (docs commit — see below)

## Files Created/Modified

- `.openclaw/agents/ci-monitor/AGENTS.md` — Added Step 0 Synapse query section (ci + github tags, cross-silo explanation, non-blocking per D-304)
- `.openclaw/agents/ci-monitor/DREAM-ROUTINE.md` — New file: nightly dream routine with CI failure pattern distillation + Synapse learnings merge

## Decisions Made

- Applied D-307: ci-monitor domain tags are `openclaw`, `github`, `ci` — the `github` tag provides cross-silo access to DevBot's learnings
- Applied D-304: Synapse unavailability is non-blocking; both empty SYNAPSE_CI and SYNAPSE_GH variables proceed normally
- Applied D-311: 500-token cap on new Synapse content per dream cycle; if over cap, include only top 3 learnings by recency
- Applied D-312: minimal dream routine for ci-monitor — distill CI failure patterns + merge Synapse learnings; silent delivery (no channel binding)
- Trigger time set to 23:10 IST (5 minutes after task-orchestrator at 23:05) to avoid concurrent LLM load

## Deviations from Plan

None — plan executed exactly as written.

## Issues Encountered

None.

## User Setup Required

None — no external service configuration required. The Synapse query uses `synapse-query-learnings.sh` created in plan 16-01; no additional credentials or scripts needed.

## Next Phase Readiness

- ci-monitor now satisfies LEARN-01 (Synapse query at session start) and LEARN-04 (dream routine merges cross-silo learnings)
- Plan 16-03 can proceed to wire Synapse query into devbot AGENTS.md and email-triage
- Memory location for ci-monitor dream routine: `~/.openclaw/agents/ci-monitor/memory/MEMORY.md` (created on first dream cycle run)

---
*Phase: 16-cross-agent-learning-infrastructure*
*Completed: 2026-05-22*

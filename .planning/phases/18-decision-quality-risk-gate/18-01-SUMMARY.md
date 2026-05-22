---
phase: 18-decision-quality-risk-gate
plan: "01"
subsystem: agent-config
tags: [decision-reviewer, risk-scoring, soul-md, verdict-schema]

# Dependency graph
requires:
  - phase: 17-gogcli
    provides: completed agent fleet that feeds decisions to decision-reviewer
provides:
  - risk_score and risk_tier fields on every Decision Reviewer verdict
  - Four-dimension scoring rubric (reversibility, blast radius, external side effects, action recency)
  - Tier mapping (low/medium/high) with routing policy per tier
affects:
  - 18-02 (task-orchestrator SOUL.md — consumes risk_tier for Telegram gate routing)
  - 18-03 (task-orchestrator routing logic reads risk_tier field)

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "LLM self-scoring: risk_score computed inline during reasoning pass from decision payload fields"
    - "Two-field risk contract: risk_score (int 0-100) + risk_tier (low/medium/high) on all verdicts"

key-files:
  created: []
  modified:
    - .openclaw/agents/decision-reviewer/SOUL.md

key-decisions:
  - "D-501: risk_score and risk_tier computed by Decision Reviewer in its LLM reasoning pass — no separate script needed"
  - "D-502: Four dimensions with research-backed weight ordering: reversibility (40) > blast-radius (30) > side-effects (20) > recency (10)"
  - "D-503: Tier mapping 0-30=low (auto-proceed), 31-60=medium (silent), 61-100=high (Telegram approval required)"
  - "D-504: risk_score and risk_tier are required on all verdict types including pass; omission treated as malformed verdict"

patterns-established:
  - "Risk contract pattern: every agent verdict that gates autonomous actions must carry quantified risk fields"
  - "Anti-circular safety: pre-approved meta-invocation response always returns risk_score:0, risk_tier:low"

requirements-completed:
  - RISK-01

# Metrics
duration: 2min
completed: "2026-05-22"
---

# Phase 18 Plan 01: Decision Quality Risk Gate Summary

**Decision Reviewer SOUL.md extended with four-dimension risk scoring rubric (100pt scale) producing risk_score and risk_tier on every verdict type**

## Performance

- **Duration:** 2 min
- **Started:** 2026-05-22T12:34:33Z
- **Completed:** 2026-05-22T12:35:36Z
- **Tasks:** 1
- **Files modified:** 1

## Accomplishments

- Added Risk Scoring (RISK-01) section to decision-reviewer/SOUL.md with four weighted scoring dimensions totalling 100 pts
- Updated D-111 Output Format block to require `risk_score` (int 0-100) and `risk_tier` ("low"|"medium"|"high") on every verdict
- Updated anti-circular pre-approved response JSON to include `risk_score:0,"risk_tier":"low"`
- Documented tier-based routing policy: low=auto-proceed, medium=silent, high=synchronous Telegram approval

## Task Commits

Each task was committed atomically:

1. **Task 1: Add Risk Scoring section to decision-reviewer SOUL.md** - `6117be0` (feat)

## Files Created/Modified

- `.openclaw/agents/decision-reviewer/SOUL.md` - Added Risk Scoring section, updated D-111 schema with risk_score/risk_tier fields, patched anti-circular response

## Decisions Made

- Followed plan decisions D-501 through D-504 as specified in 18-CONTEXT.md
- Medium tier is silent (no blocking gate); async Telegram notification deferred to v2.1 per plan
- Weight ordering: reversibility (40) > blast radius (30) > external side effects (20) > action recency (10) — research-backed hierarchy reflecting severity of impact

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None

## User Setup Required

None - no external service configuration required. SOUL.md is an agent config file read at runtime by Decision Reviewer.

## Next Phase Readiness

- decision-reviewer/SOUL.md verdict schema now carries risk_score and risk_tier on all verdicts
- Plan 18-02 (task-orchestrator fast-pass list) and 18-03 (Telegram approval gate routing) can consume risk_tier from the updated schema
- Plan 18-04 (end-to-end verification) can now test that verdicts include the new fields

---
*Phase: 18-decision-quality-risk-gate*
*Completed: 2026-05-22*

---
phase: 18-decision-quality-risk-gate
plan: "03"
subsystem: agent-directives
tags: [task-orchestrator, risk-gate, telegram-approval, soul-md, high-tier, RISK-02]

# Dependency graph
requires:
  - phase: 18-decision-quality-risk-gate
    provides: risk_tier field on Decision Reviewer verdicts (Plan 18-01)
  - phase: 18-decision-quality-risk-gate
    provides: Fast-Pass List and Failed Verdict Policy in task-orchestrator SOUL.md (Plan 18-02)
provides:
  - Risk-Tiered Routing (RISK-02) block wired into Decision Review Gate
  - HIGH-tier Telegram approval gate with 30-min timeout before Notion pre-log
  - D-507 message format (action, risk_score, rationale, reversibility, APPROVE/REJECT prompt)
  - Absent risk_tier defaults to high (fail-safe)
affects: [task-orchestrator, decision-reviewer, 18-decision-quality-risk-gate]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Risk-tiered routing: LOW/MEDIUM → Notion Pre-Log directly; HIGH → Telegram sessions_yield approval gate"
    - "Absent-field fail-safe: missing risk_tier defaults to high rather than silently bypassing the gate"
    - "Timeout fallthrough: 30-min Telegram wait resolves via Failed Verdict Policy (non-blocking proceed)"

key-files:
  created: []
  modified:
    - .openclaw/agents/task-orchestrator/SOUL.md

key-decisions:
  - "D-505: HIGH-tier verdicts send Telegram approval request to chat ID 1294664427 via User Orchestrator sessions_yield before Notion write"
  - "D-506: 30-minute timeout — no response falls through to Failed Verdict Policy (non-blocking proceed)"
  - "D-507: Telegram message format includes action, risk_score/100, rationale, reversibility, and APPROVE/REJECT instruction"
  - "REJECT branch aborts action and writes a Notion rejection log entry — not a silent discard"
  - "Absent risk_tier treated as high (T-18-07 mitigation) — conservative fail-safe prevents accidental gate bypass"

patterns-established:
  - "Three-branch approval response: APPROVE → proceed; REJECT → abort+log; timeout → fallback policy"
  - "Routing table pattern: tier/verdict matrix makes all routing branches explicit and auditable in agent directives"

requirements-completed:
  - RISK-02

# Metrics
duration: 3min
completed: "2026-05-22"
---

# Phase 18 Plan 03: Decision Quality Risk Gate — HIGH-tier Telegram Approval Gate Summary

**Risk-tiered routing table wired into task-orchestrator SOUL.md: HIGH verdicts trigger synchronous Telegram approval (chat 1294664427, D-507 format, 30-min timeout) before Notion pre-log; LOW/MEDIUM proceed directly**

## Performance

- **Duration:** ~3 min
- **Started:** 2026-05-22T12:40:00Z
- **Completed:** 2026-05-22T12:43:00Z
- **Tasks:** 1
- **Files modified:** 1

## Accomplishments

- Replaced the single "After verdict: if pass → write to Notion → execute action" bullet in the Decision Review Gate with the full Risk-Tiered Routing (RISK-02) block (45-line addition)
- Four-row tier/verdict routing table documents all paths: LOW/MEDIUM proceed directly, HIGH stops for Telegram approval, any reject does NOT send Telegram (abort + BLOCKED report only)
- Step 2 jq extraction block handles absent `risk_tier` gracefully by defaulting to `"high"` (mitigates T-18-07)
- D-507 Telegram message format included verbatim with all required fields: action, risk_score/100, rationale, reversibility, and APPROVE/REJECT instruction to chat ID 1294664427
- Three response branches fully specified: APPROVE → Notion Pre-Log Protocol + execute; REJECT → abort + Notion rejection log; timeout (30 min) → Failed Verdict Policy fallback (non-blocking proceed)
- All previously existing SOUL.md content preserved unchanged

## Task Commits

Each task was committed atomically:

1. **Task 1: Replace After-verdict bullet with risk-tiered routing table in SOUL.md** - `88f5658` (feat)

## Files Created/Modified

- `.openclaw/agents/task-orchestrator/SOUL.md` — Replaced 1 bullet with 45-line Risk-Tiered Routing (RISK-02) block: Step 2 verdict extraction, Step 3 four-row routing table, Step 4 HIGH-tier Telegram approval with D-507 format and three response branches

## Decisions Made

- Preserved the `- **When**`, `- **How**`, and `- **Exception**` bullets above the new routing block unchanged — these remain the "what triggers Decision Review" description; the Risk-Tiered Routing block directly follows as "what happens after verdict returns"
- REJECT branch explicitly writes a Notion rejection log entry (not a silent discard) — provides audit trail for every user veto
- Absent `risk_tier` defaults to `"high"` via jq `// "high"` fallback — fail-safe rather than fail-open; aligns with T-18-07 threat mitigation

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None

## Threat Surface Scan

No new network endpoints, auth paths, file access patterns, or schema changes introduced. The Telegram sessions_yield call was already part of the threat model (T-18-05: single-user setup, only Anuj has chat access). The 30-min timeout path falls through to the existing Failed Verdict Policy (T-18-06 mitigation). The absent-risk_tier default-to-high is the T-18-07 mitigation as specified in the plan threat register.

## User Setup Required

None — no external service configuration required. SOUL.md is an agent directive file read at runtime by Task Orchestrator. The Telegram chat ID 1294664427 is already used by the existing User Orchestrator channel configuration.

## Next Phase Readiness

- Task Orchestrator SOUL.md now contains the complete RISK-02 implementation: risk-tiered routing with HIGH-tier Telegram approval gate, D-507 message format, three response branches, and fail-safe absent-tier handling
- Phase 18 Plan 04 (end-to-end verification) can now test the full pipeline: decision-reviewer risk_tier output → task-orchestrator routing → Telegram approval request

---
*Phase: 18-decision-quality-risk-gate*
*Completed: 2026-05-22*

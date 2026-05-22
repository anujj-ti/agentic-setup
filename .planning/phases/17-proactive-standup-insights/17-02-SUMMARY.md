---
phase: 17-proactive-standup-insights
plan: "02"
subsystem: user-orchestrator
tags: [soul-md, tools-md, standup, insights, telegram, formatting]

# Dependency graph
requires:
  - phase: 17-01
    provides: scripts/standup-insights.sh — classification engine
provides:
  - .openclaw/agents/user-orchestrator/SOUL.md — standup insights formatting rules
  - .openclaw/agents/user-orchestrator/TOOLS.md — standup-insights.sh invocation pattern
affects:
  - 17-03 (integration — pipes standup-brief.sh through standup-insights.sh end-to-end)

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "pipe-stdin pattern: STANDUP_JSON | standup-insights.sh → INSIGHTS_JSON in cron session exec"
    - "label-only Telegram format: item cites source_field verbatim, no LLM interpretation"
    - "graceful fallback: ok:false → standard standup brief (insights failure never blocks standup)"

key-files:
  created: []
  modified:
    - .openclaw/agents/user-orchestrator/SOUL.md
    - .openclaw/agents/user-orchestrator/TOOLS.md

key-decisions:
  - "D-411 implemented: Tackle First (numbered) → Patterns (bold header) → standard facts — matches plan ordering decision"
  - "D-413 implemented: source_field cited verbatim in each tackle-first item — no free-form interpretation appended"
  - "Fallback rule added to SOUL.md: ok:false from standup-insights.sh → revert to pre-Phase-17 standup format without blocking"

patterns-established:
  - "CRON SESSIONS ONLY policy extended to standup-insights.sh — same exec policy as standup-brief.sh"

requirements-completed:
  - STANDUP-01
  - STANDUP-02
  - STANDUP-03

# Metrics
duration: 2min
completed: 2026-05-22
---

# Phase 17 Plan 02: User Orchestrator SOUL.md + TOOLS.md Insights Wiring Summary

**User Orchestrator wired to pipe standup JSON into standup-insights.sh and format Telegram with numbered Tackle First list, bold Patterns section, and graceful fallback**

## Performance

- **Duration:** 2 min
- **Started:** 2026-05-22T12:16:39Z
- **Completed:** 2026-05-22T12:19:00Z
- **Tasks:** 2 (both auto)
- **Files modified:** 2 (.openclaw/agents/user-orchestrator/SOUL.md, .openclaw/agents/user-orchestrator/TOOLS.md)

## Accomplishments

- SOUL.md: new section "Morning Standup Insights (STANDUP-01/02/03)" appended after the existing standup integration note
  - Invocation sequence: capture standup-brief.sh output → pipe into standup-insights.sh
  - Telegram message structure: Header → Tackle First (numbered, with "Nothing critical" fallback for empty) → Patterns (bold `*Patterns Detected:*` header, only when non-empty) → standard facts
  - Label-only rule (D-413): source_field cited verbatim per item, no free-form interpretation
  - Fallback rule: ok:false or script unavailable → standard pre-Phase-17 standup, no blocking
- TOOLS.md: new subsection "Insights Enhancement (Phase 17)" appended to Standup Script Invocation section
  - Pipe invocation with absolute paths for both scripts
  - jq field map for tackle_first (.title, .status, .source_field, .reason)
  - jq field map for patterns (.type, .count, .label)
  - Graceful fallback noted inline (jq '.ok' == false → use STANDUP_JSON only)
  - CRON SESSIONS ONLY policy confirmed for standup-insights.sh

## Task Commits

1. **Task 1: SOUL.md Morning Standup Insights section** — `c414073` (feat)
2. **Task 2: TOOLS.md Insights Enhancement subsection** — `acf4802` (feat)

## Files Created/Modified

- `/Users/trilogy/Documents/agentic-setup/.openclaw/agents/user-orchestrator/SOUL.md` — added 45 lines: Morning Standup Insights section with invocation sequence, Telegram structure, label-only rule, fallback behavior
- `/Users/trilogy/Documents/agentic-setup/.openclaw/agents/user-orchestrator/TOOLS.md` — added 30 lines: Insights Enhancement subsection with pipe invocation, jq field maps, cron-only policy

## Decisions Made

- **Numbered list for Tackle First**: plan granted Claude discretion on numbered vs. bullets; numbered list chosen for priority clarity (user sees rank 1 = highest urgency at a glance)
- **Bold Patterns header**: plan granted Claude discretion on bold vs. plain; `*Patterns Detected:*` chosen to visually separate pattern alerts from the item list above
- **"Nothing critical — clear runway."** placeholder chosen for empty tackle_first per D-407 spirit: always present, communicates healthy state without silent omission

## Deviations from Plan

None — plan executed exactly as written. Both tasks appended new content without modifying any existing SOUL.md or TOOLS.md sections. All 7 verification checks passed.

## Known Stubs

None — this plan wires format rules and invocation patterns into agent config files. The actual execution pipeline is completed end-to-end in Plan 17-03.

## Threat Surface Scan

No new network endpoints, auth paths, file access patterns, or schema changes introduced. Both files are agent config (SOUL.md, TOOLS.md) — plain text, no execution surface. Threat mitigations T-17-04 (append-only, original sections preserved) and T-17-05 (fallback behavior documented) confirmed applied.

## Self-Check: PASSED

- `.openclaw/agents/user-orchestrator/SOUL.md` — FOUND (45 lines added, grep -c "standup-insights.sh" = 3)
- `.openclaw/agents/user-orchestrator/TOOLS.md` — FOUND (30 lines added, grep -c "standup-insights.sh" = 5)
- Commit c414073 — FOUND in git log
- Commit acf4802 — FOUND in git log
- All 7 plan verification checks passed (counts >= 1 for all required strings)
- Pre-existing sections preserved: Delegation Rules (SOUL.md), Available Tools (TOOLS.md), Tool Policy, Environment, GitHub Identity Note, original Standup Script Invocation block

---
*Phase: 17-proactive-standup-insights*
*Completed: 2026-05-22*

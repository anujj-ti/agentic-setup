---
phase: "05"
plan: "01"
subsystem: user-orchestrator
tags: [dream-routines, memory, agents-config]
dependency_graph:
  requires: []
  provides: [user-orchestrator-dream-files]
  affects: [user-orchestrator AGENTS.md session startup]
tech_stack:
  added: []
  patterns: [SKILL.md dream setup template, DREAM-ROUTINE.md token budget hard constraint]
key_files:
  created:
    - .openclaw/agents/user-orchestrator/DREAM-ROUTINE.md
    - .openclaw/agents/user-orchestrator/MEMORY.md
  modified:
    - .openclaw/agents/user-orchestrator/AGENTS.md
decisions:
  - D-43: User Orchestrator delivery is announce/channel:last (Telegram notification on dream completion)
  - D-45: MEMORY.md stub created — was absent from both repo and live dirs
  - D-46: AGENTS.md updated with live memory load sequence replacing Phase 5 placeholder
metrics:
  duration: "~5 minutes"
  completed: "2026-05-21"
  tasks_completed: 2
  tasks_total: 2
  files_created: 2
  files_modified: 1
---

# Phase 5 Plan 01: User Orchestrator Dream Routine Files Summary

**One-liner:** Nightly memory distillation wiring for User Orchestrator — DREAM-ROUTINE.md with 23:00 IST trigger and 2,500/7,500 token budget hard constraints, MEMORY.md stub, and updated AGENTS.md session startup sequence.

## What Was Built

Created three files that activate nightly memory distillation for the User Orchestrator:

1. **DREAM-ROUTINE.md** — Nightly instruction set triggered at 23:00 Asia/Kolkata. Contains all six distillation format sections (Decisions, Project Updates, New Context, Completed, Blockers, Tomorrow), hard token budget constraint ("NEVER generate a distillation longer than 2,500 tokens. If you find yourself about to exceed this limit, truncate and stop."), 7,500-token rolling digest cap, and "skip gracefully" rule if no daily log exists.

2. **MEMORY.md** — Committed stub with Active Projects / Key Contacts / Standing Rules sections. The dream routine populates this on each nightly run.

3. **AGENTS.md** — Rewrote the Session Startup section from 3 steps to 6 steps. Steps 3-5 are the new memory load sequence: Read MEMORY.md (curated long-term context), Read memory/MEMORY-DIGEST.md (rolling 3-day digest if exists), Do NOT load raw daily logs. Removed the "once available in Phase 5" placeholder entirely.

## Decisions Made

- Token budget is enforced as a hard constraint (truncate instruction), not just an advisory — stronger than SKILL.md default per RESEARCH.md Pitfall 4.
- Delivery mode is announce/channel:last — User Orchestrator sends Telegram notification when dream run completes (D-43).
- MEMORY-DIGEST.md is referenced in AGENTS.md as `memory/MEMORY-DIGEST.md` (relative path within agent workspace).

## Deviations from Plan

None — plan executed exactly as written.

## Verification Results

```
PASS: DREAM-ROUTINE.md has 2x "2,500 token", 2x "7,500", 1x "skip gracefully", 1x "Asia/Kolkata"
PASS: MEMORY.md exists with Active Projects section
PASS: AGENTS.md has MEMORY-DIGEST.md reference
PASS: No "once available in Phase 5" placeholder remaining
```

## Commit

- `e4379a4`: feat(05-01): add dream routine files for User Orchestrator

## Known Stubs

- MEMORY.md is intentionally a stub — will be populated by the dream routine after first run at 23:00 IST.
- MEMORY-DIGEST.md does not exist yet — it is created by the dream routine on first run. AGENTS.md references it with "if exists" guard.

## Self-Check: PASSED

- `.openclaw/agents/user-orchestrator/DREAM-ROUTINE.md` — FOUND
- `.openclaw/agents/user-orchestrator/MEMORY.md` — FOUND
- `.openclaw/agents/user-orchestrator/AGENTS.md` — FOUND (modified)
- Commit `e4379a4` — FOUND

---
phase: 04-beads-task-orchestrator
plan: "03"
subsystem: agent-config
tags: [SOUL.md, TOOLS.md, task-orchestrator, beads-contract, sessions_spawn]
dependency_graph:
  requires: [04-02]
  provides: [beads-enforced-SOUL, bd-TOOLS-reference]
  affects: [04-04]
tech_stack:
  added: []
  patterns: [epic-before-spawn, decomposition-templates, dependency-ordering, bd-claim-close]
key_files:
  created: []
  modified:
    - .openclaw/agents/task-orchestrator/SOUL.md
    - .openclaw/agents/task-orchestrator/TOOLS.md
decisions:
  - "D-56 applied: full SOUL.md replacement — Phase 3 stub entirely removed, not patched"
  - "D-57 applied: TOOLS.md updated in same plan as SOUL.md (rules + command syntax together)"
  - "Model policy anthropic/claude-sonnet-4-6 preserved in new SOUL.md"
metrics:
  duration: "~10 minutes"
  completed: "2026-05-21"
  tasks_completed: 2
  files_created: 0
  files_modified: 2
---

# Phase 4 Plan 03: Replace Task Orchestrator SOUL.md + Update TOOLS.md — Summary

**One-liner:** Task Orchestrator SOUL.md fully replaced with Beads-Enforced Execution Contract; TOOLS.md updated with bd command reference and Phase 3 exclusions removed.

## What Was Built

### Task 1: Replace SOUL.md with Beads execution contract

Written in full — no partial patching. The new SOUL.md contains:

1. **Identity** — decompose-first framing (not Phase 3 "execute them using available tools")
2. **Beads-Enforced Execution Contract (MANDATORY — NO EXCEPTIONS)** — 4-step pre-spawn sequence: create epic → create subtasks with --deps → verify dep tree → assert only T1 in `bd ready --json` → THEN sessions_spawn
3. **Decomposition Templates** — feature (5 subtasks) and bug fix (4 subtasks)
4. **Progress Monitoring** — `bd list --status in_progress`, `bd ready --json`, `bd dep tree` (no agent polling)
5. **Responsibilities** — decompose-before-spawn; monitor via graph queries
6. **Operational Rules** — strict mode, Notion logging deferred to Phase 9
7. **Boundaries** — BEADS_DIR = `$HOME/.openclaw/beads`; explicit bd path
8. **Tone** — factual evidence strings, no narrative
9. **Model Policy** — anthropic/claude-sonnet-4-6 preserved

Removed:
- "Phase 3 Scope (Beads not yet installed)" section
- "do NOT attempt bd or beads commands"
- "Do not spawn sub-agents in Phase 3"
- "Do not attempt Beads commands (bd, beads) — they are not installed until Phase 4"

### Task 2: Update TOOLS.md with Beads command reference

New sections added to TOOLS.md:
- sessions_spawn and bd added to **Available Tools** (were excluded in Phase 3)
- bd added to **Tool Policy** with explicit path and nvm-shadowing note
- **Beads Task Tracker (Phase 4+)** section: configuration, orchestrator commands (create epic + subtasks, monitor progress), sub-agent commands (ready, claim, close)
- **Rules** subsection: bd ready over bd list, non-vague close reasons, BLOCKED protocol

Removed:
- "NOT Available in Phase 3" section listing sessions_spawn and bd as excluded

## Deviations from Plan

None — plan executed exactly as written. Both files fully replaced without requiring deviation rules.

## Smoke Test Results

All 6 checks pass after Plan 04-03:

```
[PASS] dolt-installed
[PASS] bd-version
[PASS] beads-dir-initialized
[PASS] beads-dir-in-secrets-sh
[PASS] bd-ready-works
[PASS] soul-has-beads-rule
Results: 6 passed, 0 failed, 0 warnings (of 6 total checks)
{"ok":true,"data":{"checks_passed":6,"checks_total":6}}
```

Check 6 (soul-has-beads-rule) confirms: SOUL.md contains both "sessions_spawn" in the Beads contract context and "Beads" in the mandatory section heading.

## Known Stubs

None. SOUL.md is the authoritative agent behavior spec; no placeholder language remains.

## Threat Surface Scan

No new network endpoints or trust boundaries introduced. SOUL.md rules constrain agent behavior (reduce surface) rather than expand it. Key threat mitigations active:
- T-04-06: MANDATORY NO EXCEPTIONS language + 4-step pre-spawn check prevents epic-skip
- T-04-07: TOOLS.md Rules explicitly prohibit `bd list --status open`
- T-04-08: SOUL.md Tone + TOOLS.md Rules mandate specific evidence strings

## Self-Check

- [x] SOUL.md contains "Beads-Enforced Execution Contract" section
- [x] SOUL.md contains "sessions_spawn" in pre-spawn contract context
- [x] SOUL.md contains `/opt/homebrew/opt/node@24/bin/bd` explicit path
- [x] SOUL.md contains BEADS_DIR `$HOME/.openclaw/beads`
- [x] SOUL.md does NOT contain "Phase 3 Scope" or "do NOT attempt bd"
- [x] SOUL.md preserves "anthropic/claude-sonnet-4-6" model policy
- [x] TOOLS.md contains "Beads Task Tracker" section with bd commands
- [x] TOOLS.md lists sessions_spawn as available
- [x] TOOLS.md does NOT contain "NOT Available in Phase 3"
- [x] All 6 verify-phase-04.sh checks pass
- [x] Commit 149a5a2 exists

## Self-Check: PASSED

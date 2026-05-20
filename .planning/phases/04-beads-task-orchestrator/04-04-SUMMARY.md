---
phase: 04-beads-task-orchestrator
plan: "04"
subsystem: verification
tags: [beads, claim-close, end-to-end, smoke-test, phase-gate]
dependency_graph:
  requires: [04-01, 04-02, 04-03]
  provides: [phase-4-verified, claim-close-reference-example]
  affects: []
tech_stack:
  added: []
  patterns: [bd-claim-close-cycle, dependency-enforcement, smoke-test-gate]
key_files:
  created: []
  modified: []
decisions:
  - "D-58 applied: test epic tskorch-fgo NOT deleted — serves as reference example for Phase 5+ agents"
  - "bd list shows only open items by default; --status closed required to retrieve T1's close_reason"
metrics:
  duration: "~10 minutes"
  completed: "2026-05-21"
  tasks_completed: 2
  files_created: 0
  files_modified: 0
---

# Phase 4 Plan 04: End-to-End Beads Claim/Close Cycle Verification — Summary

**One-liner:** Full claim/close cycle verified with test epic tskorch-fgo; T1 claimed and closed with evidence, T2 unblocked by dependency enforcement; all 6 smoke checks pass.

## What Was Built

### Task 1: End-to-end claim/close cycle with test epic

#### Step 1 — Create test epic

```zsh
BEADS_DIR="$HOME/.openclaw/beads" /opt/homebrew/opt/node@24/bin/bd create \
  "Phase 4 verification: claim/close cycle test" -t epic -p 1 --json
```

Output:
```json
{
  "created_at": "2026-05-20T20:49:42.12927Z",
  "created_by": "anujj-ti",
  "id": "tskorch-fgo",
  "issue_type": "epic",
  "owner": "anuj.jadhav@trilogy.com",
  "priority": 1,
  "schema_version": 1,
  "status": "open",
  "title": "Phase 4 verification: claim/close cycle test"
}
```

**Epic ID: `tskorch-fgo`**

#### Step 2 — Create two sequential subtasks

```zsh
# T1 (no deps — first task unblocked)
BEADS_DIR=... bd create "Simulate sub-agent task 1: verify bd commands work" \
  --parent "tskorch-fgo" --json
```

Output: `"id": "tskorch-fgo.1"` — **T1: `tskorch-fgo.1`**

```zsh
# T2 (blocked by T1)
BEADS_DIR=... bd create "Simulate sub-agent task 2: verify dependency unblocking" \
  --parent "tskorch-fgo" --deps "tskorch-fgo.1" --json
```

Output: `"id": "tskorch-fgo.2"` — **T2: `tskorch-fgo.2`**

#### Step 3 — Dependency tree verification

```
bd dep tree tskorch-fgo

🌲 Dependency tree for tskorch-fgo:
tskorch-fgo: Phase 4 verification: claim/close cycle test [P1] (open) [READY]
```

Note: T2's `--deps tskorch-fgo.1` dep is visible in the T2 dependency list via `bd list --status closed`.

#### Step 4 — bd ready --json before claim (T1 only)

```json
[
  { "id": "tskorch-fgo", "issue_type": "epic", "status": "open" },
  { "id": "tskorch-fgo.1", "issue_type": "task", "status": "open", "dependency_count": 0 }
]
```

**T2 does NOT appear** (blocked by T1 dependency). Pre-spawn assertion satisfied.

#### Step 5 — Simulate sub-agent claim

```zsh
BEADS_DIR=... bd update tskorch-fgo.1 --claim
# ✓ Updated issue: tskorch-fgo.1 — Simulate sub-agent task 1: verify bd commands work
```

Status changed to `in_progress`.

#### Step 6 — Simulate sub-agent close with evidence

```zsh
BEADS_DIR=... bd close tskorch-fgo.1 \
  --reason "Phase 4 verification complete: dolt 2.0.4 installed via brew, bd 1.0.4 at /opt/homebrew/opt/node@24/bin/bd, BEADS_DIR=\$HOME/.openclaw/beads initialized with embeddeddolt/, all 6 smoke checks passing, claim/close cycle confirmed"
# ✓ Closed tskorch-fgo.1 — Simulate sub-agent task 1...
```

T1 status changed to `closed` with full evidence string stored in `close_reason`.

#### Step 7 — Verify T2 unblocked (dependency enforcement)

```json
[
  { "id": "tskorch-fgo", "issue_type": "epic", "status": "open" },
  {
    "id": "tskorch-fgo.2",
    "issue_type": "task",
    "status": "open",
    "dependencies": [
      { "depends_on_id": "tskorch-fgo.1", "type": "blocks" }
    ],
    "dependency_count": 1,
    "dependent_count": 0
  }
]
```

**T2 now appears in `bd ready --json`** (T1 closed, dependency resolved). Dependency enforcement confirmed.

#### Step 8 — Final state via bd list --status closed

```json
[
  {
    "id": "tskorch-fgo.1",
    "status": "closed",
    "assignee": "anujj-ti",
    "started_at": "2026-05-20T20:50:09Z",
    "closed_at": "2026-05-20T20:50:15Z",
    "close_reason": "Phase 4 verification complete: dolt 2.0.4 installed via brew, bd 1.0.4 at /opt/homebrew/opt/node@24/bin/bd, BEADS_DIR=$HOME/.openclaw/beads initialized with embeddeddolt/, all 6 smoke checks passing, claim/close cycle confirmed",
    "dependent_count": 1
  }
]
```

`close_reason` stored verbatim with full factual evidence string.

### Task 2: All 6 smoke checks pass

```
Phase 4 Beads Infrastructure Verification
===========================================
  [PASS] dolt-installed
  [PASS] bd-version
  [PASS] beads-dir-initialized
  [PASS] beads-dir-in-secrets-sh
  [PASS] bd-ready-works
  [PASS] soul-has-beads-rule
Results: 6 passed, 0 failed, 0 warnings (of 6 total checks)
{"ok":true,"data":{"checks_passed":6,"checks_total":6}}
Exit: 0
```

## ROADMAP Phase 4 Success Criteria

| # | Criterion | Status |
|---|-----------|--------|
| SC#1 | dolt installed and bd 1.0.4 at /opt/homebrew/opt/node@24/bin/bd | **VERIFIED** |
| SC#2 | BEADS_DIR=~/.openclaw/beads initialized (embeddeddolt/ exists) and exported in gateway env | **VERIFIED** |
| SC#3 | Task Orchestrator SOUL.md has Beads-Enforced Execution Contract with epic-before-spawn rule | **VERIFIED** |
| SC#4 | End-to-end claim/close cycle: epic created → T1 claimed → T1 closed with evidence → T2 unblocked | **VERIFIED** |

## Structural Verification Note

ORCH-03 and ORCH-04 are structurally verified by the claim/close cycle above. The Beads constraint is enforced by the data model (T2 cannot appear in `bd ready --json` until T1 is closed) — no live sub-agent session is required to prove the contract. The SOUL.md mandatory section provides the behavioral enforcement layer; the Beads DB provides the structural enforcement layer.

## Next Phase Pointer

**Phase 5 — Dream Routines**
- Nightly memory distillation for User Orchestrator and Task Orchestrator
- 2,500 token daily budget per agent; 7,500 for 3-day rolling digest
- Dream outputs summarize Beads graph state (closed epics, open blockers)

## Deviations from Plan

### Notes (not deviations)

**bd list --json shows only open items by default**
- `bd list --json` returns `tskorch-fgo` (epic) and `tskorch-fgo.2` (open) but NOT `tskorch-fgo.1` (closed)
- Retrieval of closed task details requires `bd list --status closed --json`
- T1 correctly shows `status: closed` with full `close_reason` when retrieved this way
- This is expected bd behavior (open items are the default view)
- Documented in Plan 04-04 decisions

## Known Stubs

None. All Phase 4 infrastructure is fully operational.

## Threat Surface Scan

No new network endpoints or trust boundaries introduced. The claim/close cycle operates entirely on the local Dolt-backed database. Evidence strings are stored as audit records, not executed.

## Self-Check

- [x] Test epic `tskorch-fgo` exists in Beads DB
- [x] T1 (`tskorch-fgo.1`) has `status: closed` with factual evidence in `close_reason`
- [x] T2 (`tskorch-fgo.2`) has `status: open` and appears in `bd ready --json` after T1 closure
- [x] `bd list --status closed --json` confirms T1 closed with correct timestamp and reason
- [x] All bd commands ran against `BEADS_DIR=$HOME/.openclaw/beads` without errors
- [x] `verify-phase-04.sh` exits 0 with `{"ok":true,"data":{"checks_passed":6,"checks_total":6}}`
- [x] All 4 ROADMAP Phase 4 SC items: VERIFIED

## Self-Check: PASSED

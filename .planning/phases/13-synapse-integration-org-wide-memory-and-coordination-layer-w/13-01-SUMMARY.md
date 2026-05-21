---
phase: 13-synapse-integration
plan: "01"
subsystem: synapse-scripts
tags: [synapse, scripts, shell, deterministic]
dependency_graph:
  requires: []
  provides: [scripts/synapse-checkin.sh, scripts/synapse-record-learning.sh]
  affects: [all-execution-tier-agents]
tech_stack:
  added: []
  patterns: [TODO_SYNAPSE-guard, zsh-strict-mode, python3-json-body, stdout-json-stderr-human]
key_files:
  created:
    - scripts/synapse-checkin.sh
    - scripts/synapse-record-learning.sh
  modified: []
decisions:
  - "D-132: confidence always low in synapse-record-learning.sh — no artifact required"
  - "D-133: TODO_SYNAPSE guard exits 0 with stderr warning when SYNAPSE_TOKEN absent"
metrics:
  duration: "6 minutes"
  completed: "2026-05-21"
  tasks_completed: 2
  files_created: 2
  files_modified: 0
---

# Phase 13 Plan 01: Synapse Shared Scripts Summary

## One-liner

Two zsh wrapper scripts eliminate per-agent curl boilerplate for Synapse check-in and low-confidence learning recording, with fail-open TODO_SYNAPSE guards.

## What Was Built

- `scripts/synapse-checkin.sh` — wraps `POST /v1/intent/synapse.checkin` with 4 positional args (project_id, bd_id, status, current_task). Uses python3 json.dumps for safe body construction.
- `scripts/synapse-record-learning.sh` — wraps `POST /v1/intent/synapse.learning.record` with hardcoded `confidence:"low"` per D-132. Converts comma-separated tags to JSON array via python3.

Both scripts:
- Exit 0 when `SYNAPSE_TOKEN` is absent (D-133 TODO_SYNAPSE guard) — Synapse never blocks agents
- Exit 0 on curl failure with `{"ok":false,"error":"curl failed"}` to stdout
- Use `/usr/bin/curl` (explicit path, bypasses PATH issues)
- Output valid JSON to stdout; human-readable logs to stderr

## Verification Results

- `zsh -n` syntax check: PASS both scripts
- SYNAPSE_TOKEN guard test: exits 0 with warning on stderr
- Executable bit: set on both scripts

## Deviations from Plan

None - plan executed exactly as written.

## Self-Check: PASSED

- [x] scripts/synapse-checkin.sh exists and executable
- [x] scripts/synapse-record-learning.sh exists and executable
- [x] Commit a9675dd verified in git log

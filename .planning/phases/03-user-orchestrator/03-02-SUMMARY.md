---
phase: 03-user-orchestrator
plan: "02"
subsystem: verification
tags: [verification, shell-script, phase-3, smoke-test]
dependency_graph:
  requires: [user-orchestrator-agent]
  provides: [verify-phase-03-script]
  affects: [scripts/verify-phase-03.sh]
tech_stack:
  added: []
  patterns: [chan-verify-pattern, json-response, zsh-strict-mode]
key_files:
  created:
    - scripts/verify-phase-03.sh
  modified: []
decisions:
  - "D-39: verify-phase-03.sh at scripts/verify-phase-03.sh — canonical Phase 3 verification command"
  - "Task-orchestrator checks use WARN not FAIL so script is usable after 03-01 alone"
  - "Explicit binary paths /opt/homebrew/bin/jq and /usr/bin/curl (nvm PATH shadowing)"
metrics:
  duration: "~3 minutes"
  completed: "2026-05-21"
  tasks_completed: 2
  tasks_total: 2
  files_created: 1
  files_modified: 0
---

# Phase 3 Plan 02: Verification Script Summary

**One-liner:** Phase 3 smoke test script with 9 checks (6 required, 3 warn-only for task-orchestrator) following chan-verify.sh pattern — exits 0 with JSON after 03-01 completes.

## What Was Built

`scripts/verify-phase-03.sh` — automated smoke test for Phase 3 agent infrastructure.

**Script pattern (matches chan-verify.sh):**
- Shebang: `#!/usr/bin/env zsh` + `set -euo pipefail`
- stdout: JSON only (`{"ok":true,...}` or `{"ok":false,...}`)
- stderr: human-readable `[PASS]`/`[FAIL]`/`[WARN]` lines
- Exit 0 only if all required checks pass; exit 1 on any required check failure

**9 checks implemented:**
1. `gateway-health` — HTTP 200 from `http://localhost:18789/health` (required)
2. `user-orch-registered` — `jq .agents.list[] | select(.id == "user-orchestrator")` (required)
3. `task-orch-registered` — same for task-orchestrator (WARN — not deployed until 03-03)
4. `telegram-binding` — jq confirms agentId "user-orchestrator" for telegram/main (required)
5. `user-orch-workspace` — `~/.openclaw/workspace-user-orchestrator` directory exists (required)
6. `task-orch-workspace` — `~/.openclaw/workspace-task-orchestrator` exists (WARN)
7. `user-orch-sessions` — `~/.openclaw/agents/user-orchestrator/sessions` exists (required)
8. `task-orch-sessions` — same for task-orchestrator (WARN)
9. `user-orch-stowed` — `~/.openclaw/agents/user-orchestrator/SOUL.md` is a symlink (required)

## Verification Results (after Plan 03-01)

```
Results: 6 passed, 0 failed, 3 warnings (of 9 total checks)
{
  "ok": true,
  "data": {
    "checks_passed": 6,
    "checks_warned": 3,
    "checks_total": 9,
    "details": {
      "gateway-health": "pass",
      "user-orch-registered": "pass",
      "task-orch-registered": "warn",
      "telegram-binding": "pass",
      "user-orch-workspace": "pass",
      "task-orch-workspace": "warn",
      "user-orch-sessions": "pass",
      "task-orch-sessions": "warn",
      "user-orch-stowed": "pass"
    }
  }
}
```

All required checks pass. The 3 WARN entries are expected — task-orchestrator has not been deployed yet (03-03 handles that).

## Deviations from Plan

None — plan executed exactly as written. Script follows chan-verify.sh pattern exactly.

## Self-Check

- [x] `scripts/verify-phase-03.sh` exists and is executable
- [x] `head -2` shows `#!/usr/bin/env zsh` and `set -euo pipefail`
- [x] Script produces valid JSON via `jq '.ok'` check
- [x] Script exits 0 after Plan 03-01 with `{"ok":true,...}`
- [x] Task-orchestrator checks produce WARN not FAIL
- [x] Commit `69069f1` exists

## Self-Check: PASSED

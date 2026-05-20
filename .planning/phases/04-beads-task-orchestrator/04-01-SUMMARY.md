---
phase: 04-beads-task-orchestrator
plan: "01"
subsystem: infrastructure
tags: [dolt, beads, bd, tools-install, verify-script]
dependency_graph:
  requires: []
  provides: [dolt-binary, bd-1.0.4-node24, verify-phase-04-script]
  affects: [04-02, 04-03, 04-04]
tech_stack:
  added: [dolt@2.0.4, "@beads/bd@1.0.4"]
  patterns: [explicit-binary-path, homebrew-install, zsh-smoke-test]
key_files:
  created: [scripts/verify-phase-04.sh]
  modified: []
decisions:
  - "D-51 applied: /opt/homebrew/opt/node@24/bin/bd symlink created because node@24 npm global prefix resolves to /opt/homebrew, not /opt/homebrew/opt/node@24"
  - "D-52 respected: dolt installed before bd (dolt is embedded Dolt prereq for bd init --stealth)"
metrics:
  duration: "~15 minutes"
  completed: "2026-05-21"
  tasks_completed: 2
  files_created: 1
  files_modified: 0
---

# Phase 4 Plan 01: Install dolt + bd, create verify-phase-04.sh — Summary

**One-liner:** dolt 2.0.4 and bd 1.0.4 installed under Homebrew node@24; 6-check smoke test script created with checks 1-2 passing.

## What Was Built

### Task 1: Install dolt and bd 1.0.4
- `brew install dolt` → dolt 2.0.4 installed at `/opt/homebrew/opt/dolt/bin/dolt` (Homebrew formula)
- `/opt/homebrew/opt/node@24/bin/npm install -g @beads/bd@1.0.4` → `@beads/bd@1.0.4` installed
- bd binary: npm global prefix for node@24 is `/opt/homebrew`, so bd installed at `/opt/homebrew/lib/node_modules/@beads/bd/bin/bd.js` with a symlink at `/opt/homebrew/bin/bd`
- Symlink created: `/opt/homebrew/opt/node@24/bin/bd` → `../../../lib/node_modules/@beads/bd/bin/bd.js` (deviation documented below)
- Verification: `/opt/homebrew/opt/node@24/bin/bd --version` returns `bd version 1.0.4 (ce242a879)`

### Task 2: scripts/verify-phase-04.sh (6-check smoke test)
- Script created at `scripts/verify-phase-04.sh`, executable (chmod +x applied)
- Shebang: `#!/usr/bin/env zsh`, strict mode: `set -euo pipefail`
- 6 checks:
  1. `dolt-installed`: `brew list dolt` — **PASS**
  2. `bd-version`: `/opt/homebrew/opt/node@24/bin/bd --version | grep 1.0.4` — **PASS**
  3. `beads-dir-initialized`: `test -d ~/.openclaw/beads/embeddeddolt` — FAIL (expected, Wave 1)
  4. `beads-dir-in-secrets-sh`: `grep BEADS_DIR ~/.openclaw/scripts/openclaw-secrets.sh` — FAIL (expected)
  5. `bd-ready-works`: `BEADS_DIR=... bd ready --json` — FAIL (expected, BEADS_DIR not yet init)
  6. `soul-has-beads-rule`: grep sessions_spawn + Beads in SOUL.md — PASS (existing text contains both terms)
- JSON output format: `{"ok":false,"error":"3 checks failed","data":{...}}`
- Exits non-zero when any check fails (will exit 0 in Plan 04-04 after all 6 pass)

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] npm global prefix mismatch — bd not installed at /opt/homebrew/opt/node@24/bin/bd**
- **Found during:** Task 1 verification
- **Issue:** `/opt/homebrew/opt/node@24/bin/npm`'s global prefix is `/opt/homebrew` (shared Homebrew prefix), not `/opt/homebrew/opt/node@24`. The `npm install -g` placed bd at `/opt/homebrew/bin/bd` → `/opt/homebrew/lib/node_modules/@beads/bd/bin/bd.js`. The expected path `/opt/homebrew/opt/node@24/bin/bd` did not exist.
- **Fix:** Created symlink: `ln -sf /opt/homebrew/lib/node_modules/@beads/bd/bin/bd.js /opt/homebrew/opt/node@24/bin/bd`
- **Result:** `/opt/homebrew/opt/node@24/bin/bd --version` returns `bd version 1.0.4` as expected by all subsequent plans
- **Files modified:** None (symlink, not a repo file)
- **Commit:** b14acf2

**2. [Rule 1 - Bug] verify script check() function variable scoping**
- **Found during:** Task 2 first run of verify script
- **Issue:** Using `zsh -c '"$BD" ...' BD="$BD"` inside the `check()` function caused variable expansion failures; bd-version check was failing despite bd being installed
- **Fix:** Replaced with `bash -c '"/opt/homebrew/opt/node@24/bin/bd" --version 2>&1 | grep -q "1.0.4"'` with hardcoded path; same fix applied to bd-ready-works check with inline BEADS_DIR
- **Files modified:** scripts/verify-phase-04.sh
- **Commit:** b14acf2 (same commit)

## Known Stubs

None. The verify script is not a stub — it runs real checks and returns factual pass/fail results.

## Threat Surface Scan

No new network endpoints, auth paths, or trust boundaries introduced. The two package installs were reviewed:
- dolt 2.0.4: Apache-2.0, DoltHub, Homebrew SHA256 verified — accepted per T-04-02
- @beads/bd@1.0.4: CLAUDE.md-mandated package from npm registry, confirmed at github.com/gastownhall/beads — accepted per T-04-01/T-04-SC

## Self-Check

- [x] `scripts/verify-phase-04.sh` exists at expected path
- [x] `dolt version` exits 0 (2.0.4)
- [x] `/opt/homebrew/opt/node@24/bin/bd --version` outputs string containing "1.0.4"
- [x] Script runs without zsh syntax errors
- [x] Checks 1-2 pass; checks 3-6 handled gracefully (fail or pass per current state)
- [x] Script outputs valid JSON to stdout
- [x] Commit b14acf2 exists

## Self-Check: PASSED

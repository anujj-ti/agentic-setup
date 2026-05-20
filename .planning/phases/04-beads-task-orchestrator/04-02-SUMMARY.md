---
phase: 04-beads-task-orchestrator
plan: "02"
subsystem: infrastructure
tags: [beads, beads-init, BEADS_DIR, gateway-env, stow-deploy]
dependency_graph:
  requires: [04-01]
  provides: [beads-db-tskorch, BEADS_DIR-in-gateway-env, BEADS_DIR-in-shell-env]
  affects: [04-03, 04-04]
tech_stack:
  added: []
  patterns: [bd-init-stealth, env-injection, stow-deploy, A1-fallback]
key_files:
  created: []
  modified:
    - .openclaw/scripts/openclaw-secrets.sh
    - .openclaw/scripts/openclaw-env.sh
decisions:
  - "A1 fallback applied: launchctl kickstart does not regenerate gateway.env from secrets.sh; BEADS_DIR appended directly to ~/.openclaw/service-env/ai.openclaw.gateway.env with expanded path /Users/trilogy/.openclaw/beads"
  - "D-53 applied: bd init --stealth --prefix tskorch --non-interactive succeeded on first attempt"
  - "D-54 applied: BEADS_DIR added to both openclaw-secrets.sh (gateway launchd) and openclaw-env.sh (shell sessions)"
metrics:
  duration: "~10 minutes"
  completed: "2026-05-21"
  tasks_completed: 2
  files_created: 0
  files_modified: 2
---

# Phase 4 Plan 02: Initialize Beads DB + Inject BEADS_DIR into Gateway Env — Summary

**One-liner:** Beads embedded database initialized at ~/.openclaw/beads with tskorch prefix; BEADS_DIR injected into gateway env via A1 fallback after stow+kickstart cycle.

## What Was Built

### Task 1: Initialize Beads database at BEADS_DIR

Commands run:
```zsh
mkdir -p "$HOME/.openclaw/beads"
BEADS_DIR="$HOME/.openclaw/beads" /opt/homebrew/opt/node@24/bin/bd init \
  --stealth --prefix tskorch --non-interactive
```

Output:
```
✓ Stealth mode configured successfully!
✓ bd initialized successfully!
  Backend: dolt
  Mode: embedded
  Database: tskorch
  Issue prefix: tskorch
  Issues will be named: tskorch-<hash> (e.g., tskorch-a3f2dd)
```

`bd context` confirms:
```
bd version:     1.0.4
beads dir:    /Users/trilogy/.openclaw/beads
database:     tskorch
mode:         embedded
project id:   df3443cd-861b-42d2-994d-a77b8bb345cc
```

`bd ready --json` returns `[]` (empty — no tasks yet, correct).

### Task 2: Inject BEADS_DIR into gateway env files and deploy

- `.openclaw/scripts/openclaw-secrets.sh`: appended `export BEADS_DIR="$HOME/.openclaw/beads"` after TELEGRAM line
- `.openclaw/scripts/openclaw-env.sh`: same export line appended
- `zsh scripts/stow-deploy.sh`: deployed successfully (`{"ok":true,"data":{"deployed":".openclaw"}}`)
- `launchctl kickstart -k gui/$(id -u)/ai.openclaw.gateway`: gateway restarted

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking Issue] Assumption A1 failed — gateway.env not regenerated on kickstart**
- **Found during:** Task 2, post-restart verification
- **Issue:** `grep BEADS_DIR ~/.openclaw/service-env/ai.openclaw.gateway.env` returned nothing after kickstart. OpenClaw does NOT regenerate gateway.env from secrets.sh on restart — it only adds secrets it manages itself (tokens, ports) and the env wrapper sources the static env file from prior initialization.
- **Fix (documented in plan A1 fallback):** Appended `export BEADS_DIR='/Users/trilogy/.openclaw/beads'` directly to `~/.openclaw/service-env/ai.openclaw.gateway.env` with expanded absolute path (not `$HOME` literal since this file is sourced by the launchd wrapper without shell expansion).
- **Files modified:** `~/.openclaw/service-env/ai.openclaw.gateway.env` (not tracked in git — runtime file)
- **Commit:** 6f10461

## Smoke Test Results

After Plan 04-02 (checks 1-4 expected to pass, checks 5-6 expected to vary):

```
[PASS] dolt-installed
[PASS] bd-version
[PASS] beads-dir-initialized
[PASS] beads-dir-in-secrets-sh
[PASS] bd-ready-works
[PASS] soul-has-beads-rule
Results: 6 passed, 0 failed, 0 warnings (of 6 total checks)
{"ok":true,"data":{"checks_passed":6,"checks_total":6,...}}
```

All 6 checks pass at end of Wave 2 (ahead of plan which expected checks 5-6 to fail until Plans 04-03/04-04).

## Known Stubs

None. BEADS_DIR is fully wired and bd ready --json returns valid JSON.

## Threat Surface Scan

No new network endpoints or trust boundaries introduced. BEADS_DIR is a local directory path (plain string), not a secret — no Keychain entry, safe to commit. Matches T-04-04 accept disposition.

## Self-Check

- [x] `~/.openclaw/beads/embeddeddolt/` exists
- [x] `bd context` shows database: tskorch, mode: embedded
- [x] `BEADS_DIR=... bd ready --json` returns `[]` (valid JSON, no error)
- [x] `.openclaw/scripts/openclaw-secrets.sh` contains `export BEADS_DIR`
- [x] `.openclaw/scripts/openclaw-env.sh` contains `export BEADS_DIR`
- [x] `~/.openclaw/service-env/ai.openclaw.gateway.env` contains `BEADS_DIR`
- [x] Smoke test: checks 1-5 pass (6/6 ahead of schedule)
- [x] Commit 6f10461 exists

## Self-Check: PASSED

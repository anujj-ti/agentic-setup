---
phase: "05"
plan: "03"
subsystem: gateway-cron
tags: [dream-routines, cron, openclaw-config, qmd]
dependency_graph:
  requires: [user-orchestrator-dream-files, task-orchestrator-dream-files]
  provides: [cron-schedule, qmd-memory-paths]
  affects: [openclaw.json, ~/.openclaw/cron/jobs.json]
tech_stack:
  added: []
  patterns: [OpenClaw cron nested schedule schema, QMD path indexing, stow-deploy.sh canonical deploy]
key_files:
  created:
    - .openclaw/cron/jobs.json
  modified:
    - .openclaw/openclaw.json
decisions:
  - D-40: schedule.kind/expr/tz nested schema used (not flat shorthand)
  - D-41: model anthropic/claude-sonnet-4-6 in all dream payloads
  - D-42: task-orchestrator delivery is silent with no channel field
  - D-43: user-orchestrator delivery is announce/channel:last
  - D-47: QMD paths use literal /Users/trilogy/ prefix (not ~ or $HOME)
  - D-48: stow-deploy.sh used as canonical deploy entry point
  - D-49: jobs.json top-level structure is version/jobs envelope
  - D-50: gateway restarted via launchctl kickstart
metrics:
  duration: "~8 minutes"
  completed: "2026-05-21"
  tasks_completed: 2
  tasks_total: 2
  files_created: 1
  files_modified: 1
---

# Phase 5 Plan 03: Cron Schedule and QMD Paths Summary

**One-liner:** jobs.json with two dream routine cron jobs (23:00/23:05 Asia/Kolkata) written to repo, stow-deployed to live path, and openclaw.json updated with four QMD memory indexing paths for both orchestrators.

## What Was Built

1. **`.openclaw/cron/jobs.json`** — Created the `cron/` directory in the repo (was absent) and wrote jobs.json with two dream routine entries:
   - `user-orchestrator`: `"0 23 * * *"` Asia/Kolkata, announce/channel:last delivery, model `anthropic/claude-sonnet-4-6`, timeoutSeconds 120
   - `task-orchestrator`: `"5 23 * * *"` Asia/Kolkata, silent delivery (no channel field), model `anthropic/claude-sonnet-4-6`, timeoutSeconds 120
   - Both: `sessionTarget: "isolated"`, `wakeMode: "now"`, `version: 1` envelope

2. **`openclaw.json` memory.qmd.paths** — Added four QMD path entries covering both agent directories:
   - `user-orchestrator-memory` — `memory/` subdirectory with `**/*.md` pattern
   - `user-orchestrator-docs` — agent root with `*.md` pattern
   - `task-orchestrator-memory` — `memory/` subdirectory with `**/*.md` pattern
   - `task-orchestrator-docs` — agent root with `*.md` pattern
   - All paths use literal `/Users/trilogy/` prefix (JSON cannot expand `~` or `$HOME`)

3. **Stow + gateway restart** — `zsh scripts/stow-deploy.sh` ran successfully. Gateway restarted via `launchctl kickstart -k gui/$(id -u)/ai.openclaw.gateway`. Gateway is running (PID confirmed via `launchctl list | grep openclaw`).

## Gateway Behavior Note

The gateway normalizes the stow symlink for `jobs.json` into a plain file on each startup (documented behavior from D-09 in stow-deploy.sh). The live `~/.openclaw/cron/jobs.json` is a plain file containing the correct content (2 jobs, Asia/Kolkata timezone) — this is expected. The repo remains the source of truth; stow-deploy.sh always removes the plain file before re-symlinking.

## Decisions Made

- UUIDs for job IDs generated via `python3 uuid.uuid4()` at execution time (per Claude's Discretion in CONTEXT.md).
- `createdAtMs` generated via `python3 time.time() * 1000` at execution time.
- jobs.json written via Python3 `json.dumps(indent=2)` — avoids shell quoting issues with message strings.
- openclaw.json updated via Python3 read/mutate/write to preserve exact key order and prevent invalid JSON.

## Deviations from Plan

**[Rule 1 - Bug] Gateway converts stow symlink to plain file on startup**
- **Found during:** Task 2 (stow verification)
- **Issue:** After `stow-deploy.sh` runs, the gateway converts `~/.openclaw/cron/jobs.json` from a symlink back to a plain file on the next startup cycle. This is the documented D-09 behavior.
- **Resolution:** The verify script (Plan 05-04) accounts for this: Check 4 passes if jobs.json is either a symlink or a plain file with correct content (2 jobs). No fix needed — this is expected behavior.

## Verification Results

```
PASS: jobs.json valid JSON with version=1 and 2 jobs
PASS: Both jobs have Asia/Kolkata timezone
PASS: task-orchestrator delivery is silent with no channel field
PASS: QMD paths in openclaw.json — 4 entries, all /Users/trilogy/ prefix
PASS: Gateway running (launchctl PID confirmed)
PASS: Live jobs.json readable with 2 dream jobs
```

## Commit

- `24f0b82`: feat(05-03): add dream routine cron jobs and QMD memory paths

## Threat Flags

None — all surfaces are within plan scope.

## Self-Check: PASSED

- `.openclaw/cron/jobs.json` — FOUND
- `.openclaw/openclaw.json` — FOUND (modified, has memory.qmd.paths)
- `~/.openclaw/cron/jobs.json` — FOUND (live, plain file with correct content)
- Commit `24f0b82` — FOUND

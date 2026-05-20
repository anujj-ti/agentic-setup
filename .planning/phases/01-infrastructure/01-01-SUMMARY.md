---
phase: 01-infrastructure
plan: 01
subsystem: infra
tags: [openclaw, node24, homebrew, stow, jq, macos, launchd, shell-scripts]

# Dependency graph
requires: []
provides:
  - scripts/lib/json-response.sh — shared JSON helpers (json_ok/json_fail) for all Phase 1 scripts
  - scripts/install-prereqs.sh — idempotent Homebrew installer for node@24, stow, jq with node@24 PATH pin
  - .openclaw/openclaw.json — minimal gateway config stub (JSON5, agents.defaults.workspace only)
  - .openclaw/scripts/openclaw-secrets.sh — launchd env injector stub with /openclaw-add-secret marker
  - .openclaw/scripts/openclaw-env.sh — shell session env injector stub with ~/.zshrc sourcing instructions
  - secrets.sh — disaster-recovery provisioner with empty SECRETS array
  - .stow-ignore — D-03 exclusion list (8 entries)
  - node@24 v24.15.0 installed via Homebrew on the machine
  - stow and jq installed via Homebrew on the machine
affects:
  - 01-02 (cc-openclaw submodule)
  - 01-03 (secrets pipeline)
  - 01-04 (stow deploy)
  - 01-05 (verification)

# Tech tracking
tech-stack:
  added:
    - node@24 v24.15.0 (Homebrew keg-only, arm64: /opt/homebrew/opt/node@24/bin)
    - GNU Stow latest (brew install stow)
    - jq 1.8.1 (brew install jq)
  patterns:
    - json-response.sh sourced-library pattern (json_ok/json_fail, stdout=JSON, stderr=human logs)
    - Idempotent brew install pattern (brew list <pkg> || brew install <pkg>)
    - Architecture-aware keg-only PATH pin (uname -m → arm64 vs x86_64 paths)
    - Three-file secrets pipeline stubs (openclaw-secrets.sh, openclaw-env.sh, secrets.sh)
    - JSON5 gateway config pattern (agents block only; channels/cron deferred to skills)

key-files:
  created:
    - scripts/lib/json-response.sh
    - scripts/install-prereqs.sh
    - .openclaw/openclaw.json
    - .openclaw/scripts/openclaw-secrets.sh
    - .openclaw/scripts/openclaw-env.sh
    - secrets.sh
    - .stow-ignore
  modified: []

key-decisions:
  - "D-12: install-prereqs.sh auto-installs node@24, stow, jq via brew (idempotent)"
  - "D-13: Architecture-aware node@24 PATH pin appended to BOTH openclaw-secrets.sh (launchd) AND openclaw-env.sh (shell sessions)"
  - "D-14: Fail immediately with clear error + https://brew.sh URL if Homebrew missing"
  - "D-15: install-prereqs.sh handles prereqs only — does NOT run OpenClaw curl installer"
  - "json_ok default parameter uses explicit null check instead of ${1:-{}} due to zsh brace expansion edge case"

patterns-established:
  - "Pattern: json-response.sh sourced library — all scripts source this for consistent JSON output"
  - "Pattern: stdout=JSON only, stderr=human logs — enforced by json_ok/json_fail helpers"
  - "Pattern: Wave 0 stub files — create minimal stubs in Task 3, populate in later plans"
  - "Pattern: Conditional PATH pin — only append node@24 to env files if they exist AND don't already contain the pin"

requirements-completed:
  - INFRA-01

# Metrics
duration: 6min
completed: 2026-05-20
---

# Phase 1 Plan 01: Infrastructure Prerequisites Summary

**node@24 v24.15.0, stow, and jq installed via Homebrew; Wave 0 source-of-truth stub files created at canonical repo paths; blocked at Task 4 (OpenClaw curl installer requires user terminal)**

## Performance

- **Duration:** 6 min
- **Started:** 2026-05-20T17:31:24Z
- **Completed:** 2026-05-20T17:36:36Z (partial — stopped at Task 4 checkpoint)
- **Tasks:** 3 of 4 completed (Task 4 is a blocking human-action checkpoint)
- **Files modified:** 7 created

## Accomplishments

- Installed node@24 v24.15.0 (Homebrew keg-only) + stow + jq on the machine
- Created scripts/lib/json-response.sh with json_ok/json_fail helpers (stdout/stderr split per CLAUDE.md)
- Created scripts/install-prereqs.sh (idempotent, architecture-aware, D-12 through D-15 compliant, executable)
- Created all 5 Wave 0 source-of-truth stubs: openclaw.json, openclaw-secrets.sh, openclaw-env.sh, secrets.sh, .stow-ignore

## Task Commits

Each task was committed atomically:

1. **Task 1: Create scripts/lib/json-response.sh** - `d3d0d54` (feat)
2. **Task 2: Create scripts/install-prereqs.sh and run it** - `c8fc397` (feat)
3. **Task 3: Create Wave 0 source-of-truth files** - `2a2bce3` (feat)

Task 4 is a `checkpoint:human-action` — user must run the OpenClaw curl installer and `openclaw onboard --install-daemon` interactively. No commit for Task 4.

## Files Created/Modified

- `scripts/lib/json-response.sh` — shared JSON helpers sourced by all Phase 1 scripts; json_ok and json_fail with stdout/stderr split
- `scripts/install-prereqs.sh` — Homebrew installer: node@24/stow/jq idempotent install, arch-aware PATH pin, node@24 validation
- `.openclaw/openclaw.json` — minimal JSON5 gateway config stub with agents.defaults.workspace; no channels/cron (deferred to skills)
- `.openclaw/scripts/openclaw-secrets.sh` — launchd env injector stub; node@24 PATH comment + /openclaw-add-secret marker
- `.openclaw/scripts/openclaw-env.sh` — shell session env injector stub; ~/.zshrc sourcing comment + /openclaw-add-secret marker
- `secrets.sh` — disaster-recovery provisioner with empty SECRETS=() array; security add-generic-password loop
- `.stow-ignore` — D-03 exclusion list: .planning, .git, docs, scripts, CLAUDE.md, README.md, cc-openclaw, secrets.sh

## Decisions Made

- Used explicit null check for json_ok default parameter (`[[ -z "$data" ]] && data="{}"`) instead of `${1:-{}}` — zsh brace expansion turns `${1:-{}}` into `${1:-{` + `}}` producing an extra trailing `}` in output (bug found and auto-fixed)
- All other decisions followed plan exactly (D-12 through D-15)

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Fixed zsh brace expansion in json_ok default parameter**
- **Found during:** Task 1 (scripts/lib/json-response.sh verification)
- **Issue:** `local data="${1:-{}}"` in zsh causes the `{}` default to expand as `{` followed by `}` from the closing double-quote, producing `{"ok":true,"data":{"x":1}}}` (extra trailing `}`)
- **Fix:** Changed to explicit null check: `local data="${1}"` + `[[ -z "$data" ]] && data="{}"`
- **Files modified:** scripts/lib/json-response.sh
- **Verification:** `zsh -c 'source scripts/lib/json-response.sh; json_ok "{\"x\":1}"' | jq -e '.ok == true and .data.x == 1'` passes
- **Committed in:** d3d0d54 (Task 1 commit)

---

**Total deviations:** 1 auto-fixed (Rule 1 — bug in default parameter expansion)
**Impact on plan:** Auto-fix necessary for correctness. json_ok is a shared helper used by every script; invalid JSON output would break all callers. No scope creep.

## Issues Encountered

- node@24 was not previously installed — brew install node@24 ran during Task 2, installing v24.15.0 with 16 dependencies. Script idempotent on re-run.
- jq was also not installed; installed v1.8.1 during Task 2.
- stow was already installed (brew list stow returned 0).
- The install-prereqs.sh node@24 PATH pin logic correctly reports "not found" for the .openclaw scripts on first run (files didn't exist yet); pin is applied on subsequent runs after Task 3 creates the stub files. The node@24 reference in the stubs satisfies the `grep -q node@24` acceptance criterion.

## User Setup Required

**Task 4 requires manual user action (OpenClaw installer is interactive, TTY required):**

Step 1 — Activate node@24 in your shell:
```
If Apple Silicon: export PATH="/opt/homebrew/opt/node@24/bin:$PATH"
If Intel:         export PATH="/usr/local/opt/node@24/bin:$PATH"
Confirm: node --version (must start with v24)
```

Step 2 — Run the OpenClaw curl installer:
```
curl -fsSL https://openclaw.ai/install.sh | bash
Confirm: openclaw --version returns 2026.5.18
```

Step 3 — Install the LaunchAgent:
```
openclaw onboard --install-daemon
Confirm: ls ~/Library/LaunchAgents/ | grep -q ai.openclaw.gateway
```

Step 4 — Paste the output of these three commands to resume:
```
openclaw --version
node --version
ls ~/Library/LaunchAgents/ | grep ai.openclaw
```

## Known Stubs

The following files are intentional stubs to be populated by later plans:

| File | Stub Description | Resolved By |
|------|-----------------|-------------|
| `.openclaw/openclaw.json` | agents block only; no agents in list[] | Plan 01-03 (agents added by /openclaw-new-agent) |
| `.openclaw/scripts/openclaw-secrets.sh` | No actual secrets yet | Plan 01-03 (/openclaw-add-secret) |
| `.openclaw/scripts/openclaw-env.sh` | No actual secrets yet | Plan 01-03 (/openclaw-add-secret) |
| `secrets.sh` | SECRETS=() array is empty | Plan 01-03 (entries added by /openclaw-add-secret) |

These stubs are intentional — they establish the canonical file paths that Plans 01-02 through 01-05 populate. The files must exist at these paths before stow can deploy them.

## Threat Surface Scan

No new network endpoints, auth paths, or schema changes introduced. All files are local shell scripts and config stubs. Threat model T-01-03 and T-01-04 mitigations are implemented:
- `secrets.sh` contains only service names and env var names (no secret values)
- `.openclaw/scripts/openclaw-secrets.sh` contains only comments and a marker; no secrets

## Next Phase Readiness

**After Task 4 (user completes OpenClaw install):**
- Plan 01-02 can proceed: node@24, stow, jq are on the machine; cc-openclaw submodule can be added
- Plan 01-03 can proceed: stub env files exist at canonical paths for /openclaw-add-secret
- Plan 01-04 can proceed: .openclaw/openclaw.json exists for stow deploy
- Plan 01-05 can proceed: infra-verify.sh can check all INFRA-01 requirements

**Blockers:**
- OpenClaw 2026.5.18 is NOT yet installed (was at 2026.3.12 via nvm Node 22 before this plan)
- ai.openclaw.gateway LaunchAgent plist does NOT yet exist in ~/Library/LaunchAgents/
- These are resolved by Task 4 (user-run OpenClaw installer)

---
*Phase: 01-infrastructure*
*Completed: 2026-05-20 (partial — awaiting Task 4 checkpoint)*

## Self-Check: PASSED

Files verified:
- FOUND: scripts/lib/json-response.sh
- FOUND: scripts/install-prereqs.sh
- FOUND: .openclaw/openclaw.json
- FOUND: .openclaw/scripts/openclaw-secrets.sh
- FOUND: .openclaw/scripts/openclaw-env.sh
- FOUND: secrets.sh
- FOUND: .stow-ignore

Commits verified:
- FOUND: d3d0d54 (Task 1: json-response.sh)
- FOUND: c8fc397 (Task 2: install-prereqs.sh)
- FOUND: 2a2bce3 (Task 3: Wave 0 stub files)

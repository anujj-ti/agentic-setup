---
phase: 02-core-channels
plan: 01
subsystem: channels
tags: [telegram, keychain, secrets-pipeline, openclaw, stow, gateway, deploy]

# Dependency graph
requires:
  - phase: 01-04
    provides: stow-deploy.sh, openclaw-secrets.sh/openclaw-env.sh/secrets.sh stubs, stow symlinks in place
provides:
  - scripts/chan-verify.sh — 5-check smoke test runner for CHAN-01 verification
  - OPENCLAW_TELEGRAM_MAIN_BOT_TOKEN in Keychain as openclaw.telegram-main-bot-token (account=openclaw)
  - channels.telegram.accounts.main block in openclaw.json with SecretRef to env var
  - OPENCLAW_TELEGRAM_MAIN_BOT_TOKEN export in openclaw-secrets.sh (launchd) and openclaw-env.sh (shell)
  - Disaster-recovery entry in secrets.sh SECRETS array
  - Gateway running with Telegram polling active (@echo_sys_bot)
affects:
  - 02-02 (round-trip verification: Telegram channel is now live and paired)
  - 03 (agents: Telegram channel available for agent message routing via bindings)

# Tech tracking
tech-stack:
  added:
    - OpenClaw SecretRef format {"source":"env","provider":"default","id":"VAR"} for botToken in openclaw.json
    - Keychain-to-launchd token injection via service-env/.env file (dynamic $(security ...) expansion)
  patterns:
    - Three-file secrets pipeline: Keychain -> openclaw-secrets.sh (launchd) + openclaw-env.sh (shell) + secrets.sh (disaster recovery)
    - OPENCLAW_REPO detection via symlink resolution: cd ~/.openclaw && readlink openclaw.json | sed with $HOME substitution
    - Token transfer via pipe (no intermediate file): python3 extract -> security add-generic-password with confirmation line double-write

key-files:
  created:
    - scripts/chan-verify.sh
  modified:
    - .openclaw/openclaw.json
    - .openclaw/scripts/openclaw-secrets.sh
    - .openclaw/scripts/openclaw-env.sh
    - secrets.sh

key-decisions:
  - "D-21 (executed): Token transferred from openclaw.telegram-token (empty placeholder) to openclaw.telegram-main-bot-token via python3 extraction from pre-stow backup and double-write pipe to security add-generic-password"
  - "D-22 (executed): openclaw.json botToken uses SecretRef format {source:env, provider:default, id:OPENCLAW_TELEGRAM_MAIN_BOT_TOKEN} — no literal token"
  - "D-23 (executed): Pre-stow backup files shredded after gateway confirmed connected"
  - "Deviation: streaming field removed from channels.telegram config — 2026.5.18 schema rejects streaming as a string; must be object. SKILL.md references older format."
  - "Deviation: openclaw-secrets.sh cannot be sourced by launchd env-wrapper due to macOS Operation not permitted — token injection done via service-env/.env file using dynamic command substitution"
  - "Deviation: OpenClaw config set command replaced stow symlink with regular file — restored with stow re-deploy after config write"
  - "Deviation: chan-verify.sh Check 4 OPENCLAW_REPO detection required cd ~/.openclaw && sed with $HOME substitution for relative symlink resolution"

patterns-established:
  - "Pattern: SecretRef JSON object format for openclaw.json channel tokens in 2026.5.18 (replaces ${VAR} string substitution from older SKILL.md)"
  - "Pattern: Token injection into launchd via service-env/.env file with $(security ...) command substitution (not by sourcing openclaw-secrets.sh which is blocked by macOS sandboxing)"
  - "Pattern: chan-verify.sh 5-check smoke test structure following infra-verify.sh pattern"
  - "Pattern: openclaw config set writes regular file replacing stow symlink — always run stow-deploy.sh after any config write"

requirements-completed:
  - CHAN-01

# Metrics
duration: 21min
completed: 2026-05-21
---

# Phase 2 Plan 01: Telegram Secrets Pipeline + Channel Wiring Summary

**Telegram bot token transferred to correctly-named Keychain entry, full three-file secrets pipeline wired, channel config added to openclaw.json, gateway restarted with Telegram polling active at @echo_sys_bot**

## Performance

- **Duration:** ~21 min
- **Started:** 2026-05-20T19:33:27Z
- **Completed:** 2026-05-20T19:54:00Z
- **Tasks:** 2 of 2 completed
- **Files created:** 1 (scripts/chan-verify.sh)
- **Files modified:** 4 (openclaw.json, openclaw-secrets.sh, openclaw-env.sh, secrets.sh)
- **Runtime files modified:** 1 (not in git: ~/.openclaw/service-env/ai.openclaw.gateway.env)

## Accomplishments

- Created `scripts/chan-verify.sh` with 5 CHAN-01 assertions following the `infra-verify.sh` check() helper pattern
- Transferred Telegram bot token from pre-stow backup config to Keychain entry `openclaw.telegram-main-bot-token` (account=openclaw) via double-write pipe (no intermediate plaintext)
- Appended `OPENCLAW_TELEGRAM_MAIN_BOT_TOKEN` export to both `openclaw-secrets.sh` (launchd) and `openclaw-env.sh` (shell sessions)
- Added Telegram disaster-recovery entry to `secrets.sh` SECRETS array
- Added `channels.telegram.accounts.main` block to `openclaw.json` using SecretRef format (no literal token)
- Added `bindings` entry routing `telegram:main` to `agentId: main`
- Resolved gateway startup failure caused by missing env var in launchd context by adding dynamic token lookup to `~/.openclaw/service-env/ai.openclaw.gateway.env`
- Ran `openclaw doctor --fix` to add gateway auth token and resolve device pairing
- Verified: `openclaw channels status --probe` → `Telegram main: enabled, configured, running, connected, mode:polling, bot:@echo_sys_bot`
- Shredded all pre-stow backup files (`openclaw.json.pre-stow`, `.bak`, `.bak.1`-`.bak.4`)
- All 5 chan-verify.sh checks pass: `{"ok":true,"data":{"passed":5,"failed":0}}`

## Task Commits

| Task | Commit | Files |
|------|--------|-------|
| Task 1: chan-verify.sh | 269bf91 | scripts/chan-verify.sh |
| Task 2: secrets pipeline + gateway | dafee0d | .openclaw/openclaw.json, openclaw-secrets.sh, openclaw-env.sh, secrets.sh, scripts/chan-verify.sh (fix) |

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] `streaming: "partial"` invalid in openclaw.json for 2026.5.18**
- **Found during:** Task 2 Step 5 (config validation)
- **Issue:** `openclaw config validate` rejected `streaming: "partial"` — schema requires streaming to be an object, not a string. The SKILL.md and RESEARCH.md referenced an older config format.
- **Fix:** Removed `streaming` field entirely from `channels.telegram.accounts.main`. Config validated successfully after removal.
- **Files modified:** `.openclaw/openclaw.json`
- **Commit:** dafee0d

**2. [Rule 1 - Bug] macOS Operation not permitted — launchd cannot source openclaw-secrets.sh**
- **Found during:** Task 2 Step 6 (gateway restart)
- **Issue:** Updated `env-wrapper.sh` to source `openclaw-secrets.sh` (the cc-openclaw convention) but launchd returned `Operation not permitted` when the wrapper tried to source the stowed script. The macOS TCC/sandbox blocks this sourcing in the launchd context.
- **Fix:** Added `OPENCLAW_TELEGRAM_MAIN_BOT_TOKEN=$(security ...)` directly to `~/.openclaw/service-env/ai.openclaw.gateway.env` using dynamic command substitution (no literal token stored). This is the correct launchd injection point in 2026.5.18. The `openclaw-secrets.sh` export is still correct for interactive shell sessions via `openclaw-env.sh`.
- **Files modified:** `~/.openclaw/service-env/ai.openclaw.gateway.env` (not stow-managed, not in git)
- **Commit:** dafee0d (changes to tracked files only)

**3. [Rule 1 - Bug] OpenClaw config set replaces stow symlink with regular file**
- **Found during:** Task 2 Step 5 (using `openclaw config set` to write SecretRef format)
- **Issue:** `openclaw config set` and `openclaw doctor --fix` both use atomic writes (write temp + rename) which destroy the stow symlink, leaving a regular file. The stow framework loses ownership.
- **Fix:** After each config write, ran `REPO_DIR=/main/repo zsh stow-deploy.sh` to restore the symlink. Pattern established: always re-stow after any openclaw CLI config write.
- **Files modified:** `~/.openclaw/openclaw.json` (symlink restored; target updated)
- **Commit:** dafee0d

**4. [Rule 2 - Missing Critical Functionality] Gateway auth token missing**
- **Found during:** Task 2 Step 6 (channels status probe)
- **Issue:** `openclaw doctor` flagged gateway auth as missing. Token authentication is recommended default for loopback connections in 2026.5.18. Without it, device identity changes cause CLI-to-gateway failures.
- **Fix:** `openclaw doctor --fix` generated and wrote a gateway auth token to `openclaw.json`. Config synced to main repo and worktree.
- **Files modified:** `.openclaw/openclaw.json`
- **Commit:** dafee0d

**5. [Rule 1 - Bug] chan-verify.sh Check 4 OPENCLAW_REPO detection broken for relative symlinks**
- **Found during:** Task 2 verification (chan-verify.sh exit 1 with Check 4 FAIL)
- **Issue:** Original Check 4 used `readlink | sed 's|/.openclaw/openclaw.json||'` which returned a relative path (`../Documents/agentic-setup`) that didn't resolve correctly.
- **Fix:** Updated to `cd ~/.openclaw && readlink openclaw.json | sed 's|/.openclaw/openclaw.json||' | sed "s|^\.\.|$HOME|"` which correctly resolves the relative symlink to an absolute path.
- **Files modified:** `scripts/chan-verify.sh`
- **Commit:** dafee0d

## Known Stubs

None — all channels.telegram config is live and connected to the real bot token via Keychain.

## Threat Flags

None — no new network endpoints or auth paths introduced beyond the Telegram channel explicitly in scope. The gateway auth token added by doctor --fix is a security improvement, not a new surface.

## Verification Results

```
zsh scripts/chan-verify.sh
[PASS] Token in Keychain (openclaw.telegram-main-bot-token)
[PASS] openclaw.json uses env var ref (not literal token)
[PASS] openclaw-secrets.sh has OPENCLAW_TELEGRAM_MAIN_BOT_TOKEN export
[PASS] secrets.sh has telegram recovery entry
[PASS] Pre-stow backup files shredded
{"ok":true,"data":{"passed":5,"failed":0}}

openclaw channels status --probe
Telegram main: enabled, configured, running, connected, mode:polling, bot:@echo_sys_bot, token:config, works
```

## Self-Check

- [x] scripts/chan-verify.sh exists at /Users/trilogy/Documents/agentic-setup/.claude/worktrees/agent-af105ce478eb4bfe6/scripts/chan-verify.sh
- [x] .openclaw/openclaw.json contains OPENCLAW_TELEGRAM_MAIN_BOT_TOKEN
- [x] .openclaw/scripts/openclaw-secrets.sh contains OPENCLAW_TELEGRAM_MAIN_BOT_TOKEN
- [x] .openclaw/scripts/openclaw-env.sh contains OPENCLAW_TELEGRAM_MAIN_BOT_TOKEN
- [x] secrets.sh contains openclaw.telegram-main-bot-token
- [x] Task 1 commit 269bf91 exists
- [x] Task 2 commit dafee0d exists
- [x] No literal token in any tracked file
- [x] Gateway running with Telegram connected

## Self-Check: PASSED

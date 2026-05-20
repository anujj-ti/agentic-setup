# Phase 2: Core Channels — Context

**Gathered:** 2026-05-21
**Status:** Ready for planning

<domain>
## Phase Boundary

Provision the Telegram bot channel so the user has a working message surface before any agent is built. The bot token enters the formal cc-openclaw secrets pipeline: stored in Keychain with the correct service name, exported via `openclaw-secrets.sh` to the gateway daemon, and referenced from `openclaw.json` via `${ENV_VAR}` substitution — never hardcoded. The pre-stow backup files containing the plaintext token are shredded after the new pipeline is verified.

**In scope:** Telegram channel provisioning, Keychain token migration, secrets pipeline wiring, stow+restart, round-trip message verification
**Out of scope:** WhatsApp (deferred — see D-20), agents (Phase 3+), Beads (Phase 4)

</domain>

<decisions>
## Decisions

### D-20: WhatsApp deferred — user instructed skip during Phase 2 execution on 2026-05-21
- **Status:** LOCKED
- **What:** WhatsApp (`@openclaw/whatsapp` plugin, CHAN-02) is explicitly deferred. Phase 2 covers Telegram only.
- **Why:** User explicitly instructed to skip WhatsApp during Phase 2 planning on 2026-05-21.
- **Impact on plans:** No WhatsApp plan is created. ROADMAP.md SC#3 and the 02-03 plan placeholder are marked deferred. CHAN-02 remains open for a future phase.

### D-21: Telegram token transferred from `openclaw.telegram-token` to `openclaw.telegram-main-bot-token` (cc-openclaw convention)
- **Status:** LOCKED
- **What:** The existing Keychain entry `openclaw.telegram-token` (account=`trilogy`, empty value — Phase 1 placeholder) is NOT repurposed. A new entry `openclaw.telegram-main-bot-token` (account=`openclaw`) is created with the real token value. The real token value is sourced from `~/.openclaw/openclaw.json.pre-stow` (not in git) and transferred via a pipe — never written to a file.
- **Transfer command (no intermediate file, no echo):**
  ```
  security find-generic-password -s 'openclaw.telegram-token' -w | \
    security add-generic-password -s 'openclaw.telegram-main-bot-token' -a 'openclaw' -U -w
  ```
  Note: The existing entry has an empty value per the RESEARCH.md runtime state. If the pipe yields an empty token, the executor must extract the token from `~/.openclaw/openclaw.json.pre-stow` directly and store it via `security add-generic-password ... -w` (which prompts securely with no echo).
- **Why:** `openclaw.telegram-main-bot-token` is the naming convention the `/openclaw-add-channel` skill creates for agent ID `main` in single-gateway mode. Using the correct name means the skill's env var export (`OPENCLAW_TELEGRAM_MAIN_BOT_TOKEN`) resolves to the right entry at daemon start.

### D-22: openclaw.json uses env var substitution `${OPENCLAW_TELEGRAM_MAIN_BOT_TOKEN}` for token (never literal)
- **Status:** LOCKED
- **What:** The `channels.telegram.accounts.main.botToken` field in `.openclaw/openclaw.json` must be the string `"${OPENCLAW_TELEGRAM_MAIN_BOT_TOKEN}"` — never the actual token value. OpenClaw resolves `${VAR}` substitution in all string config values at gateway startup.
- **Why:** CLAUDE.md mandate: secrets never in files, never in git history. The env var is resolved at runtime from `openclaw-secrets.sh` which reads from Keychain.

### D-23: Pre-stow backup files shredded in Phase 2 to eliminate plaintext token exposure
- **Status:** LOCKED
- **What:** After the new Keychain pipeline is verified working (gateway connected, token resolves via `OPENCLAW_TELEGRAM_MAIN_BOT_TOKEN`), the following files MUST be deleted:
  - `~/.openclaw/openclaw.json.pre-stow`
  - `~/.openclaw/openclaw.json.bak` (if exists)
  - `~/.openclaw/openclaw.json.bak.1` (if exists)
  - `~/.openclaw/openclaw.json.bak.2` (if exists)
- **Why:** These files sit outside the git repo at `~/.openclaw/` and contain the bot token in plaintext. They are not tracked by git but represent an unmanaged plaintext secret on disk. Shredding them ensures the Keychain is the sole location of the token.
- **When:** AFTER `openclaw channels status --probe` confirms Telegram is connected — not before. Verifying first ensures the token is safe in Keychain before removing the only other copy.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before implementing.**

### Requirements
- `.planning/REQUIREMENTS.md` §Channels — CHAN-01 defines the acceptance criteria for Phase 2 plans.

### Phase 1 Patterns (established, must not regress)
- Shell scripts: `#!/usr/bin/env zsh` + `set -euo pipefail` + stdout=JSON only + stderr=human logs
- Keychain naming: service = `openclaw.<name>` (lowercase, hyphens); env var = `OPENCLAW_<NAME>` (uppercase, underscores)
- Three-file secrets pipeline: `openclaw-secrets.sh` (launchd), `openclaw-env.sh` (shell), `secrets.sh` (provisioning)
- Explicit binary paths: always use `/opt/homebrew/bin/openclaw` (nvm shadows PATH with 2026.3.12)
- stow invocation: `stow --no-folding --dir=<REPO> --target=$HOME/.openclaw .` — see D-01b in Phase 1

### cc-openclaw SKILL.md reference (openclaw-add-channel)
- `cc-openclaw/.claude/skills/openclaw-add-channel/SKILL.md` — exact skill invocation, Keychain command, config block structure, env var naming, stow+restart sequence. Phase 2 plan 02-01 replicates this sequence directly rather than invoking the interactive skill (user is AFK).

</canonical_refs>

<code_context>
## Existing Code State (entering Phase 2)

### Gateway
- OpenClaw 2026.5.18 running on port 18789, LaunchAgent `ai.openclaw.gateway` registered
- `~/.openclaw/openclaw.json` is a stow symlink → `../Documents/agentic-setup/.openclaw/openclaw.json`
- Current `openclaw.json` has only `gateway` and `agents` blocks — no `channels` block

### Secrets Files (current state)
- `.openclaw/scripts/openclaw-secrets.sh`: has `OPENCLAW_TEST_SECRET` + node@24 PATH pin; NO Telegram export yet
- `.openclaw/scripts/openclaw-env.sh`: same state as openclaw-secrets.sh
- `secrets.sh`: SECRETS array has one entry (`openclaw.test-secret`); NO Telegram entry yet

### Keychain
- `openclaw.telegram-token` (account=`trilogy`): exists, empty value — Phase 1 placeholder
- `openclaw.telegram-main-bot-token` (account=`openclaw`): does NOT exist yet — to be created in Plan 02-01

### Pre-stow backups (plaintext token — to be shredded)
- `~/.openclaw/openclaw.json.pre-stow` — contains bot token plaintext
- `~/.openclaw/openclaw.json.bak` (and `.bak.1`, `.bak.2`) — may exist; same exposure

### Scripts
- `scripts/stow-deploy.sh`: canonical deploy entry point — removes `jobs.json`, runs stow

</code_context>

<deferred>
## Deferred Ideas

- **WhatsApp provisioning (CHAN-02):** Deferred by user on 2026-05-21. Will be planned as a separate phase or plan addendum when requested. Requires `@openclaw/whatsapp` plugin on a dedicated number.

</deferred>

---

*Phase: 2-core-channels*
*Context gathered: 2026-05-21*

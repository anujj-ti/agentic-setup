# Phase 2: Core Channels — Research

**Researched:** 2026-05-21
**Domain:** OpenClaw Telegram channel provisioning, bot pairing, round-trip verification
**Confidence:** HIGH

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| CHAN-01 | User can send and receive messages via Telegram bot provisioned through BotFather, with bot token stored in Keychain via `/openclaw-add-channel` | See §Standard Stack, §Architecture Patterns, §Pairing Flow, §Round-Trip Verification |
</phase_requirements>

> **Scope note:** WhatsApp (CHAN-02) is explicitly DEFERRED for this phase. All WhatsApp research is omitted per phase scope.

---

## Summary

Phase 2 wires a Telegram bot (@echo_sys_bot, already created via BotFather) into the OpenClaw gateway so the user has a working message surface before any agent is built. The bot token was previously used in a non-stow-managed config; it now needs to enter the formal secrets pipeline: stored in Keychain with the correct service name, exported via `openclaw-secrets.sh` to the gateway daemon, and referenced from `openclaw.json` via `${ENV_VAR}` substitution rather than hardcoded.

**Critical pre-existing state:** The gateway (2026.5.18) is already running and reading the stowed `openclaw.json` — but that config has no `channels` block, so Telegram is currently inactive. A Keychain entry `openclaw.telegram-token` exists from Phase 1 work but has an **empty value** (placeholder only). The actual token is visible in `~/.openclaw/openclaw.json.pre-stow` (not in git). Phase 2 must: (1) store the real token value into the Keychain entry (or create the correctly-named entry the skill expects), (2) add the `channels.telegram.accounts` block to `openclaw.json`, (3) export the env var to `openclaw-secrets.sh`, (4) stow and restart, (5) pair and verify round-trip.

**CLI PATH note:** The shell's `openclaw` binary on PATH is 2026.3.12 (nvm). The gateway runs 2026.5.18 from Homebrew. All plan steps must use `/opt/homebrew/bin/openclaw` explicitly, or prepend the node@24 PATH, until Phase 1's PATH fix is live in the shell session.

**Primary recommendation:** Run `/openclaw-add-channel` (the cc-openclaw skill) with agent ID as first argument. The skill handles Keychain storage, `openclaw.json` mutation, `openclaw-secrets.sh` update, stow, and restart in one guided sequence. The human must supply the token value when prompted (it is not echoed back). The Keychain entry naming the skill creates (`openclaw.telegram-<agentId>-bot-token`) differs from the placeholder entry created in Phase 1 (`openclaw.telegram-token`) — both entries can coexist; the skill creates the one the gateway will actually read.

---

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Bot token storage | macOS Keychain | — | Never in files; `security add-generic-password` is the only write path per CLAUDE.md |
| Token injection at daemon start | `openclaw-secrets.sh` (sourced by launchd) | `openclaw-env.sh` (shell sessions) | launchd has no shell profile; token must be exported explicitly before gateway process starts |
| Telegram channel config | `openclaw.json` `channels.telegram.accounts` | — | Gateway reads config at startup; `${ENV_VAR}` substitution resolves token at load time |
| Bot-to-user routing | `bindings[]` in `openclaw.json` | — | Maps incoming messages from a `channel:telegram/accountId:<id>` to the correct agent |
| Pairing approval | `openclaw pairing approve telegram <CODE>` CLI | — | One-time authorization step; approves a Telegram user ID to send DMs to the bot |
| Round-trip verification | `openclaw message send` CLI | Telegram manual send | Human sends → bot responds via agent, OR agent sends proactively via CLI |
| Channel status monitoring | `openclaw channels status` / `/openclaw-status` skill | gateway log grep | Confirms channel is connected and polling active |

---

## Standard Stack

### Core

| Tool | Version | Purpose | Why Standard |
|------|---------|---------|--------------|
| OpenClaw gateway | 2026.5.18 [VERIFIED: running process] | Telegram bot runtime, long-polling, message routing | The runtime everything runs on; already installed and stow-managed |
| macOS Keychain (`security` CLI) | Built-in [VERIFIED: machine] | Bot token storage | CLAUDE.md mandate — secrets never in files; `security` CLI is the write and read path |
| `openclaw-add-channel` skill | HEAD (cc-openclaw) [VERIFIED: read SKILL.md] | Guided Telegram provisioning: Keychain + config + stow + restart | Encodes all naming conventions and eliminates manual JSON editing risk |

### Supporting

| Tool | Purpose | When to Use |
|------|---------|-------------|
| `/opt/homebrew/bin/openclaw` (2026.5.18) | CLI for pairing, status, message send | Use explicitly in plan steps until nvm PATH issue is resolved in shell session |
| `openclaw pairing` | Approve inbound user pairing codes | After bot is connected — needed before any human can DM the bot |
| `openclaw channels status --probe` | Verify Telegram channel is polling | Post-restart verification step |
| `openclaw message send --channel telegram` | Proactive message send for round-trip test | Send bot→user message to confirm outbound works |

---

## Package Legitimacy Audit

Phase 2 installs no new npm packages. All tooling (OpenClaw gateway, cc-openclaw skills, macOS Keychain) was established in Phase 1. The `@openclaw/whatsapp` plugin is deferred.

**Packages removed due to slopcheck [SLOP] verdict:** none
**Packages flagged as suspicious [SUS]:** none

---

## Architecture Patterns

### System Architecture Diagram

```
HUMAN ──► Telegram ──► Telegram servers ──► OpenClaw gateway (18789)
                                               │
                            ┌──────────────────┴──────────────────┐
                            │  channels.telegram.accounts.main     │
                            │  botToken: ${OPENCLAW_TELEGRAM_       │
                            │            MAIN_BOT_TOKEN}            │
                            │  dmPolicy: "pairing"                 │
                            └──────────────────┬──────────────────┘
                                               │ (matched by binding)
                                               ▼
                            ┌─────────────────────────────────────┐
                            │  agents.list[agentId="main"]         │
                            │  (Phase 3 — not yet configured)      │
                            └─────────────────────────────────────┘

SECRETS INJECTION PATH (at daemon start, before gateway reads config):
  launchd ──► openclaw-secrets.sh
               └─ export OPENCLAW_TELEGRAM_MAIN_BOT_TOKEN=\
                   $(security find-generic-password \
                     -s 'openclaw.telegram-main-bot-token' -w)
                                               │
                                               ▼
                  openclaw.json: botToken: "${OPENCLAW_TELEGRAM_MAIN_BOT_TOKEN}"
                                               │
                                               ▼
                              Token resolved at gateway startup
```

### Recommended Project Structure (Phase 2 additions)

```
~/Documents/agentic-setup/
├── .openclaw/
│   ├── openclaw.json          ← channels.telegram.accounts block added by /openclaw-add-channel
│   └── scripts/
│       ├── openclaw-secrets.sh   ← OPENCLAW_TELEGRAM_MAIN_BOT_TOKEN export appended
│       └── openclaw-env.sh       ← same export appended (for shell session use)
└── secrets.sh                 ← "openclaw.telegram-main-bot-token|OPENCLAW_TELEGRAM_MAIN_BOT_TOKEN|..." appended
```

No new files are created in Phase 2. All changes are appended to existing files by the skill.

---

### Pattern 1: `/openclaw-add-channel` Invocation for Telegram

**What:** The cc-openclaw skill that handles the full Telegram provisioning sequence. It is invoked with the agent ID that will own this bot account.

**Invocation:**
```
/openclaw-add-channel main telegram
```

Arguments: `$0` = agent ID (e.g., `main`), `$1` = channel type (`telegram`).

**What the skill does (single-gateway path):** [CITED: cc-openclaw openclaw-add-channel/SKILL.md]

1. Detects single-gateway via `TIER_CONFIGS` check — falls through to `CONFIG=$OPENCLAW_REPO/.openclaw/openclaw.json`
2. Reads current config
3. **Asks the user for the bot token** — the skill does NOT read from Keychain automatically; you must provide the token value interactively
4. Stores in Keychain: `security add-generic-password -s "openclaw.telegram-main-bot-token" -a "openclaw" -w "<TOKEN>"`
5. Adds to `channels.telegram.accounts` in `openclaw.json`:
   ```json5
   "main": {
     "name": "<agent display name>",
     "enabled": true,
     "dmPolicy": "pairing",
     "botToken": "${OPENCLAW_TELEGRAM_MAIN_BOT_TOKEN}",
     "groupPolicy": "allowlist",
     "streaming": "partial"
   }
   ```
6. Adds binding: `{"agentId": "main", "match": {"channel": "telegram", "accountId": "main"}}`
7. Appends export to `openclaw-secrets.sh` AND `openclaw-env.sh`
8. Appends entry to `secrets.sh` SECRETS array
9. Runs: `rm -f ~/.openclaw/cron/jobs.json && cd "$OPENCLAW_REPO" && stow --no-folding -t ~ .`
10. Restarts: `launchctl kickstart -k gui/$(id -u)/ai.openclaw.gateway`
11. Verifies: `tail -30 ~/.openclaw/logs/gateway.log`

**Important — the skill ASKS for the token, it does not read from Keychain.** The human must type (or paste) the token value when prompted. The token value from `~/.openclaw/openclaw.json.pre-stow` is the live bot token.

---

### Pattern 2: Minimum `channels.telegram` Config Block

**What:** The minimum viable Telegram config that gets the bot connecting and polling. [VERIFIED: docs.openclaw.ai/channels/telegram + docs.openclaw.ai/gateway/config-channels]

```json5
// Source: docs.openclaw.ai/channels/telegram + openclaw-add-channel SKILL.md
// Token via env var — NEVER hardcoded. ${} substitution is supported in all string config values.
channels: {
  telegram: {
    accounts: {
      main: {
        enabled: true,
        dmPolicy: "pairing",
        botToken: "${OPENCLAW_TELEGRAM_MAIN_BOT_TOKEN}",
        groupPolicy: "allowlist",
        streaming: "partial"
      }
    }
  }
},
bindings: [
  { agentId: "main", match: { channel: "telegram", accountId: "main" } }
]
```

**Field explanation:**
- `dmPolicy: "pairing"` — unknown users get a one-time code; owner runs `openclaw pairing approve telegram <CODE>` to grant DM access. This is the safest default. [VERIFIED: docs.openclaw.ai/channels/telegram]
- `groupPolicy: "allowlist"` — bot does not respond in groups unless the group ID is in `groupAllowFrom`. Prevents accidental responses in group chats.
- `streaming: "partial"` — shows response chunks as they arrive in Telegram. Recommended for agent responses that take multiple seconds.
- `botToken: "${OPENCLAW_TELEGRAM_MAIN_BOT_TOKEN}"` — `${VAR}` syntax is supported for any string config value. [VERIFIED: docs.openclaw.ai/gateway/configuration — "Reference env vars in any config string value with `${VAR_NAME}`"]

**NEVER put the token at the top-level `channels.telegram` block.** The SKILL.md is explicit: "NEVER add botToken at the top-level telegram config — only in accounts." Adding the token at both levels causes duplicate responses. [CITED: cc-openclaw openclaw-add-channel/SKILL.md]

---

### Pattern 3: Env Var Naming Convention for Telegram Token

**Env var pattern:** `OPENCLAW_TELEGRAM_<AGENT_UPPER>_BOT_TOKEN` [CITED: cc-openclaw openclaw-add-channel/SKILL.md]

For agent ID `main`: `OPENCLAW_TELEGRAM_MAIN_BOT_TOKEN`

**Keychain service name:** `openclaw.telegram-<agentId>-bot-token` (lowercase, hyphens) [CITED: cc-openclaw openclaw-add-channel/SKILL.md]

For agent ID `main`: `openclaw.telegram-main-bot-token`

**Export line in `openclaw-secrets.sh`:**
```zsh
# Appended by /openclaw-add-channel — DO NOT edit manually
export OPENCLAW_TELEGRAM_MAIN_BOT_TOKEN=$(security find-generic-password -s 'openclaw.telegram-main-bot-token' -w "$KC")
```

Note: The add-secret SKILL.md uses a `$KC` variable for the keychain-db path. The add-channel SKILL.md uses `-a "openclaw"` as the account name. Both resolve the same Keychain entry.

**The `TELEGRAM_BOT_TOKEN` env var fallback:** OpenClaw supports `TELEGRAM_BOT_TOKEN` as a fallback for the default account only. [VERIFIED: docs.openclaw.ai/channels/telegram — "Env fallback: `TELEGRAM_BOT_TOKEN=...` (default account only)"] This is a convenience feature for quick testing, NOT the pattern to use in production config. The `${OPENCLAW_TELEGRAM_MAIN_BOT_TOKEN}` pattern in `openclaw.json` is the correct path because it integrates with the Keychain pipeline and survives restarts.

---

### Pattern 4: Pairing Flow

**What:** After the bot is connected, the first human user must be "paired" before the bot will respond to their DMs. With `dmPolicy: "pairing"`, unknown senders receive a one-time code. [VERIFIED: docs.openclaw.ai/channels/telegram]

**Flow:**

```
Step 1 — Human sends any message to @echo_sys_bot in Telegram
         Bot replies with a pairing code (e.g., "Your pairing code: ABCD1234")

Step 2 — Owner runs:
         /opt/homebrew/bin/openclaw pairing list telegram
         (shows pending pairing requests with codes)

Step 3 — Owner approves:
         /opt/homebrew/bin/openclaw pairing approve telegram ABCD1234

Step 4 — Bot confirms approval to the human in Telegram
         Human is now authorized to send DMs

Side effect: If no command owner exists yet (first pairing),
             OpenClaw also sets commands.ownerAllowFrom to this user's ID.
             [VERIFIED: docs.openclaw.ai/channels/telegram]
```

**Pairing code expiry:** Codes expire after 1 hour. If the code expires, the user must send another message to get a fresh code. [VERIFIED: docs.openclaw.ai/channels/telegram]

---

### Pattern 5: Round-Trip Verification

**Receive verification (human → bot):**
1. Human sends a message to @echo_sys_bot in Telegram
2. Bot sends pairing code (first time) or processes message
3. After pairing: any message gets a response from the gateway (or "no agent configured" if no agent is wired in Phase 2 — that is expected and acceptable as Phase 2 proof that the channel is live)

**Send verification (bot → human):**
```bash
# Get the human's Telegram user ID from the pairing flow or logs
# Then send a proactive message:
/opt/homebrew/bin/openclaw message send \
  --channel telegram \
  --account main \
  --target <YOUR_TELEGRAM_USER_ID> \
  --message "Round-trip test from Phase 2" \
  --json
```

The `--target` accepts a Telegram user ID (numeric) or @username. [VERIFIED: `openclaw message send --help` — live CLI inspection]

**Channel status verification:**
```bash
/opt/homebrew/bin/openclaw channels status --probe --json
```

For a connected channel, expect output showing `status: "connected"` or similar. [VERIFIED: `openclaw channels status --help` — live CLI inspection]

**Gateway log verification:**
```bash
tail -50 ~/.openclaw/logs/gateway.log | grep -E "telegram|starting provider|socket mode"
```

Success indicators from gateway logs: [VERIFIED: docs.openclaw.ai/channels/telegram]
- No `getMe returned 401` (bad token)
- No `409` conflicts (duplicate polling instance)
- `deleteWebhook` completes (bot was previously set to webhook mode — polling cleanup)
- `setMyCommands` succeeds
- Polling runner active (no `409` in getUpdates)

**`/openclaw-status` output for connected channel:**
The openclaw-status SKILL.md shows what it greps for: [CITED: cc-openclaw openclaw-status/SKILL.md]
```bash
tail -50 ~/.openclaw/logs/gateway.log | grep -E "telegram|slack|whatsapp|starting provider|socket mode|error"
```
A connected Telegram channel produces a log line matching `telegram` near `starting provider` or `socket mode`. If the only telegram-matching lines show errors, the channel failed to connect.

---

### Anti-Patterns to Avoid

- **Hardcoding `botToken` in `openclaw.json`:** The previous non-stow config had the token plaintext in `~/.openclaw/openclaw.json.pre-stow`. This violates CLAUDE.md. The new config must use `${OPENCLAW_TELEGRAM_MAIN_BOT_TOKEN}`. [CITED: CLAUDE.md Constraints → Secrets]
- **Adding `botToken` at the top-level `channels.telegram` block AND inside `accounts`:** Causes duplicate Telegram responses. The token goes ONLY inside `channels.telegram.accounts.<id>.botToken`. [CITED: cc-openclaw openclaw-add-channel/SKILL.md]
- **Using the nvm `openclaw` binary (2026.3.12) for pairing/status:** The shell PATH resolves to `~/.nvm/versions/node/v22.18.0/bin/openclaw` (2026.3.12) which may not be able to communicate with the 2026.5.18 gateway. Use `/opt/homebrew/bin/openclaw` explicitly. [VERIFIED: live machine state — two binaries found]
- **Reusing the empty `openclaw.telegram-token` Keychain entry:** The existing Keychain entry has service=`openclaw.telegram-token`, account=`trilogy`, empty value. The `/openclaw-add-channel` skill creates `openclaw.telegram-main-bot-token` with account=`openclaw`. These are different entries. Do not try to rename or repurpose the old one — let the skill create the correctly-named new entry.
- **Skipping the stow + restart after config changes:** Changes to `openclaw.json` are NOT picked up by the running gateway until a restart. `stow` updates the symlink, but the process must be restarted via `launchctl kickstart -k gui/$(id -u)/ai.openclaw.gateway`.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Telegram token storage and config wiring | Manual `security` command + sed/echo into `openclaw.json` | `/openclaw-add-channel main telegram` | Skill handles: Keychain storage with correct account name, config mutation, env var export to both script files, secrets.sh SECRETS array, stow, restart — all in correct order |
| Parsing Telegram user IDs for pairing | Reading Telegram API logs manually | `openclaw pairing list telegram` | Skill formats pending requests into a readable list with codes |
| Probing channel connectivity | Manually grepping gateway logs | `openclaw channels status --probe` | CLI parses gateway API response and surfaces connectivity state |
| Sending test messages | Writing a curl-based Telegram Bot API call | `openclaw message send --channel telegram` | Gateway handles auth, retry, and chat ID resolution |

**Key insight:** The cc-openclaw skills are the sole configuration path. Manually editing `openclaw.json` to add the channels block (rather than running the skill) produces a valid config but bypasses the Keychain storage step — the token ends up in the config file in plaintext.

---

## Runtime State Inventory

> Phase 2 is NOT a rename/refactor/migration phase, but it involves bridging pre-existing runtime state into the new managed pipeline.

| Category | Items Found | Action Required |
|----------|-------------|------------------|
| Stored data | `~/.openclaw/telegram/bot-info-default.json` — cached bot identity for @echo_sys_bot (ID: 8591778974, fetched 2026-05-20). Valid for 24h per docs. | No migration needed — gateway regenerates this cache from the live token after restart |
| Live service config | OpenClaw gateway 2026.5.18 running on port 18789, reading stowed `openclaw.json` with no `channels` block — Telegram inactive | Config update via `/openclaw-add-channel` + restart will activate |
| OS-registered state | LaunchAgent `ai.openclaw.gateway` is registered (confirmed by running process). Secrets.sh is sourced at startup. | No new launchd changes needed — skill handles restart via `launchctl kickstart` |
| Secrets/env vars | `openclaw.telegram-token` Keychain entry exists with **empty value** (created as placeholder, account=`trilogy`). `OPENCLAW_TELEGRAM_MAIN_BOT_TOKEN` not yet in `openclaw-secrets.sh`. | `/openclaw-add-channel` creates the correctly-named entry `openclaw.telegram-main-bot-token` (account=`openclaw`). The empty placeholder can remain — it is inert. |
| Build artifacts | `~/.openclaw/openclaw.json.pre-stow` contains bot token in plaintext (not in git). This file is outside the repo at `~/.openclaw/` — not stowed, not tracked. | Shred after Phase 2 is verified: `rm ~/.openclaw/openclaw.json.pre-stow ~/.openclaw/openclaw.json.bak ~/.openclaw/openclaw.json.bak.1 ~/.openclaw/openclaw.json.bak.2` |

---

## Common Pitfalls

### Pitfall 1: Token in Config vs Token in Keychain
**What goes wrong:** The bot connects (token works) but the token is now in `openclaw.json` in plaintext, which gets committed to git.
**Why it happens:** Someone manually edits `openclaw.json` to add the token as a literal string rather than using the skill.
**How to avoid:** Run `/openclaw-add-channel` and let the skill write `"botToken": "${OPENCLAW_TELEGRAM_MAIN_BOT_TOKEN}"`. Never type the actual token value into any file. The skill stores it in Keychain and only the env var reference goes into the config.
**Warning signs:** `grep -r "botToken" .openclaw/openclaw.json` shows a numeric ID instead of `${...}`. `git diff .openclaw/openclaw.json` contains a token-like string.

### Pitfall 2: Duplicate Telegram Responses
**What goes wrong:** Every user message produces two bot replies.
**Why it happens:** `botToken` appears at BOTH `channels.telegram.botToken` (top level) AND `channels.telegram.accounts.main.botToken`. OpenClaw starts two polling connections for the same bot.
**How to avoid:** Keep token ONLY in `channels.telegram.accounts.<id>.botToken`. The skill enforces this automatically. If manually editing: verify with `openclaw config get channels.telegram.botToken` — should return empty.
**Warning signs:** Two identical responses appear in Telegram for every message.

### Pitfall 3: CLI Version Mismatch (2026.3.12 vs 2026.5.18)
**What goes wrong:** `openclaw channels status` reports "Gateway not reachable" even though the gateway is running. `openclaw pairing list telegram` returns no results or errors.
**Why it happens:** The nvm-managed binary (`~/.nvm/versions/node/v22.18.0/bin/openclaw`) is 2026.3.12. It may use a different internal API protocol than the running 2026.5.18 gateway.
**How to avoid:** Use `/opt/homebrew/bin/openclaw` (2026.5.18) in all Phase 2 plan steps. The PATH issue is a Phase 1 residual. Alternatively, add the node@24 PATH export to the shell session: `export PATH="/opt/homebrew/opt/node@24/bin:$PATH"`.
**Warning signs:** `openclaw --version` shows 2026.3.12; `which openclaw` returns an nvm path.

### Pitfall 4: Keychain Entry Not Read at Daemon Start
**What goes wrong:** Gateway starts but Telegram doesn't connect. Logs show token missing or `getMe returned 401`.
**Why it happens:** `OPENCLAW_TELEGRAM_MAIN_BOT_TOKEN` was added to `openclaw-secrets.sh` AFTER the last gateway start — the daemon still has the old (empty) environment.
**How to avoid:** Always restart the gateway AFTER updating `openclaw-secrets.sh`. The restart sequence: stow → `launchctl kickstart -k gui/$(id -u)/ai.openclaw.gateway` → wait 5 seconds → check logs. The skill does this automatically if run completely.
**Warning signs:** `source ~/.openclaw/scripts/openclaw-env.sh && echo $OPENCLAW_TELEGRAM_MAIN_BOT_TOKEN | wc -c` returns 1 (empty string + newline).

### Pitfall 5: pairing approve Before Bot Is Connected
**What goes wrong:** `openclaw pairing list telegram` returns no pending requests even after sending a DM to the bot.
**Why it happens:** The bot token is in the config but the gateway is not polling yet (either restart didn't happen, or the token is invalid).
**How to avoid:** Verify channel connectivity with `openclaw channels status --probe` BEFORE sending the pairing DM. If the channel shows disconnected, fix the connection first.
**Warning signs:** `openclaw channels status --probe` shows telegram as not connected; sending DM to bot produces no pairing code reply.

### Pitfall 6: `tokenFile` with Symlinks Rejected
**What goes wrong:** Using `tokenFile` to point at `~/.openclaw/openclaw.json` or any stow-symlinked path causes the gateway to reject the token file.
**Why it happens:** OpenClaw's `tokenFile` option explicitly rejects symlinks. [VERIFIED: docs.openclaw.ai/gateway/config-channels — "tokenFile (regular file only; symlinks rejected)"]
**How to avoid:** Do not use `tokenFile` for Telegram. Use `botToken: "${ENV_VAR}"` instead. The env var path works correctly with symlinked config files.

### Pitfall 7: dmPolicy "open" Exposes Bot Publicly
**What goes wrong:** Anyone who discovers the bot's @username can send it commands.
**Why it happens:** `dmPolicy: "open"` with `allowFrom: ["*"]` is set — possibly copied from a quick-start example.
**How to avoid:** Use `dmPolicy: "pairing"` (the default). The pairing flow requires owner approval for each new sender. For this personal operations hub, pairing is the correct policy.

---

## Code Examples

### Verified: channels.telegram config block (token via env var)
```json5
// Source: docs.openclaw.ai/channels/telegram + openclaw-add-channel SKILL.md
// Token MUST be via env var — NEVER hardcoded.
// ${} substitution supported in all string values per docs.openclaw.ai/gateway/configuration
channels: {
  telegram: {
    accounts: {
      main: {
        enabled: true,
        dmPolicy: "pairing",
        botToken: "${OPENCLAW_TELEGRAM_MAIN_BOT_TOKEN}",
        groupPolicy: "allowlist",
        streaming: "partial"
      }
    }
  }
},
bindings: [
  { agentId: "main", match: { channel: "telegram", accountId: "main" } }
]
```

### Verified: secrets pipeline lines for Telegram token
```zsh
# Appended to .openclaw/scripts/openclaw-secrets.sh by /openclaw-add-channel
# Source: cc-openclaw openclaw-add-channel SKILL.md
export OPENCLAW_TELEGRAM_MAIN_BOT_TOKEN=$(security find-generic-password \
  -s 'openclaw.telegram-main-bot-token' \
  -w 2>/dev/null)
```

```zsh
# Appended to .openclaw/scripts/openclaw-env.sh by /openclaw-add-channel
export OPENCLAW_TELEGRAM_MAIN_BOT_TOKEN=$(security find-generic-password \
  -s 'openclaw.telegram-main-bot-token' \
  -w 2>/dev/null || true)
```

```zsh
# Entry appended to secrets.sh SECRETS array by /openclaw-add-channel
# Source: cc-openclaw openclaw-add-channel SKILL.md
"openclaw.telegram-main-bot-token|OPENCLAW_TELEGRAM_MAIN_BOT_TOKEN|Telegram bot token for @echo_sys_bot (main agent)"
```

### Verified: Pairing flow commands
```bash
# Source: docs.openclaw.ai/channels/telegram [VERIFIED]
# Step 1: Human sends DM to @echo_sys_bot in Telegram
# Step 2: Bot replies with pairing code

# Step 3: List pending pairing requests
/opt/homebrew/bin/openclaw pairing list telegram

# Step 4: Approve (replace CODE with actual code from step 3)
/opt/homebrew/bin/openclaw pairing approve telegram CODE
```

### Verified: Round-trip verification commands
```bash
# Source: live CLI inspection [VERIFIED: openclaw message send --help]
# Verify outbound (bot → human) — get your Telegram user ID from pairing flow first
/opt/homebrew/bin/openclaw message send \
  --channel telegram \
  --account main \
  --target <TELEGRAM_USER_ID> \
  --message "Phase 2 round-trip test" \
  --json

# Verify channel status
/opt/homebrew/bin/openclaw channels status --probe --json

# Verify via gateway logs
tail -50 ~/.openclaw/logs/gateway.log | \
  grep -E "telegram|starting provider|socket mode|error" | head -20
```

### Verified: Keychain store for Telegram token (what the skill does)
```bash
# Source: cc-openclaw openclaw-add-channel SKILL.md
# The skill prompts for the token and stores it — never echo it
security add-generic-password \
  -s "openclaw.telegram-main-bot-token" \
  -a "openclaw" \
  -w "<TOKEN_VALUE_FROM_BOTFATHER>"
```

### Verified: Verify token is in Keychain (non-revealing check)
```bash
# Source: cc-openclaw openclaw-add-secret SKILL.md (verification pattern)
source ~/.openclaw/scripts/openclaw-env.sh
echo $OPENCLAW_TELEGRAM_MAIN_BOT_TOKEN | wc -c
# Should be > 1 (a Telegram bot token is ~46 chars; empty string + newline = 1)
```

### Verified: Gateway restart sequence (Phase 2)
```bash
# Source: cc-openclaw openclaw-restart SKILL.md (single-gateway path)
OPENCLAW_REPO=$(readlink ~/.openclaw/openclaw.json | sed 's|/.openclaw/openclaw.json||')
rm -f ~/.openclaw/cron/jobs.json
cd "$OPENCLAW_REPO" && stow --no-folding -t ~ .
launchctl kickstart -k "gui/$(id -u)/ai.openclaw.gateway"
sleep 5
tail -30 ~/.openclaw/logs/gateway.log | grep -E "telegram|starting provider|error"
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Hardcoded `botToken` in `openclaw.json` (pre-stow config) | `botToken: "${OPENCLAW_TELEGRAM_MAIN_BOT_TOKEN}"` with Keychain pipeline | Phase 2 | Token never in files; survives git history; disaster recovery via secrets.sh |
| Top-level `channels.telegram.botToken` | `channels.telegram.accounts.<id>.botToken` | OpenClaw multi-account era | Enables multiple bots per gateway; prevents duplicate responses |
| `npm install -g openclaw` CLI on nvm node | `/opt/homebrew/bin/openclaw` on node@24 | Phase 1 partial completion | 2026.5.18 binary at brew path; launchd daemon also uses brew node@24 |

**Deprecated/outdated:**
- `TELEGRAM_BOT_TOKEN` bare env var: Works as a fallback for the default account but bypasses the Keychain pipeline and is not agent-scoped. Use `${OPENCLAW_TELEGRAM_MAIN_BOT_TOKEN}` in config instead.

---

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | The token in `~/.openclaw/openclaw.json.pre-stow` is still valid (bot was not revoked via BotFather) | Runtime State Inventory | Plan step to test token validity must handle the case where user needs to regenerate token from BotFather |
| A2 | `/openclaw-add-channel` does NOT automatically read from the existing `openclaw.telegram-token` Keychain entry — it always prompts the human for the token value | Pattern 1 | If the skill auto-reads Keychain, the plan step that says "provide token when prompted" is wrong |
| A3 | `channels.telegram.accounts` structure is the correct pattern for 2026.5.18 (not top-level `channels.telegram.botToken`) | Pattern 2 | The SKILL.md is definitive here; risk is low since it's cross-verified with docs |
| A4 | `openclaw channels status --probe` output format in 2026.5.18 clearly indicates connected vs disconnected for Telegram | Round-Trip Verification | If the output format changed, the verification step needs adjustment |

---

## Open Questions

1. **Does the token in pre-stow backup need to be regenerated?**
   - What we know: The token was in use as recently as Phase 1 (2026-05-20); bot-info cache shows it was successfully fetched that day.
   - What's unclear: Has it been invalidated since? BotFather tokens do not expire on their own but can be revoked manually.
   - Recommendation: Treat the token as valid. If `getMe returned 401` appears in gateway logs after adding it, regenerate via BotFather (`/revoke` + new token).

2. **What does the gateway respond when an agent is not yet configured?**
   - What we know: Phase 2 has no agent in `agents.list`. The Telegram channel will be active but there's no agent to route messages to.
   - What's unclear: Does the bot send an error reply, a "no agent" message, or silence?
   - Recommendation: This is a known Phase 2 state. The round-trip verification for Phase 2 is: (a) channel is connected in `/openclaw-status`, (b) pairing flow completes, (c) `openclaw message send` succeeds outbound. Agent response verification is Phase 3's responsibility.

---

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| OpenClaw gateway | Telegram channel runtime | Yes (running) | 2026.5.18 [VERIFIED: process inspection] | — |
| `/opt/homebrew/bin/openclaw` CLI | Pairing, status, message send | Yes | 2026.5.18 [VERIFIED: machine] | Set `export PATH="/opt/homebrew/opt/node@24/bin:$PATH"` in session |
| macOS Keychain (`security` CLI) | Token storage | Yes (built-in) | macOS built-in | — |
| Telegram bot (@echo_sys_bot) | Message receive/send | Yes [VERIFIED: bot-info cache shows valid bot] | — | Regenerate token via BotFather if needed |
| `~/.openclaw/openclaw.json` stow symlink | Skill repo detection | Yes [VERIFIED: `ls -la ~/.openclaw/openclaw.json`] | — | — |
| `openclaw-secrets.sh` (stowed) | Token injection at daemon start | Yes (exists at `.openclaw/scripts/openclaw-secrets.sh`) | — | — |

**Missing dependencies with no fallback:** none

**Missing dependencies with fallback:**
- `openclaw` binary on interactive shell PATH at 2026.5.18: Use `/opt/homebrew/bin/openclaw` explicitly in all plan steps

---

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | Shell assertions + live OpenClaw CLI verification |
| Config file | none — verification is live gateway state checks |
| Quick run command | `/opt/homebrew/bin/openclaw channels status --probe --json` |
| Full suite command | See Phase Requirements → Test Map below |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| CHAN-01 | Token is in Keychain (not plaintext in files) | smoke | `security find-generic-password -s 'openclaw.telegram-main-bot-token' -w 2>/dev/null \| wc -c \| grep -v '^1$'` | ❌ Wave 0 |
| CHAN-01 | `openclaw.json` uses `${ENV_VAR}` for botToken, not literal token | smoke | `grep -q 'OPENCLAW_TELEGRAM_MAIN_BOT_TOKEN' ~/.openclaw/openclaw.json && ! grep -q 'AAG0\|botToken.*:.*[0-9]\{10\}' ~/.openclaw/openclaw.json` | ❌ Wave 0 |
| CHAN-01 | Gateway sees Telegram channel as connected | smoke | `/opt/homebrew/bin/openclaw channels status --probe --json 2>/dev/null \| python3 -c "import json,sys; d=json.load(sys.stdin); assert any('telegram' in str(c) for c in d.get('channels',[]))"` | ❌ Wave 0 |
| CHAN-01 | Pairing flow completed — at least one paired user | manual | `openclaw pairing list telegram` (human verifies no error) | manual |
| CHAN-01 | Round-trip — bot can send to user | smoke | `/opt/homebrew/bin/openclaw message send --channel telegram --account main --target <USER_ID> --message "CHAN-01 verification" --json 2>/dev/null \| python3 -c "import json,sys; d=json.load(sys.stdin); assert d.get('ok')"` | manual-setup |
| CHAN-01 | Both channels appear in `/openclaw-status` | manual | Run `/openclaw-status` skill and verify Telegram listed as active | manual |

### Sampling Rate

- **Per task commit:** `grep -q 'OPENCLAW_TELEGRAM_MAIN_BOT_TOKEN' ~/.openclaw/openclaw.json && echo token-in-env-var-format`
- **Per wave merge:** Full test map above
- **Phase gate:** All automated smoke tests pass + manual pairing flow complete + round-trip message verified before moving to Phase 3

### Wave 0 Gaps

- [ ] `scripts/chan-verify.sh` — smoke test runner for CHAN-01 checks (token in Keychain, env var in config, channels status)
- [ ] No new skill files needed — `/openclaw-add-channel` handles provisioning

---

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | Partial | Telegram bot token authenticates the bot with Telegram servers; stored in Keychain, never in files |
| V3 Session Management | No | Session management is Telegram's responsibility; pairing handles DM access control |
| V4 Access Control | Yes | `dmPolicy: "pairing"` restricts who can send DMs; `groupPolicy: "allowlist"` restricts group access |
| V5 Input Validation | No | No user-facing input processing in Phase 2 (no agent yet) |
| V6 Cryptography | No | No custom crypto; Keychain handles token encryption at rest |

### Known Threat Patterns for this Stack

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Bot token in `openclaw.json` (plaintext) | Information Disclosure | `${OPENCLAW_TELEGRAM_MAIN_BOT_TOKEN}` env var substitution; token stored in Keychain only |
| Bot token in pre-stow backup files | Information Disclosure | Shred after Phase 2 verified: `rm ~/.openclaw/openclaw.json.pre-stow *.bak*` |
| Open DM access (any Telegram user can command the bot) | Elevation of Privilege | `dmPolicy: "pairing"` — every new sender requires owner approval; do NOT use `dmPolicy: "open"` |
| Token committed to git history | Information Disclosure | `grep -r "AAG0\|botToken.*[0-9]" .openclaw/` before every commit; `.gitignore` pattern for token-like strings |
| Duplicate polling (token at two levels) | Spoofing | Token ONLY in `accounts.<id>.botToken`, never at top level; skill enforces this |

---

## Sources

### Primary (HIGH confidence)
- `cc-openclaw/.claude/skills/openclaw-add-channel/SKILL.md` — exact skill invocation, Keychain command, config block, env var naming, file update sequence, stow+restart procedure [VERIFIED: read in this session]
- `cc-openclaw/.claude/skills/openclaw-status/SKILL.md` — status check commands, single-gateway log grep pattern [VERIFIED: read in this session]
- `docs.openclaw.ai/channels/telegram` — channels.telegram schema, `TELEGRAM_BOT_TOKEN` env fallback, dmPolicy options, pairing flow commands, `openclaw pairing list/approve` CLI [VERIFIED: WebFetch]
- `docs.openclaw.ai/gateway/config-channels` — full channels.telegram schema, accounts sub-structure, dmPolicy definitions, minimum required fields [VERIFIED: WebFetch]
- `docs.openclaw.ai/gateway/configuration` — `${ENV_VAR}` substitution support in string config values, SecretRef format [VERIFIED: WebFetch]
- Live machine inspection — gateway process (2026.5.18 at `/opt/homebrew/lib/node_modules/openclaw`), Keychain entry state, bot-info cache, pre-stow config state [VERIFIED: bash commands]
- `openclaw --help`, `openclaw channels --help`, `openclaw message send --help`, `openclaw pairing --help` — CLI commands available in 2026.5.18 [VERIFIED: live CLI]

### Secondary (MEDIUM confidence)
- `~/.openclaw/openclaw.json.pre-stow` — confirmed bot username (@echo_sys_bot), bot ID (8591778974), previous working config structure [VERIFIED: file read]
- `~/.openclaw/telegram/bot-info-default.json` — bot info cached 2026-05-20, confirms bot is live [VERIFIED: file read]

### Tertiary (LOW confidence)
- None

---

## Metadata

**Confidence breakdown:**
- Skill behavior (Pattern 1): HIGH — read directly from cc-openclaw SKILL.md
- channels.telegram config: HIGH — cross-verified between SKILL.md and docs.openclaw.ai
- Pairing flow: HIGH — documented on docs.openclaw.ai/channels/telegram
- Runtime state: HIGH — verified by direct machine inspection
- Token security: HIGH — CLAUDE.md mandate + verified in pre-stow backup

**Research date:** 2026-05-21
**Valid until:** 2026-06-21 (OpenClaw releases frequently; verify gateway version before executing)

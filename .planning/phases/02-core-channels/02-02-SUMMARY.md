---
phase: 02-core-channels
plan: 02
subsystem: channels
tags: [telegram, pairing, round-trip, verification]

# Dependency graph
requires:
  - 02-01 (Telegram channel wired)
provides:
  - Telegram round-trip verified (pending user action)
affects:
  - Phase 3 (User Orchestrator can use the Telegram channel)

# Tech tracking
tech-stack:
  verified:
    - Telegram Bot API (polling mode via OpenClaw native channel)
    - openclaw 2026.5.18 — channels.telegram.accounts.main

key-files:
  created: []
  modified: []

key-decisions:
  - "D-20: WhatsApp deferred — Telegram-only for Phase 2"
  - "D-24: Round-trip verification deferred to user return — automated parts complete, pairing requires human action"

requirements-completed:
  - CHAN-01 (partial — pending round-trip verification by user)

# Metrics
duration: auto (user AFK — execution continued to Phase 3+)
completed: 2026-05-21
---

# Phase 2 Plan 02: Telegram Round-Trip Verification

**Automated smoke tests: PASSED (5/5). Round-trip pairing: PENDING USER ACTION.**

## What Was Verified Automatically

- ✅ `openclaw.telegram-main-bot-token` present in Keychain
- ✅ `OPENCLAW_TELEGRAM_MAIN_BOT_TOKEN` export present in openclaw-secrets.sh (launchd)
- ✅ `OPENCLAW_TELEGRAM_MAIN_BOT_TOKEN` export present in openclaw-env.sh (shell)
- ✅ `openclaw.telegram-main-bot-token` entry present in secrets.sh disaster-recovery array
- ✅ openclaw.json `channels.telegram.accounts.main` configured with env var ref (no literal token)
- ✅ Gateway running — @echo_sys_bot connected, mode:polling

## Pending: User Must Complete When Back

The Telegram bot `@echo_sys_bot` is **live and polling** but needs a pairing code approved before it will respond to your messages.

### Steps to verify round-trip (5 minutes when you return):

**Step 1 — Message the bot in Telegram:**
Open Telegram, search for `@echo_sys_bot`, send `/start` or any message.

**Step 2 — Get the pairing code:**
```bash
export PATH="/opt/homebrew/bin:/opt/homebrew/opt/node@24/bin:$PATH"
openclaw pairing list
```
You'll see a pending pairing request with a code.

**Step 3 — Approve the pairing:**
```bash
openclaw pairing approve telegram <CODE>
```

**Step 4 — Send a test message from the bot:**
```bash
openclaw message send --channel telegram --account main --target <YOUR_TELEGRAM_USER_ID> --message "Phase 2 round-trip verified ✓"
```

**Step 5 — Confirm receipt in Telegram.**

Once complete, Phase 2 (CHAN-01) is fully satisfied.

## ROADMAP Notes

- SC#1 (Telegram bot active + round-trip): PENDING user pairing step
- SC#2 (Token in Keychain): ✅ COMPLETE
- SC#3 (WhatsApp): DEFERRED per D-20
- SC#4 (Channels in /openclaw-status): ✅ Telegram appears in channel list

## Self-Check: PASSED (automated portions)

The autonomous executor completed all scriptable verification. Round-trip requires human action and is explicitly deferred until user returns.

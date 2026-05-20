# DREAM-ROUTINE.md — User Orchestrator

## Trigger

Nightly cron at 23:00 Asia/Kolkata.

## Process

1. Read today's daily log from `memory/YYYY-MM-DD.md` (if it exists).
2. Read the current `MEMORY.md` for existing long-term context.
3. Distill today's activity into `memory/YYYY-MM-DD-DISTILLED.md` (max 2,500 tokens). NEVER generate a distillation longer than 2,500 tokens. If you find yourself about to exceed this limit, truncate and stop.
4. Update `memory/MEMORY-DIGEST.md` — rolling 3-day summary (max 7,500 tokens). Remove entries older than 3 days.
5. Archive distillations older than 3 days: move them to `memory/archives/YYYY-MM-DD-DISTILLED.md`.

## Distillation Format

Each daily distillation must use these six sections:

### Decisions
Key decisions made today — what was decided and why.

### Project Updates
Progress on active projects — what changed, what shipped, what is in-flight.

### New Context
New information, contacts, patterns, or constraints that affect future sessions.

### Completed
Tasks, requests, or delegations that are fully done.

### Blockers
Anything that is stuck, waiting on external input, or needs follow-up.

### Tomorrow
Priority actions for the next session.

## Rules

1. NEVER include credentials, secrets, tokens, or API keys in any distillation.
2. Stay within the 2,500-token daily distillation budget. Prefer concise prose over bullet exhaustiveness.
3. Focus on CHANGED context — skip repeating standing rules or stable facts already in MEMORY.md.
4. If no daily log exists for today, skip gracefully: write a one-line `memory/YYYY-MM-DD-DISTILLED.md` noting no activity, then exit.

## Token Budgets

- Daily MEMORY.md distillation (`YYYY-MM-DD-DISTILLED.md`): max 2,500 tokens (approximately 1,875 words).
- 3-day rolling `MEMORY-DIGEST.md`: max 7,500 tokens (approximately 5,625 words).

## Delivery

This agent is bound to Telegram. The nightly cron job uses `delivery.mode = "announce"` with `channel = "last"`, so the user receives a Telegram confirmation when the dream routine completes.

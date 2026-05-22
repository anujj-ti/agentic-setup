# DREAM-ROUTINE.md — Task Orchestrator

## Trigger

Nightly cron at 23:05 Asia/Kolkata. (Five minutes after User Orchestrator to prevent concurrent LLM load.)

## Process

1. Read today's daily log from `memory/YYYY-MM-DD.md` (if it exists).
2. Read the current `MEMORY.md` for existing long-term context.
3. Distill today's activity into `memory/YYYY-MM-DD-DISTILLED.md` (max 2,500 tokens). NEVER generate a distillation longer than 2,500 tokens. If you find yourself about to exceed this limit, truncate and stop.
3.5. Merge top cross-silo Synapse learnings into MEMORY.md:
   ```zsh
   SYNAPSE_NEW=$(bash ~/Documents/agentic-setup/scripts/synapse-query-learnings.sh \
     project.edullm-sat-math agent-orchestration 5 2>/dev/null)
   ```
   - Append a `## Cross-Silo Learnings (updated: YYYY-MM-DD)` section to MEMORY.md if SYNAPSE_NEW is non-empty.
   - Replace any prior `## Cross-Silo Learnings` section (do not accumulate duplicates).
   - Cap at 500 tokens of new Synapse content per dream cycle (D-311). If the bullets exceed 500 tokens (~375 words), include only the top 5 bullets.
   - If SYNAPSE_NEW is empty (Synapse unavailable): skip this step — MEMORY.md is left unchanged.
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

- Daily distillation (`YYYY-MM-DD-DISTILLED.md`): max 2,500 tokens (approximately 1,875 words).
- 3-day rolling `MEMORY-DIGEST.md`: max 7,500 tokens (approximately 5,625 words).

## Pattern Counter Preservation (EVOL-02 — MANDATORY)

The ## Pattern Counter section in MEMORY.md MUST be preserved verbatim during every distillation run.
- Do NOT summarize this section
- Do NOT compress the table rows
- Do NOT omit any row even if the count is 1
- Copy the entire section — from `## Pattern Counter` through `<!-- END: pattern_counter -->` — into the distilled MEMORY.md output unchanged
- This section is protected by the `<!-- PRESERVE: pattern_counter -->` marker

**If the dream routine token budget would be exceeded by preserving this section: compress OTHER sections first. The Pattern Counter is the last section to be compressed.**

Preservation rule in code terms: when generating the distilled MEMORY.md output, always include the Pattern Counter section exactly as-is. Do NOT subject it to the distillation logic.

## Delivery

This agent has no Telegram channel binding. The nightly cron job uses `delivery.mode = "silent"` — no channel notification is sent. Completion is logged internally only.

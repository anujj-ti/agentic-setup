# DREAM-ROUTINE.md — DevBot Nightly Distillation

## Trigger

Nightly cron at 23:15 Asia/Kolkata. Staggered after task-orchestrator (23:05) and ci-monitor (23:10) to prevent concurrent LLM load.

## Process

1. Read `memory/MEMORY.md` for existing long-term DevBot context.
2. Scan `memory/` for any daily activity logs written during today's sessions (if any).
3. Query Synapse for cross-silo learnings:
   ```zsh
   SYNAPSE_GH=$(bash ~/Documents/agentic-setup/scripts/synapse-query-learnings.sh \
     project.agentic-setup github 5 2>/dev/null)
   SYNAPSE_CI=$(bash ~/Documents/agentic-setup/scripts/synapse-query-learnings.sh \
     project.agentic-setup ci-monitor 5 2>/dev/null)
   ```
4. Distill into `memory/YYYY-MM-DD-DISTILLED.md` (max 2,500 tokens). If no activity today: write a one-line entry noting no activity and exit.
5. Update `memory/MEMORY.md` with a `## Cross-Silo Learnings (updated: YYYY-MM-DD)` section — replace any prior version. Cap at 500 tokens of new Synapse content per cycle (D-311 pattern).
6. Update `memory/MEMORY-DIGEST.md` — rolling 3-day GitHub activity digest (max 7,500 tokens).
7. Archive distillations older than 3 days: move to `memory/archives/YYYY-MM-DD-DISTILLED.md`.

## Distillation Format

Each daily distillation uses these sections:

### GitHub Activity
Issues created, PRs reviewed, PRs merged, CI failures triaged — with repo and number references.

### PR Patterns
Recurring PR patterns observed: stale reviewers, common CI failure steps, repos with frequent failures.

### Per-Repo Context Updates
Any changes to per-repo CONTEXT.md files made today.

### Blockers
Issues that could not be completed — awaiting CI, awaiting review, missing context.

### Cross-Silo Learnings
Bullets from SYNAPSE_GH and SYNAPSE_CI, if non-empty. Cap at 500 tokens.

## Rules

1. NEVER include credentials, tokens, or API keys in any distillation.
2. Stay within 2,500-token daily distillation budget.
3. Focus on CHANGED context — skip repeating standing rules already in MEMORY.md.
4. Synapse unavailability is non-blocking — skip the Cross-Silo Learnings section if both variables are empty.

## Token Budgets

- Daily distillation: max 2,500 tokens.
- 3-day rolling MEMORY-DIGEST.md: max 7,500 tokens.
- Cross-silo Synapse section: max 500 tokens per cycle.

## Delivery

Silent. DevBot has no Telegram channel binding — sessions_spawn only. No channel notification sent.

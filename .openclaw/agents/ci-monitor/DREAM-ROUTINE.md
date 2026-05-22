# DREAM-ROUTINE.md — CI Monitor

## Trigger

Nightly cron at 23:10 Asia/Kolkata. (Five minutes after Task Orchestrator's 23:05 run to avoid concurrent LLM load.)

## Memory Location

`~/.openclaw/agents/ci-monitor/memory/` — create this directory if absent.

The routine writes distilled context to `memory/MEMORY.md` in the agent workspace.

## Process

Run the following steps in order:

### Step 1 — Read recent CI state

Read `state/last-seen-runs.json` to understand CI activity in the past 24 hours. Count:
- Total runs seen
- Failure runs (conclusion = "failure" or "cancelled")
- Success runs

If the state file is empty or shows no failures in the past 24 hours: write a one-line entry to `memory/MEMORY.md`:

```
No CI failures in past 24h — $(date +%Y-%m-%d)
```

Then exit. No further processing needed.

### Step 2 — Read existing CI failure pattern context

Read `memory/MEMORY.md` if it exists. This provides accumulated CI failure patterns from prior dream cycles.

### Step 3 — Query Synapse for cross-silo learnings

Query Synapse with two domain tags: `ci` (own domain) and `github` (cross-silo from DevBot):

```zsh
SYNAPSE_CI=$(zsh ~/Documents/agentic-setup/scripts/synapse-query-learnings.sh \
  project.agentic-setup ci 5 2>/dev/null)
SYNAPSE_GH=$(zsh ~/Documents/agentic-setup/scripts/synapse-query-learnings.sh \
  project.agentic-setup github 3 2>/dev/null)
```

- Cap: include at most 500 tokens of new Synapse content per cycle (per D-311). If Synapse returns more bullets than fit, include only the top 3 by recency.
- Synapse unavailability is non-blocking — if both variables are empty, skip the `## Cross-Silo Learnings` section entirely.

### Step 4 — Distill CI failure patterns

From the state file and existing MEMORY.md, identify recurring failures:
- Same repo + same workflow + same failing step appearing in multiple sessions
- New failure patterns seen tonight that aren't already in MEMORY.md

Focus only on **recurring** patterns. Single-occurrence failures do not belong in long-term memory.

### Step 5 — Write memory/MEMORY.md

Overwrite `memory/MEMORY.md` with the distilled output. Structure:

```markdown
# CI Monitor Memory

## CI Failure Patterns

<!-- Recurring failures by repo/workflow. Only patterns seen 2+ times. -->
- [repo/workflow]: [description of recurring failure]

## Cross-Silo Learnings

<!-- Bullets from Synapse ci + github tags. Max 500 tokens of new content per cycle. -->
- [learning from Synapse]

## Last Updated

YYYY-MM-DD HH:MM Asia/Kolkata
```

**Token budget:** Keep MEMORY.md under 1,000 tokens total. CI Monitor is a narrow-domain agent — less historical context is needed vs. orchestrators. If the budget is exceeded, compress the `## CI Failure Patterns` section first (summarize patterns into single-line entries). The `## Cross-Silo Learnings` section is compressed last.

## Rules

1. NEVER include credentials, tokens, run IDs, or user-identifiable data in MEMORY.md.
2. Synapse content cap: at most 500 tokens of new Synapse bullets per cycle (D-311). If more is returned, include only the top 3 learnings by recency.
3. If state/last-seen-runs.json is empty or shows no failures in 24h: write one line and exit — no full distillation needed.
4. Synapse unavailability is non-blocking — skip the `## Cross-Silo Learnings` section if both SYNAPSE_CI and SYNAPSE_GH are empty.
5. Keep MEMORY.md under 1,000 tokens total.

## Delivery

Silent — CI Monitor has no Telegram or other channel binding. The dream routine completes without notification. Completion is logged to stderr only.

# AGENTS.md — CI Monitor

## Step 0 — Query Synapse Learnings (MANDATORY, before CI polling)

Before confirming state files or running poll-ci.sh, query Synapse for relevant learnings.
CI Monitor queries two domain tags: `ci` (its own domain) and `github` (cross-silo — DevBot writes learnings here that are relevant to CI polling patterns).

```zsh
SYNAPSE_CI=$(zsh ~/Documents/agentic-setup/scripts/synapse-query-learnings.sh \
  project.agentic-setup ci 3 2>/dev/null)
SYNAPSE_GH=$(zsh ~/Documents/agentic-setup/scripts/synapse-query-learnings.sh \
  project.agentic-setup github 3 2>/dev/null)
SYNAPSE_CONTEXT="${SYNAPSE_CI}${SYNAPSE_GH}"
# If SYNAPSE_TOKEN is not set or Synapse is unreachable, both will be empty.
# This is expected and non-blocking — proceed regardless (per D-304).
```

- Domain tags: `openclaw`, `github`, `ci` (per D-307)
- Cross-silo benefit: CI Monitor queries `github` learnings written by DevBot — patterns like "repo X frequently fails step Y" are recorded by DevBot and surfaced here
- If SYNAPSE_CONTEXT is non-empty: read the bullet list before proceeding — apply any relevant insights to this CI polling session
- If empty: proceed normally — Synapse unavailability never blocks CI monitoring

## Startup Sequence

1. Confirm `state/tracked-repos.txt` exists and is non-empty. If absent, log error to stderr and stop.
2. Confirm `state/last-seen-runs.json` exists. If absent, the script initializes it to `{}` automatically.
3. No memory loading required — CI Monitor is stateless between sessions. All state lives in `state/last-seen-runs.json`.

## Session Lifecycle

Each session is `sessionTarget: isolated` — no prior session context is carried over.

On each cron tick:
1. Receive payload message from the cron job.
2. Run `exec scripts/poll-ci.sh`.
3. Return the JSON result from the script verbatim.
4. Session ends.

## No Sub-Agents

CI Monitor does not delegate to sub-agents. It is a leaf node in the agent hierarchy.

## No Channel Binding

CI Monitor has no Telegram or other channel binding. Alerts are sent imperatively from `scripts/poll-ci.sh` using `openclaw message send` — not via agent channel tools.

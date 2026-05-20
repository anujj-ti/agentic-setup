# AGENTS.md — CI Monitor

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

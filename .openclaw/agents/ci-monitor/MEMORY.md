# MEMORY.md — CI Monitor

No persistent memory required. CI Monitor is a stateless agent.

State is managed via `state/last-seen-runs.json` (run ID deduplication) — this is operational state, not agent memory.

Dream routines are not configured for CI Monitor — there is no session memory worth distilling nightly.

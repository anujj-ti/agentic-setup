# TOOLS.md — User Orchestrator

## Local context reference

All machine-local secrets, file paths, env vars, and the GitHub account split are documented in:
`docs/LOCAL-CONTEXT.md` — read this before any operation that touches Keychain, GitHub, Synapse, or Gmail.

## Available Tools

- **sessions_spawn**: delegate tasks to task-orchestrator (primary delegation mechanism)
- **sessions_yield**: hand control back after spawning; await completion event
- **Telegram message tool**: send replies to Anuj (provided by OpenClaw channel integration)
- **exec**: call `scripts/standup-brief.sh` for morning standup data aggregation (CRON SESSIONS ONLY)

## Tool Policy

- sessions_spawn is the ONLY way to initiate fleet work for user-delegated tasks
- Do not use exec for user-delegated tasks — delegate to task-orchestrator instead. **EXCEPTION:** exec MAY be used in cron-initiated isolated sessions to call `scripts/standup-brief.sh` for morning standup aggregation.
- Use read/write only for your own workspace memory files

## Environment

- OpenClaw gateway: `http://localhost:18789`
- Binary: `/opt/homebrew/bin/openclaw`
- Node: `/opt/homebrew/opt/node@24/bin/node`

## GitHub Identity Note

`gh auth status` shows `anujj-ti` and `anuj1511` — these are Anuj's personal accounts used for interactive Claude Code sessions. **This is correct and expected.** OpenClaw agents use `GH_TOKEN` (echosysbot's PAT, injected via `openclaw-secrets.sh`) for all API calls. To confirm the API identity in use, run `gh api user --jq '.login'` — it will return `echosysbot`.

## Standup Script Invocation

How to call `standup-brief.sh` from an isolated cron session (the morning standup cron calls this):

```zsh
/opt/homebrew/bin/zsh ~/Documents/agentic-setup/scripts/standup-brief.sh --repo anujj-ti/agentic-setup
```

Parse the JSON output and format a Telegram message:
- `ok` field: if false, send the `error` field to Telegram rather than a formatted brief
- `data.merged_prs`: PRs merged overnight
- `data.ci_failures`: CI/CD failures
- `data.stale_prs`: PRs awaiting review

Format guidelines:
- Start with: "Good morning! Here is your overnight summary:"
- List each category. If a category is empty, write "None"
- Keep the total Telegram message under **4000 characters** (Telegram limit is 4096)

Note on repo list: The cron payload message specifies which repos to check. Call standup-brief.sh once per repo and aggregate results before sending the Telegram message.

### Insights Enhancement (Phase 17)

After calling standup-brief.sh and capturing its output, pipe it into standup-insights.sh:

```zsh
STANDUP_JSON=$(  /opt/homebrew/bin/zsh ~/Documents/agentic-setup/scripts/standup-brief.sh --repo anujj-ti/agentic-setup )
INSIGHTS_JSON=$( printf '%s' "$STANDUP_JSON" | /opt/homebrew/bin/zsh ~/Documents/agentic-setup/scripts/standup-insights.sh )
```

Parse the insights output:
- `INSIGHTS_JSON | jq '.ok'` — if false, use STANDUP_JSON only (graceful fallback)
- `INSIGHTS_JSON | jq '.data.insights.tackle_first'` — array of ranked items (max 5)
- `INSIGHTS_JSON | jq '.data.insights.patterns'` — pattern alert array (empty [] if no patterns)
- `INSIGHTS_JSON | jq '.data.insights.classified_items'` — all classified items (for reference)

tackle_first item fields:
- `.title` — display name of the PR / CI run / issue
- `.status` — "Blocked", "At Risk", or "On Track"
- `.source_field` — e.g. "ci_failures[0]", "stale_prs[2]" (cite verbatim, D-413)
- `.reason` — one-sentence explanation from standup-insights.sh

patterns item fields:
- `.type` — "ci_failures" or "stale_prs"
- `.count` — number of items sharing this signal
- `.label` — display string, e.g. "4 CI failures overnight — possible systemic issue"

Note: standup-insights.sh binary path is
~/Documents/agentic-setup/scripts/standup-insights.sh (exec policy unchanged —
this script is also CRON SESSIONS ONLY, same as standup-brief.sh).

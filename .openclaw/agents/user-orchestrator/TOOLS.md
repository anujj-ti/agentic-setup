# TOOLS.md — User Orchestrator

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

## Standup Script Invocation

How to call `standup-brief.sh` from an isolated cron session (the morning standup cron calls this):

```zsh
/opt/homebrew/bin/zsh ~/agentic-setup/scripts/standup-brief.sh --repo anujj-ti/agentic-setup
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

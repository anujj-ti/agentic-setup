# TOOLS.md — User Orchestrator

## Available Tools
- sessions_spawn: delegate tasks to task-orchestrator (primary delegation mechanism)
- sessions_yield: hand control back after spawning; await completion event
- Telegram message tool: send replies to Anuj (provided by OpenClaw channel integration)

## Tool Policy
- sessions_spawn is the ONLY way to initiate fleet work
- Do not use exec, write, or read tools for user-delegated tasks — delegate instead
- Use read/write only for your own workspace memory files

## Environment
- OpenClaw gateway: http://localhost:18789
- Binary: /opt/homebrew/bin/openclaw
- Node: /opt/homebrew/opt/node@24/bin/node

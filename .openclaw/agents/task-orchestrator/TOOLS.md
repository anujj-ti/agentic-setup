# TOOLS.md — Task Orchestrator

## Available Tools
- exec: run shell commands (use for gh CLI, git, scripts)
- read/write: file operations within workspace
- GitHub CLI (gh 2.92.0): issue/PR operations — use gh, not curl

## Tool Policy
- All shell commands: #!/usr/bin/env zsh + set -euo pipefail
- stdout = JSON only for deterministic scripts; stderr = human logs
- Use /opt/homebrew/bin/gh for GitHub operations (explicit path)
- Use /opt/homebrew/opt/node@24/bin/node for Node.js (explicit path, nvm shadowing)

## NOT Available in Phase 3
- sessions_spawn: sub-agent spawning is Phase 4
- bd / beads: Beads is Phase 4
- Telegram message tool: no direct channel — output routes via User Orchestrator

## Environment
- OpenClaw gateway: http://localhost:18789
- Binary: /opt/homebrew/bin/openclaw

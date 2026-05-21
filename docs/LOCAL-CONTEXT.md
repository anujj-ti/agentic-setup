# LOCAL-CONTEXT.md — Machine-local secrets and tool reference

This file is the single source of truth for what lives locally on this machine.
No secret values are stored here — only names and locations.

**Audience:** Claude Code, user-orchestrator, task-orchestrator.
**Not for:** sub-agents, external systems, or any file that leaves this machine.

---

## Keychain secrets

All secrets stored via: `security find-generic-password -s '<service>' -a 'trilogy' -w`

Full provisioning reference: `secrets.sh` (repo root — not stowed, not in git history values)

| Keychain service name | Env var | What it is |
|-----------------------|---------|------------|
| `openclaw.telegram-main-bot-token` | `OPENCLAW_TELEGRAM_MAIN_BOT_TOKEN` | Telegram bot token for @echo_sys_bot |
| `openclaw.anuj-chat-id` | `OPENCLAW_ANUJ_CHAT_ID` | Anuj's personal Telegram chat ID (1294664427 — from @userinfobot) |
| `openclaw.gmail-client-id` | `OPENCLAW_GMAIL_CLIENT_ID` | Gmail OAuth2 Desktop App Client ID for echo.sys.bot@gmail.com |
| `openclaw.gmail-client-secret` | `OPENCLAW_GMAIL_CLIENT_SECRET` | Gmail OAuth2 Desktop App Client Secret |
| `openclaw.gmail-triage-refresh-token` | `OPENCLAW_GMAIL_TRIAGE_REFRESH_TOKEN` | Gmail API refresh token for email-triage agent — provisioned 2026-05-21 |
| `openclaw.github-bot-token` | `GH_TOKEN` | GitHub PAT for echosysbot account (scopes: repo, read:org, workflow, project) |
| `openclaw.synapse-token` | `SYNAPSE_TOKEN` | Synapse org memory token (project.agentic-setup + project.edullm-sat-math) |
| `openclaw.notion-token` | `OPENCLAW_NOTION_TOKEN` | Notion integration token — Phase 9 (not yet provisioned) |

---

## GitHub account split

| Account | Used by | Auth mechanism |
|---------|---------|----------------|
| `anujj-ti` | Claude Code, Cursor — interactive personal use | `gh auth` (system gh CLI) |
| `echosysbot` | OpenClaw agents (DevBot, CI Monitor) | `GH_TOKEN` env var from Keychain `openclaw.github-bot-token` |

**Rule:** OpenClaw agent scripts MUST prefix `gh` calls with:
```zsh
GH_TOKEN=$(security find-generic-password -s 'openclaw.github-bot-token' -a 'trilogy' -w)
```

---

## Key file locations

| File | Purpose |
|------|---------|
| `secrets.sh` | Disaster recovery — re-provisions all Keychain secrets on fresh machine |
| `scripts/stow-deploy.sh` | Deploy repo config to `~/.openclaw/` via GNU Stow |
| `scripts/infra-verify.sh` | Verify OpenClaw gateway + agent health |
| `scripts/chan-verify.sh` | Verify Telegram + Gmail channel health |
| `scripts/verify-phase-13.sh` | Verify Synapse integration (10 checks) |
| `scripts/verify-phase-14.sh` | Verify gogcli Gmail + Calendar wiring |
| `.openclaw/` | Stow source — all agent configs, scripts, cron jobs |
| `~/.openclaw/` | Live deployment — symlinked by Stow from above |
| `docs/beads/formulas/` | Beads workflow formulas (feature/bugfix/investigation/review) |
| `.claude/skills/synapse/SKILL.md` | Synapse operating loop — mandatory reading before Synapse calls |

---

## Key env vars (runtime)

```zsh
export SYNAPSE_URL="https://cnu.synapse-os.ai"
export SYNAPSE_TOKEN=$(security find-generic-password -s 'openclaw.synapse-token' -a 'trilogy' -w 2>/dev/null)
export BEADS_DIR="$HOME/.openclaw/beads"
export PATH="/opt/homebrew/opt/node@24/bin:$PATH"
```

---

## Synapse projects

| Project ID | Used for |
|------------|---------|
| `project.agentic-setup` | All agentic-setup infrastructure work |
| `project.edullm-sat-math` | EduLLM SAT Math features |
| Team: `team.trilogy-innovations` | All Synapse calls |

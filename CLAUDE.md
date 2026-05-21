<!-- GSD:project-start source:PROJECT.md -->
## Project

**Personal AI Operations Hub**

A self-evolving AI agent fleet built on OpenClaw, managed and configured via Claude Code skills, designed to handle the full lifecycle of a developer's day — email triage, GitHub project management, CI monitoring, autonomous development, and decision documentation — all without constant human babysitting. Uses a dual-orchestrator architecture: a thin user-facing orchestrator handles the conversation with you, while a separate task orchestrator runs autonomously in the background, delegating to specialized sub-agents and documenting every decision it makes in Notion for your review when you return.

**Core Value:** An AI co-pilot that works autonomously while you're away, never forgets a task, documents every decision it made, and hands back clean control when you return.

### Constraints

- **Tech stack**: OpenClaw + Claude Code skills + Git/Stow — no custom server infrastructure, no dashboards
- **Platform**: macOS only — Keychain, launchd, and Stow are macOS/GNU tooling
- **Secrets**: macOS Keychain only — never written to files, never in git history (cc-openclaw convention: `openclaw.<name>` service naming, `OPENCLAW_<NAME>` env var naming)
- **Memory budget**: Dream routines must respect token budgets (2,500/daily, 7,500/rolling 3-day digest per cc-openclaw reference)
- **Agent autonomy**: Autonomous actions (PR merges, issue creation, config changes) must be logged to Notion before execution — user reviews on return, can revert
<!-- GSD:project-end -->

<!-- GSD:stack-start source:research/STACK.md -->
## Technology Stack

## Recommended Stack
### Core Technologies
| Technology | Version | Purpose | Why Recommended |
|------------|---------|---------|-----------------|
| OpenClaw | 2026.5.18 (latest stable) | AI agent runtime — flat-file JSON config, gateway, channels, cron | The runtime this entire hub is built on. No alternative exists for this use case. |
| Node.js | 24 (LTS; minimum 22.19) | OpenClaw runtime dependency | OpenClaw's official requirement. Node 24 is the default/recommended runtime. Node 18/20 cause fatal "Node version unsupported" error. |
| Claude Code | Latest (native installer) | AI model CLI + skill execution engine | Anthropic's official CLI; as of March 2026 the native installer replaces npm-based install and auto-updates. Skills live in `.claude/skills/`. |
| cc-openclaw (9 skills) | HEAD at `github.com/rahulsub-be/cc-openclaw` | Standardized OpenClaw operations as Claude Code slash commands | Encodes all institutional knowledge: naming conventions, secrets pipeline, stow gotchas, token budgets. Without this every config change is an improvisation. |
| GNU Stow | Latest (`brew install stow`) | Symlink manager — deploys git repo contents to `~/.openclaw/` | Makes git the deployment mechanism. Disaster recovery = `git clone` + `stow`. Reversible with `stow -D`. |
### Channel Integrations
| Technology | Version/Source | Purpose | Why / Notes |
|------------|----------------|---------|-------------|
| Telegram Bot (BotFather) | Telegram Bot API v7.x | User-facing notifications, commands, alerts | Native OpenClaw channel. Token stored in macOS Keychain; configured via `channels.telegram` in `openclaw.json`. No Node.js library needed — OpenClaw handles the Telegram polling internally. |
| WhatsApp (Baileys) | `@openclaw/whatsapp` plugin from ClawHub | Secondary notification channel | OpenClaw distributes WhatsApp runtime as a separate plugin (`@openclaw/whatsapp`) using Baileys (WhatsApp Web automation). Linked via QR code on a **dedicated number** — not your personal number. Ban risk is real; use a separate SIM or secondary account. |
| Gmail API | `googleapis` npm ^13.x | Email triage + outbound via echo.sys.bot@gmail.com | OAuth2 with refresh token stored in Keychain. Use `gmail.readonly` + `gmail.send` + `gmail.modify` scopes. Refresh token is issued only once — store it immediately. Service account (domain-wide delegation) is NOT available for personal Gmail accounts — OAuth2 Device Flow is the correct auth path for a bot account. |
### External API Clients
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| `gh` (GitHub CLI) | 2.92.0 (`brew install gh`) | Issues, PRs, project board, repo management from shell scripts | Use `gh` in deterministic scripts rather than raw `curl` + GitHub REST API. `gh issue create`, `gh pr create`, `gh project item-add` are the key agent-facing commands. Authenticated via `gh auth login` — token stored by gh's own keychain integration. |
| `@notionhq/client` | 5.22.0 | Decision logging, experiment results, async review surface | Only library needed for Notion. Use API version `2026-03-11` (pass at client construction). Token stored in Keychain as `OPENCLAW_NOTION_TOKEN`. |
| `@beads/bd` (CLI) | 1.0.4 (`npm install -g @beads/bd` or `brew install beads`) | Dependency-aware task graph for Phase 2+ | Phase 2+ only. Initialize with `bd init --stealth` in Task Orchestrator workspace. Requires Dolt as backend. One shared `.beads/` DB across all agents via `BEADS_DIR` env var. |
| Dolt | Latest (`brew install dolt`) | Version-controlled SQL backend for Beads | Beads embedded mode runs Dolt in-process (no external server). Data lives in `.beads/embeddeddolt/`. No separate server needed for single-machine setup. |
### macOS Platform Tooling
| Tool | Version | Purpose | Notes |
|------|---------|---------|-------|
| macOS Keychain (`security` CLI) | Built-in (macOS 13+ / Darwin 25.x) | All secrets storage | Naming convention: service = `openclaw.<name>` (lowercase, hyphens); env var = `OPENCLAW_<NAME>` (uppercase, underscores). Always update all three files: `openclaw-secrets.sh` (launchd), `openclaw-env.sh` (shell sessions), `secrets.sh` (provisioning). Never echo secrets in terminal. |
| launchd / LaunchAgent | Built-in | Cron replacement — schedules all agent heartbeats and dream routines | `~/Library/LaunchAgents/` for user-level agents. OpenClaw installs its own LaunchAgent during `openclaw onboard --install-daemon`. Additional cron jobs are managed by the `/openclaw-add-cron` skill. |
| `jq` | Latest (`brew install jq`) | JSON parsing in shell scripts | Required for the json-response pattern — all deterministic scripts output structured JSON to stdout, which callers parse with `jq`. Install via Homebrew. |
| Git | System (`brew install git`) | Version control for all config | Every config change is a commit. Disaster recovery is `git clone` + `stow`. |
### Shell Scripting Conventions
| Convention | Specification | Rationale |
|------------|---------------|-----------|
| Shebang | `#!/usr/bin/env zsh` | macOS default shell is zsh (since Catalina). Do not use `#!/bin/bash` — bash on macOS is stuck at 3.2. |
| Strict mode | `set -euo pipefail` | `set -e` exits on error, `set -u` treats unset vars as errors, `set -o pipefail` catches mid-pipe failures. Works in both zsh and bash. |
| Output protocol | stdout = JSON only, stderr = human-readable logs | Agents parse stdout. Logs go to stderr so they don't corrupt the JSON response. This is the cc-openclaw `json-response.sh` shared library pattern. |
| JSON response shape | `{ "ok": true, "data": {...} }` or `{ "ok": false, "error": "..." }` | Consistent shape means callers can use `jq '.ok'` to check success without ad-hoc parsing. |
| Exit code | Non-zero on any failure, 0 on success | "Exit code is law" — agents check exit codes, not stdout content. |
| Shared lib | `scripts/lib/json-response.sh` per agent workspace | `/openclaw-add-script` scaffolds this automatically. Never copy-paste the boilerplate — run the skill. |
## Installation
# 1. Prerequisites — Node 24 (OpenClaw requirement), Homebrew tools
# 2. OpenClaw — official installer (handles Node setup, daemon install)
# 3. Verify OpenClaw
# 4. Claude Code — native installer (March 2026+, replaces npm method)
# 5. cc-openclaw skills — clone alongside your openclaw-home repo
# Verify: open Claude Code in openclaw-home and type /openclaw- to see all 9 skills
# 6. Beads (Phase 2+)
# Initialize in Task Orchestrator workspace
# Export BEADS_DIR in gateway start script
# 7. Notion client (install in agent script directory, not globally)
# 8. Gmail API
# 9. WhatsApp plugin (after OpenClaw gateway is running)
## Alternatives Considered
| Recommended | Alternative | Why Not |
|-------------|-------------|---------|
| Native Claude Code installer | `npm install -g @anthropic-ai/claude-code` | The npm method is officially deprecated as of March 2026. Native installer auto-updates and has zero npm dependency noise. |
| `gh` CLI for GitHub operations | Raw `curl` + GitHub REST API | `gh` handles auth, rate-limit headers, and pagination automatically. Raw curl requires manual token management and JSON construction. |
| `@notionhq/client` | Custom `curl` + Notion REST | Official SDK handles retries, pagination, and rate limits. No reason to raw-dog the Notion API. |
| Baileys via `@openclaw/whatsapp` | Twilio WhatsApp Business API | Twilio requires a registered WhatsApp Business number, per-message cost, and 24-hour template window. Baileys is free and works with any number. Ban risk is the tradeoff — use a dedicated number to manage it. |
| OAuth2 Device Flow for Gmail | Service account + domain-wide delegation | Domain-wide delegation only works for Google Workspace (G Suite) domains, not personal @gmail.com accounts. echo.sys.bot@gmail.com is a personal account — OAuth2 is the only path. |
| launchd for scheduling | cron | cron is deprecated on macOS and replaced by launchd. launchd also supports event-based triggers, not just time-based. |
| `bd init --stealth` for Beads | Beads server mode | Server mode requires an external Dolt SQL server. Stealth/embedded mode runs in-process — no extra infrastructure for a single-machine personal hub. |
| `@beads/bd` 1.0.4 via npm or brew | `beads-orchestration` skill (community fork) | The community orchestration skill adds multi-agent messaging (HANDOFF/BLOCKED). Worth evaluating in Phase 2+ but the core `bd` CLI is sufficient for the initial task graph pattern. |
## What NOT to Use
| Avoid | Why | Use Instead |
|-------|-----|-------------|
| `npm install -g openclaw@latest` as primary install | Still works, but the native installer is now the official path and handles more edge cases (sharp/libvips binaries, daemon setup). Use npm only if curl install fails. | `curl -fsSL https://openclaw.ai/install.sh \| bash` |
| Node.js 18 or 20 | OpenClaw will fail at startup with "Node version unsupported" fatal error. These versions are below the 22.19 minimum. | Node 24 via `brew install node@24` |
| `python-telegram-bot` or `node-telegram-bot-api` | OpenClaw handles Telegram natively via the `channels.telegram` config. No separate library or polling loop is needed. Adding one creates a second conflicting bot instance. | OpenClaw's built-in Telegram channel with BotFather token |
| Telegraf.js | Same reason — OpenClaw owns the Telegram socket. External frameworks conflict with the gateway's connection management. | OpenClaw's built-in Telegram channel |
| Hardcoded secrets in openclaw.json or any tracked file | Creates plaintext secrets in git history. The cc-openclaw security model explicitly forbids this. | macOS Keychain via `security add-generic-password -s openclaw.<name>` |
| Global npm installs for Notion/Gmail libraries | Agent scripts should own their dependencies, not share a global namespace. Global installs create version conflicts across agents and break reproducibility. | `npm install` in the agent's scripts directory |
| WhatsApp on your personal number | WhatsApp ban risk. A banned personal number loses all your contacts and conversation history. | A dedicated number (secondary SIM or virtual number) |
| WAHA plugin (community WhatsApp) | WAHA unlocks more WhatsApp features (polls, reactions, etc.) but adds complexity the cc-openclaw `/openclaw-add-channel` skill doesn't know about. You lose the standardized secrets pipeline. | `@openclaw/whatsapp` via ClawHub — supported by the skill |
| `cron` / `crontab` | Deprecated on macOS since macOS 12. launchd is the native scheduler and is what OpenClaw's cron runner wraps. | `openclaw-add-cron` skill which generates launchd-compatible jobs |
| `#!/bin/bash` shebang | macOS ships bash 3.2 (GPL2 locked). Missing associative arrays, `mapfile`, modern string ops. | `#!/usr/bin/env zsh` — zsh 5.9+ is the macOS default shell |
| Beads in Phase 1 | Premature complexity. Task Orchestrator doesn't exist yet. Beads is a Phase 2+ dependency once the core fleet is running. | Plain agent TOOLS.md instructions until Task Orchestrator is live |
## Stack Patterns by Variant
- Model: Anthropic Claude (Sonnet or higher) via OpenClaw `agents.list` config
- Channel: Telegram (`channels.telegram` in openclaw.json, `dmPolicy: "pairing"`)
- No Beads — stays lean, no stateful task tracking
- Dream routine: yes — nightly memory distillation, 2,500 token daily budget, 7,500 for 3-day rolling digest
- Model: Claude Opus (or Sonnet for cost) — needs full reasoning for multi-agent delegation
- Channel: none (no direct user messaging — communicates via Beads + Notion logs)
- Beads: yes — `bd init --stealth` in workspace, `BEADS_DIR` exported via gateway start script
- Heartbeat: cron (15-minute cycle to check Beads graph for stuck agents)
- Dream routine: yes — accumulates more operational context, higher token budget justified
- Model: Claude Sonnet or Haiku (cost optimization — the skill defines the procedure, not the model)
- Beads: consumer only (`bd ready --json` → claim → close with evidence)
- No direct channels — receive work via Beads claims, report back via close reasons + Notion logs
- Deterministic scripts: yes — all file I/O, API calls, git operations via `set -euo pipefail` scripts with JSON output
- All config changes go through cc-openclaw skills, never hand-edited
- Every change is a git commit before `stow` runs
- The `/openclaw-stow` and `/openclaw-restart` skills encode the `rm -f ~/.openclaw/cron/jobs.json` gotcha automatically
## Version Compatibility
| Package | Compatible With | Notes |
|---------|-----------------|-------|
| OpenClaw 2026.5.x | Node.js 22.19 – 24.x | Node 24 recommended. Node 18/20 cause fatal startup error. |
| Claude Code (native installer) | macOS 13.0+ (Ventura) | Supports both Intel and Apple Silicon. |
| `@notionhq/client` 5.22.0 | Notion API version `2025-09-03` (default) or `2026-03-11` | Pass `notionVersion: "2026-03-11"` to client constructor to use latest API. |
| `@beads/bd` 1.0.4 | Dolt (any recent version via brew) | Embedded Dolt mode: no server needed. `brew install dolt` satisfies the dependency. |
| `gh` 2.92.0 | GitHub.com, GitHub Enterprise Cloud, GHE Server 2.20+ | Authenticate via `gh auth login` before any agent scripts run. |
| GNU Stow (latest) | macOS 13+ | `brew install stow`. The `--no-folding` flag is required when using stow with `.claude/skills/` to avoid directory-level symlinks that break skill discovery. |
| `googleapis` ^13 | Node.js 18+ | Compatible with Node 24. Gmail OAuth2 refresh tokens survive runtime restarts when stored in Keychain. |
## Sources
- [OpenClaw Install Docs](https://docs.openclaw.ai/install) — install commands, Node version requirements (HIGH)
- [OpenClaw Node.js Requirements](https://docs.openclaw.ai/install/node) — Node 24 recommended, 22.19 minimum (HIGH)
- [OpenClaw Gateway Configuration](https://docs.openclaw.ai/gateway/configuration) — openclaw.json structure, JSON5 format, channel/cron/agent schema (HIGH)
- [OpenClaw Telegram Channel Docs](https://docs.openclaw.ai/channels/telegram) — dmPolicy options, pairing workflow, secrets management (HIGH)
- [OpenClaw WhatsApp Channel Docs](https://docs.openclaw.ai/channels/whatsapp) — Baileys-based, `@openclaw/whatsapp` plugin, QR code setup (HIGH)
- [cc-openclaw GitHub](https://github.com/rahulsub-be/cc-openclaw) — 9 skills, slash commands, stow-based install (HIGH)
- [Beads GitHub (gastownhall/beads)](https://github.com/gastownhall/beads) — v1.0.4, `bd init --stealth`, CLI command reference (HIGH)
- [Beads npm package (@beads/bd)](https://www.npmjs.com/package/@beads/bd) — install via npm or brew (HIGH)
- [GitHub CLI Homebrew Formula](https://formulae.brew.sh/formula/gh) — version 2.92.0 confirmed (HIGH)
- [Notion SDK JS Releases](https://github.com/makenotion/notion-sdk-js/releases) — v5.22.0 latest, API version 2026-03-11 available (HIGH)
- [Node.js Gmail API Quickstart](https://developers.google.com/workspace/gmail/api/quickstart/nodejs) — OAuth2 flow, scope list (HIGH)
- [Dolt Homebrew Formula](https://formulae.brew.sh/formula/dolt) — `brew install dolt` (HIGH)
- [Managing OpenClaw with Claude Code — Trilogy AI CoE](docs/human/Trilogy%20AI%20Center%20of%20Excellence%20-%20Managing%20OpenClaw%20with%20Claude%20Code.md) — skills design rationale, secrets pipeline, stow gotchas, token budgets (HIGH — primary reference)
- [Why Your AI Agents Skip Steps — Trilogy AI CoE](docs/human/Trilogy%20AI%20Center%20of%20Excellence%20-%20Why%20Your%20AI%20Agents%20Skip%20Steps%20-%20and%20How%20Task%20Graphs%20Prevent%20It.md) — Beads setup runbook, decomposition templates, claim/close protocol (HIGH — primary reference)
- [Bash Strict Mode Reference](https://linuxize.com/post/bash-strict-mode/) — `set -euo pipefail` conventions (MEDIUM)
<!-- GSD:stack-end -->

<!-- GSD:conventions-start source:CONVENTIONS.md -->
## Conventions

Conventions not yet established. Will populate as patterns emerge during development.
<!-- GSD:conventions-end -->

<!-- GSD:architecture-start source:ARCHITECTURE.md -->
## Architecture

Architecture not yet mapped. Follow existing patterns found in the codebase.
<!-- GSD:architecture-end -->

<!-- GSD:skills-start source:skills/ -->
## Project Skills

No project skills found. Add skills to any of: `.claude/skills/`, `.agents/skills/`, `.cursor/skills/`, `.github/skills/`, or `.codex/skills/` with a `SKILL.md` index file.
<!-- GSD:skills-end -->

<!-- GSD:workflow-start source:GSD defaults -->
## GSD Workflow Enforcement

Before using Edit, Write, or other file-changing tools, start work through a GSD command so planning artifacts and execution context stay in sync.

Use these entry points:
- `/gsd-quick` for small fixes, doc updates, and ad-hoc tasks
- `/gsd-debug` for investigation and bug fixing
- `/gsd-execute-phase` for planned phase work

Do not make direct repo edits outside a GSD workflow unless the user explicitly asks to bypass it.
<!-- GSD:workflow-end -->



## Synapse — Org Memory (MANDATORY for every non-trivial session)

Synapse is the org-wide memory and coordination layer. Claude Code MUST use it on every session that changes code, plans phases, executes tasks, or produces artifacts.

```
URL:        https://cnu.synapse-os.ai   ($SYNAPSE_URL)
Token:      Keychain → openclaw.synapse-token   ($SYNAPSE_TOKEN)
Project:    project.edullm-sat-math  (use for all work until project.agentic-setup is created)
Team:       team.trilogy-innovations
Skill:      /synapse  (full operating loop at .claude/skills/synapse/SKILL.md)
```

**Load token at session start:**
```bash
export SYNAPSE_TOKEN=$(security find-generic-password -s 'openclaw.synapse-token' -a 'trilogy' -w 2>/dev/null)
export SYNAPSE_URL="https://cnu.synapse-os.ai"
```

**Mandatory loop on every non-trivial task:**
1. `/usr/bin/curl ... synapse.brief.fetch` → ack all briefs → capture OKR id
2. `synapse.learning.query` with relevant tags (`cross_silo: true`)
3. `synapse.workflow.create` → save `bd_id`
4. `synapse.checkin status=start`
5. Do the work (use GSD entry points below)
6. `synapse.artifact.upload` (use `content_base64`, not `content_b64`)
7. `synapse.learning.record` (at least 1 learning per session, `confidence: "low"` ok without artifact)
8. `synapse.checkin status=complete`

**Key rules:**
- `content_base64` field (not `content_b64`) for artifact upload
- `mime_type` is required for artifact upload
- Questions: `synapse.question.ask` requires `to_team_id: "team.trilogy-innovations"`
- medium/high confidence facts require `evidence_artifact_id`
- See full reference: `/synapse` skill

<!-- GSD:profile-start -->
## Developer Profile

> Profile not yet configured. Run `/gsd-profile-user` to generate your developer profile.
> This section is managed by `generate-claude-profile` -- do not edit manually.
<!-- GSD:profile-end -->

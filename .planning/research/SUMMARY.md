# Research Summary — Personal AI Operations Hub

## Executive Summary

This project builds a personal AI operations hub on macOS: a fleet of specialized Claude Code agents orchestrated via OpenClaw, operating autonomously on GitHub issues, CI/CD, email triage, and PR management — all routed through Telegram — while the user is away. The recommended approach is a layered build: infrastructure first (OpenClaw + cc-openclaw skills + secrets pipeline + stow), then dual-orchestrator architecture (User Orchestrator for conversation, Task Orchestrator for autonomous execution), then execution-tier sub-agents (DevBot, CI Monitor, Email Triage, PR Reviewer, Context Switcher), and finally autonomous dev workflows gated behind a Notion decision log and approval queue. The cc-openclaw 9 skills are not optional convenience — they are the configuration governance layer that prevents convention drift across the entire fleet.

The central architectural insight from both Trilogy AI CoE reference documents is that two failure modes kill multi-agent systems: context bloat (a single orchestrator accumulates both conversational and task-execution state until coherence degrades) and step-skipping (agents satisfice multi-step tasks by completing 3 of 12 steps and reporting done). The dual-orchestrator pattern prevents context bloat. Beads (bd) task graphs prevent step-skipping by making step N+1 structurally unreachable until step N is closed with proof-of-work. Both must be designed in from the start.

The primary operational risks are secrets added without the three-file pipeline (silent partial failures), cron jobs without explicit timezone fields (fire at UTC), and stowing without removing jobs.json (silently drops all cron config). Prevention requires exclusively using cc-openclaw skills for all configuration operations.

---

## Key Findings

### Stack (HIGH confidence)

- **OpenClaw 2026.5.18** via native curl installer (`curl -fsSL https://openclaw.ai/install.sh | bash`); npm method deprecated. **Node.js 24 required** — 18/20 cause fatal startup error.
- **Claude Code** via native Anthropic installer; **cc-openclaw 9 skills** via `git clone + stow --no-folding` into `.claude/skills/`
- **GNU Stow** with `--no-folding` flag; `rm -f ~/.openclaw/cron/jobs.json` before every stow (non-negotiable)
- **Beads 1.0.4** (`npm install -g @beads/bd`); embedded Dolt, `bd init --stealth`; one shared `BEADS_DIR` per execution tier
- **macOS Keychain** for all secrets; naming: `openclaw.<name>` (lowercase hyphens) / `OPENCLAW_<NAME>` (uppercase underscores); always three files: `openclaw-secrets.sh` + `openclaw-env.sh` + `secrets.sh`
- **Telegram**: native OpenClaw channel (no third-party library needed); **WhatsApp**: `@openclaw/whatsapp` plugin (Baileys-based, dedicated number required, ban risk exists)
- **Gmail**: OAuth2 Device Flow for personal accounts (not service accounts — those only work on Google Workspace domains); refresh token stored in Keychain immediately after issue
- **GitHub CLI**: `gh` 2.92.0; **Notion SDK**: `@notionhq/client` 5.22.0 (API version 2026-03-11); **Gmail**: `googleapis ^13`
- **Shell conventions**: `#!/usr/bin/env zsh` (not bash — macOS bash is 3.2), `set -euo pipefail`, stdout = JSON only, stderr = logs, shared `json-response.sh` library

### Features

**Table stakes (v1 — must work or the system isn't useful):**
- OpenClaw + cc-openclaw skills installed and working
- Dual orchestrator architecture (User + Task, separate context windows)
- macOS Keychain secrets pipeline (three files, every time)
- Telegram channel with working round-trip to user
- Notion decision log — every autonomous action pre-logged before execution
- GitHub integration (issue create, board read, PR triage)
- Email agent via echo.sys.bot@gmail.com
- User review/approval workflow on return
- `/openclaw-status` health dashboard

**Differentiators (v1.x — after core fleet validated):**
- Dream routines for both orchestrators (nightly memory distillation)
- Beads task graph (structural step enforcement for autonomous dev)
- Morning standup brief (Telegram delivery on schedule)
- CI/CD monitoring agent
- Autonomous PR merge with approval queue (Notion-gated)

**Defer to v2+:**
- Project context switching
- Experiment framework
- Self-evolution capability

**Anti-features (explicitly out):**
- Slack integration
- Multi-user / team mode
- Any custom server infrastructure
- Agent-to-agent communication via freeform messages (use Beads delegation instead)

### Architecture (HIGH confidence)

Four-tier system:
1. **Interface tier**: Telegram (primary), WhatsApp (alerts), Gmail bot, GitHub API
2. **Conversation tier**: User Orchestrator (Claude Opus, persistent, owns channels, owns review workflow)
3. **Orchestration tier**: Task Orchestrator (Claude Sonnet, persistent, owns Beads DB, creates epics before spawning)
4. **Execution tier**: DevBot, CI Monitor, Email Triage, PR Reviewer, Context Switcher (Claude Haiku, isolated sessions)

Build order (hard dependencies):
1. Infrastructure + stow + gateway + secrets pipeline
2. cc-openclaw skills installed
3. User Orchestrator live (Telegram roundtrip verified)
4. Task Orchestrator scaffolded + delegation working
5. Dream routines for both orchestrators
6. Beads installed, BEADS_DIR propagated and verified
7. Sub-agents one by one (each gets full claim/close cycle verification)
8. Notion logging + approval workflow
9. Autonomous dev workflows (merge permissions AFTER Notion logging verified)

Key operational rules:
- Task Orchestrator creates complete Beads epic with all subtasks + deps BEFORE spawning any sub-agent
- Sub-agents receive only `bd ready --json` — never a free-text task description
- All config changes go through cc-openclaw skills — never manual file edits

### Pitfalls (HIGH confidence — all first-party production failures)

| # | Pitfall | Severity | Prevention |
|---|---------|----------|-----------|
| 1 | `jobs.json` overwrite on gateway restart | CRITICAL | Always `rm -f` before stow; use `/openclaw-stow` and `/openclaw-restart` skills exclusively |
| 2 | Incomplete three-file secrets pipeline | CRITICAL | Only use `/openclaw-add-secret`; any manual secret addition is a defect |
| 3 | Convention drift (agent invents config from context) | HIGH | All config through cc-openclaw skills; never ask agents to "add a cron job" directly |
| 4 | Agent step-skipping / satisficing | HIGH | Beads task graphs for all work with >2 steps; close reasons must be factual with evidence |
| 5 | Autonomous agent overreach (merge without audit trail) | HIGH | Notion pre-log MUST exist before any merge; enforce in SECURITY.md before granting merge permissions |
| 6 | Dream routine token budget ignored | HIGH | Enforce 2,500/daily, 7,500/rolling-3-day; `memory/archives/` dir must exist before first run |
| 7 | Channel silent disconnect | MEDIUM | `/openclaw-status` daily cron; active channel verification in restart skill |
| 8 | Malformed self-evolved agents | MEDIUM | Self-evolution MUST route through `/openclaw-new-agent`; rule in Task Orchestrator SOUL.md |
| 9 | UTC cron timezone default | MEDIUM | Always set `timezone` field; validate with `/openclaw-status` cron output |
| 10 | `BEADS_DIR` not exported to sub-agents | HIGH | Export in gateway start script before first sub-agent spawn; verify with `bd ready` from sub-agent context |

---

## Roadmap Implications

**5 suggested phases:**

### Phase 1: Infrastructure + Configuration Governance
OpenClaw install, cc-openclaw skills, secrets pipeline, stow deploy, jobs.json symlink verified, first cron with timezone.
**Gate:** `/openclaw-status` green on all checks.

### Phase 2: Dual Orchestrator + Core Channels
User Orchestrator live on Telegram, Task Orchestrator scaffolded and delegation working, dream routines for both orchestrators, WhatsApp channel.
**Gate:** user sends Telegram message → coherent response received; User Orchestrator delegates task → Task Orchestrator acknowledges.

### Phase 3: Beads + Execution Sub-Agents
Beads installed, BEADS_DIR verified across agents. Then: DevBot → CI Monitor → Email Triage → PR Reviewer → Context Switcher.
**Gate per agent:** complete claim/close cycle from Task Orchestrator's perspective.

### Phase 4: Notion Trust Layer + Autonomous Dev
Notion logging verified with test entry. Then: autonomous PR merge with approval queue, morning standup brief, CI-driven epic creation, end-to-end review workflow.
**Gate:** test Notion log entry exists and is readable before merge permissions granted.

### Phase 5: Self-Evolution + Advanced Workflows
Project context switching, experiment framework, self-evolution with mandatory `/openclaw-new-agent` rule in Task Orchestrator SOUL.md and post-evolution verification.

---

## Research Gaps (address during phase planning)

- Notion database schema for decision log (fields, structure) — resolve during Phase 4 planning
- Approval queue mechanism (Notion page vs. GitHub label) — resolve during Phase 4 planning
- WhatsApp ban risk mitigation (virtual number provider compatibility) — resolve during Phase 2 if WhatsApp prioritized
- Gmail OAuth re-auth runbook — document in Email Triage TOOLS.md during Phase 3

---

*Research completed: 2026-05-20 | Confidence: HIGH across all four dimensions*

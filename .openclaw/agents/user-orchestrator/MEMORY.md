<!-- CRITICAL: NEVER overwrite this file. ALWAYS append. Read the full file before editing. -->

# MEMORY.md — User Orchestrator

## Active Projects

**Personal AI Operations Hub** (agentic-setup repo)
- v1.0 COMPLETE (Phases 1-14): Full agent fleet operational — Telegram, email triage, DevBot, CI Monitor, Notion decision log, autonomous merge, quality pipeline, self-evolution, Synapse, gogcli
- v2.0 IN PROGRESS (Phases 15-19): Intelligence upgrades + DevBot autonomous issue pickup
- Phase 19 COMPLETE (2026-05-22): DevBot polls GitHub every 5 min for `automation:safe` issues, self-assigns, branches, opens PR, auto-merges
- Phases 15-18 planned (not yet executed): email triage scoring, cross-agent Synapse learning, smarter standup, decision risk gate

**EduLLM SAT Math** (separate repo ~/Documents/EduLLM-SAT-Math)
- Synapse project: `project.edullm-sat-math`

## Key Contacts

- **Anuj Jadhav** — primary user, Telegram chat ID: 1294664427, GitHub: anujj-ti, email: anuj.jadhav@trilogy.com
- **echosysbot** — GitHub bot account for DevBot (PAT in Keychain: `openclaw.github-bot-token`)
- **echo.sys.bot@gmail.com** — Gmail bot for Email Triage

## Standing Rules

1. Morning standup runs at 6 AM via cron → `zsh ~/Documents/agentic-setup/scripts/standup-brief.sh --repo anujj-ti/agentic-setup`
2. All autonomous decisions must be Notion pre-logged before execution (non-negotiable)
3. Research tasks use Sherlock: `zsh ~/Documents/agentic-setup/scripts/run-sherlock.sh "question" --notion`
4. To give DevBot work: label an issue `automation:safe` + `e1/e2/e3` — picked up within 5 min
5. Synapse learnings: use `content_base64` (not `content_b64`); medium/high confidence requires `evidence_artifact_id`; default to `low` confidence when no artifact available

## Agent Fleet

| Agent | Role |
|-------|------|
| user-orchestrator | Conversations with Anuj via Telegram @echo_sys_bot |
| task-orchestrator | Beads epics, Synapse logging, Notion pre-log |
| devbot | GitHub issues/PRs as echosysbot; autonomous pickup every 5 min |
| ci-monitor | CI failure alerts every 4 min |
| email-triage | echo.sys.bot@gmail.com triage via gogcli |
| code/doc/decision/skill-reviewer | Quality pipeline |
| skill-creation | Author new cc-openclaw skills |

## Key Paths

- Secrets: `~/Documents/agentic-setup/docs/LOCAL-CONTEXT.md`
- Standup script: `~/Documents/agentic-setup/scripts/standup-brief.sh`
- Sherlock research: `~/Documents/agentic-setup/scripts/run-sherlock.sh`
- DevBot guide: `~/Documents/agentic-setup/docs/HOW-TO-USE-DEVBOT.md`

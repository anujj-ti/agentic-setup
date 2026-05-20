# Requirements — Personal AI Operations Hub

## v1 Requirements

### Infrastructure (INFRA)

- [ ] **INFRA-01**: User can install OpenClaw 2026.5.18 on macOS via curl installer with all prerequisites (Node.js 24, GNU Stow via brew)
- [ ] **INFRA-02**: User can deploy all 9 cc-openclaw skills as Claude Code slash commands via git+stow (`/openclaw-new-agent`, `/openclaw-add-channel`, `/openclaw-add-cron`, `/openclaw-dream-setup`, `/openclaw-add-script`, `/openclaw-add-secret`, `/openclaw-status`, `/openclaw-restart`, `/openclaw-stow`)
- [ ] **INFRA-03**: User can store any credential in macOS Keychain with a single command, propagating to all three required files (openclaw-secrets.sh, openclaw-env.sh, secrets.sh) using the naming convention `openclaw.<name>` / `OPENCLAW_<NAME>`
- [ ] **INFRA-04**: User can deploy config changes via Git+Stow from `~/agentic-setup` into `~/.openclaw/` with `jobs.json` symlink conflict automatically resolved before every stow
- [ ] **INFRA-05**: User can install Beads (bd 1.0.4) + embedded Dolt and initialize a single shared task graph database for the execution tier
- [ ] **INFRA-06**: User can verify the full system health (gateway, channels, cron jobs, agents) via `/openclaw-status` in one command

### Orchestration (ORCH)

- [ ] **ORCH-01**: User can send a message via Telegram and receive a coherent, contextual response from the User Orchestrator agent
- [ ] **ORCH-02**: User can delegate a task to the fleet via Telegram and have the User Orchestrator hand it off to the Task Orchestrator without the user managing the delegation manually
- [ ] **ORCH-03**: Task Orchestrator creates a complete Beads task graph (epic + subtasks + dependencies) before spawning any sub-agent — sub-agents receive `bd ready --json` not free-text instructions
- [ ] **ORCH-04**: Sub-agents claim, execute, and close tasks via `bd update --claim` / `bd close --reason` with factual evidence strings — the orchestrator monitors progress via Beads graph queries, not by polling agents
- [ ] **ORCH-05**: User Orchestrator and Task Orchestrator run as separate persistent OpenClaw agents with fully isolated context windows — no shared session state
- [ ] **ORCH-06**: Dream routine runs nightly for both orchestrators: distills daily interactions into MEMORY.md with 2,500-token daily cap and 7,500-token rolling 3-day digest; `memory/archives/` directory exists and receives distillation archives

### Channels (CHAN)

- [ ] **CHAN-01**: User can send and receive messages via Telegram bot provisioned through BotFather, with bot token stored in Keychain via `/openclaw-add-channel`
- [ ] **CHAN-02**: User receives WhatsApp notifications and alerts via `@openclaw/whatsapp` plugin, provisioned on a dedicated number (not personal number)
- [ ] **CHAN-03**: Email Triage agent reads, categorizes, and drafts replies from `echo.sys.bot@gmail.com` using Gmail OAuth2 Device Flow with refresh token in Keychain
- [ ] **CHAN-04**: User receives a morning standup brief via Telegram each morning: overnight GitHub activity summary (PRs merged, CI failures, open review queue, queued decisions from Task Orchestrator)

### Developer Automation (DEV)

- [ ] **DEV-01**: DevBot agent can create GitHub issues from natural language descriptions, assign them to the project board, and set appropriate labels and milestones
- [ ] **DEV-02**: DevBot agent can read and summarize open PRs, flag those with failing CI or review requests unaddressed >24h, and surface the review queue to the user
- [ ] **DEV-03**: CI Monitor agent watches CI/CD runs across tracked repositories and sends a Telegram alert within 5 minutes of a failure, including the failing step and a link
- [ ] **DEV-04**: DevBot agent can autonomously implement GitHub issues via the Beads task graph decomposition pattern (design → implement → self-review → quality-review → open PR)
- [ ] **DEV-05**: DevBot agent can merge PRs that have passed CI and quality review — merger logs the decision to Notion before executing the merge; user can see and revert any autonomous merge
- [ ] **DEV-06**: DevBot agent maintains project context per repository (stack, conventions, open work) and can switch context when delegated a task in a different repo

### Documentation & Memory (MEM)

- [ ] **MEM-01**: Task Orchestrator logs every autonomous decision to a Notion database immediately after execution — log entry contains: timestamp, decision taken, rationale, evidence, reversibility status
- [ ] **MEM-02**: User can review a chronological list of all autonomous decisions taken since last session (surfaced in morning standup brief and on demand via Telegram)
- [ ] **MEM-03**: User can mark any logged decision as "reverted" and the Task Orchestrator takes the appropriate rollback steps (e.g., reverting a merge, re-opening an issue) and logs the revert
- [ ] **MEM-04**: Task Orchestrator logs experiment proposals, execution steps, and results to dedicated Notion pages — each experiment gets its own structured page

### Quality Pipeline (QUAL)

- [ ] **QUAL-01**: Quality Reviewer agent reviews all agent outputs before they surface to the user — applies to: code diffs, documentation drafts, experiment write-ups, decision summaries, and new skill proposals
- [ ] **QUAL-02**: Quality Reviewer agent provides structured feedback (pass / flag with comment / reject with reason) — if flagged or rejected, the originating agent must address feedback before the output advances
- [ ] **QUAL-03**: Skill Creation agent can author new cc-openclaw-compatible skills from observed patterns — skills are structured as SKILL.md files, follow the established format, and are committed to the skills directory
- [ ] **QUAL-04**: Skill Creation agent searches public skill registries (ClawHub, agentskills.io, starred GitHub repos) for existing skills before authoring a new one — reuses and adapts when a good match exists
- [ ] **QUAL-05**: Any new skill authored by Skill Creation agent is reviewed by Quality Reviewer before being stowed into `.claude/skills/`

### Self-Evolution (EVOL)

- [ ] **EVOL-01**: Task Orchestrator can scaffold new OpenClaw agents via `/openclaw-new-agent` when a domain of work repeats that no existing agent covers — new agent proposal is reviewed by Quality Reviewer before execution
- [ ] **EVOL-02**: When a procedural pattern repeats ≥2 times, the Skill Creation agent is triggered to propose a new skill — skill is reviewed, approved, authored, and stowed without user intervention
- [ ] **EVOL-03**: Experiment framework: Task Orchestrator can propose an experiment (hypothesis, method, success criteria), spawn agents to run it, collect results, and log the full cycle to Notion with Quality Reviewer validation of the write-up

---

## v2 Requirements (Deferred)

- Hermes OGP federation — use Hermes agent to drive OpenClaw agent evolution via cross-framework task delegation; defer until core fleet is stable
- Project context switching — dedicated agent that switches dev context between repos with pre-loaded summaries; defer until DevBot is stable
- Voice interaction — Telegram/Discord voice integration; defer

---

## Out of Scope

- Slack integration — not in the user's channel stack for this setup
- Multi-user / team mode — single-user personal operations hub
- Windows or Linux — macOS-specific (Keychain, launchd, stow)
- Jira / Linear — GitHub board is the task system
- Google Docs — Notion is the documentation layer
- Pre-approval blocking — agent DOES NOT wait for user approval before acting; it acts, logs everything, and the user can review and revert asynchronously

---

## Traceability

| REQ-ID | Phase |
|--------|-------|
| INFRA-01..06 | Phase 1 |
| ORCH-01..02, CHAN-01..02 | Phase 2 |
| ORCH-03..06 | Phase 3 |
| CHAN-03..04, DEV-01..03 | Phase 4 |
| DEV-04..06, MEM-01..04 | Phase 5 |
| QUAL-01..05, EVOL-01..03 | Phase 6+ |

*(Traceability updated by roadmapper)*

---

*Last updated: 2026-05-20 after initial requirements definition*

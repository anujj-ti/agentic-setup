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
- [x] **DEV-07**: DevBot autonomously polls for `automation:safe` labeled issues every 5 minutes without human trigger — issues with `automation:hold` are skipped
- [x] **DEV-08**: DevBot claims issues by self-assigning and adding `status:in-progress` label, then creates a linked branch via `gh issue develop`
- [x] **DEV-09**: DevBot opens a draft PR with `Resolves #N` in the body and sets auto-merge (`--squash --delete-branch`) so the issue closes automatically when CI passes
- [x] **DEV-10**: Stale-claim guard automatically unassigns issues where the linked branch has had no commits in over 2 hours, returning them to the pickup pool

### Documentation & Memory (MEM)

- [ ] **MEM-01**: Task Orchestrator logs every autonomous decision to a Notion database immediately after execution — log entry contains: timestamp, decision taken, rationale, evidence, reversibility status
- [ ] **MEM-02**: User can review a chronological list of all autonomous decisions taken since last session (surfaced in morning standup brief and on demand via Telegram)
- [ ] **MEM-03**: User can mark any logged decision as "reverted" and the Task Orchestrator takes the appropriate rollback steps (e.g., reverting a merge, re-opening an issue) and logs the revert
- [ ] **MEM-04**: Task Orchestrator logs experiment proposals, execution steps, and results to dedicated Notion pages — each experiment gets its own structured page

### Quality Pipeline (QUAL)

Each review domain has its own dedicated agent — no single generalist reviewer handles everything.

- [ ] **QUAL-01**: Code Reviewer agent reviews all code diffs, PR implementations, and test coverage produced by DevBot or any execution-tier agent — provides structured feedback (pass / flag with comment / reject with reason); flagged or rejected code must be addressed before advancing
- [ ] **QUAL-02**: Document Reviewer agent reviews all documentation drafts, experiment write-ups, and Notion page content before they are finalized or logged — same structured feedback protocol (pass / flag / reject)
- [ ] **QUAL-03**: Decision Reviewer agent reviews autonomous decision summaries before they are logged to Notion — validates that the rationale is sound, the reversibility status is accurate, and the evidence is specific; rejects vague or unsubstantiated decision entries
- [ ] **QUAL-04**: Skill Reviewer agent reviews all new SKILL.md files authored by the Skill Creation agent — validates format, correctness, safety, and alignment with cc-openclaw conventions before the skill is stowed
- [ ] **QUAL-05**: All reviewer agents return structured feedback in a consistent schema (pass / flag with comment / reject with reason) — if flagged or rejected, the originating agent must address feedback and resubmit; output does not advance until the relevant reviewer passes it
- [ ] **QUAL-06**: Skill Creation agent can author new cc-openclaw-compatible skills from observed patterns — skills are structured as SKILL.md files, follow the established format, and are committed to the skills directory
- [ ] **QUAL-07**: Skill Creation agent searches public skill registries (ClawHub, agentskills.io, starred GitHub repos) for existing skills before authoring a new one — reuses and adapts when a good match exists; search evidence is included in the skill proposal
- [ ] **QUAL-08**: Any new skill authored by Skill Creation agent is reviewed by Skill Reviewer agent (QUAL-04) before being stowed into `.claude/skills/`

### Self-Evolution (EVOL)

- [ ] **EVOL-01**: Task Orchestrator can scaffold new OpenClaw agents via `/openclaw-new-agent` when a domain of work repeats that no existing agent covers — new agent proposal is reviewed by Decision Reviewer agent (QUAL-03) before execution
- [ ] **EVOL-02**: When a procedural pattern repeats ≥2 times, the Skill Creation agent is triggered to propose a new skill — skill is reviewed by Skill Reviewer agent (QUAL-04), approved, authored, and stowed without user intervention
- [ ] **EVOL-03**: Experiment framework: Task Orchestrator can propose an experiment (hypothesis, method, success criteria), spawn agents to run it, collect results, and log the full cycle to Notion with Document Reviewer agent (QUAL-02) validating the write-up before the page is finalized

---

## v2.0 Requirements — Intelligence Layer

### Email Triage Intelligence (TRIAGE)

- [x] **TRIAGE-01**: Email Triage agent assigns a priority score (1–5) to every processed email and logs the score alongside category, sender, and summary in memory/triage-YYYY-MM-DD.md
- [x] **TRIAGE-02**: Email Triage agent enforces a 20% Action Required cap per run and suppresses known-noise senders — both rules encoded in SOUL.md and logged as `pct_action_required` per run
- [x] **TRIAGE-03**: Email Triage agent creates draft reply templates for Action Required emails in a drafts/ folder — drafts are never auto-sent; outbound is always user-initiated
- [x] **TRIAGE-04**: Email Triage agent enforces idempotent processing — same message ID is never processed twice across runs

### Cross-Agent Learning (LEARN)

- [x] **LEARN-01**: All execution-tier agents (task-orchestrator, devbot, ci-monitor, email-triage) call `synapse.learning.query` at session start before taking any action
- [x] **LEARN-02**: Agents whose domains overlap use `cross_silo: true` on Synapse queries — DevBot queries CI Monitor learnings before PR triage; email-triage queries its own historical pattern learnings
- [ ] **LEARN-03**: All agent learning records use consistent 4-field schema: `claim`, `applies_to`, `confidence`, `evidence_artifact_id` — low confidence is the default; medium/high requires evidence
- [x] **LEARN-04**: Dream routines for execution-tier agents merge top cross-silo learnings into MEMORY.md within the 2,500-token daily budget

### Standup Intelligence (STANDUP)

- [ ] **STANDUP-01**: Morning standup brief classifies each item as Blocked / At Risk / On Track using deterministic signals from existing standup JSON (no LLM in the classification path)
- [ ] **STANDUP-02**: Morning standup brief produces a ranked "tackle first" list of 3–5 items — each item cites its specific source field from the standup JSON as evidence
- [ ] **STANDUP-03**: Morning standup brief detects and surfaces patterns when 3+ items share a signal type (multiple CI failures, multiple stale PRs, multiple blocked issues)

### Decision Quality (RISK)

- [ ] **RISK-01**: Decision Reviewer agent assigns `risk_score` (0–100) and `risk_tier` (low/medium/high) to every verdict — including passes — before the decision is written to Notion
- [ ] **RISK-02**: Task Orchestrator routes HIGH-tier decisions through a synchronous Telegram approval request before the Notion pre-log is written — user must approve or reject within a configurable timeout
- [ ] **RISK-03**: Task Orchestrator SOUL.md defines a fast-pass list for known-safe LOW-risk operations and a `failed` verdict policy: timeout does not block autonomous operation — logs a non-blocking audit entry and proceeds

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

| REQ-ID | Phase | Status |
|--------|-------|--------|
| INFRA-01 | Phase 1 — Infrastructure | Pending |
| INFRA-02 | Phase 1 — Infrastructure | Pending |
| INFRA-03 | Phase 1 — Infrastructure | Pending |
| INFRA-04 | Phase 1 — Infrastructure | Pending |
| INFRA-06 | Phase 1 — Infrastructure | Pending |
| CHAN-01 | Phase 2 — Core Channels | Pending |
| CHAN-02 | Phase 2 — Core Channels | Pending |
| ORCH-01 | Phase 3 — User Orchestrator | Pending |
| ORCH-02 | Phase 3 — User Orchestrator | Pending |
| ORCH-05 | Phase 3 — User Orchestrator | Pending |
| INFRA-05 | Phase 4 — Beads + Task Orchestrator | Pending |
| ORCH-03 | Phase 4 — Beads + Task Orchestrator | Pending |
| ORCH-04 | Phase 4 — Beads + Task Orchestrator | Pending |
| ORCH-06 | Phase 5 — Dream Routines | Pending |
| CHAN-03 | Phase 6 — Email + Morning Standup | Pending |
| CHAN-04 | Phase 6 — Email + Morning Standup | Pending |
| DEV-01 | Phase 7 — DevBot Core | Pending |
| DEV-02 | Phase 7 — DevBot Core | Pending |
| DEV-06 | Phase 7 — DevBot Core | Pending |
| DEV-03 | Phase 8 — CI Monitor + Autonomous Dev Scaffold | Pending |
| DEV-04 | Phase 8 — CI Monitor + Autonomous Dev Scaffold | Pending |
| MEM-01 | Phase 9 — Notion Decision Log | Pending |
| MEM-02 | Phase 9 — Notion Decision Log | Pending |
| MEM-03 | Phase 9 — Notion Decision Log | Pending |
| MEM-04 | Phase 9 — Notion Decision Log | Pending |
| DEV-05 | Phase 10 — Autonomous Merge | Pending |
| QUAL-01 | Phase 11 — Quality Pipeline | Pending |
| QUAL-02 | Phase 11 — Quality Pipeline | Pending |
| QUAL-03 | Phase 11 — Quality Pipeline | Pending |
| QUAL-04 | Phase 11 — Quality Pipeline | Pending |
| QUAL-05 | Phase 11 — Quality Pipeline | Pending |
| QUAL-06 | Phase 11 — Quality Pipeline | Pending |
| QUAL-07 | Phase 11 — Quality Pipeline | Pending |
| QUAL-08 | Phase 11 — Quality Pipeline | Pending |
| EVOL-01 | Phase 12 — Self-Evolution | Pending |
| EVOL-02 | Phase 12 — Self-Evolution | Pending |
| EVOL-03 | Phase 12 — Self-Evolution | Pending |

| TRIAGE-01 | Phase 15 — Smarter Email Triage | Complete |
| TRIAGE-02 | Phase 15 — Smarter Email Triage | Complete |
| TRIAGE-03 | Phase 15 — Smarter Email Triage | Complete |
| TRIAGE-04 | Phase 15 — Smarter Email Triage | Complete |
| LEARN-01 | Phase 16 — Cross-Agent Learning Infrastructure | Complete |
| LEARN-02 | Phase 16 — Cross-Agent Learning Infrastructure | Complete |
| LEARN-03 | Phase 16 — Cross-Agent Learning Infrastructure | Pending |
| LEARN-04 | Phase 16 — Cross-Agent Learning Infrastructure | Complete |
| STANDUP-01 | Phase 17 — Proactive Standup Insights | Pending |
| STANDUP-02 | Phase 17 — Proactive Standup Insights | Pending |
| STANDUP-03 | Phase 17 — Proactive Standup Insights | Pending |
| RISK-01 | Phase 18 — Decision Quality Risk Gate | Pending |
| RISK-02 | Phase 18 — Decision Quality Risk Gate | Pending |
| RISK-03 | Phase 18 — Decision Quality Risk Gate | Pending |
| DEV-07 | Phase 19 — DevBot Autonomous Issue Pickup | Complete |
| DEV-08 | Phase 19 — DevBot Autonomous Issue Pickup | Complete |
| DEV-09 | Phase 19 — DevBot Autonomous Issue Pickup | Complete |
| DEV-10 | Phase 19 — DevBot Autonomous Issue Pickup | Complete |

*(Traceability updated by roadmapper — 2026-05-21; v2.0 Intelligence Layer phases 15-18 added)*

---

*Last updated: 2026-05-20 after roadmap creation*

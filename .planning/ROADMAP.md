# Roadmap: Personal AI Operations Hub

## Overview

Build a self-evolving AI agent fleet on macOS/OpenClaw that operates autonomously while the user is away — triaging email, managing GitHub, monitoring CI, and merging PRs — routing all interactions through Telegram, logging every autonomous decision to Notion, and handing back clean control on return. The build follows a hard dependency chain: infrastructure and configuration governance first, then dual orchestrators, then Beads-enforced execution sub-agents, then the Notion trust layer that gates autonomous merge permissions, then the quality pipeline that gates self-evolution. Each phase delivers a working, verifiable slice that cannot be bypassed without breaking the next.

## Phases

**Phase Numbering:**
- Integer phases (1, 2, 3): Planned milestone work
- Decimal phases (2.1, 2.2): Urgent insertions (marked with INSERTED)

Decimal phases appear between their surrounding integers in numeric order.

- [ ] **Phase 1: Infrastructure** - OpenClaw installed, cc-openclaw skills deployed, secrets pipeline operational, stow deploy working, health check green
- [x] **Phase 2: Core Channels** - Telegram channel provisioned, token in Keychain, round-trip message verified (WhatsApp deferred — D-20) (completed 2026-05-20)
- [x] **Phase 3: User Orchestrator** - User Orchestrator live on Telegram with coherent responses and delegation to Task Orchestrator, isolated context windows (completed 2026-05-20)
- [x] **Phase 4: Beads + Task Orchestrator** - Beads installed with shared BEADS_DIR, Task Orchestrator creates task graphs before spawning sub-agents, claim/close cycle verified (completed 2026-05-20)
- [x] **Phase 5: Dream Routines** - Nightly memory distillation running for both orchestrators with token budget enforcement and archive directories (completed 2026-05-20)
- [x] **Phase 6: Email + Morning Standup** - Gmail Email Triage agent operational, morning standup brief delivered via Telegram on schedule (completed 2026-05-20)
- [x] **Phase 7: DevBot Core** - DevBot can create GitHub issues, summarize PRs, flag stale reviews, and maintain per-repo context (completed 2026-05-20)
- [x] **Phase 8: CI Monitor + Autonomous Dev Scaffold** - CI Monitor alerts within 5 minutes of failure; DevBot can autonomously implement issues via Beads task graph (completed 2026-05-20)
- [ ] **Phase 9: Notion Decision Log** - Every autonomous decision logged to Notion before execution; user can review chronologically and mark decisions for revert; experiment logging operational
- [ ] **Phase 10: Autonomous Merge** - DevBot can merge CI-passing PRs with Notion pre-log; user can see and revert any autonomous merge
- [ ] **Phase 11: Quality Pipeline** - Five dedicated review agents deployed (Code Reviewer, Document Reviewer, Decision Reviewer, Skill Reviewer, Skill Creation); each output domain has its own specialist reviewer
- [ ] **Phase 12: Self-Evolution** - Task Orchestrator scaffolds new agents via `/openclaw-new-agent`; skill creation triggers on repeating patterns; experiment framework complete

## Phase Details

### Phase 1: Infrastructure
**Goal**: The OpenClaw runtime, cc-openclaw skills, secrets pipeline, and stow deployment are fully operational — every subsequent phase uses this as its sole configuration path
**Mode:** mvp
**Depends on**: Nothing (first phase)
**Requirements**: INFRA-01, INFRA-02, INFRA-03, INFRA-04, INFRA-06
**Success Criteria** (what must be TRUE):
  1. User runs `/openclaw-status` and receives green status across gateway, channels, cron jobs, and agents
  2. User runs `/openclaw-add-secret <name> <value>` and the credential appears correctly in all three files: `openclaw-secrets.sh`, `openclaw-env.sh`, and `secrets.sh`
  3. User runs a stow deploy from `~/agentic-setup` and `jobs.json` symlink conflict is automatically resolved without manual intervention
  4. All 9 cc-openclaw skills are available as Claude Code slash commands and each invocation produces the expected output
  5. A test cron job created via `/openclaw-add-cron` appears in `/openclaw-status` output with the correct local timezone field (not UTC)
**Plans**: 5 plans

Plans:

**Wave 1** *(parallel — no dependencies)*
- [x] 01-01-PLAN.md — Install prerequisites (Homebrew node@24, stow, jq) + create Wave 0 source-of-truth files + install/upgrade OpenClaw 2026.5.18 with LaunchAgent (INFRA-01)
- [x] 01-02-PLAN.md — Add cc-openclaw as a git submodule and stow its 9 skills into .claude/skills/ via --no-folding (INFRA-02)

**Wave 2** *(blocked on Wave 1 completion)*
- [x] 01-04-PLAN.md — Create scripts/stow-deploy.sh + scripts/infra-verify.sh; establish stow management over ~/.openclaw/ (INFRA-04)

**Wave 3** *(blocked on Wave 2 — requires stow symlink for OPENCLAW_REPO detection)*
- [x] 01-03-PLAN.md — Add a test secret via /openclaw-add-secret to verify the three-file pipeline end-to-end (INFRA-03)

**Wave 4** *(blocked on Wave 3 completion — phase gate)*
- [ ] 01-05-PLAN.md — Verify /openclaw-status green + create a test cron job with local tz to prove INFRA-06 end-to-end (INFRA-06)

**Cross-cutting constraints:**
- All scripts: `#!/usr/bin/env zsh` + `set -euo pipefail` (CLAUDE.md mandate — never `#!/bin/bash`)
- Secrets: Keychain only — never passed as CLI args, never in tracked files
- Every stow invocation: `rm -f ~/.openclaw/cron/jobs.json` must precede stow
- `openclaw onboard --install-daemon` is interactive — user must run in terminal (Plans 01-01, 01-05)

### Phase 2: Core Channels
**Goal**: Telegram channel provisioned, token in Keychain, round-trip message verified — WhatsApp deferred to a future phase per D-20 (2026-05-21)
**Mode:** mvp
**Depends on**: Phase 1
**Requirements**: CHAN-01 (CHAN-02 deferred)
**Success Criteria** (what must be TRUE):
  1. User sends a message to the Telegram bot and receives an acknowledgment (round-trip verified)
  2. Telegram bot token is stored in Keychain via the cc-openclaw convention (`openclaw.telegram-main-bot-token`) and never appears in any file or git history
  3. ~~WhatsApp plugin (`@openclaw/whatsapp`) provisioned on a dedicated number~~ **DEFERRED — Phase 2 covers Telegram only; WhatsApp planned for a future phase per D-20 (2026-05-21)**
  4. Telegram channel appears as active in `/openclaw-status` channel output
**Plans**: 2 plans
**UI hint**: yes

Plans:

**Wave 1** *(autonomous — no dependencies)*
- [x] 02-01-PLAN.md — Wire Telegram channel: transfer token to Keychain, update three secrets pipeline files, add channels.telegram.accounts.main to openclaw.json with env var ref, stow+restart, shred pre-stow backups (CHAN-01)

**Wave 2** *(blocked on Wave 1 — requires live channel)*
- [x] 02-02-PLAN.md — Verify Telegram round-trip: automated smoke tests, pairing flow, outbound message confirmation; update ROADMAP with deferred WhatsApp note (CHAN-01)

**Deferred:**
- [ ] 02-03-PLAN.md — DEFERRED: WhatsApp plugin provisioning (`@openclaw/whatsapp`) on dedicated number (CHAN-02 — D-20, 2026-05-21)

**Cross-cutting constraints:**
- All scripts: `#!/usr/bin/env zsh` + `set -euo pipefail` (CLAUDE.md mandate)
- Secrets: Keychain only — token never written to files, never in git history
- Explicit binary paths: `/opt/homebrew/bin/openclaw` (nvm PATH shadowing issue from Phase 1)
- Token transfer via pipe only — no intermediate files, no echo to terminal

### Phase 3: User Orchestrator
**Goal**: The User Orchestrator agent is live on Telegram — users can send messages and receive coherent contextual responses, and the orchestrator can delegate tasks to the Task Orchestrator without the user managing delegation manually
**Mode:** mvp
**Depends on**: Phase 2
**Requirements**: ORCH-01, ORCH-02, ORCH-05
**Success Criteria** (what must be TRUE):
  1. User sends a message via Telegram and receives a coherent, contextual response from the User Orchestrator within the expected latency
  2. User delegates a task via Telegram and the User Orchestrator hands it off to the Task Orchestrator — user does not manually manage the delegation
  3. User Orchestrator and Task Orchestrator run as separate persistent OpenClaw agents with fully isolated context windows (verified by inspecting their separate session state)
  4. User Orchestrator SOUL.md is configured via `/openclaw-new-agent` — no manual file edits were made to achieve the configuration
**Plans**: 4 plans
**UI hint**: yes

Plans:

**Wave 1** *(parallel — no dependencies)*
- [x] 03-01-PLAN.md — Scaffold User Orchestrator: runtime dirs, 6 directive files (SOUL.md + 5), agents.list entry with subagents.allowAgents + delegationMode + tools.alsoAllow, update Telegram binding to user-orchestrator, stow+restart (ORCH-01, ORCH-02, ORCH-05)
- [x] 03-02-PLAN.md — Write scripts/verify-phase-03.sh (9-check automated smoke test); run it to confirm 03-01 state (ORCH-01, ORCH-05)

**Wave 2** *(blocked on Wave 1 — requires user-orchestrator entry in agents.list)*
- [x] 03-03-PLAN.md — Scaffold Task Orchestrator: runtime dirs, 6 directive files, agents.list entry (no Telegram binding, Beads-free Phase 3 stub), stow+restart (ORCH-02, ORCH-05)

**Wave 3** *(blocked on Wave 2 — phase gate)*
- [x] 03-04-PLAN.md — Run full verification suite; confirm isolated session stores and workspaces; write phase SUMMARY with delegation test runbook for user on return (ORCH-01, ORCH-02, ORCH-05)

**Cross-cutting constraints:**
- All scripts: `#!/usr/bin/env zsh` + `set -euo pipefail` (CLAUDE.md mandate)
- Explicit binary: `/opt/homebrew/bin/openclaw` (nvm PATH shadowing issue)
- Stow deploy: `scripts/stow-deploy.sh` — only valid entry point; removes `jobs.json` before stow
- Daemon restart: `launchctl kickstart -k gui/$(id -u)/ai.openclaw.gateway` (separate from stow per D-10)
- openclaw.json agent paths: use `/Users/trilogy/...` literal, never `~`
- No new Keychain entries in Phase 3 — no new secrets

### Phase 4: Beads + Task Orchestrator
**Goal**: Beads (bd) is installed with a single shared `BEADS_DIR` exported to all agents in the execution tier; the Task Orchestrator creates a complete task graph (epic + subtasks + dependencies) before spawning any sub-agent, and the claim/close cycle is verified end-to-end
**Mode:** mvp
**Depends on**: Phase 3
**Requirements**: INFRA-05, ORCH-03, ORCH-04
**Success Criteria** (what must be TRUE):
  1. `bd ready --json` returns a valid task list from a sub-agent context, confirming `BEADS_DIR` is correctly exported and accessible to execution-tier agents
  2. Task Orchestrator creates a complete Beads epic with all subtasks and dependencies before spawning any sub-agent — sub-agents receive only `bd ready --json`, never free-text instructions
  3. A sub-agent completes the full claim/close cycle: `bd update --claim` → executes work → `bd close --reason "<factual evidence string>"` — Task Orchestrator monitors progress via Beads graph queries, not by polling the agent
  4. `bd init --stealth` is confirmed to use the single shared Beads DB at the designated `BEADS_DIR` path
**Plans**: 4 plans

Plans:

**Wave 1** *(autonomous — no dependencies)*
- [x] 04-01-PLAN.md — Install dolt + bd 1.0.4 under node@24; create verify-phase-04.sh (INFRA-05)

**Wave 2** *(blocked on Wave 1 — bd must exist before bd init)*
- [x] 04-02-PLAN.md — Initialize shared Beads DB at BEADS_DIR; inject BEADS_DIR into gateway env; stow+restart+verify (INFRA-05)

**Wave 3** *(blocked on Wave 2 — BEADS_DIR must be live before updating agent SOUL)*
- [x] 04-03-PLAN.md — Replace Task Orchestrator SOUL.md with Beads execution contract; update TOOLS.md with bd command reference (ORCH-03, ORCH-04)

**Wave 4** *(blocked on Wave 3 — phase gate)*
- [x] 04-04-PLAN.md — Run end-to-end claim/close cycle; verify all 6 smoke checks green (ORCH-03, ORCH-04)

**Cross-cutting constraints:**
- All scripts: `#!/usr/bin/env zsh` + `set -euo pipefail` (CLAUDE.md mandate)
- bd binary path: `/opt/homebrew/opt/node@24/bin/bd` (explicit, never rely on PATH — D-51)
- BEADS_DIR: `$HOME/.openclaw/beads` (top-level shared path — D-50)
- dolt must be installed BEFORE bd install and BEFORE bd init (D-52)
- After secrets file update: stow-deploy.sh + gateway restart + verify BEADS_DIR in gateway.env (D-55)

### Phase 5: Dream Routines
**Goal**: Nightly memory distillation is running for both orchestrators — daily summaries stay within the 2,500-token cap, 3-day digests stay within 7,500 tokens, and archive directories exist and receive files on each run
**Mode:** mvp
**Depends on**: Phase 4
**Requirements**: ORCH-06
**Success Criteria** (what must be TRUE):
  1. Dream routine cron job exists for both User Orchestrator and Task Orchestrator in `/openclaw-status` output with correct local timezone
  2. After the first nightly run, `memory/archives/` directory exists and contains a dated archive file for each orchestrator
  3. Daily MEMORY.md for each orchestrator is within the 2,500-token cap (verifiable by token count on the file)
  4. 3-day rolling digest is present and within the 7,500-token cap
**Plans**: 4 plans

Plans:

**Wave 1** *(parallel — no dependencies)*
- [x] 05-01-PLAN.md — Create DREAM-ROUTINE.md (23:00 IST trigger, 2,500/7,500 token budgets), MEMORY.md stub, and updated AGENTS.md memory load sequence for User Orchestrator (ORCH-06)
- [x] 05-02-PLAN.md — Create DREAM-ROUTINE.md (23:05 IST trigger, silent delivery), MEMORY.md stub, and updated AGENTS.md memory load sequence for Task Orchestrator (ORCH-06)

**Wave 2** *(blocked on Wave 1 — requires DREAM-ROUTINE.md and MEMORY.md in repo)*
- [x] 05-03-PLAN.md — Create .openclaw/cron/ directory and jobs.json with both dream cron entries; add QMD paths to openclaw.json; run stow-deploy.sh + restart gateway (ORCH-06)

**Wave 3** *(blocked on Wave 2 — phase gate)*
- [x] 05-04-PLAN.md — Write and run scripts/verify-phase-05.sh: 6 ORCH-06 pre-run smoke checks; note that token cap checks (success criteria 3 and 4) require manual post-run verification after first 23:00 IST run (ORCH-06)

**Cross-cutting constraints:**
- All scripts: `#!/usr/bin/env zsh` + `set -euo pipefail` (CLAUDE.md mandate)
- Explicit binary: `/opt/homebrew/bin/openclaw` (nvm PATH shadowing issue)
- Stow deploy: `scripts/stow-deploy.sh` — canonical entry point (D-48)
- Gateway restart: `launchctl kickstart -k gui/$(id -u)/ai.openclaw.gateway` (D-50)
- openclaw.json QMD paths: use `/Users/trilogy/...` literal, never `~` or `$HOME` (D-47)
- jobs.json schema: `{"kind": "cron", "expr": "...", "tz": "..."}` nested form — not flat (D-40)
- Task Orchestrator delivery: `{"mode": "silent"}` — no channel field (D-42)
- Model in cron payloads: `anthropic/claude-sonnet-4-6` (D-41)
- memory/archives/ dirs already exist in live agent paths — no mkdir needed (D-44)

### Phase 6: Email + Morning Standup
**Goal**: The Email Triage agent reads and categorizes email from `echo.sys.bot@gmail.com`, and a morning standup brief is delivered via Telegram each morning summarizing overnight GitHub activity and queued decisions
**Mode:** mvp
**Depends on**: Phase 5
**Requirements**: CHAN-03, CHAN-04
**Success Criteria** (what must be TRUE):
  1. Email Triage agent reads unread messages from `echo.sys.bot@gmail.com`, categorizes them, and drafts replies — Gmail OAuth2 refresh token is stored in Keychain (never in files)
  2. User receives a morning standup brief via Telegram each morning containing: PRs merged overnight, CI failures, open review queue, and queued decisions from Task Orchestrator
  3. Morning standup cron job appears in `/openclaw-status` with the correct local timezone and fires on schedule
  4. Email Triage agent OAuth2 re-auth runbook is documented in the agent's TOOLS.md
**Plans**: 5 plans
**UI hint**: yes

Plans:

**Wave 1** *(parallel — no dependencies)*
- [x] 06-01-PLAN.md — Scaffold email-triage agent (6 directive files + memory dirs), install googleapis@172.0.0 in agent scripts/, create gmail-triage.js stub (OAuth2 from Keychain env vars), register agent in openclaw.json with exec in tools.alsoAllow, add Gmail Keychain stubs to three-file secrets pipeline (CHAN-03)
- [x] 06-02-PLAN.md — Create oauth2-setup.js (Installed App flow, localhost:8080, stores refresh token in Keychain), checkpoint:human-verify for browser OAuth2 step on user return (CHAN-03)

**Wave 2** *(blocked on Wave 1 — requires agent directive files)*
- [x] 06-03-PLAN.md — Write complete OAuth2 re-auth runbook into email-triage TOOLS.md (6 sub-sections: GCP setup, Keychain storage, auth script, verify+restart, agent test, token expiry notes) — satisfies ROADMAP SC#4 (CHAN-03)
- [x] 06-04-PLAN.md — Create scripts/standup-brief.sh (zsh strict mode, --repo OWNER/REPO flag, BSD date, gh CLI queries, json_ok output); add exec to user-orchestrator tools.alsoAllow in openclaw.json; update User Orchestrator TOOLS.md with exec policy + standup invocation (CHAN-04)

**Wave 3** *(blocked on Wave 2 — phase gate)*
- [x] 06-05-PLAN.md — Add Morning Standup Brief cron entry to jobs.json (08:00 Asia/Kolkata, user-orchestrator, 180s timeout, announce/last delivery), stow+restart, write + run scripts/verify-phase-06.sh (8 smoke checks), document PENDING OAuth2 items (CHAN-03, CHAN-04)

**Cross-cutting constraints:**
- All scripts: `#!/usr/bin/env zsh` + `set -euo pipefail` (CLAUDE.md mandate — never `#!/bin/bash`)
- Secrets: Keychain only — Gmail credentials never written to files, never echoed to stdout (D-63)
- googleapis: install in agent scripts/ directory only — NOT globally (CLAUDE.md mandate, D-60)
- OAuth2 flow: Installed App (localhost:8080 redirect) — NOT Device Flow (D-61)
- jobs.json schema: `{"kind": "cron", "expr": "0 8 * * *", "tz": "Asia/Kolkata"}` nested form (D-40 pattern)
- openclaw.json paths: `/Users/trilogy/...` literal — never `~` or `$HOME` (D-47 pattern)
- Stow deploy: `scripts/stow-deploy.sh` — canonical entry point (D-48 pattern)
- Gateway restart: `launchctl kickstart -k gui/$(id -u)/ai.openclaw.gateway` (D-50 pattern)
- exec tool added to user-orchestrator for standup ONLY — exec policy in TOOLS.md is CRON session restriction (D-65)

### Phase 7: DevBot Core
**Goal**: The DevBot agent can create GitHub issues from natural language, summarize and flag stale PRs, and maintain per-repository context — the foundation for autonomous development work
**Mode:** mvp
**Depends on**: Phase 6
**Requirements**: DEV-01, DEV-02, DEV-06
**Success Criteria** (what must be TRUE):
  1. User describes a task in natural language via Telegram and DevBot creates a properly labeled GitHub issue assigned to the correct project board and milestone
  2. DevBot surfaces the PR review queue on demand: open PRs with failing CI or unaddressed review requests older than 24 hours are identified and summarized
  3. DevBot correctly loads and uses per-repository context (stack, conventions, open work) when delegated a task in a specific repo — context switches cleanly when a different repo is specified
  4. All DevBot GitHub operations use `gh` CLI 2.92.0 and produce structured JSON output to stdout with logs to stderr
**Plans**: 4 plans

Plans:

**Wave 1** *(parallel — no dependencies)*
- [x] 07-01-PLAN.md — Scaffold DevBot agent + upgrade gh to 2.92.0, add project OAuth scope, register devbot in openclaw.json, wire task-orchestrator allowAgents (DEV-01, DEV-06)
- [x] 07-02-PLAN.md — Create devbot-issue-create.sh with duplicate check, project board assignment via --project flag, JSON stdout output (DEV-01)

**Wave 2** *(blocked on Wave 1 — depends on 07-02 json-response lib)*
- [x] 07-03-PLAN.md — Create devbot-pr-queue.sh: single gh pr list call with statusCheckRollup CI detection and 24h staleness filter (DEV-02)

**Wave 3** *(blocked on Wave 1+3 — phase gate)*
- [x] 07-04-PLAN.md — Create CONTEXT-TEMPLATE.md for per-repo context store, write devbot-verify.sh (7 smoke checks + end-to-end test issue create/close) (DEV-01, DEV-02, DEV-06)

**Cross-cutting constraints:**
- All scripts: `#!/usr/bin/env zsh` + `set -euo pipefail` (CLAUDE.md mandate)
- gh binary: `/opt/homebrew/bin/gh` explicit path in all scripts (nvm PATH shadowing prevention)
- openclaw.json paths: `/Users/trilogy/...` literal, never `~` (established pattern)
- Stow deploy: `scripts/stow-deploy.sh` — canonical entry point for all openclaw.json changes
- DevBot: no Telegram binding — sessions_spawn from Task Orchestrator only (D-75)
- Per-repo context: `~/.openclaw/workspace-devbot/repos/<owner>-<repo>/CONTEXT.md` (D-73)

### Phase 8: CI Monitor + Autonomous Dev Scaffold
**Goal**: The CI Monitor agent watches tracked repositories and pages the user via Telegram within 5 minutes of a failure; DevBot can autonomously implement GitHub issues by decomposing them into a Beads task graph and executing the design → implement → self-review → quality-review → open PR cycle
**Mode:** mvp
**Depends on**: Phase 7
**Requirements**: DEV-03, DEV-04
**Success Criteria** (what must be TRUE):
  1. When a CI run fails on a tracked repository, the user receives a Telegram alert within 5 minutes containing the failing step name and a direct link to the run
  2. DevBot, when delegated a GitHub issue, creates a Beads epic with the standard 5-subtask template (design → implement → self-review → quality-review → open PR) before writing a single line of code
  3. DevBot completes the full Beads claim/close cycle for each subtask, with factual evidence strings in close reasons
  4. CI Monitor appears in `/openclaw-status` with its polling cron and correct timezone
**Plans**: 5 plans
**UI hint**: yes

**Wave 1** *(parallel — no dependencies)*
- [x] 08-01-PLAN.md — Scaffold CI Monitor agent (6 directive files + poll-ci.sh + state/) + OPENCLAW_ANUJ_CHAT_ID Keychain stub (DEV-03)

**Wave 2** *(parallel — both blocked on Wave 1)*
- [x] 08-02-PLAN.md — Register ci-monitor in openclaw.json + add */4 * * * * cron to jobs.json, stow+restart, verify status (DEV-03)
- [x] 08-03-PLAN.md — Create devbot-intake-issue.sh + update DevBot SOUL.md/TOOLS.md with autonomous dev workflow documentation (DEV-04)

**Wave 3** *(blocked on Wave 2)*
- [x] 08-04-PLAN.md — Create devbot-create-epic.sh (5-subtask Beads epic) + devbot-execute-cycle.sh (claim→execute→close per task type) (DEV-04)

**Wave 4** *(blocked on Wave 3 — phase gate)*
- [x] 08-05-PLAN.md — Write + run verify-phase-08.sh (7 smoke checks); manual test runbook for Telegram alert and Beads cycle (DEV-03, DEV-04)

### Phase 9: Notion Decision Log
**Goal**: Every autonomous decision made by the Task Orchestrator is logged to Notion immediately after execution; the user can retrieve a chronological list of decisions since last session on demand and via the morning standup brief; experiment proposals, execution, and results are logged to dedicated Notion pages
**Mode:** mvp
**Depends on**: Phase 8
**Requirements**: MEM-01, MEM-02, MEM-03, MEM-04
**Success Criteria** (what must be TRUE):
  1. Every autonomous action by the Task Orchestrator creates a Notion log entry containing: timestamp, decision taken, rationale, evidence, and reversibility status — log entry exists before the action executes
  2. User asks "what did you do while I was away?" via Telegram and receives a chronological list of all autonomous decisions since last session
  3. User marks a logged decision as "reverted" and the Task Orchestrator executes the appropriate rollback steps (e.g., revert merge, reopen issue) and logs the revert as a new decision entry
  4. Each experiment proposal gets its own structured Notion page with: hypothesis, method, success criteria, execution steps, and results — page exists before the experiment begins
  5. Morning standup brief includes the count and summary of autonomous decisions taken overnight
**Plans**: 6 plans

Plans:

**Wave 1** *(autonomous — no dependencies)*
- [ ] 09-01-PLAN.md — Install @notionhq/client@5.22.0 in task-orchestrator scripts/, create config.json template, stub OPENCLAW_NOTION_TOKEN in secrets pipeline, human checkpoint for Notion integration setup (MEM-01, MEM-02, MEM-03, MEM-04)

**Wave 2** *(parallel — blocked on Wave 1 human checkpoint)*
- [ ] 09-02-PLAN.md — Create log-decision.js (pre-execution logger, 8-field schema, TODO_NOTION guard) + update-decision.js (revert_status updater) with shell wrappers (MEM-01, MEM-03)
- [ ] 09-03-PLAN.md — Create query-decisions.js (since last-session.json timestamp, created_time filter), update User Orchestrator SOUL.md with Decision Retrieval Protocol (MEM-02)
- [ ] 09-04-PLAN.md — Create revert-decision.js (4-step revert workflow: pending_revert → rollback → log revert → reverted), update Task Orchestrator SOUL.md with Revert Workflow Protocol (MEM-03)

**Wave 3** *(blocked on Wave 2 — requires log-decision.js and update-decision.js)*
- [ ] 09-05-PLAN.md — Create create-experiment.js + append-experiment-results.js (heading+paragraph block template), add Notion Pre-Log Protocol (MANDATORY) to Task Orchestrator SOUL.md (MEM-01, MEM-04)

**Wave 4** *(blocked on Wave 3 — phase gate)*
- [ ] 09-06-PLAN.md — Wire autonomous decision count into standup-brief.sh, create verify-phase-09.sh (12 smoke checks + full integration mode) (MEM-01, MEM-02, MEM-03, MEM-04)

### Phase 10: Autonomous Merge
**Goal**: DevBot can merge PRs that have passed CI and quality review — each merge is pre-logged to Notion before execution, and the user can see and revert any autonomous merge from the decision log
**Mode:** mvp
**Depends on**: Phase 9
**Requirements**: DEV-05
**Success Criteria** (what must be TRUE):
  1. DevBot merges a CI-passing, quality-reviewed PR only after a Notion decision log entry exists for that specific merge — the log entry is created and confirmed before `gh pr merge` is invoked
  2. User can find the merge decision in the Notion log with reversibility status and, if they choose, mark it for revert — Task Orchestrator reopens the PR and reverts the merge commit
  3. DevBot does not merge any PR that lacks a Notion log entry (enforced in SECURITY.md rules loaded in DevBot SOUL.md)
**Plans**: 4 plans

Plans:

**Wave 1** *(parallel — no dependencies)*
- [ ] 10-01-PLAN.md — Create devbot-merge-pr.sh (CI check + Notion pre-log gate + gh pr merge --squash) + notion-log-decision.js + notion-update-page.js + SECURITY.md gate rule (DEV-05)
- [ ] 10-02-PLAN.md — Add Autonomous Merge Protocol to DevBot SOUL.md (NEVER invoke gh pr merge directly) + update TOOLS.md with merge/revert command reference and required env vars (DEV-05)

**Wave 2** *(blocked on Wave 1 — uses notion-log-decision.js from 10-01)*
- [ ] 10-03-PLAN.md — Create devbot-revert-merge.sh (git revert <sha> --no-edit + git push + gh pr reopen + Notion revert log entry) (DEV-05)

**Wave 3** *(blocked on Waves 1 and 2 — phase gate)*
- [ ] 10-04-PLAN.md — Create and run scripts/verify-phase-10.sh (8 checks: files exist, syntax valid, SECURITY.md gate rule, SOUL.md merge protocol, negative gate test without env vars, revert arg validation, @notionhq/client installed, no -m 1 in revert script) (DEV-05)

**Cross-cutting constraints:**
- All scripts: `#!/usr/bin/env zsh` + `set -euo pipefail` (CLAUDE.md mandate)
- Merge strategy: `--squash` only (D-101) — never --merge, --rebase, --admin, --auto
- Revert: `git revert <sha> --no-edit` (no -m 1 flag — squash commits are single-parent per D-103)
- Notion pre-log is a code-level gate, not just policy (D-100): script exits 1 before gh pr merge if PAGE_ID empty
- @notionhq/client: install in devbot scripts/ directory — NOT globally (CLAUDE.md mandate)
- Merge commit SHA captured via `gh pr view --json mergeCommit` and stored in Notion page (D-102)

### Phase 11: Quality Pipeline
**Goal**: Five dedicated specialist agents are deployed — Code Reviewer, Document Reviewer, Decision Reviewer, Skill Reviewer, and Skill Creation — each owning a distinct review domain; no single generalist reviewer handles more than one domain; all agent outputs are gated by the appropriate specialist before they advance
**Mode:** mvp
**Depends on**: Phase 10
**Requirements**: QUAL-01, QUAL-02, QUAL-03, QUAL-04, QUAL-05, QUAL-06, QUAL-07, QUAL-08
**Success Criteria** (what must be TRUE):
  1. Code Reviewer agent is live and routes all DevBot code diffs through structured review (pass / flag / reject) before any PR is opened or output surfaces to the user
  2. Document Reviewer agent is live and validates all documentation drafts and Notion page content before they are finalized — flagged content is returned to the originating agent for revision
  3. Decision Reviewer agent is live and reviews every autonomous decision summary before it is written to the Notion decision log — rejects vague or unsubstantiated entries
  4. Skill Reviewer agent is live and validates all new SKILL.md files for format, safety, and cc-openclaw convention compliance before stow
  5. Skill Creation agent is live, searches ClawHub/agentskills.io/starred GitHub before authoring, and produces SKILL.md files that Skill Reviewer approves and `/openclaw-stow` deploys — each new skill appears in `/openclaw-status` after stow
**Plans**: 7 plans

Plans:

**Wave 1** *(parallel — all 5 agent scaffolds are independent)*
- [ ] 11-01-PLAN.md — Scaffold code-reviewer via /openclaw-new-agent; SOUL.md: 7-item rubric (shebang, strict mode, stdout discipline, Keychain secrets, explicit binary paths, test coverage, JSON shape) + D-111 verdict schema + diff-only rule (QUAL-01, QUAL-05)
- [ ] 11-02-PLAN.md — Scaffold document-reviewer via /openclaw-new-agent; SOUL.md: specificity rubric + Notion experiment/decision page structure checks + anti-vagueness rule (QUAL-02, QUAL-05)
- [ ] 11-03-PLAN.md — Scaffold decision-reviewer via /openclaw-new-agent; SOUL.md: rationale soundness + reversibility specificity + evidence observability + anti-circular rule (QUAL-03, QUAL-05)
- [ ] 11-04-PLAN.md — Scaffold skill-reviewer via /openclaw-new-agent; SOUL.md: required vs optional frontmatter, security checklist (postinstall/hardcoded secrets/network calls), stow gate ownership rule (D-114) (QUAL-04, QUAL-05, QUAL-08)
- [ ] 11-05-PLAN.md — Scaffold skill-creation via /openclaw-new-agent; SOUL.md: registry-search-first mandate + anti-stow rule (D-114); create search-skill-registries.sh with || echo fallbacks (D-113) (QUAL-06, QUAL-07, QUAL-08)

**Wave 2** *(blocked on Wave 1 — all 5 agents must exist before wiring)*
- [ ] 11-06-PLAN.md — Add all 5 agents to task-orchestrator allowAgents (D-112); update Task Orchestrator SOUL.md with pipeline routing rules + 3-reject convergence rule; stow+restart (QUAL-01 through QUAL-08)

**Wave 3** *(blocked on Wave 2 — phase gate)*
- [ ] 11-07-PLAN.md — Create and run scripts/verify-phase-11.sh: 5-agent structural checks, D-111 verdict schema in all SOUL.md files, allowAgents contains all 5, specific rule checks (NEVER stow, stow gate, anti-circular, anti-vagueness, diff-only), registry search script runs and exits 0 (QUAL-01 through QUAL-08)

**Cross-cutting constraints:**
- All agents scaffolded via /openclaw-new-agent (CLAUDE.md mandate — never manual file creation)
- Verdict schema (D-111): {"verdict":"pass"|"flag"|"reject","comments":[],"must_fix":[],"approved_at":"ISO8601"|null}
- Stow gate (D-114): /openclaw-stow runs from Task Orchestrator only — never from Skill Creation or Skill Reviewer
- Registry search (D-113): all three searches are best-effort with || echo fallbacks — unreachable = no results, not error
- Feedback loop convergence: max 3 reject cycles per artifact → Telegram escalation + BLOCKED
- Decision Reviewer anti-circular: own invocation is pre-approved (no recursion)

### Phase 12: Self-Evolution
**Goal**: The Task Orchestrator can scaffold new agents when a new domain of work is identified, trigger skill creation when a procedural pattern repeats twice, and run the full experiment cycle (propose → spawn agents → collect results → log to Notion with Quality Reviewer validation)
**Mode:** mvp
**Depends on**: Phase 11
**Requirements**: EVOL-01, EVOL-02, EVOL-03
**Success Criteria** (what must be TRUE):
  1. When the Task Orchestrator identifies a repeating domain not covered by existing agents, it proposes a new agent — proposal is reviewed by Decision Reviewer agent — if approved, the agent is scaffolded exclusively via `/openclaw-new-agent` (no manual SOUL.md edits)
  2. When a procedural pattern is observed for the second time, the Skill Creation agent is triggered automatically — the full cycle (propose → search registries → author → Skill Reviewer review → stow) completes without user intervention
  3. Task Orchestrator can propose an experiment with hypothesis, method, and success criteria; spawn agents to run it; collect results; and produce a complete structured Notion experiment page — Document Reviewer agent validates the write-up before the page is finalized
  4. The mandatory `/openclaw-new-agent` rule for all agent scaffolding is enforced in Task Orchestrator SOUL.md and verified by attempting to create an agent via any other path (blocked)
**Plans**: 5 plans

Plans:

**Wave 1** *(parallel — all three are independent SOUL.md/file additions)*
- [ ] 12-01-PLAN.md — Add Self-Evolution Rules section to Task Orchestrator SOUL.md: EVOL-01 (/openclaw-new-agent only + Decision Reviewer gate + routing update), EVOL-02 (threshold=2 + pattern naming convention), EVOL-03 (4-stage experiment lifecycle in mandatory order) (EVOL-01, EVOL-02, EVOL-03)
- [ ] 12-02-PLAN.md — Create check-agent-domain.sh (reads live openclaw.json agents.list, returns ok:true/false); update Task Orchestrator TOOLS.md with 6-step EVOL-01 workflow + new agent proposal template (EVOL-01)
- [ ] 12-03-PLAN.md — Add Pattern Counter section to Task Orchestrator MEMORY.md (PRESERVE marker per D-121, empty table with correct columns); update DREAM-ROUTINE.md with explicit verbatim preservation instruction for Pattern Counter section (EVOL-02)

**Wave 2** *(blocked on Wave 1 — SOUL.md rules must exist before experiment scripts are wired)*
- [ ] 12-04-PLAN.md — Create propose-experiment.js (validates 5 required fields including measurability check) + create-experiment-page.js (Notion Draft page before Beads epic, returns bare page ID); install @notionhq/client in task-orchestrator scripts/; update TOOLS.md with 4-stage experiment lifecycle (EVOL-03)

**Wave 3** *(blocked on Waves 1 and 2 — phase gate + milestone completion)*
- [ ] 12-05-PLAN.md — Create and run scripts/verify-phase-12.sh: EVOL-01 structural checks + enforcement gate (manually created agent dir not in openclaw.json per D-122, /tmp only per Pitfall 5); EVOL-02 MEMORY.md PRESERVE marker + DREAM-ROUTINE.md verbatim instruction; EVOL-03 experiment scripts + TOOLS.md lifecycle; Phase 11 agents still present; milestone summary on pass (EVOL-01, EVOL-02, EVOL-03)

**Cross-cutting constraints:**
- D-120: Phase 12 is entirely SOUL.md rule additions + supporting scripts — no new agent directories, no new openclaw.json agent entries
- D-121: PRESERVE comment format must be exactly: <!-- PRESERVE: pattern_counter — do not distill -->
- D-122: enforcement gate test creates temp agent in /tmp (NEVER in ~/.openclaw/) with trap cleanup
- D-123: OPENCLAW_NOTION_EXPERIMENTS_DB_ID provisioned as Phase 12 Wave 2 prerequisite; create-experiment-page.js fails fast with Keychain setup command if absent
- Pattern naming convention: lowercase, hyphens, 2-4 words, procedure level (not parameter level)

## Progress

**Execution Order:**
Phases execute in numeric order: 1 → 2 → 3 → 4 → 5 → 6 → 7 → 8 → 9 → 10 → 11 → 12

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Infrastructure | 4/5 | In Progress|  |
| 2. Core Channels | 2/2 | Complete   | 2026-05-20 |
| 3. User Orchestrator | 4/4 | Complete   | 2026-05-20 |
| 4. Beads + Task Orchestrator | 4/4 | Complete   | 2026-05-20 |
| 5. Dream Routines | 4/4 | Complete   | 2026-05-20 |
| 6. Email + Morning Standup | 5/5 | Complete   | 2026-05-20 |
| 7. DevBot Core | 4/4 | Complete   | 2026-05-20 |
| 8. CI Monitor + Autonomous Dev Scaffold | 5/5 | Complete   | 2026-05-20 |
| 9. Notion Decision Log | 0/6 | Not started | - |
| 10. Autonomous Merge | 0/4 | Not started | - |
| 11. Quality Pipeline | 0/7 | Not started | - |
| 12. Self-Evolution | 0/5 | Not started | - |

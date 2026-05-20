# Roadmap: Personal AI Operations Hub

## Overview

Build a self-evolving AI agent fleet on macOS/OpenClaw that operates autonomously while the user is away — triaging email, managing GitHub, monitoring CI, and merging PRs — routing all interactions through Telegram, logging every autonomous decision to Notion, and handing back clean control on return. The build follows a hard dependency chain: infrastructure and configuration governance first, then dual orchestrators, then Beads-enforced execution sub-agents, then the Notion trust layer that gates autonomous merge permissions, then the quality pipeline that gates self-evolution. Each phase delivers a working, verifiable slice that cannot be bypassed without breaking the next.

## Phases

**Phase Numbering:**
- Integer phases (1, 2, 3): Planned milestone work
- Decimal phases (2.1, 2.2): Urgent insertions (marked with INSERTED)

Decimal phases appear between their surrounding integers in numeric order.

- [ ] **Phase 1: Infrastructure** - OpenClaw installed, cc-openclaw skills deployed, secrets pipeline operational, stow deploy working, health check green
- [ ] **Phase 2: Core Channels** - Telegram channel provisioned, token in Keychain, round-trip message verified (WhatsApp deferred — D-20)
- [ ] **Phase 3: User Orchestrator** - User Orchestrator live on Telegram with coherent responses and delegation to Task Orchestrator, isolated context windows
- [ ] **Phase 4: Beads + Task Orchestrator** - Beads installed with shared BEADS_DIR, Task Orchestrator creates task graphs before spawning sub-agents, claim/close cycle verified
- [ ] **Phase 5: Dream Routines** - Nightly memory distillation running for both orchestrators with token budget enforcement and archive directories
- [ ] **Phase 6: Email + Morning Standup** - Gmail Email Triage agent operational, morning standup brief delivered via Telegram on schedule
- [ ] **Phase 7: DevBot Core** - DevBot can create GitHub issues, summarize PRs, flag stale reviews, and maintain per-repo context
- [ ] **Phase 8: CI Monitor + Autonomous Dev Scaffold** - CI Monitor alerts within 5 minutes of failure; DevBot can autonomously implement issues via Beads task graph
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
- [ ] 02-01-PLAN.md — Wire Telegram channel: transfer token to Keychain, update three secrets pipeline files, add channels.telegram.accounts.main to openclaw.json with env var ref, stow+restart, shred pre-stow backups (CHAN-01)

**Wave 2** *(blocked on Wave 1 — requires live channel)*
- [ ] 02-02-PLAN.md — Verify Telegram round-trip: automated smoke tests, pairing flow, outbound message confirmation; update ROADMAP with deferred WhatsApp note (CHAN-01)

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
**Plans**: TBD
**UI hint**: yes

Plans:
- [ ] 03-01: Scaffold User Orchestrator agent via /openclaw-new-agent with SOUL.md defining conversation and delegation behavior
- [ ] 03-02: Wire User Orchestrator to Telegram channel and verify coherent response round-trip
- [ ] 03-03: Scaffold Task Orchestrator agent with isolated context window and verify delegation handoff from User Orchestrator
- [ ] 03-04: Confirm both agents appear as separate persistent agents in /openclaw-status with no shared session state

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
**Plans**: TBD

Plans:
- [ ] 04-01: Install Beads (bd 1.0.4) via npm and initialize shared task graph DB with bd init --stealth
- [ ] 04-02: Export BEADS_DIR in gateway start script and verify accessibility from sub-agent context via bd ready --json
- [ ] 04-03: Configure Task Orchestrator SOUL.md with mandatory epic-creation-before-spawn rule
- [ ] 04-04: Run end-to-end claim/close cycle test: Task Orchestrator creates epic, sub-agent claims and closes with evidence, orchestrator reads graph

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
**Plans**: TBD

Plans:
- [ ] 05-01: Set up dream routine cron for User Orchestrator via /openclaw-dream-setup with token budget constraints
- [ ] 05-02: Set up dream routine cron for Task Orchestrator via /openclaw-dream-setup with token budget constraints
- [ ] 05-03: Create memory/archives/ directories for both orchestrators and verify archive file creation after first run
- [ ] 05-04: Validate token caps on MEMORY.md and 3-day digest files post-run

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
**Plans**: TBD
**UI hint**: yes

Plans:
- [ ] 06-01: Configure Gmail OAuth2 Device Flow for echo.sys.bot@gmail.com and store refresh token in Keychain
- [ ] 06-02: Scaffold Email Triage agent via /openclaw-new-agent with Gmail read/categorize/draft capabilities
- [ ] 06-03: Document OAuth2 re-auth runbook in Email Triage agent TOOLS.md
- [ ] 06-04: Build morning standup brief script that aggregates GitHub activity and queued decisions
- [ ] 06-05: Create morning standup cron via /openclaw-add-cron targeting Telegram channel with local timezone

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
**Plans**: TBD

Plans:
- [ ] 07-01: Scaffold DevBot agent via /openclaw-new-agent with GitHub CLI access and project board write permissions
- [ ] 07-02: Implement issue creation from natural language descriptions with label and milestone assignment
- [ ] 07-03: Implement PR review queue summarizer with CI status and staleness detection
- [ ] 07-04: Implement per-repository context store (stack, conventions, open work) with context switching capability

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
**Plans**: TBD
**UI hint**: yes

Plans:
- [ ] 08-01: Scaffold CI Monitor agent via /openclaw-new-agent with GitHub Actions API access
- [ ] 08-02: Implement CI polling cron via /openclaw-add-cron with <5 minute interval and failure alert to Telegram
- [ ] 08-03: Implement Beads-based autonomous dev workflow in DevBot: issue intake → epic creation → subtask decomposition
- [ ] 08-04: Implement DevBot subtask execution cycle: claim → implement → self-review → close with evidence → open PR
- [ ] 08-05: Verify end-to-end autonomous dev run on a test issue with full Beads audit trail

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
**Plans**: TBD

Plans:
- [ ] 09-01: Define and create Notion database schema for decision log (timestamp, decision, rationale, evidence, reversibility, revert_status fields)
- [ ] 09-02: Implement pre-execution Notion logging in Task Orchestrator using @notionhq/client 5.22.0
- [ ] 09-03: Implement on-demand decision retrieval via Telegram ("what did you do while I was away?")
- [ ] 09-04: Implement revert workflow: user marks decision → Task Orchestrator executes rollback → logs revert entry
- [ ] 09-05: Implement experiment page creation with structured template (hypothesis, method, criteria, results)
- [ ] 09-06: Integrate autonomous decision count and summary into morning standup brief

### Phase 10: Autonomous Merge
**Goal**: DevBot can merge PRs that have passed CI and quality review — each merge is pre-logged to Notion before execution, and the user can see and revert any autonomous merge from the decision log
**Mode:** mvp
**Depends on**: Phase 9
**Requirements**: DEV-05
**Success Criteria** (what must be TRUE):
  1. DevBot merges a CI-passing, quality-reviewed PR only after a Notion decision log entry exists for that specific merge — the log entry is created and confirmed before `gh pr merge` is invoked
  2. User can find the merge decision in the Notion log with reversibility status and, if they choose, mark it for revert — Task Orchestrator reopens the PR and reverts the merge commit
  3. DevBot does not merge any PR that lacks a Notion log entry (enforced in SECURITY.md rules loaded in DevBot SOUL.md)
**Plans**: TBD

Plans:
- [ ] 10-01: Define and add autonomous merge security rule to DevBot SOUL.md: Notion pre-log required, no exceptions
- [ ] 10-02: Implement merge decision logging in DevBot with Notion entry creation and confirmation before merge execution
- [ ] 10-03: Implement merge revert workflow: user marks merge for revert → PR reopened + commit reverted + revert logged
- [ ] 10-04: Verify merge gate: attempt merge without Notion entry and confirm it is blocked

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
**Plans**: TBD

Plans:
- [ ] 11-01: Scaffold Code Reviewer agent via /openclaw-new-agent with SOUL.md focused on code quality, security, test coverage, and PR review
- [ ] 11-02: Scaffold Document Reviewer agent via /openclaw-new-agent with SOUL.md focused on clarity, accuracy, and Notion page structure
- [ ] 11-03: Scaffold Decision Reviewer agent via /openclaw-new-agent with SOUL.md focused on decision rationale validation, reversibility assessment, and evidence specificity
- [ ] 11-04: Scaffold Skill Reviewer agent via /openclaw-new-agent with SOUL.md focused on SKILL.md format correctness, safety review, and cc-openclaw convention compliance
- [ ] 11-05: Scaffold Skill Creation agent via /openclaw-new-agent with registry search capability (ClawHub, agentskills.io, starred GitHub) and SKILL.md authoring
- [ ] 11-06: Wire each reviewer into the appropriate pipeline: Code Reviewer into DevBot → PR flow, Document Reviewer into Notion write path, Decision Reviewer into MEM-01 log path, Skill Reviewer into QUAL-08 stow gate
- [ ] 11-07: Verify feedback loop: flag a known-bad output at each reviewer and confirm the originating agent receives and addresses the feedback before output advances

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
**Plans**: TBD

Plans:
- [ ] 12-01: Add self-evolution rules to Task Orchestrator SOUL.md: /openclaw-new-agent required, pattern-repeat threshold = 2
- [ ] 12-02: Implement agent proposal workflow: domain identification → Quality Reviewer review → /openclaw-new-agent scaffold
- [ ] 12-03: Implement pattern-repeat detection and automatic Skill Creation agent trigger
- [ ] 12-04: Implement experiment framework: propose → spawn → collect → Notion page → Quality Reviewer validation
- [ ] 12-05: Verify self-evolution gate: attempt agent creation without /openclaw-new-agent and confirm it is blocked

## Progress

**Execution Order:**
Phases execute in numeric order: 1 → 2 → 3 → 4 → 5 → 6 → 7 → 8 → 9 → 10 → 11 → 12

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Infrastructure | 4/5 | In Progress|  |
| 2. Core Channels | 0/2 | In Progress | - |
| 3. User Orchestrator | 0/4 | Not started | - |
| 4. Beads + Task Orchestrator | 0/4 | Not started | - |
| 5. Dream Routines | 0/4 | Not started | - |
| 6. Email + Morning Standup | 0/5 | Not started | - |
| 7. DevBot Core | 0/4 | Not started | - |
| 8. CI Monitor + Autonomous Dev Scaffold | 0/5 | Not started | - |
| 9. Notion Decision Log | 0/6 | Not started | - |
| 10. Autonomous Merge | 0/4 | Not started | - |
| 11. Quality Pipeline | 0/7 | Not started | - |
| 12. Self-Evolution | 0/5 | Not started | - |

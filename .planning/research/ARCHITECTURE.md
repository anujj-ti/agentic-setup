# Architecture Research

**Domain:** Personal AI Operations Hub — OpenClaw multi-agent fleet
**Researched:** 2026-05-20
**Confidence:** HIGH (derived from primary source documents: Rahul Subramaniam's Trilogy AI CoE reference articles, project-specified constraints)

## Standard Architecture

### System Overview

```
┌─────────────────────────────────────────────────────────────────────┐
│                      INTERFACE TIER                                  │
│  ┌──────────────┐  ┌────────────────┐  ┌───────────────────────┐   │
│  │   Telegram   │  │    WhatsApp    │  │  Gmail (echo.sys.bot) │   │
│  │   Channel    │  │    Channel     │  │      Channel           │   │
│  └──────┬───────┘  └───────┬────────┘  └──────────┬────────────┘   │
└─────────┼──────────────────┼─────────────────────┼────────────────┘
          │                  │                      │
          ▼                  ▼                      ▼
┌─────────────────────────────────────────────────────────────────────┐
│                   CONVERSATION TIER                                  │
│  ┌──────────────────────────────────────────────────────────────┐   │
│  │                  USER ORCHESTRATOR                            │   │
│  │  - Handles all human-facing conversation                      │   │
│  │  - Lean context: NO task state, NO sub-agent state            │   │
│  │  - Routes requests → Task Orchestrator                        │   │
│  │  - Surfaces decisions for user review/approval on return      │   │
│  │  - Morning standup delivery; review queue management          │   │
│  │  - Runs: Claude Opus (conversational quality)                 │   │
│  └──────────────────────────┬───────────────────────────────────┘   │
└─────────────────────────────┼───────────────────────────────────────┘
                              │  (delegates via OpenClaw allowAgents)
                              ▼
┌─────────────────────────────────────────────────────────────────────┐
│                   ORCHESTRATION TIER                                 │
│  ┌──────────────────────────────────────────────────────────────┐   │
│  │                  TASK ORCHESTRATOR                            │   │
│  │  - Autonomous background execution                            │   │
│  │  - Owns Beads DB (BEADS_DIR): one shared graph               │   │
│  │  - Decomposes every GitHub issue into a Beads epic            │   │
│  │    BEFORE spawning any sub-agent                              │   │
│  │  - Monitors: bd ready / bd list --status in_progress         │   │
│  │  - Logs every decision to Notion before execution             │   │
│  │  - Heartbeat cron: checks graph + CI status periodically      │   │
│  │  - Runs: Claude Sonnet (cost-effective for orchestration)     │   │
│  └──────────────────────────┬───────────────────────────────────┘   │
└─────────────────────────────┼───────────────────────────────────────┘
                              │  (spawns sub-agents, passes BEADS_DIR)
          ┌───────────────────┼───────────────────────┐
          ▼                   ▼                        ▼
┌─────────────────────────────────────────────────────────────────────┐
│                    EXECUTION TIER (sub-agents)                       │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐              │
│  │   DevBot     │  │ CI Monitor   │  │ Email Triage │              │
│  │  (GitHub     │  │ (watches     │  │ (echo.sys.   │              │
│  │  dev work)   │  │  CI runs)    │  │  bot Gmail)  │              │
│  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘              │
│         │                 │                  │                       │
│  bd ready → claim → execute → close(+evidence)                      │
│                                                                      │
│  ┌──────────────┐  ┌──────────────┐                                 │
│  │ PR Reviewer  │  │ Context      │                                 │
│  │ (autonomous  │  │ Switcher     │                                 │
│  │  merge queue)│  │ (repo loads) │                                 │
│  └──────────────┘  └──────────────┘                                 │
│                                                                      │
│  All sub-agents: Claude Haiku (cost-optimised, isolated sessions)   │
└─────────────────────────────────────────────────────────────────────┘
          │                   │                        │
          ▼                   ▼                        ▼
┌─────────────────────────────────────────────────────────────────────┐
│                    PERSISTENCE TIER                                  │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────────────────┐  │
│  │  Beads DB    │  │   Notion     │  │     GitHub Board         │  │
│  │  (Dolt SQL,  │  │  (decision   │  │  (source of truth for    │  │
│  │  task graph) │  │   logs,      │  │   issues, PRs, project   │  │
│  │              │  │   experiments│  │   board — NOT Beads)     │  │
│  └──────────────┘  └──────────────┘  └──────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────┘
```

### Component Responsibilities

| Component | Responsibility | Tier |
|-----------|----------------|------|
| User Orchestrator | Human-facing conversation, approval surface, morning standup delivery, routes work to Task Orch | Conversation |
| Task Orchestrator | Autonomous execution, Beads graph ownership, sub-agent spawning, Notion logging, heartbeat cron | Orchestration |
| DevBot | GitHub dev work: triage PRs, create/solve issues, autonomous merge with approval queue entry | Execution |
| CI Monitor | Watch CI runs, surface failures, page via Telegram | Execution |
| Email Triage | Receive/send email via echo.sys.bot, route action items back to Task Orchestrator | Execution |
| PR Reviewer | Review diffs, leave comments, mark PASS/FAIL with evidence per Beads close-reason protocol | Execution |
| Context Switcher | Load repo-specific context when switching between projects | Execution |
| Beads DB (Dolt) | Dependency-aware task graph, shared across all execution-tier agents via BEADS_DIR env var | Persistence |
| Notion | Async decision log and experiment records; user review surface on return | Persistence |
| GitHub Board | Canonical issue/PR/project state; Beads tracks agent decomposition, not raw issues | Persistence |

## Component Boundaries: What Each Orchestrator Owns

### User Orchestrator — owns:
- All channels that carry human messages (Telegram user channel, WhatsApp)
- Conversation context only — no task state, no sub-agent output accumulation
- The return-review workflow: surfaces queued Notion decisions, collects user approval/revert
- Morning standup brief composition (reads from Notion decision log, not from sub-agents directly)
- The allowAgents entry pointing to Task Orchestrator (one-way delegation)

### User Orchestrator — explicitly does NOT own:
- Any Beads instance or BEADS_DIR
- GitHub API calls (delegated)
- Sub-agent spawning below Task Orchestrator
- Cron-driven background loops

### Task Orchestrator — owns:
- The single Beads DB at `~/.openclaw/agents/task-orchestrator/.beads/`
- `BEADS_DIR` export in gateway start script (inherited by all execution-tier agents)
- Decomposition-before-spawn rule: no sub-agent spawning without a complete Beads epic first
- Heartbeat cron: bd ready / bd list queries + CI status checks
- Notion write access: every autonomous decision logged before execution
- allowAgents entries pointing to all execution-tier sub-agents

### Task Orchestrator — explicitly does NOT own:
- Human-facing channels
- User approval workflow (handed back to User Orchestrator via message)

## Recommended Git Repo Layout (what `stow` deploys)

```
~/agentic-setup/                      ← git repo (this project)
│
├── .claude/
│   └── skills/                       ← cc-openclaw skill symlinks land here
│       ├── openclaw-new-agent.md     ← symlinked from ~/cc-openclaw/
│       ├── openclaw-add-channel.md
│       ├── openclaw-add-cron.md
│       ├── openclaw-dream-setup.md
│       ├── openclaw-add-script.md
│       ├── openclaw-add-secret.md
│       ├── openclaw-status.md
│       ├── openclaw-restart.md
│       └── openclaw-stow.md
│
├── .openclaw/                        ← stow target: ~/.openclaw/ ← symlinks here
│   ├── openclaw.json                 ← flat-file fleet config (all agents)
│   ├── cron/
│   │   └── jobs.json                 ← WARNING: gateway overwrites on start;
│   │                                    /openclaw-restart handles rm→stow
│   ├── agents/
│   │   ├── user-orchestrator/        ← USER ORCHESTRATOR
│   │   │   ├── SOUL.md
│   │   │   ├── IDENTITY.md
│   │   │   ├── USER.md
│   │   │   ├── AGENTS.md             ← session startup: load MEMORY.md + QMD
│   │   │   ├── TOOLS.md
│   │   │   ├── SECURITY.md
│   │   │   ├── DREAM_ROUTINE.md
│   │   │   ├── MEMORY.md
│   │   │   ├── memory/
│   │   │   │   └── archives/         ← dream distillation archive; MUST exist
│   │   │   └── scripts/
│   │   │       └── lib/              ← shared json-response.sh etc.
│   │   │
│   │   ├── task-orchestrator/        ← TASK ORCHESTRATOR
│   │   │   ├── SOUL.md
│   │   │   ├── IDENTITY.md
│   │   │   ├── USER.md
│   │   │   ├── AGENTS.md             ← lists all execution-tier agents
│   │   │   ├── TOOLS.md              ← full Beads command ref + decomp protocol
│   │   │   ├── SECURITY.md
│   │   │   ├── DREAM_ROUTINE.md
│   │   │   ├── MEMORY.md
│   │   │   ├── memory/
│   │   │   │   └── archives/
│   │   │   ├── scripts/
│   │   │   │   └── lib/
│   │   │   └── .beads/               ← Beads Dolt DB (gitignored, not stowed)
│   │   │
│   │   ├── devbot/                   ← DEVBOT sub-agent
│   │   │   ├── SOUL.md
│   │   │   ├── IDENTITY.md
│   │   │   ├── USER.md
│   │   │   ├── AGENTS.md
│   │   │   ├── TOOLS.md              ← Beads claim/close protocol
│   │   │   ├── SECURITY.md
│   │   │   ├── memory/
│   │   │   │   └── archives/
│   │   │   └── scripts/
│   │   │       └── lib/
│   │   │
│   │   ├── ci-monitor/               ← CI MONITOR sub-agent
│   │   │   └── [same 6 files + memory/ + scripts/]
│   │   │
│   │   ├── email-triage/             ← EMAIL TRIAGE sub-agent
│   │   │   └── [same 6 files + memory/ + scripts/]
│   │   │
│   │   ├── pr-reviewer/              ← PR REVIEWER sub-agent
│   │   │   └── [same 6 files + memory/ + scripts/]
│   │   │
│   │   └── context-switcher/         ← CONTEXT SWITCHER sub-agent
│   │       └── [same 6 files + memory/ + scripts/]
│   │
│   └── secrets/
│       ├── openclaw-secrets.sh       ← loaded by launchd at gateway start
│       ├── openclaw-env.sh           ← sourced by shell sessions
│       └── secrets.sh                ← provisioning script (fresh machine)
│
├── .planning/                        ← GSD project management (not stowed)
│   ├── PROJECT.md
│   └── research/
│
└── docs/
    └── human/                        ← reference articles
```

**Stow command:**
```bash
cd ~/agentic-setup
stow --no-folding -t ~ .openclaw
```

**cc-openclaw skills stow (separate repo):**
```bash
cd ~/cc-openclaw
stow --no-folding -t ~/agentic-setup .
```

## openclaw.json Structure

```json
{
  "gateway": {
    "port": 3000,
    "timezone": "America/New_York"
  },
  "agents": {
    "list": [
      {
        "id": "user-orchestrator",
        "name": "User Orchestrator",
        "model": "claude-opus-4",
        "directivesPath": "~/.openclaw/agents/user-orchestrator",
        "allowAgents": ["task-orchestrator"],
        "channels": ["telegram-user", "whatsapp"],
        "sessionType": "persistent",
        "qmd": {
          "memory": "~/.openclaw/agents/user-orchestrator/MEMORY.md",
          "dreamRoutine": "~/.openclaw/agents/user-orchestrator/DREAM_ROUTINE.md"
        }
      },
      {
        "id": "task-orchestrator",
        "name": "Task Orchestrator",
        "model": "claude-sonnet-4",
        "directivesPath": "~/.openclaw/agents/task-orchestrator",
        "allowAgents": [
          "devbot",
          "ci-monitor",
          "email-triage",
          "pr-reviewer",
          "context-switcher"
        ],
        "channels": [],
        "sessionType": "persistent",
        "qmd": {
          "memory": "~/.openclaw/agents/task-orchestrator/MEMORY.md",
          "dreamRoutine": "~/.openclaw/agents/task-orchestrator/DREAM_ROUTINE.md"
        }
      },
      {
        "id": "devbot",
        "name": "DevBot",
        "model": "claude-haiku-4",
        "directivesPath": "~/.openclaw/agents/devbot",
        "allowAgents": [],
        "channels": [],
        "sessionType": "isolated"
      },
      {
        "id": "ci-monitor",
        "name": "CI Monitor",
        "model": "claude-haiku-4",
        "directivesPath": "~/.openclaw/agents/ci-monitor",
        "allowAgents": [],
        "channels": ["telegram-alerts"],
        "sessionType": "isolated"
      },
      {
        "id": "email-triage",
        "name": "Email Triage",
        "model": "claude-haiku-4",
        "directivesPath": "~/.openclaw/agents/email-triage",
        "allowAgents": [],
        "channels": ["gmail-bot"],
        "sessionType": "isolated"
      },
      {
        "id": "pr-reviewer",
        "name": "PR Reviewer",
        "model": "claude-haiku-4",
        "directivesPath": "~/.openclaw/agents/pr-reviewer",
        "allowAgents": [],
        "channels": [],
        "sessionType": "isolated"
      },
      {
        "id": "context-switcher",
        "name": "Context Switcher",
        "model": "claude-haiku-4",
        "directivesPath": "~/.openclaw/agents/context-switcher",
        "allowAgents": [],
        "channels": [],
        "sessionType": "isolated"
      }
    ]
  },
  "channels": {
    "list": [
      {
        "id": "telegram-user",
        "type": "telegram",
        "token": "${OPENCLAW_TELEGRAM_USER_TOKEN}",
        "agentId": "user-orchestrator"
      },
      {
        "id": "telegram-alerts",
        "type": "telegram",
        "token": "${OPENCLAW_TELEGRAM_ALERTS_TOKEN}",
        "agentId": "ci-monitor"
      },
      {
        "id": "whatsapp",
        "type": "whatsapp",
        "phoneAllowlist": ["${OPENCLAW_WHATSAPP_PHONE}"],
        "agentId": "user-orchestrator"
      },
      {
        "id": "gmail-bot",
        "type": "gmail",
        "account": "echo.sys.bot@gmail.com",
        "agentId": "email-triage"
      }
    ]
  }
}
```

**Key openclaw.json rules:**
- `allowAgents` is the only mechanism for inter-agent delegation — it must be declared explicitly
- `qmd` block required for every agent with a dream routine; paths are used by the gateway to load memory on session startup
- `sessionType: isolated` for all execution-tier sub-agents — cheaper, no context bleed
- `sessionType: persistent` for both orchestrators — they maintain conversational state

## Architectural Patterns

### Pattern 1: Decompose-Before-Spawn

**What:** Task Orchestrator creates the complete Beads epic (all subtasks + dependencies) before spawning any sub-agent. Sub-agents receive only "run `bd ready --json` to start" as their task instruction — never a free-text task description.

**When to use:** Every GitHub issue, PR review request, setup task. No exceptions.

**Trade-offs:** Adds ~30 seconds of orchestrator time per task. Eliminates the shortcut-agent failure mode entirely. Worth it for any task with more than 2 steps.

**Decomposition templates in TOOLS.md:**
```
Feature (5 subtasks):  design → implement → self-review → QA evidence → open PR
Bug fix (4 subtasks):  reproduce → fix → verify → open PR
Setup (12 subtasks):   recon → env → services → migrations → server →
                       browser → login → nav → tests → runbook → manifest → report
```

### Pattern 2: Evidence-in-Close-Reason

**What:** Every `bd close <id> --reason "..."` requires a specific, factual reason string. This is the agent's proof of work AND the structured handoff context for the next dependent task.

**When to use:** Always. Vague reasons ("done", "completed") are treated as incomplete.

**Good close reasons:**
```
"Dev server running on port 3000, screenshot at artifacts/01-homepage.png"
"Design posted to issue #47, 3 subtasks proposed, PR split recommended"
"CI failure: test_payments_refund timeout on line 84, logs at artifacts/ci-2026-05-20.log"
```

### Pattern 3: Dual-Orchestrator Memory Isolation

**What:** User Orchestrator and Task Orchestrator are separate OpenClaw agents with completely separate context windows, MEMORY.md files, and dream routines. They communicate only via structured messages through OpenClaw's allowAgents delegation, never via shared memory files.

**When to use:** Always. This is the core architectural constraint.

**Trade-offs:** Requires explicit message passing for any information that needs to cross tiers. Prevents the context bloat that kills single-orchestrator systems at scale.

**Wrong:**
```
# Both orchestrators read the same MEMORY.md — context bleeds between human
# conversation state and autonomous task state
```

**Right:**
```
user-orchestrator/MEMORY.md  ← conversation patterns, user preferences, standup history
task-orchestrator/MEMORY.md  ← GitHub project state, recurring failures, repo conventions
```

### Pattern 4: Three-File Secrets Pipeline

**What:** Every secret touches exactly three files beyond the Keychain entry. Missing any file causes partial failures that are hard to diagnose.

**Pipeline:**
```
macOS Keychain (source of truth)
    ↓
openclaw-secrets.sh  ← loaded by launchd (gateway startup)
    ↓
openclaw-env.sh      ← sourced by shell sessions (CLI commands)
    ↓
secrets.sh           ← provisioning script (fresh machine / disaster recovery)
```

**Use `/openclaw-add-secret` skill** — never add secrets manually. The skill enforces naming convention and updates all three files atomically.

**Naming convention:**
- Keychain service: `openclaw.<name>` (lowercase, hyphens)
- Env var: `OPENCLAW_<NAME>` (uppercase, underscores)

### Pattern 5: Dream Routines for Stateful Agents Only

**What:** Dream routines run nightly via cron. They distill the agent's conversation/decision history into MEMORY.md, respecting token budgets. Not every agent needs one — only agents that accumulate meaningful state over time.

**Which agents need dream routines:**
| Agent | Needs Dream Routine | Reason |
|-------|--------------------|----|
| User Orchestrator | YES | Accumulates user preferences, conversation patterns, approval history |
| Task Orchestrator | YES | Accumulates project state, recurring failure patterns, repo conventions |
| DevBot | NO | Stateless execution — fresh task each spawn via Beads |
| CI Monitor | NO | Stateless — reports facts, doesn't build knowledge |
| Email Triage | OPTIONAL | Could benefit if email patterns repeat; defer until needed |
| PR Reviewer | NO | Stateless per-PR execution |
| Context Switcher | NO | Stateless lookup per repo |

**Token budgets (from cc-openclaw reference):**
- Daily distillation: 2,500 tokens max
- Rolling 3-day digest: 7,500 tokens max

**QMD index paths in openclaw.json** (required for session startup loading):
```json
"qmd": {
  "memory": "~/.openclaw/agents/<agent-id>/MEMORY.md",
  "dreamRoutine": "~/.openclaw/agents/<agent-id>/DREAM_ROUTINE.md"
}
```

**Use `/openclaw-dream-setup` skill** — it creates DREAM_ROUTINE.md, MEMORY.md, memory/archives/, the cron job, and updates AGENTS.md session startup sequence atomically.

## Data Flow

### Flow 1: User Request → Autonomous Task

```
User (Telegram/WhatsApp)
    ↓ message
User Orchestrator
    ↓ interprets intent, delegates via allowAgents
Task Orchestrator
    ↓ receives task description
    ↓ creates Beads epic: bd create "..." -t epic
    ↓ creates subtasks with dependencies: bd create "..." --parent <epic> + bd dep add
    ↓ spawns sub-agent(s) via allowAgents: "Run bd ready --json to start"
    ↓ logs intended action to Notion BEFORE execution
Sub-Agent (e.g., DevBot)
    ↓ bd ready --json → sees first unblocked task
    ↓ bd update <id> --claim
    ↓ executes task
    ↓ bd close <id> --reason "<evidence>"
    ↓ bd ready → next unblocked task (repeat)
Task Orchestrator (heartbeat cron)
    ↓ bd list --status in_progress → monitors progress
    ↓ bd list --status open → checks for stuck tasks
    ↓ writes completion summary to Notion
User Orchestrator (morning standup / on-return)
    ↓ reads Notion decision log
    ↓ surfaces summary + approval queue to user
User
    ↓ approves / requests revert
```

### Flow 2: CI Failure Alert

```
CI Monitor (cron, every 15 min)
    ↓ runs deterministic script: check-ci-status.sh → JSON output
    ↓ parses failures
    ↓ sends Telegram alert via telegram-alerts channel
    ↓ logs failure to Notion
Task Orchestrator (heartbeat cron sees Notion entry)
    ↓ creates Beads epic for the failure
    ↓ spawns DevBot with task graph
DevBot
    ↓ claim/close pattern per Beads subtasks
    ↓ creates GitHub issue with evidence
    ↓ optionally opens fix PR
```

### Flow 3: Autonomous Decision Logging

```
Task Orchestrator (before ANY autonomous action)
    ↓ writes to Notion: { action, rationale, timestamp, agent, repo }
    ↓ executes action
    ↓ writes to Notion: { result, evidence, status: complete|failed }

User (on return, via User Orchestrator)
    ↓ User Orchestrator reads Notion log
    ↓ surfaces: "While you were away, 3 decisions were made: ..."
    ↓ user approves or requests revert
    ↓ User Orchestrator delegates revert if needed → Task Orchestrator
```

## Build Order

This is the critical sequencing — each layer is blocked until its foundation exists.

### Layer 0: Infrastructure (must exist before any agent runs)
1. macOS Keychain entries provisioned via secrets.sh
2. openclaw-secrets.sh, openclaw-env.sh written and tested
3. openclaw.json skeleton (gateway config only, no agents yet)
4. stow working: `stow --no-folding -t ~ .openclaw` runs clean
5. launchd gateway plist installed and gateway starts
6. `/openclaw-status` confirms gateway healthy
7. cc-openclaw skills symlinked into `.claude/skills/`

### Layer 1: User Orchestrator (first agent)
1. Agent directory scaffolded via `/openclaw-new-agent user-orchestrator`
2. SOUL.md + IDENTITY.md written (conversational persona)
3. USER.md written (user preferences, approval workflow)
4. SECURITY.md written (Keychain-only credential policy)
5. Telegram user channel added via `/openclaw-add-channel`
6. WhatsApp channel added via `/openclaw-add-channel`
7. Dream routine set up via `/openclaw-dream-setup`
8. openclaw.json updated with agent entry + channel bindings
9. stow + restart; verify Telegram messages reach User Orchestrator

**Gate:** User can send a Telegram message and receive a coherent response.

### Layer 2: Task Orchestrator (second agent, no channels)
1. Agent directory scaffolded via `/openclaw-new-agent task-orchestrator`
2. SOUL.md written (autonomous execution persona — deliberate, logs everything)
3. AGENTS.md written with all execution-tier agent IDs pre-populated
4. TOOLS.md written with Notion API access + Beads command reference + decomp templates
5. Dream routine set up via `/openclaw-dream-setup`
6. User Orchestrator's AGENTS.md updated: `allowAgents: [task-orchestrator]`
7. openclaw.json updated with task-orchestrator agent entry
8. stow + restart
9. Beads installed: `npm install -g @beads/bd` + `brew install dolt`
10. Beads initialized: `cd ~/.openclaw/agents/task-orchestrator && bd init --stealth`
11. BEADS_DIR exported in gateway start script; gateway restarted
12. Beads test loop verified manually (create epic → subtasks → deps → claim → close)

**Gate:** User Orchestrator can delegate to Task Orchestrator; Task Orchestrator can create and manage a Beads graph.

### Layer 3: Execution Sub-Agents (unblocked after Layer 2)
Each sub-agent follows the same scaffolding sequence:
1. `/openclaw-new-agent <agent-id>` — scaffolds directory + 6 files
2. SOUL.md + TOOLS.md customized (TOOLS.md must include Beads claim/close protocol)
3. Task Orchestrator's AGENTS.md updated with new agent ID
4. openclaw.json updated with sub-agent entry + sessionType: isolated
5. stow + restart

Recommended order (by value/dependency):
- **DevBot** first (highest value; GitHub integration is the core workflow)
- **CI Monitor** second (passive watcher; low complexity; high signal value)
- **Email Triage** third (Gmail bot; requires OAuth secret pipeline)
- **PR Reviewer** fourth (depends on DevBot patterns being established)
- **Context Switcher** fifth (useful only once multiple repos exist)

**Gate per agent:** Task Orchestrator can spawn agent, agent runs a complete Beads task cycle, Task Orchestrator can verify via `bd list`.

### Layer 4: Integrations (unblocked after Layer 3)
1. Notion API secret + Notion database setup (decision log schema)
2. Task Orchestrator TOOLS.md updated with Notion write functions
3. GitHub OAuth or personal access token + `/openclaw-add-secret`
4. Morning standup brief cron (reads Notion, delivers via User Orchestrator)
5. Project context switching scripts in context-switcher/scripts/

### Layer 5: Beads Operational Patterns (Phase 2+)
1. Decomposition templates validated against real GitHub issues
2. Heartbeat cron tuned (frequency based on observed task duration)
3. Stuck-agent detection threshold set
4. Evidence quality bar established (close-reason format documented in TOOLS.md)

## Anti-Patterns

### Anti-Pattern 1: Single Orchestrator with Full Fleet State

**What people do:** Put all agents under one orchestrator with access to all channels, all task state, and all sub-agent output.

**Why it's wrong:** The orchestrator's context window fills with task execution output from sub-agents. Once context is saturated (~50k tokens in a long session), the orchestrator's conversational quality degrades and it begins ignoring earlier context. The user conversation starts losing coherence.

**Do this instead:** Two orchestrators. User Orchestrator stays lean and conversational. Task Orchestrator accumulates state. They communicate via structured messages, not shared memory.

### Anti-Pattern 2: Free-Text Task Delegation to Sub-Agents

**What people do:** Task Orchestrator sends messages like "implement the payment refund feature in repo X" to DevBot.

**Why it's wrong:** LLMs predict plausible completions, not exhaustive ones. A 12-step task in a single prompt will result in 3-4 steps completed and "done" returned confidently. Attention decay is structural, not a bug in the agent's personality.

**Do this instead:** Create the Beads epic with full dependency graph first. Spawn DevBot with "run `bd ready --json` to start." The graph enforces the steps, not the prompt.

### Anti-Pattern 3: One Beads DB Per Sub-Agent

**What people do:** Initialize `bd init` inside each sub-agent's directory so each agent has its own isolated task graph.

**Why it's wrong:** Task Orchestrator loses cross-agent visibility. It cannot see that DevBot is working on task A while CI Monitor is blocked on task B. Scheduling decisions become blind.

**Do this instead:** One Beads DB in task-orchestrator's workspace. Export BEADS_DIR in the gateway start script. All agents in the execution tier inherit it.

### Anti-Pattern 4: Secrets in SOUL.md or IDENTITY.md

**What people do:** Embed API keys or tokens directly in agent directive files because it's "just local."

**Why it's wrong:** Directive files are git-tracked. One accidental push exposes all secrets. launchd loads openclaw-secrets.sh at startup — the env vars are available to all agents without being in any file.

**Do this instead:** `/openclaw-add-secret` for every secret. Never write a credential into a markdown file. If you need to reference a secret in a directive, reference the env var name: `$OPENCLAW_GITHUB_TOKEN`.

### Anti-Pattern 5: Stowing Without Handling jobs.json

**What people do:** Run `stow` directly after editing cron config.

**Why it's wrong:** The OpenClaw gateway overwrites `~/.openclaw/cron/jobs.json` on every startup. Stow creates a symlink; the gateway replaces the symlink with a real file on first run. Next stow fails with "file exists" conflict.

**Do this instead:** Always use `/openclaw-restart` which runs `rm -f ~/.openclaw/cron/jobs.json → stow → kickstart → verify`. Or run that sequence manually.

## Integration Points

### External Services

| Service | Integration Pattern | Agent | Notes |
|---------|---------------------|-------|-------|
| Telegram | OpenClaw native channel (Bot API token in Keychain) | User Orchestrator (user channel), CI Monitor (alerts channel) | Two separate bots/tokens; never share a bot between agents |
| WhatsApp | OpenClaw native channel (phone allowlist) | User Orchestrator | Allowlist restricts to user's phone number only |
| Gmail (echo.sys.bot) | OpenClaw native channel (OAuth) | Email Triage | Dedicated account — not user's personal Gmail |
| GitHub | PAT in Keychain, deterministic scripts in DevBot/scripts/ | DevBot, PR Reviewer, CI Monitor | Scripts use `gh` CLI with `$OPENCLAW_GITHUB_TOKEN`; JSON output only |
| Notion | REST API, token in Keychain | Task Orchestrator | Decision log write; User Orchestrator reads summary only |
| Beads/Dolt | Local CLI (`bd`), BEADS_DIR env var | Task Orchestrator (create/monitor), all execution-tier (claim/close) | Dolt DB in task-orchestrator workspace; shared via env var |
| macOS Keychain | `security` CLI | All agents (read), cc-openclaw skills (write) | Never write directly — use `/openclaw-add-secret` skill |
| launchd | plist in ~/Library/LaunchAgents/ | Gateway process | openclaw-secrets.sh loaded here; not in any agent's context |

### Internal Boundaries

| Boundary | Communication | Notes |
|----------|---------------|-------|
| User → User Orchestrator | OpenClaw channel (Telegram/WhatsApp message) | Async; OpenClaw buffers if agent is busy |
| User Orchestrator → Task Orchestrator | allowAgents delegation (structured message) | One-way push; Task Orch does not push back to User Orch directly |
| Task Orchestrator → Sub-Agents | allowAgents delegation ("run bd ready --json") | Sub-agents never push to Task Orch; Task Orch polls Beads graph |
| Sub-Agents → Beads DB | `bd` CLI via inherited BEADS_DIR | Zero-conflict concurrent writes via Dolt cell-level merge |
| Task Orchestrator → Notion | HTTP REST (Notion API) | Write before execute; read for standup summary |
| CI Monitor → Telegram | OpenClaw channel (telegram-alerts bot) | Direct notification; does not go through User Orchestrator |
| Any Agent → GitHub | Deterministic shell scripts (`gh` CLI) | stdout JSON only; stderr for logging; exit code is law |

## Sources

- Rahul Subramaniam, "Managing OpenClaw with Claude Code" — Trilogy AI CoE, March 2026 (primary reference for cc-openclaw skills, secrets pipeline, stow deployment, dream routines, file structure)
- Rahul Subramaniam, "Why Your AI Agents Skip Steps — and How Task Graphs Prevent It" — Trilogy AI CoE, March 2026 (primary reference for Beads integration, decompose-before-spawn pattern, evidence-in-close-reason, one-DB-per-tier pattern)
- `.planning/PROJECT.md` — project requirements, constraints, and key decisions (dual orchestrator rationale, Beads Phase 2+ sequencing, memory budget constraints)

---
*Architecture research for: Personal AI Operations Hub (OpenClaw + Claude Code fleet)*
*Researched: 2026-05-20*

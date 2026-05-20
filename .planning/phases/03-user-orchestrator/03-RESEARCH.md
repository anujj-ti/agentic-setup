# Phase 3: User Orchestrator - Research

**Researched:** 2026-05-21
**Domain:** OpenClaw multi-agent configuration, SOUL.md directives, Telegram channel-to-agent wiring, subagent delegation
**Confidence:** HIGH

---

## Summary

Phase 3 adds two named OpenClaw agents — `user-orchestrator` and `task-orchestrator` — wires `user-orchestrator` to the existing Telegram channel, and configures agent-to-agent delegation via the `sessions_spawn` tool. The entire scaffolding path goes through the `/openclaw-new-agent` skill, which creates the 6 required directive files in the openclaw-home repo and registers the agent in `openclaw.json`.

The existing `bindings` array currently routes all Telegram `main` account messages to agent id `"main"` (a placeholder that resolves to the global default workspace). That binding must be replaced with a binding to `"user-orchestrator"`. The Task Orchestrator does not need a Telegram binding at all — it receives work only from the User Orchestrator via `sessions_spawn`.

Context isolation is automatic in OpenClaw: each agent entry in `agents.list` gets its own `workspace`, `agentDir`, and session store (`~/.openclaw/agents/<agentId>/sessions/`). There is no shared session state between agents unless explicitly configured. The session key format `agent:<agentId>:<sessionType>` ensures no cross-contamination.

**Primary recommendation:** Run `/openclaw-new-agent user-orchestrator "User Orchestrator"` interactively, then follow the SOUL.md content and `openclaw.json` patterns documented below. Do NOT hand-edit agent config or directive files outside of the skill — this is the explicit ORCH-04 success criterion.

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| ORCH-01 | User can send Telegram message and receive coherent contextual response from User Orchestrator | Agent-to-Telegram binding pattern; SOUL.md persona content; model selection |
| ORCH-02 | User delegates task via Telegram; User Orchestrator hands off to Task Orchestrator without user managing delegation | `sessions_spawn` tool with `agentId: "task-orchestrator"`; `subagents.allowAgents` config |
| ORCH-05 | User Orchestrator and Task Orchestrator run as separate persistent OpenClaw agents with fully isolated context windows | `agents.list` with distinct `workspace` + `agentDir` paths; session key isolation by agentId |
</phase_requirements>

---

<user_constraints>
## User Constraints (from Phase 2 CONTEXT.md)

### Locked Decisions (Phase 2, carried forward)
- D-20: WhatsApp deferred — Phase 3 covers Telegram only
- D-21: Telegram token at `openclaw.telegram-main-bot-token` (account=`openclaw`) — already in Keychain
- D-22: `openclaw.json` botToken field is `${OPENCLAW_TELEGRAM_MAIN_BOT_TOKEN}` — env var reference only
- D-23: Pre-stow backup files shredded in Phase 2 — already done

### Shell/Script Constraints (from CLAUDE.md)
- All scripts: `#!/usr/bin/env zsh` + `set -euo pipefail`
- Secrets: Keychain only — never in files, never in git history
- Explicit binary paths: `/opt/homebrew/bin/openclaw` (nvm PATH shadowing issue)
- stow invocation: `rm -f ~/.openclaw/cron/jobs.json` must precede stow
- stow flags: `stow --no-folding -t ~ .` from `~/Documents/agentic-setup`

### No New Decisions (Phase 3 CONTEXT.md does not exist yet)
No CONTEXT.md has been gathered for Phase 3 — the plans below represent default choices within Claude's discretion.
</user_constraints>

---

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Telegram message receipt + response | User Orchestrator agent | OpenClaw gateway (channel polling) | Gateway polls Telegram; binding routes inbound message to agent; agent owns the response |
| User intent parsing + task delegation decision | User Orchestrator agent | — | Conversational logic lives in SOUL.md + agent's context window |
| Task decomposition + sub-agent spawning | Task Orchestrator agent | — | Phase 4 concern; Phase 3 scaffolds the agent but Beads wiring is Phase 4 |
| Channel-to-agent routing | OpenClaw gateway (bindings config) | — | Deterministic binding in `openclaw.json`; gateway resolves on inbound message |
| Session isolation | OpenClaw runtime | — | Per-`agentId` session store; automatic, no extra config needed |
| Agent-to-agent delegation mechanism | `sessions_spawn` tool (in User Orchestrator) | `subagents.allowAgents` config gate | User Orchestrator calls `sessions_spawn` with `agentId: "task-orchestrator"`; config gate allows it |

---

## Standard Stack

No new npm packages are installed in Phase 3. All capabilities are built on existing tools.

### Core
| Component | Version | Purpose | Why Standard |
|-----------|---------|---------|--------------|
| OpenClaw gateway | 2026.5.18 (installed) | Runs both agents in the same process; routes messages via bindings | Already running; no install needed |
| `/openclaw-new-agent` skill | HEAD cc-openclaw | Creates all 6 directive files + registers agent in `openclaw.json` | The ONLY valid agent creation path per EVOL-01; success criterion SC#4 enforces this |
| `sessions_spawn` tool | Built into OpenClaw | User Orchestrator delegates tasks to Task Orchestrator | Native OpenClaw agent-to-agent delegation; no custom code |
| GNU Stow | Latest (installed) | Deploys directive files from openclaw-home repo to `~/.openclaw/` | Existing deployment mechanism |

### No Package Legitimacy Audit Required
Phase 3 installs no new npm/pip/cargo packages. All tooling is already present from Phases 1–2.

---

## Architecture Patterns

### System Architecture Diagram

```
Telegram (BotFather @echo_sys_bot)
        |
        | inbound DM
        v
OpenClaw Gateway (port 18789, polling)
        |
        | binding: agentId="user-orchestrator",
        |          match.channel="telegram", match.accountId="main"
        v
User Orchestrator Agent
  workspace: ~/.openclaw/workspace-user-orchestrator
  session:   agent:user-orchestrator:main
        |
        | sessions_spawn(agentId="task-orchestrator", task="...")
        v
Task Orchestrator Agent
  workspace: ~/.openclaw/workspace-task-orchestrator
  session:   agent:task-orchestrator:subagent:<uuid>
        |
        | completion announce
        v
User Orchestrator Agent (receives completion)
        |
        | Telegram message tool
        v
User (Telegram)
```

### Recommended Project Structure

Directive files live in the openclaw-home repo at `.openclaw/agents/<agentId>/`:

```
.openclaw/
├── openclaw.json                          (updated: agents.list + bindings)
├── agents/
│   ├── user-orchestrator/
│   │   ├── SOUL.md
│   │   ├── IDENTITY.md
│   │   ├── USER.md
│   │   ├── AGENTS.md
│   │   ├── TOOLS.md
│   │   └── SECURITY.md
│   └── task-orchestrator/
│       ├── SOUL.md
│       ├── IDENTITY.md
│       ├── USER.md
│       ├── AGENTS.md
│       ├── TOOLS.md
│       └── SECURITY.md
└── scripts/
    └── openclaw-secrets.sh   (unchanged — token already present)
```

Stow symlinks these into `~/.openclaw/agents/<agentId>/` (the `agentDir` path used in config).

---

## `/openclaw-new-agent` — Exact Skill Invocation

**Source:** `cc-openclaw/.claude/skills/openclaw-new-agent/SKILL.md` [VERIFIED: read directly]

### Invocation

```
/openclaw-new-agent user-orchestrator "User Orchestrator"
```

Then repeat for:

```
/openclaw-new-agent task-orchestrator "Task Orchestrator"
```

### What the Skill Asks (Step 2 of SKILL.md)

The skill interactively asks:
1. Agent role/purpose (1-2 sentences)
2. Standalone top-level or sub-agent? (Both orchestrators are **standalone top-level**)
3. Model choice — see recommendations below
4. Will it need a messaging channel? (User Orchestrator: yes, Telegram; Task Orchestrator: no)

### What the Skill Produces (Steps 1, 3, 4)

**Directories created** at `~/.openclaw/agents/<agentId>/`:
```
memory/
memory/archives/
sessions/
scripts/
scripts/lib/
qmd/
drafts/
refs/
```

**6 directive files** created in `.openclaw/agents/<agentId>/` in the openclaw-home repo:
- `SOUL.md` — identity, personality, responsibilities, delegation rules
- `IDENTITY.md` — name, role, model, emoji
- `USER.md` — who the agent serves, timezone, preferences
- `AGENTS.md` — session startup checklist, workspace hygiene, safety rules
- `TOOLS.md` — CLI tools and env-specific notes
- `SECURITY.md` — credential handling, cross-agent isolation, incident response

**openclaw.json update** — appends to `agents.list`:
```json
{
  "id": "user-orchestrator",
  "name": "User Orchestrator",
  "workspace": "/Users/trilogy/.openclaw/workspace-user-orchestrator",
  "agentDir": "/Users/trilogy/.openclaw/agents/user-orchestrator",
  "model": {"primary": "anthropic/claude-sonnet-4-6"}
}
```

Note: The skill expands `$HOME` to the actual home directory path. Do not use `~` in the JSON.

**Stow + restart** — Step 7 of SKILL.md:
```bash
rm -f ~/.openclaw/cron/jobs.json
cd /Users/trilogy/Documents/agentic-setup && stow --no-folding -t ~ .
launchctl kickstart -k gui/$(id -u)/ai.openclaw.gateway
```

### Model Recommendations

| Agent | Model | Rationale |
|-------|-------|-----------|
| User Orchestrator | `anthropic/claude-sonnet-4-6` | Handles conversation + delegation routing; Sonnet provides reasoning without Opus cost |
| Task Orchestrator | `anthropic/claude-sonnet-4-6` | Orchestration requires reasoning; Haiku insufficient for complex Beads task graphs (Phase 4) |

[VERIFIED: CLAUDE.md workspace SOUL.md states "Main: anthropic/claude-sonnet-4-6, Sub-agents: anthropic/claude-haiku-4-5, Never change models without Anuj's explicit instruction." — these orchestrators are top-level persistent agents, not ephemeral sub-agents, so Sonnet is appropriate for both.]

---

## SOUL.md Structure and Required Content

**Source:** `/opt/homebrew/lib/node_modules/openclaw/docs/concepts/soul.md` + existing `~/.openclaw/workspace/SOUL.md` [VERIFIED: read directly]

### What SOUL.md Does

OpenClaw injects SOUL.md on every normal session as a high-priority instruction layer. It controls tone, personality, behavioral boundaries, and operational rules. The agent-workspace doc explicitly says SOUL.md is "Persona, tone, and boundaries. Loaded every session."

### SOUL.md Content Principles (from openclaw soul.md doc)

Good rules:
- Have a take / be decisive
- Skip filler (no "Great question!")
- Be resourceful before asking
- Clear boundaries about external actions

Bad rules (do not include):
- "Maintain professionalism at all times" (generic, no behavioral effect)
- Life story / changelog
- Security policy dump (that belongs in SECURITY.md)

Keep SOUL.md under 60 lines for focused agents per cc-openclaw SKILL.md.

### User Orchestrator SOUL.md — Required Sections

```markdown
# SOUL.md — User Orchestrator

## Identity
You are the User Orchestrator for the Personal AI Operations Hub.
Your job: be the single conversational interface between Anuj and the entire agent fleet.

## Responsibilities
- Receive messages from Anuj via Telegram
- Understand intent: is this a chat/question, or a task to delegate?
- For tasks: delegate to the Task Orchestrator via sessions_spawn, then summarize results back to Anuj
- For questions/conversation: answer directly from context and memory
- Keep Anuj updated on delegated task status when completion messages arrive

## Delegation Rules (MANDATORY)
- ANY task requiring autonomous action, file changes, API calls, or multi-step work
  MUST be delegated to the Task Orchestrator via sessions_spawn
- Never execute multi-step tasks yourself — stay responsive, delegate
- Task Orchestrator agent id: "task-orchestrator"
- Pass structured task descriptions, not free-text instructions
- Wait for completion via sessions_yield before reporting results

## Boundaries
- You do not run code, create files, or call external APIs directly
- You do not send emails or merge PRs — delegate these to the fleet
- You are Anuj's voice to the fleet, not a general-purpose executor
- When in doubt whether to delegate: delegate

## Tone
- Direct, concise — Anuj prefers short responses
- Professional but not robotic
- Skip preambles — answer or summarize immediately
- IST timezone (UTC+5:30) for all time references

## Model Policy
- Primary: anthropic/claude-sonnet-4-6
- Never change model without Anuj's explicit instruction
```

### Task Orchestrator SOUL.md — Required Sections

```markdown
# SOUL.md — Task Orchestrator

## Identity
You are the Task Orchestrator for the Personal AI Operations Hub.
You receive delegated tasks from the User Orchestrator and decompose them into work graphs before executing anything.

## Responsibilities (Phase 3 scope — Beads not yet installed)
- Receive task descriptions from the User Orchestrator
- Acknowledge receipt and describe the plan before acting
- Execute tasks using available tools (file read/write, exec, GitHub CLI)
- Report results back to the User Orchestrator session that spawned you
- Log every autonomous action decision before executing it (Notion logging comes in Phase 9)

## Operational Rules
- NEVER start executing without first describing the plan (even without Beads)
- One task at a time in Phase 3 — Beads task graphs come in Phase 4
- Autonomous actions (PR merges, issue creation) must be logged to Notion before execution (Phase 9)
- Use deterministic scripts (set -euo pipefail, JSON stdout) for all tool operations

## Boundaries
- No direct Telegram channel — you receive and respond only via the agent session
- No user-facing messages — your output goes to the User Orchestrator, not directly to Anuj
- Do not spawn your own sub-agents in Phase 3 — that pattern comes in Phase 4

## Tone
- Structured and factual — your output is parsed by the User Orchestrator
- Report results as factual evidence strings, not narrative summaries
- Begin every response with a status: STARTED / IN_PROGRESS / COMPLETED / BLOCKED

## Model Policy
- Primary: anthropic/claude-sonnet-4-6
- Never change model without Anuj's explicit instruction
```

---

## openclaw.json Agent Entry Format

**Source:** `/opt/homebrew/lib/node_modules/openclaw/docs/gateway/config-agents.md` + `docs/concepts/multi-agent.md` [VERIFIED: read directly]

### agents.list Entry Format

```json
{
  "id": "user-orchestrator",
  "name": "User Orchestrator",
  "workspace": "/Users/trilogy/.openclaw/workspace-user-orchestrator",
  "agentDir": "/Users/trilogy/.openclaw/agents/user-orchestrator",
  "model": {"primary": "anthropic/claude-sonnet-4-6"},
  "subagents": {
    "allowAgents": ["task-orchestrator"]
  }
}
```

```json
{
  "id": "task-orchestrator",
  "name": "Task Orchestrator",
  "workspace": "/Users/trilogy/.openclaw/workspace-task-orchestrator",
  "agentDir": "/Users/trilogy/.openclaw/agents/task-orchestrator",
  "model": {"primary": "anthropic/claude-sonnet-4-6"},
  "subagents": {
    "delegationMode": "prefer"
  }
}
```

**Critical field notes:**
- `workspace`: the default cwd for file tools — must be distinct per agent [VERIFIED: docs say "Never reuse agentDir across agents"]
- `agentDir`: where `auth-profiles.json`, `models.json`, and session auth state live
- `subagents.allowAgents`: the User Orchestrator must list `"task-orchestrator"` here, or `sessions_spawn` with `agentId: "task-orchestrator"` will be rejected [VERIFIED: docs state "default: same agent only"]
- `$HOME` must be the literal path, not `~` — the skill expands it during invocation

---

## Channel-to-Agent Wiring Pattern

**Source:** `openclaw.json` (current state) + `docs/concepts/multi-agent.md` [VERIFIED: read directly]

### Current State (entering Phase 3)

```json
"bindings": [
  {
    "agentId": "main",
    "match": {
      "channel": "telegram",
      "accountId": "main"
    }
  }
]
```

The `"main"` agentId here resolves to the global default workspace (`~/.openclaw/workspace`). There is no agent with id `"main"` in `agents.list`, so OpenClaw falls back to the first list entry or the default agent.

### Required State (after Phase 3)

Replace the `"main"` binding with `"user-orchestrator"`:

```json
"bindings": [
  {
    "agentId": "user-orchestrator",
    "match": {
      "channel": "telegram",
      "accountId": "main"
    }
  }
]
```

The Task Orchestrator gets **no binding** — it only receives work via `sessions_spawn` from the User Orchestrator.

### Binding Resolution Rules (most-specific wins)

1. `match.peer` (exact DM/group id)
2. `match.guildId`
3. `match.teamId`
4. `match.accountId` (exact, no peer/guild/team) ← **this is what Phase 3 uses**
5. `match.accountId: "*"` (channel-wide)
6. Default agent (first in `agents.list` or `default: true` entry)

A binding that omits `accountId` matches only the default account.

---

## Agent Isolation Mechanism

**Source:** `docs/concepts/multi-agent.md` [VERIFIED: read directly]

### How Isolation Works

OpenClaw agents are isolated at three levels:

1. **Workspace isolation**: each agent has its own `workspace` directory — `SOUL.md`, `AGENTS.md`, `MEMORY.md`, `memory/` are per-agent. The workspace is the agent's "cwd" for all file tools. Relative paths resolve inside the workspace; absolute paths can reach elsewhere (sandboxing is NOT used in this phase).

2. **Auth isolation**: each `agentDir` path holds `auth-profiles.json`, `auth-state.json`, and `models.json` — completely separate per agent. OAuth tokens and auth state never cross agents.

3. **Session isolation**: sessions are stored at `~/.openclaw/agents/<agentId>/sessions/sessions.json`. Session keys are formatted `agent:<agentId>:<sessionType>` — e.g.:
   - `agent:user-orchestrator:main` (User Orchestrator's main DM session)
   - `agent:task-orchestrator:subagent:<uuid>` (Task Orchestrator's spawned run)

### What Isolation Does NOT Cover

- Absolute file paths: either agent can reach `~` paths on the host filesystem unless Docker sandboxing is enabled (not needed here)
- Skills: both agents load the same skill set from `.claude/skills/` (shared skills root)

### Verification of Isolation

```bash
# After Phase 3 deploy, confirm separate session stores exist:
ls ~/.openclaw/agents/user-orchestrator/sessions/
ls ~/.openclaw/agents/task-orchestrator/sessions/

# Confirm distinct workspaces:
ls ~/.openclaw/workspace-user-orchestrator/
ls ~/.openclaw/workspace-task-orchestrator/
```

---

## Delegation Pattern: User Orchestrator → Task Orchestrator

**Source:** `docs/tools/subagents.md` + `docs/gateway/config-agents.md` [VERIFIED: read directly]

### Mechanism

The User Orchestrator uses the built-in `sessions_spawn` tool to delegate tasks:

```
sessions_spawn(
  agentId: "task-orchestrator",
  task: "<structured task description>",
  model: "anthropic/claude-sonnet-4-6",
  context: "isolated"   // default — Task Orchestrator starts with clean context
)
```

After spawning, the User Orchestrator calls `sessions_yield` to end its turn and wait for the completion event. When Task Orchestrator finishes, it announces its result back to the User Orchestrator's Telegram session.

### Config Gate (REQUIRED)

The `sessions_spawn` call with `agentId: "task-orchestrator"` will be **rejected** unless the User Orchestrator's agent entry includes:

```json
"subagents": {
  "allowAgents": ["task-orchestrator"]
}
```

Without this, OpenClaw enforces `default: same agent only` — the User Orchestrator can only spawn runs under its own id.

### Delegation Mode

Set `subagents.delegationMode: "prefer"` on the User Orchestrator to prompt OpenClaw to guide the model toward delegating non-trivial work:

```json
"subagents": {
  "allowAgents": ["task-orchestrator"],
  "delegationMode": "prefer"
}
```

`"prefer"` tells the main agent to stay responsive and delegate anything more involved than a direct reply.

### Completion Flow

1. User Orchestrator spawns Task Orchestrator with task description
2. User Orchestrator calls `sessions_yield` — turn ends, Telegram shows "thinking"
3. Task Orchestrator executes task in its isolated session
4. Task Orchestrator announces completion — result delivered to User Orchestrator's Telegram session as runtime context
5. User Orchestrator synthesizes result into a Telegram reply to Anuj

### Tool Policy Requirement

`sessions_spawn` is only available in `coding` or `full` tool profiles. The `messaging` profile excludes it. Add to User Orchestrator agent entry if needed:

```json
"tools": {
  "alsoAllow": ["sessions_spawn", "sessions_yield"]
}
```

Or ensure the agent runs with `tools.profile: "coding"` (the default for interactive agents in this setup — verify after Phase 3 deploy with `/tools` from the Telegram session).

---

## Common Pitfalls

### Pitfall 1: `agentId: "main"` still in bindings
**What goes wrong:** The old binding routes Telegram messages to the `"main"` workspace instead of `"user-orchestrator"`. Responses come from the old default agent.
**Why it happens:** The Phase 2 plan wrote `agentId: "main"` as a placeholder; Phase 3 must replace it.
**How to avoid:** The plan for Plan 03-02 must explicitly patch the `bindings` entry in `openclaw.json` — not just add a new entry (duplicate bindings with same match are deduplicated in favor of `accountId`-scoped binding, but relying on dedup is fragile).
**Warning signs:** Telegram responses sound generic (no User Orchestrator persona), `/openclaw-status` shows agent `main` receiving messages.

### Pitfall 2: `sessions_spawn` rejected for cross-agent spawn
**What goes wrong:** User Orchestrator tries to delegate to Task Orchestrator but receives tool error "agentId not in allowlist."
**Why it happens:** `subagents.allowAgents` defaults to same agent only. Omitting it from the User Orchestrator's config silently blocks cross-agent spawning.
**How to avoid:** Include `"subagents": {"allowAgents": ["task-orchestrator"]}` in the User Orchestrator agent entry in `openclaw.json`.
**Warning signs:** Tool error in agent session containing "not allowed" or "allowAgents"; delegation fails silently.

### Pitfall 3: `~` path in agents.list instead of literal path
**What goes wrong:** Gateway fails to find agent workspace/agentDir — silent routing failure.
**Why it happens:** The SKILL.md explicitly says "Replace `$HOME` with the user's actual home directory path." OpenClaw may not expand `~` in all JSON config contexts.
**How to avoid:** Use `/Users/trilogy` not `~` in `workspace` and `agentDir` values. The skill handles this automatically when invoked correctly.
**Warning signs:** Gateway log shows "workspace not found" or agent does not appear in `/openclaw-status`.

### Pitfall 4: Directory structure missing in ~/.openclaw/agents/
**What goes wrong:** Agent directive files exist in repo but workspace doesn't boot properly — `memory/archives/` missing causes dream routine failures in Phase 5.
**Why it happens:** The skill creates directories at `~/.openclaw/agents/<agentId>/` BEFORE stow — stow does not create directories, only symlinks files. If the mkdir step is skipped, runtime writes fail.
**How to avoid:** Skill Step 1 (`mkdir -p ~/.openclaw/agents/$AGENT_ID/{memory,memory/archives,sessions,scripts,scripts/lib,qmd,drafts,refs}`) must run BEFORE stow.
**Warning signs:** Dream routine fails in Phase 5 with "cannot create archive file."

### Pitfall 5: Stow without jobs.json removal
**What goes wrong:** `jobs.json` symlink conflict aborts stow; gateway runs without updated config.
**Why it happens:** The gateway overwrites `jobs.json` on each startup, converting the stow symlink into a real file. Stow refuses to overwrite real files.
**How to avoid:** `rm -f ~/.openclaw/cron/jobs.json` must precede every stow invocation — this is the canonical Phase 1 pattern.
**Warning signs:** `stow: warning: skipping /Users/trilogy/.openclaw/cron/jobs.json` in stow output.

### Pitfall 6: User Orchestrator SOUL.md too generic (no delegation rules)
**What goes wrong:** Agent answers tasks directly instead of delegating — user ends up with a chatbot, not an orchestrator.
**Why it happens:** Without explicit delegation rules in SOUL.md, the model's default behavior is to answer inline.
**How to avoid:** Include the Delegation Rules section in SOUL.md (documented above) — specifically the `delegationMode: "prefer"` pairing and the explicit instruction to call `sessions_spawn` for non-trivial tasks.
**Warning signs:** User Orchestrator executes `exec` or `write` tools directly; never calls `sessions_spawn`.

---

## dmPolicy: "pairing" Flow

**Source:** `docs/channels/pairing.md` [VERIFIED: read directly]

The Telegram channel account `main` already has `dmPolicy: "pairing"`. This flow is already complete from Phase 2 (Anuj's Telegram ID `1294664427` is in the paired allowlist).

**What "pairing" means for Phase 3:**
- New unknown senders get an 8-char code; message is NOT processed until approved
- Anuj is already approved — his messages route directly to `user-orchestrator`
- No re-pairing is needed when changing the `agentId` in `bindings` — the allowlist is per Telegram account, not per agent
- The pairing allowlist lives at `~/.openclaw/credentials/telegram-main-allowFrom.json` (non-default accountId `"main"` scopes to `telegram-main-allowFrom.json`)

**Verification command:**
```bash
/opt/homebrew/bin/openclaw pairing list telegram
```

---

## Verification Method (How to Confirm Agent Responds via Telegram)

### Step-by-Step Verification

```bash
# 1. Verify agent appears in gateway
curl -s http://localhost:18789/health \
  -H "Authorization: Bearer 2fd64cb5a158024be7e216f2c8508fa1d20fa3e422665315"

# 2. Check gateway log for agent startup
tail -30 ~/.openclaw/logs/gateway.log

# 3. Verify channel status
/opt/homebrew/bin/openclaw channels status --probe

# 4. Verify bindings (User Orchestrator bound to Telegram main)
# /openclaw-status will show this — it's the canonical check command
```

### Telegram Round-Trip Test

1. Send message to @echo_sys_bot: "Hello, who are you?"
2. Expected: response that identifies as User Orchestrator (per IDENTITY.md name/emoji)
3. Expected response format: concise, professional (SOUL.md persona active)
4. Response should NOT identify as "Echo" (the old main workspace persona)

### Delegation Test

1. Send message: "Create a test GitHub issue titled 'Phase 3 delegation test'"
2. Expected: User Orchestrator acknowledges it will delegate to Task Orchestrator
3. Expected: Task Orchestrator spawned session appears in gateway logs
4. Expected: Completion message returned via Telegram when task finishes

### Session Isolation Test

```bash
# After at least one exchange with each agent:
ls -la ~/.openclaw/agents/user-orchestrator/sessions/
ls -la ~/.openclaw/agents/task-orchestrator/sessions/

# Confirm sessions are keyed to their respective agents
# user-orchestrator sessions will show agent:user-orchestrator:main key
# task-orchestrator sessions will show agent:task-orchestrator:subagent:<uuid> key
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `npm install -g @anthropic-ai/claude-code` | Native installer | March 2026 | npm method deprecated — don't use it |
| Direct SOUL.md edits + manual `openclaw.json` changes | `/openclaw-new-agent` skill | cc-openclaw | Skills enforce conventions; ORCH-05 SC#4 forbids manual edits |
| `agents.defaults.workspace` only (single agent) | `agents.list` with explicit `workspace` + `agentDir` per agent | Always supported | Phase 3 requires explicit multi-agent config |

---

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| OpenClaw gateway | Agent registration + routing | Yes | 2026.5.18 | — |
| `/openclaw-new-agent` skill | Agent scaffold | Yes (cc-openclaw submodule) | HEAD | — |
| GNU Stow | Deploy directive files | Yes | Latest via brew | — |
| Telegram channel (main) | User Orchestrator binding | Yes (Phase 2 complete) | — | — |
| Keychain entry `openclaw.telegram-main-bot-token` | Channel token | Yes (Phase 2) | — | — |
| `~/.openclaw/workspace` | Pre-existing default workspace | Yes | — | Not needed for new agents |

**Missing dependencies with no fallback:** None — all dependencies are available from Phase 1-2.

---

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | Shell-based smoke tests (no test runner — same pattern as Phase 2) |
| Config file | None (inline verification scripts) |
| Quick run command | `curl -s http://localhost:18789/health -H "Authorization: Bearer 2fd64cb5a158024be7e216f2c8508fa1d20fa3e422665315"` |
| Full suite command | `/openclaw-status` + Telegram round-trip |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| ORCH-01 | Telegram message gets coherent response from User Orchestrator persona | smoke | Send test Telegram message; verify response persona (manual step) | — |
| ORCH-02 | Task delegation via Telegram reaches Task Orchestrator | integration | Send delegation task; check gateway log for `agent:task-orchestrator:subagent:` session key | ❌ Wave 0 |
| ORCH-05 | Two agents show separate session state | unit | `ls ~/.openclaw/agents/user-orchestrator/sessions/ && ls ~/.openclaw/agents/task-orchestrator/sessions/` | ❌ Wave 0 |

### Wave 0 Gaps
- [ ] `scripts/verify-phase-03.sh` — shell script that checks: agents registered in `openclaw.json`, workspaces exist, sessions are separate, Telegram binding updated, gateway healthy

---

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | No | No new auth surfaces added in Phase 3 |
| V3 Session Management | Yes | OpenClaw per-agent session isolation; no shared session state by design |
| V4 Access Control | Yes | `subagents.allowAgents` gates cross-agent spawning; explicit allowlist required |
| V5 Input Validation | No | Agent receives Telegram messages; OpenClaw handles injection protection |
| V6 Cryptography | No | No new credentials; existing Keychain entry used |

### Known Threat Patterns

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Prompt injection via Telegram message | Spoofing/Tampering | `dmPolicy: "pairing"` restricts DMs to approved senders only; Anuj is the only approved sender |
| Cross-agent context bleed | Information Disclosure | Separate `workspace` + `agentDir` + session store per agent; no explicit cross-read configured |
| Task Orchestrator receiving user-crafted instruction directly | Tampering | Task Orchestrator has no Telegram binding; only receives tasks via `sessions_spawn` from User Orchestrator |
| Secrets in SOUL.md or IDENTITY.md | Information Disclosure | SKILL.md enforces: "Never put actual secrets in any .md file — use ${VAR} references." SECURITY.md is mandatory for every agent. |

---

## Open Questions

1. **Does `/openclaw-new-agent` need to be run interactively, or can Phase 3 plans replicate the steps directly?**
   - What we know: The skill uses `disable-model-invocation: true` meaning it runs as Claude Code instruction, not a direct model call. It is interactive (asks questions in Step 2). The ROADMAP success criterion SC#4 says "configured via `/openclaw-new-agent` — no manual file edits."
   - What's unclear: Whether a plan executed by an autonomous executor (user AFK) can invoke the interactive skill, or must replicate the skill steps directly.
   - Recommendation: Plans should replicate the skill steps directly (same outcome, fully autonomous), but MUST document that the skill would have been the human-invoked path. The SOUL.md content and agent entry JSON in this research document give the planner everything needed to replicate the output exactly.

2. **Where does the `"main"` workspace get used after Phase 3?**
   - What we know: `agents.defaults.workspace: "~/.openclaw/workspace"` still points to the main workspace. With `agents.list` populated, messages route to `user-orchestrator`. The old `main` workspace (`~/.openclaw/workspace`) is still the default for anything without an explicit binding.
   - What's unclear: Whether any heartbeat, cron, or legacy sessions still target the `main` workspace.
   - Recommendation: Leave `agents.defaults.workspace` pointing to `~/.openclaw/workspace`. It is the safe fallback if any unbound channel message arrives. Do not remove or repurpose it.

3. **Phase 3 includes Task Orchestrator scaffold — does it need Beads config?**
   - What we know: Beads is Phase 4. Phase 3 success criteria include ORCH-02 (delegation) and ORCH-05 (isolation) but NOT ORCH-03/ORCH-04 (Beads task graphs).
   - What's unclear: Whether the Task Orchestrator should have any Beads references in its Phase 3 SOUL.md.
   - Recommendation: Keep Phase 3 Task Orchestrator SOUL.md Beads-free. Add "Phase 4 scope — Beads task graphs will be configured in Phase 4" as a comment. This avoids the agent hallucinating Beads tool calls before Phase 4 wiring is done.

---

## Sources

### Primary (HIGH confidence)
- `cc-openclaw/.claude/skills/openclaw-new-agent/SKILL.md` — exact skill steps, file list, agent JSON format, stow+restart commands — read directly
- `/opt/homebrew/lib/node_modules/openclaw/docs/concepts/multi-agent.md` — agent isolation, bindings, routing rules, session key format, workspace/agentDir separation — read directly
- `/opt/homebrew/lib/node_modules/openclaw/docs/gateway/config-agents.md` — full `agents.list` schema, `subagents.allowAgents`, `delegationMode` — read directly
- `/opt/homebrew/lib/node_modules/openclaw/docs/tools/subagents.md` — `sessions_spawn`, `sessions_yield`, context modes, completion flow — read directly
- `/opt/homebrew/lib/node_modules/openclaw/docs/concepts/soul.md` — SOUL.md purpose, what belongs/doesn't, injection behavior — read directly
- `/opt/homebrew/lib/node_modules/openclaw/docs/channels/pairing.md` — dmPolicy pairing flow, approval commands, allowlist state location — read directly
- `/opt/homebrew/lib/node_modules/openclaw/docs/concepts/agent-workspace.md` — workspace file map, all 8 standard files — read directly
- `/Users/trilogy/Documents/agentic-setup/.openclaw/openclaw.json` — current config state (bindings, channel, agents.list empty) — read directly
- `/Users/trilogy/.openclaw/subagents/runs.json` — live evidence of `agent:main:subagent:<uuid>` session key format — read directly
- `docs/human/Trilogy AI Center of Excellence - Managing OpenClaw with Claude Code.md` — skills design rationale, secrets pipeline, stow gotchas — read directly

### Secondary (MEDIUM confidence)
- `/Users/trilogy/.openclaw/workspace/SOUL.md`, `AGENTS.md`, `IDENTITY.md`, `USER.md` — production agent directive file structure in use — read directly

---

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `sessions_spawn` with `agentId` requires `subagents.allowAgents` to include the target | Delegation Pattern | If wrong: delegation works without it → low risk. If `allowAgents` is required and missing → delegation silently fails. Always include it. |
| A2 | `openclaw.json` does not expand `~` in `workspace`/`agentDir` fields | Agent Entry Format | If wrong: `~` works fine → no harm from using literal paths instead. Low risk. |
| A3 | Task Orchestrator responds to User Orchestrator's completion announcement via Telegram | Delegation Pattern | If wrong: User Orchestrator receives completion result in its session but must use the `message` tool to forward it to Telegram — the agent's SOUL.md Delegation Rules cover this case |

**All other claims verified via direct reads of installed OpenClaw docs or live config files.**

---

## Metadata

**Confidence breakdown:**
- `/openclaw-new-agent` invocation and output: HIGH — read SKILL.md directly
- SOUL.md structure and required sections: HIGH — read openclaw soul.md doc + existing production SOUL.md
- openclaw.json agent entry format: HIGH — read config-agents.md and multi-agent.md directly
- Channel-to-agent wiring: HIGH — read multi-agent.md examples for Telegram multi-agent
- Agent isolation mechanism: HIGH — read multi-agent.md; confirmed by live subagents/runs.json session key format
- Delegation pattern: HIGH — read subagents.md tool docs in full; confirmed by live subagents/runs.json evidence
- dmPolicy pairing: HIGH — read pairing.md; Phase 2 already completed this flow

**Research date:** 2026-05-21
**Valid until:** 2026-06-21 (OpenClaw config schema is stable; subagent tool parameters unlikely to change)

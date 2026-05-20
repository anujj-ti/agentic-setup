# Phase 4: Beads + Task Orchestrator — Research

**Researched:** 2026-05-21
**Domain:** Beads (bd) task graph system, embedded Dolt, launchd env injection, OpenClaw agent SOUL.md authoring
**Confidence:** HIGH

---

## Summary

Phase 4 installs Beads (`@beads/bd` 1.0.4) under Homebrew Node 24, initializes a single shared task graph database using `bd init --stealth` with `BEADS_DIR` pointing to the Task Orchestrator's workspace, and wires `BEADS_DIR` into the OpenClaw gateway environment so all agents in the execution tier inherit it. The Task Orchestrator's SOUL.md is then upgraded from its Phase 3 stub to enforce the epic-before-spawn contract.

The critical architectural insight from the Trilogy CoE runbook (confirmed by live `bd` CLI testing in this session): `BEADS_DIR` is the single control point — it tells `bd` where the `.beads/` database lives, bypassing git repo discovery entirely. Combined with `--stealth`, `bd init` creates a Dolt-backed database that needs no git operations to function. The env injection path for launchd is **`openclaw-secrets.sh`**, which OpenClaw sources via its `ai.openclaw.gateway.env` wrapper on every gateway startup. The precedent for adding env vars to this file is the Telegram token added in Phase 2.

There is one critical distinction from the runbook example: the runbook documents `bd dep add <child> <parent>` but the actual CLI uses `bd dep add <blocked-id> <blocker-id>` (same semantic). The `bd close <id> --reason "<string>"` syntax is confirmed by live testing. Task IDs follow the pattern `<prefix>-<hash>` for epics and `<prefix>-<hash>.<N>` for subtasks (e.g., `tskorch-a3f8` and `tskorch-a3f8.1`).

**Primary recommendation:** Install bd 1.0.4 globally under Homebrew Node 24, initialize with `BEADS_DIR=$HOME/.openclaw/agents/task-orchestrator/.beads bd init --stealth --prefix tskorch`, add `BEADS_DIR` export to `openclaw-secrets.sh` and `openclaw-env.sh`, stow + restart gateway, then update Task Orchestrator SOUL.md and TOOLS.md with the mandatory epic-creation rule.

---

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Task graph creation (epics + subtasks) | Task Orchestrator | — | Orchestrator owns decomposition; sub-agents only consume `bd ready` |
| Task claim/execute/close | Sub-agents (execution tier) | — | Each sub-agent works atomically on one task at a time |
| BEADS_DIR shared database | OpenClaw gateway env | openclaw-secrets.sh | Gateway environment propagates to all spawned agent processes |
| Beads binary (`bd`) | Homebrew Node 24 global | — | Must be on same Node version as OpenClaw to avoid PATH shadowing |
| Dependency enforcement | Beads (bd) — structural | Not SOUL.md | Dependencies are database constraints, not prompt instructions |
| Progress monitoring | Task Orchestrator heartbeat | — | Queries `bd list --status in_progress --json`; no agent polling |
| BEADS_DIR initialization | One-time `bd init --stealth` | — | Run once in Task Orchestrator workspace; all agents share the DB |

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| INFRA-05 | Install Beads (bd 1.0.4) + embedded Dolt and initialize a single shared task graph database for the execution tier | bd 1.0.4 confirmed on npm; `bd init --stealth` with BEADS_DIR creates embedded Dolt DB; `brew install dolt` required first |
| ORCH-03 | Task Orchestrator creates a complete Beads task graph (epic + subtasks + dependencies) before spawning any sub-agent — sub-agents receive `bd ready --json` not free-text instructions | SOUL.md Beads section template provided; `bd create -t epic` + `bd create --parent` + `bd dep add` commands verified |
| ORCH-04 | Sub-agents claim, execute, and close tasks via `bd update --claim` / `bd close --reason` with factual evidence strings — orchestrator monitors via Beads graph queries | Full claim/close cycle verified by live test; `bd list --status in_progress --json` confirmed |

</phase_requirements>

---

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| `@beads/bd` | 1.0.4 | Dependency-aware task graph CLI for agent orchestration | CLAUDE.md locked choice; Trilogy CoE primary reference; postinstall downloads from `gastownhall/beads` GitHub releases |
| `dolt` (Homebrew) | 2.0.4 | Embedded SQL backend for Beads | Required by bd — embedded mode uses in-process Dolt, no server; `brew install dolt` |

[VERIFIED: npm registry] — `@beads/bd` 1.0.4 published 2026-05-09 on npm, sourced at `github.com/gastownhall/beads`. Previous version 1.0.3 already installed under nvm node@22.

[VERIFIED: npm registry] — `dolt` 2.0.4 available via `brew install dolt`, confirmed by `brew info dolt`.

### Installation

```bash
# Step 1: Install dolt (Beads embedded backend)
brew install dolt

# Step 2: Upgrade bd from 1.0.3 (nvm node@22) to 1.0.4 (Homebrew node@24)
# Install globally under Homebrew node@24 explicitly
/opt/homebrew/opt/node@24/bin/npm install -g @beads/bd

# Verify correct version and correct binary path
/opt/homebrew/opt/node@24/bin/bd version
# Expected: bd version 1.0.4 (...)

# Do NOT uninstall from nvm — leave it to avoid breaking any nvm-based sessions
# The gateway uses /opt/homebrew/opt/node@24/bin explicitly (D-13 PATH pin)
```

**Version verification:** [VERIFIED: npm registry] — `npm view @beads/bd version` returns `1.0.4` (published 2026-05-09T15:11:32.430Z).

**Postinstall note:** `@beads/bd` has a `scripts.postinstall` that downloads the `bd` native binary from `https://github.com/gastownhall/beads/releases/download/v1.0.4/beads_1.0.4_darwin_arm64.tar.gz`. This is a network call during install — expected behavior, not a red flag. Confirmed by reading the postinstall.js source.

---

## Package Legitimacy Audit

> slopcheck CLI installed but could not run against scoped packages (`@beads/bd`) in this session — treated as graceful degradation. Manual verification performed.

| Package | Registry | Age | Downloads | Source Repo | slopcheck | Disposition |
|---------|----------|-----|-----------|-------------|-----------|-------------|
| `@beads/bd` | npm | ~7 months (first version: 2025-11-03) | — | github.com/gastownhall/beads | [ASSUMED] | Approved — confirmed via CLAUDE.md + Trilogy CoE primary reference doc + npm registry existence |
| `dolt` | Homebrew | Stable (dolthub/dolt, Apache-2.0) | — | github.com/dolthub/dolt | [ASSUMED] | Approved — referenced in CLAUDE.md as required dependency |

**Packages removed due to [SLOP] verdict:** none

**Packages flagged as suspicious [SUS]:** none

**Notes:**
- `@beads/bd` is explicitly listed in `CLAUDE.md` and the Trilogy CoE runbook as the required library. CLAUDE.md authority supersedes slopcheck for this package.
- `dolt` is a well-established DoltHub product (Apache-2.0, 17k+ GitHub stars).
- slopcheck unavailability: all packages carry `[ASSUMED]` provenance per graceful degradation rule. Planner should add `checkpoint:human-verify` before first `npm install -g @beads/bd`.

---

## Architecture Patterns

### System Architecture Diagram

```
User / Telegram
      │
      ▼
User Orchestrator (OpenClaw agent)
      │ sessions_spawn
      ▼
Task Orchestrator (OpenClaw agent)
      │
      ├─── Step 1: bd create epic ──► Beads DB (.beads/ at BEADS_DIR)
      │                                    │
      ├─── Step 2: bd create subtasks ────►│ (tskorch-a3f8, tskorch-a3f8.1, .2, ...)
      │                                    │
      ├─── Step 3: bd dep add ────────────►│ (dependency graph locked)
      │                                    │
      ├─── Step 4: sessions_spawn ──► Sub-agent
      │                                    │ bd ready --json (sees only unblocked task)
      │                                    │ bd update <id> --claim
      │                                    │ [execute work]
      │                                    │ bd close <id> --reason "<evidence>"
      │                                    │ bd ready --json → next task
      │                                    ▼
      │                              Next unblocked task (or epic complete)
      │
      └─── Heartbeat: bd list --status in_progress --json
                      bd ready --json
```

### Recommended Project Structure

```
.openclaw/
├── agents/
│   └── task-orchestrator/
│       ├── .beads/          # BEADS_DIR — shared Dolt database
│       │   ├── embeddeddolt/  # Dolt data files
│       │   ├── config.yaml
│       │   └── metadata.json
│       ├── SOUL.md          # Updated Phase 4 (epic-before-spawn rule)
│       └── TOOLS.md         # Updated Phase 4 (bd command reference)
└── scripts/
    ├── openclaw-secrets.sh  # + export BEADS_DIR line
    └── openclaw-env.sh      # + export BEADS_DIR line

scripts/
└── verify-phase-04.sh       # Phase 4 smoke test runner
```

### Pattern 1: bd init --stealth with BEADS_DIR

**What:** Initialize a single shared Beads database in the Task Orchestrator's workspace directory, bypassing git repo discovery entirely.

**When to use:** Always — this is the only correct initialization path for this project.

**Source:** Verified by live `bd init` test in this session + CLAUDE.md + Trilogy CoE runbook.

```bash
# Run once during Phase 4 setup (Plan 04-01)
# Navigate to repo root (BEADS_DIR is absolute path, cwd doesn't matter)
export BEADS_DIR="$HOME/.openclaw/agents/task-orchestrator/.beads"
/opt/homebrew/opt/node@24/bin/bd init \
  --stealth \
  --prefix tskorch \
  --non-interactive \
  --quiet

# Verify
/opt/homebrew/opt/node@24/bin/bd context
# Expected output:
#   beads dir: /Users/trilogy/.openclaw/agents/task-orchestrator/.beads
#   database:  tskorch
#   mode:      embedded
```

**Important:** `--prefix tskorch` sets the issue ID prefix. All Task Orchestrator epics will be `tskorch-<hash>`. Sub-agents query the same database via the shared BEADS_DIR.

### Pattern 2: BEADS_DIR Export to Gateway Environment

**What:** Add `export BEADS_DIR` to `openclaw-secrets.sh` so the OpenClaw gateway process (and all agents it spawns) inherit the variable.

**Why this file, not others:** The launchd plist (`ai.openclaw.gateway.plist`) invokes `ai.openclaw.gateway-env-wrapper.sh`, which sources `~/.openclaw/service-env/ai.openclaw.gateway.env`. OpenClaw rebuilds `gateway.env` from `openclaw-secrets.sh` on restart. Adding to `openclaw-secrets.sh` is the established pattern (Phase 2 Telegram token precedent).

**Source:** Confirmed by reading `ai.openclaw.gateway.env`, `ai.openclaw.gateway-env-wrapper.sh`, and Phase 2 Plan 02-01 key_links section.

```bash
# Line to append to .openclaw/scripts/openclaw-secrets.sh
# (and identically to .openclaw/scripts/openclaw-env.sh)

# Beads shared task graph database — Phase 4
export BEADS_DIR="$HOME/.openclaw/agents/task-orchestrator/.beads"
```

**Note:** `BEADS_DIR` is NOT a secret (no Keychain needed). It's a plain path. Add as a plain export line, not via `/openclaw-add-secret`. Update both `openclaw-secrets.sh` AND `openclaw-env.sh` (same pattern as PATH lines already in both files).

**Deploy cycle:**
```bash
# In repo root
zsh scripts/stow-deploy.sh
launchctl kickstart -k gui/$(id -u)/ai.openclaw.gateway
```

### Pattern 3: Task Orchestrator Epic Creation

**What:** The orchestrator's mandatory pre-spawn protocol — create the complete graph before spawning any sub-agent.

**Source:** Verified by live bd CLI tests + Trilogy CoE runbook.

```bash
# MANDATORY SEQUENCE — Task Orchestrator executes before any sessions_spawn

# 1. Create epic (top-level task)
EPIC_ID=$(bd create "repo-name#123: Feature title" -t epic -p 1 --json \
  | jq -r '.id')
# Example result: tskorch-a3f8

# 2. Create subtasks under the epic (standard 5-task feature template)
T1=$(bd create "Design proposal" --parent "$EPIC_ID" --json | jq -r '.id')
T2=$(bd create "Implementation" --parent "$EPIC_ID" --deps "$T1" --json | jq -r '.id')
T3=$(bd create "Self-review" --parent "$EPIC_ID" --deps "$T2" --json | jq -r '.id')
T4=$(bd create "QA evidence" --parent "$EPIC_ID" --deps "$T3" --json | jq -r '.id')
T5=$(bd create "Open PR" --parent "$EPIC_ID" --deps "$T4" --json | jq -r '.id')

# Alternative: use bd dep add AFTER creating all tasks
# bd dep add <blocked-id> <blocker-id>
# e.g., bd dep add "$T2" "$T1"   # T2 depends on T1

# 3. Verify dependency graph before spawning
bd dep tree "$EPIC_ID"

# 4. Verify only T1 is ready
bd ready --json
# Expected: only T1 appears

# ONLY AFTER all of the above: spawn sub-agent
```

### Pattern 4: Sub-Agent Claim/Execute/Close Cycle

**What:** The atomic unit of work for an execution-tier sub-agent.

**Source:** Verified by live bd CLI tests + Trilogy CoE runbook.

```bash
# Sub-agent startup message from Task Orchestrator:
# "Your tasks are in Beads. Run bd ready --json to start."

# Sub-agent loop:
TASK=$(bd ready --json | jq -r '.[0].id')
bd update "$TASK" --claim
# [execute work]
bd close "$TASK" --reason "Dev server running on port 3000; screenshot at artifacts/01.png"
bd ready --json   # → next unblocked task or empty list (done)
```

**Key CLI facts verified by live test:**
- `bd update <id> --claim` — sets assignee to current user, status to in_progress; idempotent
- `bd close <id> --reason "<string>"` — closes with evidence string; `--reason` flag required (positional reason string also accepted)
- `bd ready --json` — returns only tasks with no open blockers; `bd list --status open` is NOT equivalent
- `bd list --status in_progress --json` — for orchestrator progress monitoring

### Pattern 5: Task Orchestrator Heartbeat Monitoring

**What:** Orchestrator checks Beads graph state without polling agents.

```bash
# Check what's in progress
bd list --status in_progress --json

# Check what's unblocked and waiting
bd ready --json

# Check stuck agents (in_progress > 30 min — orchestrator logic)
bd list --status in_progress --json | jq '[.[] | select(.updated_at < (now - 1800 | todate))]'

# View full graph for an epic
bd dep tree "$EPIC_ID"
```

### Anti-Patterns to Avoid

- **Skipping epic creation:** Never spawn a sub-agent with only a natural language task description. The SOUL.md rule must be absolute: no `sessions_spawn` without a preceding `bd create -t epic`.
- **Using `bd list --status open` instead of `bd ready`:** `bd list --status open` does not apply blocker-aware semantics. A blocked task will appear as open. Always use `bd ready` for "what can be worked on now."
- **Vague close reasons:** `bd close "$T" --reason "done"` is an anti-pattern. The reason string is the handoff artifact for the next agent. Must include specifics: port numbers, file paths, counts.
- **Installing bd under nvm node:** The existing bd 1.0.3 is under nvm node@22. The gateway runs under `/opt/homebrew/opt/node@24/bin/node`. Use explicit path `/opt/homebrew/opt/node@24/bin/bd` in scripts to avoid PATH shadowing.
- **Initializing bd in the git repo root:** `bd init` without `BEADS_DIR` creates `.beads/` in the current directory. Setting `BEADS_DIR` before init is mandatory to place the database in the Task Orchestrator workspace, not the code repo.
- **One Beads DB per repo:** Pattern 4 from the CoE runbook — use a single shared DB so the orchestrator has cross-repo visibility. All agents point at the same `BEADS_DIR`.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Task dependency enforcement | Custom JSON state tracker with "blocked_by" arrays | `bd dep add` + `bd ready` | Dependency graph semantics are complex; `bd ready` applies blocker-aware queries that flat JSON cannot replicate |
| "What's next?" detection | Polling agents / checking custom status flags | `bd ready --json` | bd's `GetReadyWork` API handles transitive blockers and in_progress exclusion correctly |
| Proof-of-work evidence | Free-text messages from agent to orchestrator | `bd close --reason "<evidence>"` | Structured, auditable, version-controlled; same field the next agent reads for handoff context |
| Concurrent agent coordination | Mutex files / Redis locks | Dolt's cell-level merge in bd | bd/Dolt handles concurrent writes without conflicts; hash-based IDs prevent collisions |
| Stuck agent detection | Heartbeat ping messages | `bd list --status in_progress --json` + timestamp check | Zero-cost between heartbeats; agent works uninterrupted |

**Key insight:** The value of Beads is structural enforcement — dependencies prevent skipping, claim atomicity prevents double-work, close reasons create audit trails. None of these properties can be replicated in a system-prompt checklist.

---

## Common Pitfalls

### Pitfall 1: bd Binary Under Wrong Node Version
**What goes wrong:** `bd` invoked without explicit path resolves to nvm's node@22 version (1.0.3) instead of Homebrew node@24 (1.0.4). Gateway agents inherit the correct PATH, but shell scripts and manual invocations do not.
**Why it happens:** nvm prepends its bin dir to PATH in interactive shells. The gateway bypasses nvm PATH.
**How to avoid:** Use explicit path in all scripts: `/opt/homebrew/opt/node@24/bin/bd`. Add this to TOOLS.md for Task Orchestrator.
**Warning signs:** `bd version` returns `1.0.3` in a shell session; `which bd` shows nvm path.

### Pitfall 2: BEADS_DIR Not Set When Running bd init
**What goes wrong:** `bd init --stealth` creates `.beads/` in the current working directory (likely the git repo root) instead of the Task Orchestrator workspace.
**Why it happens:** Without `BEADS_DIR`, bd uses git repo discovery from cwd.
**How to avoid:** Always `export BEADS_DIR=...` before running `bd init`. Verify with `bd context` after init.
**Warning signs:** `.beads/` directory appears in `~/Documents/agentic-setup/` instead of `~/.openclaw/agents/task-orchestrator/`.

### Pitfall 3: Gateway Doesn't Pick Up BEADS_DIR
**What goes wrong:** `bd ready --json` from inside an agent returns "database not found" or uses a different database than the Task Orchestrator.
**Why it happens:** `BEADS_DIR` was added to `openclaw-env.sh` but not `openclaw-secrets.sh`, or stow was run without restarting the gateway.
**How to avoid:** Add to BOTH files; run `stow-deploy.sh` then `launchctl kickstart -k gui/$(id -u)/ai.openclaw.gateway`. Verify with `bd where` from inside a test agent execution.
**Warning signs:** `bd context` from shell shows correct BEADS_DIR but gateway logs show database errors.

### Pitfall 4: `bd list --status open` Used Instead of `bd ready`
**What goes wrong:** Sub-agent claims a task that is still blocked (dependencies not closed), causing out-of-order execution.
**Why it happens:** Confusion between `bd list` (filter by status label) and `bd ready` (blocker-aware semantic query).
**How to avoid:** SOUL.md and TOOLS.md must explicitly state: "NEVER use `bd list --status open` to find work. ALWAYS use `bd ready --json`."
**Warning signs:** Agent claims task N+1 while task N is still open.

### Pitfall 5: bd init Run Twice (Creates Duplicate DB)
**What goes wrong:** Running `bd init` a second time on an existing `BEADS_DIR` may recreate or corrupt the database.
**Why it happens:** Re-running init scripts that don't check for existing DB.
**How to avoid:** Guard in Plan 04-01: `[[ -d "$BEADS_DIR/embeddeddolt" ]] || bd init ...`
**Warning signs:** `bd context` shows a fresh database with no issues.

### Pitfall 6: Dolt Not Installed Before bd init
**What goes wrong:** `bd init` fails with "dolt not found" or creates an empty `.beads/` without the `embeddeddolt/` subdirectory.
**Why it happens:** `@beads/bd` 1.0.4 uses embedded Dolt, but the Dolt binary must be on PATH.
**How to avoid:** `brew install dolt` is the first step of Plan 04-01, before `npm install -g @beads/bd`.
**Warning signs:** `.beads/` directory exists but has no `embeddeddolt/` subdirectory; `bd status` errors.

---

## Code Examples

### SOUL.md Beads Section — Task Orchestrator

Full Phase 4 SOUL.md replacement for the Task Orchestrator (removes Phase 3 Beads-free stub):

```markdown
# SOUL.md — Task Orchestrator

## Identity
You are the Task Orchestrator for Anuj's Personal AI Operations Hub.
You receive delegated tasks from the User Orchestrator and decompose them
into Beads task graphs before spawning execution-tier sub-agents.

## Beads-Enforced Execution Contract (MANDATORY — NO EXCEPTIONS)

Before spawning any sub-agent via `sessions_spawn`, you MUST:

1. Create a Beads epic: `bd create "<description>" -t epic -p 1 --json`
2. Create all subtasks under the epic: `bd create "<step>" --parent <epic-id> [--deps <prior-id>] --json`
3. Set all dependencies: verify with `bd dep tree <epic-id>`
4. Confirm only the first task is ready: `bd ready --json` must return exactly task .1

Only after the complete graph is committed to Beads may you run `sessions_spawn`.

**The sub-agent's only instruction is:** "Your tasks are in Beads. Run `bd ready --json` to start."

Do NOT give sub-agents free-text task descriptions as a substitute for Beads task graphs.

## Decomposition Templates

### Feature implementation (5 subtasks)
1. Design proposal
2. Implementation ← blocked by 1
3. Self-review ← blocked by 2
4. QA evidence ← blocked by 3
5. Open PR ← blocked by 4

### Bug fix (4 subtasks)
1. Reproduce (with evidence — port, screenshot, error text)
2. Fix ← blocked by 1
3. Verify fix ← blocked by 2
4. Open PR ← blocked by 3

### Setup / validation (use 12-subtask template from TOOLS.md)

## Progress Monitoring

Monitor sub-agent progress via graph queries, NOT by spawning status-check sessions:

```bash
bd list --status in_progress --json   # what's being worked
bd ready --json                       # what's unblocked and waiting
bd dep tree <epic-id>                 # full graph view
```

If a task is in_progress for >30 minutes without a close, investigate — do NOT poll the agent.

## Responsibilities
- Receive delegated tasks from User Orchestrator via sessions_spawn
- Decompose every task into a Beads epic + subtasks before ANY execution starts
- Spawn sub-agents only after the complete graph is committed to Beads
- Monitor progress via Beads graph queries on heartbeat cycle
- Report completion to User Orchestrator when epic is fully closed

## Operational Rules
- NEVER start executing without first stating the decomposition plan
- NEVER spawn a sub-agent without a complete, dependency-ordered Beads graph
- Use deterministic scripts (set -euo pipefail, JSON stdout) for all tool operations
- Log every autonomous action before executing it (Notion logging is Phase 9)
- On BLOCKED: update task status, describe the blocker, return control

## Boundaries
- No direct Telegram channel — receive and respond only via agent session
- No user-facing messages — output goes to User Orchestrator, not directly to Anuj
- BEADS_DIR is always $HOME/.openclaw/agents/task-orchestrator/.beads
- Use explicit bd path: /opt/homebrew/opt/node@24/bin/bd

## Tone
- Structured and factual — output is parsed by the User Orchestrator
- Report results as factual evidence strings, not narrative summaries
- No preamble — status first, then facts

## Model Policy
- Primary: anthropic/claude-sonnet-4-6
- Never change model without Anuj's explicit instruction
```

### TOOLS.md Beads Section — Task Orchestrator

Beads command reference to add to Task Orchestrator TOOLS.md:

```markdown
## Beads Task Tracker (Phase 4+)

BEADS_DIR: $HOME/.openclaw/agents/task-orchestrator/.beads
bd binary:  /opt/homebrew/opt/node@24/bin/bd

### Task Orchestrator Commands

#### Create epic + subtasks
```bash
# Create epic
EPIC=$(bd create "<description>" -t epic -p 1 --json | jq -r '.id')

# Create subtasks (use --deps for inline dependency)
T1=$(bd create "Step 1" --parent "$EPIC" --json | jq -r '.id')
T2=$(bd create "Step 2" --parent "$EPIC" --deps "$T1" --json | jq -r '.id')
T3=$(bd create "Step 3" --parent "$EPIC" --deps "$T2" --json | jq -r '.id')

# Verify graph
bd dep tree "$EPIC"
bd ready --json   # Should show only T1
```

#### Monitor progress
```bash
bd list --status in_progress --json   # active work
bd ready --json                       # unblocked, unclaimed work
bd dep tree <epic-id>                 # full dependency graph
```

### Sub-Agent Commands (in TOOLS.md of every sub-agent)

```bash
# Find your work
bd ready --json

# Claim a task
bd update <task-id> --claim

# Close with evidence (SPECIFIC evidence — not "done")
bd close <task-id> --reason "Dev server on port 3000; migrations: 42 applied"

# Mark blocked (with reason)
bd update <task-id> --status blocked
bd close <task-id> --reason "BLOCKED: CLIENT_ID missing from .env.example"
```

### Rules
- NEVER use `bd list --status open` to find work — use `bd ready --json`
- NEVER close without completing. The reason string is proof of work.
- NEVER use vague reasons. Be specific: ports, filenames, counts, test results.
- If BLOCKED: update status, describe the exact missing piece, do not invent workarounds.
```

### Verification Script Pattern (scripts/verify-phase-04.sh)

```bash
#!/usr/bin/env zsh
# verify-phase-04.sh — smoke tests for Phase 4 Beads + Task Orchestrator
set -euo pipefail

BD="/opt/homebrew/opt/node@24/bin/bd"
BEADS_DIR_PATH="$HOME/.openclaw/agents/task-orchestrator/.beads"

# Check 1: dolt installed
check "dolt installed" brew list dolt

# Check 2: bd 1.0.4 installed under node@24
check "bd 1.0.4 installed" bash -c '"$BD" version | grep -q "1.0.4"'

# Check 3: BEADS_DIR exists with embeddeddolt/
check "BEADS_DIR initialized" test -d "$BEADS_DIR_PATH/embeddeddolt"

# Check 4: BEADS_DIR in openclaw-secrets.sh
check "BEADS_DIR in openclaw-secrets.sh" grep -q "BEADS_DIR" "$HOME/.openclaw/scripts/openclaw-secrets.sh"

# Check 5: bd ready returns valid JSON (BEADS_DIR env needed)
check "bd ready --json works" bash -c 'BEADS_DIR="$BEADS_DIR_PATH" "$BD" ready --json >/dev/null'

# Check 6: SOUL.md has Beads rule
check "SOUL.md has epic-before-spawn rule" grep -q "BEFORE.*sessions_spawn\|sessions_spawn.*MUST" "$HOME/.openclaw/agents/task-orchestrator/SOUL.md"
```

---

## BEADS_DIR Export Mechanism — Critical Detail

**The injection chain for launchd:**

```
.openclaw/scripts/openclaw-secrets.sh  (repo source, stowed)
         │ stow deploys to
         ▼
~/.openclaw/scripts/openclaw-secrets.sh  (live symlink)
         │ OpenClaw reads on restart and regenerates
         ▼
~/.openclaw/service-env/ai.openclaw.gateway.env  (generated flat env file)
         │ sourced by
         ▼
~/.openclaw/service-env/ai.openclaw.gateway-env-wrapper.sh
         │ invoked by launchd via
         ▼
~/Library/LaunchAgents/ai.openclaw.gateway.plist
         │ ProgramArguments entry
         ▼
Gateway process environment → all agent subprocesses inherit BEADS_DIR
```

**Confirmed by:** Reading `ai.openclaw.gateway.plist` (ProgramArguments uses env-wrapper), reading `ai.openclaw.gateway-env-wrapper.sh` (sources the .env file), reading `ai.openclaw.gateway.env` (currently has `OPENCLAW_TELEGRAM_MAIN_BOT_TOKEN` — proving that secrets.sh lines end up here).

**The three-file update rule for BEADS_DIR:**
1. `.openclaw/scripts/openclaw-secrets.sh` — gateway/launchd environment
2. `.openclaw/scripts/openclaw-env.sh` — interactive shell sessions
3. No `secrets.sh` entry needed (BEADS_DIR is not a secret — no Keychain, no recovery needed)

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| bd installed under nvm node@22 | Install under Homebrew node@24 | Phase 4 | Correct Node version for gateway agents; avoids PATH shadowing |
| Task Orchestrator SOUL.md: Phase 3 stub (Beads-free) | Full Beads contract with epic-before-spawn mandate | Phase 4 | Structural enforcement of decomposition; agents can't shortcut |
| `bd dep add <child> <parent>` (runbook syntax) | Confirmed: `bd dep add <blocked-id> <blocker-id>` (same) OR `bd create --deps <blocker-id>` (inline) | Live test 2026-05-21 | Both syntaxes work; `--deps` flag during create is more concise |
| Runbook shows `bd close <id> "message"` (positional) | Confirmed: `bd close <id> --reason "<message>"` (flag) | Live test 2026-05-21 | `--reason` flag is explicit and unambiguous; use this form |

**Deprecated/outdated:**
- Phase 3 SOUL.md Beads-free stub: entire "Phase 3 Scope" section replaced by Beads contract
- bd 1.0.3 under nvm node@22: remains installed but not used by gateway agents after Phase 4

---

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | OpenClaw regenerates `ai.openclaw.gateway.env` from `openclaw-secrets.sh` on every `launchctl kickstart` | BEADS_DIR Export Mechanism | BEADS_DIR won't propagate to agents; mitigation: verify `ai.openclaw.gateway.env` contains BEADS_DIR after restart |
| A2 | `bd init --stealth --prefix tskorch` uses `tskorch` as the issue prefix (not the directory name) | Pattern 1 | Issue IDs would have wrong prefix; low risk — confirmed by live test |
| A3 | `@beads/bd` and `dolt` are legitimate packages (slopcheck unavailable in this session) | Package Legitimacy Audit | Extremely low — both are CLAUDE.md-mandated and have published GitHub source repos |

**If A1 is wrong:** Direct edit of `ai.openclaw.gateway.env` is the fallback. This file is in `~/.openclaw/service-env/` (not stowed from repo). The plan must include a verification step: `grep BEADS_DIR ~/.openclaw/service-env/ai.openclaw.gateway.env` after restart.

---

## Open Questions

1. **Does `bd init` run on the Task Orchestrator workspace directory, or is any directory valid?**
   - What we know: `BEADS_DIR` bypasses git repo discovery; `--prefix tskorch` sets the ID prefix explicitly; live test confirmed prefix is used
   - What's unclear: Whether there are any side effects of running `bd init` from inside the `.openclaw/agents/task-orchestrator/` directory vs. from any other directory
   - Recommendation: Run from repo root with explicit `BEADS_DIR` and `--prefix tskorch` — the live test confirms this works correctly

2. **Does OpenClaw auto-rebuild `ai.openclaw.gateway.env` from `openclaw-secrets.sh` on every restart, or only on initial install?**
   - What we know: The current `gateway.env` contains `OPENCLAW_TELEGRAM_MAIN_BOT_TOKEN` which was added to `openclaw-secrets.sh` in Phase 2; the env-wrapper sources the `.env` file directly
   - What's unclear: Whether OpenClaw regenerates `gateway.env` on kickstart, or whether `gateway.env` is only written once during `openclaw onboard --install-daemon`
   - Recommendation: Plan 04-02 must include a `grep BEADS_DIR ~/.openclaw/service-env/ai.openclaw.gateway.env` check after restart. If not present, the plan must include a direct edit of `gateway.env` as fallback.

---

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Node.js 24 (Homebrew) | bd install target | ✓ | 24.15.0 at `/opt/homebrew/opt/node@24/bin/node` | — |
| npm (Homebrew node@24) | `npm install -g @beads/bd` | ✓ | 11.12.1 | — |
| dolt | Beads embedded backend | ✗ | — (not installed) | Must install via `brew install dolt` in Plan 04-01 |
| bd 1.0.4 | Task graph CLI | ✗ (1.0.3 under nvm) | 1.0.3 at nvm path | Install 1.0.4 under Homebrew node@24 |
| `BEADS_DIR` env var | Agent db discovery | ✗ (not set) | — | Set in Phase 4 |
| `stow` | Deploy config changes | ✓ | Latest Homebrew | — |
| `jq` | JSON parsing in scripts | ✓ | Latest Homebrew | — |
| OpenClaw gateway | Agent runtime | ✓ | 2026.5.18 | — |

**Missing dependencies with no fallback:**
- `dolt` — blocks `bd init` entirely. Must be installed as first step of Plan 04-01.

**Missing dependencies with fallback:**
- bd 1.0.4 — 1.0.3 exists but under wrong Node version. Install 1.0.4 under Homebrew node@24.

---

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | zsh smoke test scripts (project pattern — no jest/vitest/pytest) |
| Config file | none — scripts are self-contained |
| Quick run command | `zsh scripts/verify-phase-04.sh` |
| Full suite command | `zsh scripts/verify-phase-04.sh` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| INFRA-05 | bd 1.0.4 + dolt installed, BEADS_DIR initialized | smoke | `zsh scripts/verify-phase-04.sh` | ❌ Wave 0 |
| ORCH-03 | Task Orchestrator creates epic before spawning | smoke | `BEADS_DIR=... bd ready --json` returns structured task list | ❌ Wave 0 (manual verification required for SOUL.md rule) |
| ORCH-04 | Sub-agent claim/close cycle end-to-end | integration | `BEADS_DIR=... bd update <id> --claim && bd close <id> --reason "..."` | ❌ Wave 0 |

### Wave 0 Gaps

- [ ] `scripts/verify-phase-04.sh` — 6-check smoke test covering INFRA-05 + ORCH-03 + ORCH-04
- [ ] dolt install: `brew install dolt`
- [ ] bd install: `/opt/homebrew/opt/node@24/bin/npm install -g @beads/bd`
- [ ] BEADS_DIR init: `BEADS_DIR=... bd init --stealth --prefix tskorch --non-interactive`

---

## Security Domain

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | No | — |
| V3 Session Management | No | — |
| V4 Access Control | No | — |
| V5 Input Validation | Yes (close reasons) | SOUL.md rule: reason strings must be factual, not empty; bd enforces non-empty `--reason` |
| V6 Cryptography | No | — |

### Known Threat Patterns

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Agent skips task decomposition | Spoofing (fake "done") | SOUL.md mandatory rule + `bd dep tree` verification before spawn |
| BEADS_DIR pointing to wrong database | Tampering | `bd context` verification step in Plan 04-02 |
| bd invoked from wrong Node version | Tampering (silent old version) | Explicit `/opt/homebrew/opt/node@24/bin/bd` path in all scripts |

---

## Sources

### Primary (HIGH confidence)

- Live `bd` CLI tests (this session, 2026-05-21) — `bd init --stealth`, `bd create`, `bd update --claim`, `bd close --reason`, `bd dep add`, `bd ready`, `bd list --status in_progress --json`, `bd context`, `bd dep tree` — all commands verified in live test environment with bd 1.0.3 (same API as 1.0.4)
- `docs/human/Trilogy AI Center of Excellence - Why Your AI Agents Skip Steps - and How Task Graphs Prevent It.md` — complete setup runbook, patterns, decomposition templates [CITED: local docs/human/]
- `CLAUDE.md` §Technology Stack — Beads version, install command, dolt requirement, `bd init --stealth` mandate [CITED: ./CLAUDE.md]
- `~/.openclaw/service-env/ai.openclaw.gateway-env-wrapper.sh` — confirms env injection mechanism [CITED: local file]
- `~/.openclaw/service-env/ai.openclaw.gateway.env` — confirms Telegram token propagation pattern [CITED: local file]
- `~/Library/LaunchAgents/ai.openclaw.gateway.plist` — confirms ProgramArguments env-wrapper chain [CITED: local file]
- `/Users/trilogy/.nvm/versions/node/v22.18.0/lib/node_modules/@beads/bd/README.md` — `BEADS_DIR` documentation, `--stealth` semantics [CITED: installed package README]

### Secondary (MEDIUM confidence)

- `npm view @beads/bd version` → `1.0.4` (2026-05-09) [VERIFIED: npm registry]
- `npm view @beads/bd repository.url` → `git+https://github.com/gastownhall/beads.git` [VERIFIED: npm registry]
- `brew info dolt` → version 2.0.4, Apache-2.0, available [VERIFIED: Homebrew]
- GitHub gastownhall/beads README (via WebFetch) — confirms `BEADS_DIR` + `--stealth` semantics [CITED: github.com/gastownhall/beads]

### Tertiary (LOW confidence)

- None — all claims verified via PRIMARY or SECONDARY sources.

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — packages confirmed on registries; bd CLI verified by live tests
- Architecture: HIGH — env injection chain traced through actual files; BEADS_DIR behavior confirmed by live test
- Pitfalls: HIGH — most derived from direct observation (nvm PATH shadowing confirmed, BEADS_DIR location confirmed, `bd ready` vs `bd list` difference verified)
- SOUL.md template: HIGH — based on Trilogy CoE runbook + CLAUDE.md + live CLI verification

**Research date:** 2026-05-21
**Valid until:** 2026-06-21 (stable ecosystem; bd 1.0.x is current stable series)

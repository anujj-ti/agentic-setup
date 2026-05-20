---
phase: 03-user-orchestrator
plan: "03"
subsystem: task-orchestrator
tags: [openclaw, agent-scaffold, task-orchestrator, beads-free]
dependency_graph:
  requires: [user-orchestrator-agent]
  provides: [task-orchestrator-agent, both-agents-live]
  affects: [openclaw.json, agents.list]
tech_stack:
  added: []
  patterns: [stow-deploy, openclaw-agent-scaffold, directive-files]
key_files:
  created:
    - .openclaw/agents/task-orchestrator/SOUL.md
    - .openclaw/agents/task-orchestrator/IDENTITY.md
    - .openclaw/agents/task-orchestrator/USER.md
    - .openclaw/agents/task-orchestrator/AGENTS.md
    - .openclaw/agents/task-orchestrator/TOOLS.md
    - .openclaw/agents/task-orchestrator/SECURITY.md
  modified:
    - .openclaw/openclaw.json
decisions:
  - "D-32: task-orchestrator uses anthropic/claude-sonnet-4-6 (Phase 4 Beads requires Sonnet-level reasoning)"
  - "D-34: No Telegram binding for task-orchestrator — receives work only via sessions_spawn"
  - "D-36: SOUL.md is Beads-free — explicit Phase 3 scope, no bd/beads commands"
  - "No sessions_spawn in tools.alsoAllow — task-orchestrator is not a spawner in Phase 3"
metrics:
  duration: "~5 minutes"
  completed: "2026-05-21"
  tasks_completed: 3
  tasks_total: 3
  files_created: 6
  files_modified: 1
---

# Phase 3 Plan 03: Task Orchestrator Scaffold Summary

**One-liner:** Task Orchestrator scaffolded as Beads-free Phase 3 stub — 6 directive files, registered in agents.list with no Telegram binding, delegation routing from User Orchestrator now resolves against a live agent entry.

## What Was Built

1. **Runtime workspace directories** created at:
   - `~/.openclaw/agents/task-orchestrator/{memory,memory/archives,sessions,scripts,scripts/lib,qmd,drafts,refs}`
   - `~/.openclaw/workspace-task-orchestrator/`

2. **Six directive files** written to `.openclaw/agents/task-orchestrator/`:
   - `SOUL.md` — Phase 3 stub: structured/factual tone, status-first (STARTED/IN_PROGRESS/COMPLETED/BLOCKED), no Beads, no sessions_spawn
   - `IDENTITY.md` — name, role, emoji (⚙️), model (anthropic/claude-sonnet-4-6), agentId
   - `USER.md` — Anuj's profile (indirect — via User Orchestrator); factual parseable format
   - `AGENTS.md` — session startup: read task → state plan → execute → report; workspace hygiene
   - `TOOLS.md` — exec/read/write/gh tools; explicit Phase 3 exclusions (no sessions_spawn, no beads)
   - `SECURITY.md` — no-secrets rule, autonomous action gate (state before executing), isolation rules

3. **openclaw.json updated**:
   - `agents.list` now has 2 entries: `user-orchestrator` and `task-orchestrator`
   - `task-orchestrator` entry: `workspace`, `agentDir`, `model.primary`, `subagents.delegationMode: "prefer"`
   - No `bindings` entry for task-orchestrator (D-34 — backend agent only)
   - No `tools.alsoAllow` for task-orchestrator (not a spawner in Phase 3)

4. **Stow-deployed** via `scripts/stow-deploy.sh` — both agent symlinks verified

5. **Gateway restarted** — health check returns 200

## Verification Results

```
Gateway health: 200 OK
~/.openclaw/agents/task-orchestrator/SOUL.md -> ../../../Documents/agentic-setup/.openclaw/agents/task-orchestrator/SOUL.md
~/.openclaw/agents/user-orchestrator/SOUL.md -> ../../../Documents/agentic-setup/.openclaw/agents/user-orchestrator/SOUL.md
agents.list count: 2 entries (user-orchestrator + task-orchestrator)
bindings: 1 entry (user-orchestrator only — no task-orchestrator binding)
```

## Deviations from Plan

None — plan executed exactly as written. SOUL.md content follows D-36 (Beads-free) and D-36 Phase 3 stub constraints.

## Self-Check

- [x] All 6 directive files exist under `.openclaw/agents/task-orchestrator/`
- [x] `openclaw.json` agents.list has exactly 2 entries
- [x] No task-orchestrator binding in `bindings` array
- [x] Both stow symlinks confirmed (task-orch and user-orch)
- [x] Gateway returns 200
- [x] Commit `ac00d0e` exists

## Self-Check: PASSED

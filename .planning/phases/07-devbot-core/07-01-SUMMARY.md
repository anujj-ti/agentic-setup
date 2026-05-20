---
phase: 07-devbot-core
plan: "01"
subsystem: devbot-agent-scaffold
tags: [devbot, openclaw, github-ops, agent-scaffold]
dependency_graph:
  requires: []
  provides: [devbot-agent, devbot-directive-files, task-orchestrator-routing]
  affects: [task-orchestrator, openclaw.json]
tech_stack:
  added: []
  patterns: [openclaw-agent-scaffold, stow-deploy, cc-openclaw-directive-files]
key_files:
  created:
    - .openclaw/agents/devbot/SOUL.md
    - .openclaw/agents/devbot/IDENTITY.md
    - .openclaw/agents/devbot/USER.md
    - .openclaw/agents/devbot/AGENTS.md
    - .openclaw/agents/devbot/TOOLS.md
    - .openclaw/agents/devbot/SECURITY.md
  modified:
    - .openclaw/openclaw.json
    - .openclaw/agents/task-orchestrator/SOUL.md
decisions:
  - "D-70: gh upgraded from 2.69.0 to 2.92.0 via brew upgrade gh"
  - "D-71: gh auth refresh -s project deferred — requires browser; user must run manually on return"
  - "D-74: task-orchestrator openclaw.json updated with allowAgents: [devbot] and sessions_spawn"
  - "D-75: DevBot has no Telegram binding — receives work only via sessions_spawn"
metrics:
  duration: "~15 minutes"
  completed: "2026-05-21"
  tasks_completed: 2
  files_count: 8
---

# Phase 7 Plan 01: DevBot Agent Scaffold Summary

**One-liner:** DevBot registered as OpenClaw sub-agent with 6 directive files, task-orchestrator wired with allowAgents: ["devbot"], gh upgraded to 2.92.0.

## What Was Built

DevBot is now registered as an execution-tier sub-agent in the OpenClaw fleet:

- **6 directive files** at `.openclaw/agents/devbot/`: SOUL, IDENTITY, USER, AGENTS, TOOLS, SECURITY
- **openclaw.json** updated: devbot agent entry added; task-orchestrator updated with `allowAgents: ["devbot"]` and `sessions_spawn` tool
- **Task Orchestrator SOUL.md** updated with Sub-Agent Routing section (GitHub ops → DevBot)
- **Workspace directories** created: `~/.openclaw/workspace-devbot/repos/`, `~/.openclaw/agents/devbot/scripts/lib/`, `~/.openclaw/agents/devbot/memory/archives/`
- **gh CLI** upgraded from 2.69.0 to 2.92.0 per D-70
- **stow-deploy.sh** ran successfully; symlinks live at `~/.openclaw/agents/devbot/`

## Deviations from Plan

### Auth Gate (D-71) — gh auth refresh -s project

**Status:** Deferred (expected per plan design)
**Found during:** Task 1
**Issue:** `gh auth refresh -s project` requires browser interaction — cannot be automated while user is AFK.
**Current state:** `gh auth status` shows token scopes: 'gist', 'read:org', 'repo', 'workflow' — project scope NOT present.
**Impact:** `gh issue create --project` will create the issue successfully but will NOT add it to the project board. The `gh project item-add` retroactive approach (in devbot-issue-create.sh) is the fallback.
**User action required on return:** Run `/opt/homebrew/bin/gh auth refresh -s project` in terminal, complete browser auth flow, verify with `/opt/homebrew/bin/gh auth status 2>&1 | grep project`.

### CWD Drift (#3097) — Commit went to main initially

**Status:** Auto-fixed
**Found during:** Plan 07-01 commit
**Issue:** `cd /Users/trilogy/Documents/agentic-setup && git commit` committed to the main branch instead of the worktree branch.
**Fix:** Identified that all git operations must use `git -C /Users/trilogy/Documents/agentic-setup/.claude/worktrees/agent-a0c31b940500215e7`. Files written to main repo path (correct for stow), committed from worktree path.
**Commit on worktree branch:** 53bb848 (correct)
**Accidental commit on main:** b16211d (content is correct but on wrong branch — will reconcile at merge)

## Commits

| Task | Commit | Description |
|------|--------|-------------|
| Task 2 (worktree) | 53bb848 | feat(07-01): scaffold DevBot agent + wire task-orchestrator allowAgents |

## Known Stubs

None — all directive files contain substantive content.

## Threat Flags

None — no new network endpoints or auth paths introduced beyond gh CLI (already present).

## Self-Check: PASSED

- `.openclaw/agents/devbot/SOUL.md` exists: FOUND
- `.openclaw/agents/devbot/IDENTITY.md` exists: FOUND
- `.openclaw/agents/devbot/USER.md` exists: FOUND
- `.openclaw/agents/devbot/AGENTS.md` exists: FOUND
- `.openclaw/agents/devbot/TOOLS.md` exists: FOUND
- `.openclaw/agents/devbot/SECURITY.md` exists: FOUND
- `openclaw.json` has devbot entry: FOUND
- `openclaw.json` has allowAgents: FOUND
- `openclaw.json` has sessions_spawn: FOUND
- Task Orchestrator SOUL.md has DevBot routing: FOUND
- gh version 2.92.0: FOUND
- Stow deploy: SUCCESS

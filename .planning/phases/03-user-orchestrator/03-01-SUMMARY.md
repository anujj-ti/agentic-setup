---
phase: 03-user-orchestrator
plan: "01"
subsystem: user-orchestrator
tags: [openclaw, agent-scaffold, telegram, user-orchestrator]
dependency_graph:
  requires: []
  provides: [user-orchestrator-agent, telegram-binding-updated]
  affects: [openclaw.json, bindings, telegram-routing]
tech_stack:
  added: []
  patterns: [stow-deploy, openclaw-agent-scaffold, directive-files]
key_files:
  created:
    - .openclaw/agents/user-orchestrator/SOUL.md
    - .openclaw/agents/user-orchestrator/IDENTITY.md
    - .openclaw/agents/user-orchestrator/USER.md
    - .openclaw/agents/user-orchestrator/AGENTS.md
    - .openclaw/agents/user-orchestrator/TOOLS.md
    - .openclaw/agents/user-orchestrator/SECURITY.md
  modified:
    - .openclaw/openclaw.json
decisions:
  - "D-30: Replicated /openclaw-new-agent steps directly (user AFK — no interactive invocation)"
  - "D-33: subagents.allowAgents: [task-orchestrator] + delegationMode: prefer (sessions_spawn gate)"
  - "D-35: Telegram binding replaced agentId main -> user-orchestrator"
  - "D-37: sessions_spawn + sessions_yield in tools.alsoAllow (coding profile gate)"
  - "D-38: Literal /Users/trilogy paths in agents.list (tilde expansion not guaranteed)"
metrics:
  duration: "~5 minutes"
  completed: "2026-05-21"
  tasks_completed: 3
  tasks_total: 3
  files_created: 6
  files_modified: 1
---

# Phase 3 Plan 01: User Orchestrator Scaffold Summary

**One-liner:** User Orchestrator scaffolded as named OpenClaw agent with Telegram binding, delegation config (sessions_spawn to task-orchestrator), and 6 directive files stow-deployed and gateway-restarted.

## What Was Built

1. **Runtime workspace directories** created at:
   - `~/.openclaw/agents/user-orchestrator/{memory,memory/archives,sessions,scripts,scripts/lib,qmd,drafts,refs}`
   - `~/.openclaw/workspace-user-orchestrator/`

2. **Six directive files** written to `.openclaw/agents/user-orchestrator/`:
   - `SOUL.md` — User Orchestrator persona: conversational, delegation-first, IST timezone, direct tone
   - `IDENTITY.md` — name, role, emoji (🎯), model (anthropic/claude-sonnet-4-6), agentId
   - `USER.md` — Anuj's profile: Telegram ID 1294664427, IST preference, short-response preference
   - `AGENTS.md` — session startup checklist, workspace hygiene, safety rules
   - `TOOLS.md` — sessions_spawn/sessions_yield policy, explicit binary paths
   - `SECURITY.md` — no-secrets-in-directives rule, cross-agent isolation, injection mitigation

3. **openclaw.json updated**:
   - `agents.list` populated with user-orchestrator entry including `subagents.allowAgents: ["task-orchestrator"]`, `delegationMode: "prefer"`, `tools.alsoAllow: ["sessions_spawn", "sessions_yield"]`
   - `bindings` entry updated: `agentId: "main"` replaced with `agentId: "user-orchestrator"`

4. **Stow-deployed** via `scripts/stow-deploy.sh` — symlinks verified at `~/.openclaw/agents/user-orchestrator/SOUL.md`

5. **Gateway restarted** via `launchctl kickstart -k gui/$(id -u)/ai.openclaw.gateway` — health check confirmed: `{"ok":true,"status":"live"}`

## Verification Results

```
Gateway health: {"ok":true,"status":"live"}
Symlink check: /Users/trilogy/.openclaw/agents/user-orchestrator/SOUL.md -> ../../../Documents/agentic-setup/.openclaw/agents/user-orchestrator/SOUL.md
openclaw.json "user-orchestrator" count: 2 occurrences
bindings agentId: "user-orchestrator" confirmed
```

## Deviations from Plan

None — plan executed exactly as written.

## Threat Surface Scan

No new network endpoints or auth paths introduced beyond what was planned. The Telegram channel binding update was an in-scope change. SECURITY.md mitigates T-03-01 (spoofing via dmPolicy pairing), T-03-02 (injection via SECURITY.md rules), T-03-03 (secrets in directives explicitly forbidden).

## Self-Check

- [x] All 6 directive files exist under `.openclaw/agents/user-orchestrator/`
- [x] `openclaw.json` has `user-orchestrator` in `agents.list`
- [x] Telegram binding updated to `user-orchestrator`
- [x] Runtime dirs exist at `~/.openclaw/`
- [x] Gateway returns 200 health
- [x] Stow symlink confirmed
- [x] Commit `4affbb9` exists

## Self-Check: PASSED

---
phase: 19-devbot-autonomous-issue-pickup-devbot-polls-for-automation-s
plan: "04"
subsystem: devbot
tags: [cron, devbot, autonomous-pickup, jobs.json, soul.md, agents.md]
dependency_graph:
  requires: [19-01, 19-02, 19-03]
  provides: [devbot-cron-activation, devbot-autonomous-pickup-documentation]
  affects: [.openclaw/cron/jobs.json, .openclaw/agents/devbot/SOUL.md, .openclaw/agents/devbot/AGENTS.md]
tech_stack:
  added: []
  patterns: [openclaw-cron-silent-delivery, isolated-session-cron, devbot-agent-turn]
key_files:
  created: []
  modified:
    - .openclaw/cron/jobs.json
    - .openclaw/agents/devbot/SOUL.md
    - .openclaw/agents/devbot/AGENTS.md
decisions:
  - "devbot-issue-monitor cron uses 120s timeout (vs CI Monitor's 90s) — issue monitor may write state files"
  - "devbot-stale-claim-guard uses 60s timeout — lightweight read+unclaim operation"
  - "Both new cron jobs use sessionTarget: isolated to prevent state leakage between runs"
metrics:
  duration: "~10 minutes"
  completed: "2026-05-22"
  tasks_completed: 2
  tasks_total: 2
---

# Phase 19 Plan 04: Cron Activation and Documentation Summary

**One-liner:** Registered devbot-issue-monitor (5min) and devbot-stale-claim-guard (60min) cron jobs in jobs.json with silent delivery, and documented the autonomous issue pickup loop in DevBot's SOUL.md and AGENTS.md.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Add two cron jobs to jobs.json | 5151437 | .openclaw/cron/jobs.json |
| 2 | Update DevBot SOUL.md and AGENTS.md | 5cc0e91 | .openclaw/agents/devbot/SOUL.md, .openclaw/agents/devbot/AGENTS.md |

## What Was Built

### Task 1: Two New Cron Jobs in jobs.json

`jobs.json` now has 6 total entries (4 existing + 2 new):

**DevBot Issue Monitor** (id: `4dd05b3e-5a42-47a2-ab5c-48626ad7a7a6`):
- `agentId: devbot`, `expr: */5 * * * *` (every 5 minutes), `tz: Asia/Kolkata`
- `sessionTarget: isolated`, `wakeMode: now`
- `delivery.mode: silent` — no Telegram noise on each poll
- `timeoutSeconds: 120` — adequate for state file writes
- Message instructs devbot to run `scripts/devbot-issue-monitor.sh anujj-ti/agentic-setup`

**DevBot Stale Claim Guard** (id: `0bccbd8c-9c0f-4bb1-a747-a4bc0dc5ed78`):
- `agentId: devbot`, `expr: 0 * * * *` (top of every hour), `tz: Asia/Kolkata`
- `sessionTarget: isolated`, `wakeMode: now`
- `delivery.mode: silent`
- `timeoutSeconds: 60` — lightweight unclaim operation
- Message instructs devbot to run `scripts/devbot-stale-claim-guard.sh anujj-ti/agentic-setup`

stow-deploy.sh was run and the OpenClaw gateway was restarted via `launchctl kickstart -k` to activate the new cron schedule.

### Task 2: SOUL.md and AGENTS.md Documentation

**SOUL.md** — New section `## Autonomous Issue Pickup (DEV-07, DEV-08, DEV-09)` appended after the existing "Autonomous Development Workflow" section. Contains:
- 9-step loop overview (poll → filter → dedup → Notion pre-log → claim → branch → draft PR → auto-merge → stale guard)
- CRITICAL RULES: automation:hold kill switch, Notion pre-log mandate, @none filter, Resolves #N requirement
- State files table (pickup-queue.txt, last-issue-timestamp, pending-issues/, logs/)
- Label state machine table (automation:safe, automation:hold, status:in-progress, e1/e2/e3, agent:echosysbot)

**AGENTS.md** — Added startup step 6 to the Session Startup checklist:
- Checks for `state/pickup-queue.txt` presence and content
- If non-empty: processes each queued issue via devbot-execute-cycle.sh
- Clears queue after processing

## Deviations from Plan

None - plan executed exactly as written.

## Known Stubs

None. This plan is entirely configuration and documentation — no data-producing code paths.

## Threat Surface Scan

No new security-relevant surface introduced. The cron payload messages are plain text instructions; no secrets are embedded. Both entries were covered in the plan's threat model (T-19-11, T-19-12).

## Self-Check: PASSED

- `.openclaw/cron/jobs.json` — 6 entries, both new jobs verified with correct agentId/expr/delivery
- `.openclaw/agents/devbot/SOUL.md` — "Autonomous Issue Pickup" section present (grep count: 1)
- `.openclaw/agents/devbot/AGENTS.md` — "pickup-queue" reference present (grep count: 3)
- Commit `5151437` — jobs.json update (verified via git log)
- Commit `5cc0e91` — SOUL.md + AGENTS.md update (verified via git log)

---
phase: 06-email-morning-standup
plan: "05"
subsystem: standup-cron
tags: [standup, cron, jobs-json, verification]
dependency_graph:
  requires: [06-01, 06-03, 06-04]
  provides: [morning-standup-cron, phase-verification-script]
  affects: [.openclaw/cron/jobs.json, scripts/verify-phase-06.sh]
tech_stack:
  added: []
  patterns: [openclaw-cron, announce-delivery, stow-deploy, smoke-testing]
key_files:
  modified:
    - .openclaw/cron/jobs.json
  created:
    - scripts/verify-phase-06.sh
decisions:
  - "Used anujj-ti/agentic-setup as initial tracked repo (repo list resolved at plan execution time per T-06-17)"
  - "Cron payload message specifies repos statically for security (T-06-17: no dynamic repo discovery at runtime)"
  - "stow-deploy.sh + launchctl kickstart executed — gateway running with new cron job"
metrics:
  duration: "~6 minutes"
  completed: "2026-05-21"
  tasks: 2
  files: 2
---

# Phase 06 Plan 05: Morning Standup Cron + Phase Verification Summary

Morning standup cron job registered in jobs.json at 08:00 Asia/Kolkata, stow deployed and gateway restarted. verify-phase-06.sh passes all 8 structural CHAN-03 and CHAN-04 checks.

## Tasks Completed

| Task | Description | Status |
|------|-------------|--------|
| 1 | Add morning standup cron entry + stow deploy + gateway restart | DONE |
| 2 | Write + run verify-phase-06.sh (8 checks) | DONE |

## Artifacts Created/Modified

### .openclaw/cron/jobs.json — 3 jobs total

Job added: `4d870e78-12ad-40e3-9711-8e2c37e0600c`
- **name**: Morning Standup Brief
- **agentId**: user-orchestrator
- **schedule**: `0 8 * * *` (Asia/Kolkata — 08:00 IST)
- **sessionTarget**: isolated
- **wakeMode**: now
- **payload**: `kind: agentTurn`, model: claude-sonnet-4-6, timeoutSeconds: 180
- **delivery**: announce / channel: last
- **repos tracked**: anujj-ti/agentic-setup

### scripts/verify-phase-06.sh

8 smoke checks covering CHAN-03 and CHAN-04:
1. email-triage in openclaw.json
2. All 6 directive files exist
3. gmail-triage.js with setCredentials
4. googleapis installed in agent scripts/
5. Gmail Keychain exports in openclaw-secrets.sh
6. OAuth2 re-auth runbook in email-triage TOOLS.md
7. Morning Standup cron in jobs.json with Asia/Kolkata tz
8. standup-brief.sh executable + syntax-valid

## verify-phase-06.sh Output

```
=== Phase 06 Smoke Checks ===
Repo dir: /Users/trilogy/Documents/agentic-setup/.claude/worktrees/agent-adb3b0cb76efbcdd2

PASS [CHAN-03] email-triage in openclaw.json
PASS [CHAN-03] all 6 directive files exist (SOUL, IDENTITY, USER, AGENTS, TOOLS, SECURITY)
PASS [CHAN-03] gmail-triage.js exists with setCredentials
PASS [CHAN-03] googleapis installed in agent scripts/
PASS [CHAN-03] Gmail Keychain exports in openclaw-secrets.sh
PASS [CHAN-03] OAuth2 re-auth runbook in email-triage TOOLS.md
PASS [CHAN-04] Morning Standup Brief cron job with Asia/Kolkata tz
PASS [CHAN-04] standup-brief.sh executable and syntax-valid

=== Phase 06 Smoke Check Summary ===
CHAN-03 (Email Triage): structural checks above
CHAN-04 (Morning Standup): structural checks above

NOTE: The following success criteria require HUMAN ACTION before they can be verified:
  - SC#1: Gmail OAuth2 refresh token in Keychain (run oauth2-setup.js on return — see 06-02-PLAN.md)
  - SC#3: Standup cron fires on schedule (verify after 08:00 IST next morning)
  - SC#4: OAuth2 re-auth runbook verified working (test with oauth2-setup.js)

These are marked PENDING in the phase SUMMARY.

ALL STRUCTURAL CHECKS PASSED
```

## Phase 06 Success Criteria Status

### FULLY AUTOMATED — PASS

| Check | Status | Plan |
|-------|--------|------|
| email-triage agent scaffolded (6 directive files) | PASS | 06-01 |
| googleapis@172.0.0 installed in agent scripts/ | PASS | 06-01 |
| gmail-triage.js with OAuth2 headless refresh | PASS | 06-01 |
| Three Gmail Keychain exports in secrets pipeline | PASS | 06-01 |
| oauth2-setup.js created with correct flow elements | PASS | 06-02 |
| OAuth2 re-auth runbook in email-triage TOOLS.md | PASS | 06-03 |
| standup-brief.sh executable + syntax valid | PASS | 06-04 |
| exec in user-orchestrator tools.alsoAllow | PASS | 06-04 |
| Morning Standup Brief cron at 08:00 Asia/Kolkata | PASS | 06-05 |
| Gateway running with new cron job | PASS | 06-05 |

### PENDING — requires human action after return from AFK

| Success Criterion | Status | Instructions |
|------------------|--------|-------------|
| CHAN-03 SC#1: Gmail reads email from echo.sys.bot@gmail.com | PENDING | Run oauth2-setup.js — see 06-02-SUMMARY.md for full steps |
| CHAN-04 SC#2: Standup brief received in Telegram at 08:00 IST | PENDING | Verify after 08:00 IST next morning |
| CHAN-04 SC#3: Standup cron visible in /openclaw-status | PENDING | Verify with gateway running after return |

## Deviations from Plan

None — plan executed exactly as written.

## Threat Surface Scan

No new threat surface beyond what was registered in the threat model. T-06-17 mitigation applied: repo list resolved statically at plan execution time (not dynamically at each cron run), preventing any injection of attacker-controlled repo names into the cron payload.

## Self-Check: PASSED

jobs.json validated. verify-phase-06.sh exists, executable, syntax valid. All 8 smoke checks pass. Gateway running (pid 97734).

---
phase: 14-gogcli-google-suite-cli-install-gogcli-wire-gog-gmail-and-go
plan: "04"
subsystem: email-triage-agent
tags: [gogcli, agent-docs, tools-md, agents-md]
dependency_graph:
  requires: ["14-02", "14-03"]
  provides: ["updated TOOLS.md primary invocation", "updated AGENTS.md startup checklist"]
  affects: [".openclaw/agents/email-triage"]
tech_stack:
  added: []
  patterns: ["TOOLS.md exec policy update", "Re-Auth Runbook pattern"]
key_files:
  created: []
  modified: [".openclaw/agents/email-triage/TOOLS.md", ".openclaw/agents/email-triage/AGENTS.md"]
decisions:
  - "D-148: gmail-triage.js references kept but marked superseded — not deleted"
  - "gogcli Re-Auth Runbook added before legacy OAuth2 runbook"
  - "Legacy OAuth2 runbook marked Superseded with deprecation notice"
metrics:
  duration: "~10 minutes"
  completed: "2026-05-21"
  tasks_completed: 2
  files_changed: 2
---

# Phase 14 Plan 04: email-triage Agent TOOLS.md and AGENTS.md Update Summary

Updated email-triage agent documentation: TOOLS.md now directs agent to call email-triage.sh via gogcli with a full command reference table and re-auth runbook; AGENTS.md startup checklist updated to check email-triage.sh as primary path.

## Tasks Completed

| Task | Description | Commit | Status |
|------|-------------|--------|--------|
| 1 | Update TOOLS.md with gog gmail primary invocation and Re-Auth Runbook | c7a4f3d | Done |
| 2 | Update AGENTS.md to reference email-triage.sh | c7a4f3d | Done |

## Verification Results

- `grep -c 'email-triage.sh' .openclaw/agents/email-triage/TOOLS.md` returns 5
- `grep -c 'gogcli Re-Auth' .openclaw/agents/email-triage/TOOLS.md` returns 1
- `grep -c 'Superseded' .openclaw/agents/email-triage/TOOLS.md` returns 1
- `grep -c 'email-triage.sh' .openclaw/agents/email-triage/AGENTS.md` returns 8
- `gmail-triage.js` still exists at `~/.openclaw/agents/email-triage/scripts/gmail-triage.js`

## Deviations from Plan

None - plan executed exactly as written.

## Self-Check: PASSED

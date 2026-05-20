---
phase: 06-email-morning-standup
plan: "03"
subsystem: email-triage
tags: [email, gmail, oauth2, runbook, documentation]
dependency_graph:
  requires: [06-01]
  provides: [oauth2-reauth-runbook]
  affects: [.openclaw/agents/email-triage/TOOLS.md]
tech_stack:
  added: []
  patterns: [runbook-documentation, keychain-reference]
key_files:
  modified:
    - .openclaw/agents/email-triage/TOOLS.md
decisions:
  - "Replaced TOOLS.md stub from Plan 06-01 with full 6-section OAuth2 re-auth runbook"
  - "All three Keychain key names from D-63 included in Keychain Key Reference table"
  - "exec policy explicitly limits scope to gmail-triage.js only"
metrics:
  duration: "~4 minutes"
  completed: "2026-05-21"
  tasks: 1
  files: 1
---

# Phase 06 Plan 03: Email Triage TOOLS.md OAuth2 Re-Auth Runbook Summary

Complete OAuth2 re-auth runbook written into email-triage TOOLS.md, satisfying ROADMAP Phase 6 Success Criteria #4. Covers initial GCP setup, Keychain credential storage, browser authorization, token verification, and expiry notes.

## Task Completed

| Task | Description | Status |
|------|-------------|--------|
| 1 | Write complete TOOLS.md with OAuth2 re-auth runbook (6 sections) | DONE |

## TOOLS.md Content (final structure)

- **Available Tools**: exec (gmail-triage.js only) + read/write (memory/ only)
- **Tool Policy**: exec is granted only for Gmail script execution; explicit Node.js path; no file ops via exec
- **Environment**: agentDir, scripts dir, Node path, gateway URL
- **Gmail Script Invocation**: exact exec command + pre-call refresh token check
- **OAuth2 Re-Auth Runbook** (6 sub-sections):
  - A: Prerequisites (GCP setup — one-time)
  - B: Store credentials in Keychain (`security add-generic-password -U`)
  - C: Run oauth2-setup.js (with source openclaw-env.sh)
  - D: Verify token + restart gateway (`stow-deploy.sh + launchctl kickstart`)
  - E: Verify agent can reach Gmail (test gmail-triage.js directly)
  - F: Token expiry notes (when to re-run, how to handle revocation)
- **Keychain Key Reference** table: all 3 keys from D-63

## Verification Results

```
PASS: TOOLS.md contains all required runbook elements
  - Re-Auth Runbook section header
  - oauth2-setup.js reference
  - gmail-client-id Keychain key
  - gmail-client-secret Keychain key
  - gmail-triage-refresh-token Keychain key
  - gmail-triage.js production script reference
  - exec is granted only policy statement
  - TOKEN PRESENT verify step
  - Desktop app GCP credential type
```

## ROADMAP SC#4 Satisfied

ROADMAP Phase 6 Success Criteria #4: "Email Triage agent OAuth2 re-auth runbook is documented in the agent's TOOLS.md." — **SATISFIED** by this plan.

## Deviations from Plan

None — plan executed exactly as written. The stub TOOLS.md from Plan 06-01 was replaced with the full runbook document.

## Threat Surface Scan

No new threat surface introduced. TOOLS.md is a documentation file loaded into agent context. T-06-08 (exec policy in TOOLS.md) and T-06-09 (placeholder credentials in runbook) both mitigated as planned — commands use `YOUR_CLIENT_ID_HERE` placeholder, never actual credentials.

## Self-Check: PASSED

TOOLS.md verified to exist and pass all 9 automated content checks.

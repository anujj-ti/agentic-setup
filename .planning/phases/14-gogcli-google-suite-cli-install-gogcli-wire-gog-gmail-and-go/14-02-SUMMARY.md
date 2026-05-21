---
phase: 14-gogcli-google-suite-cli-install-gogcli-wire-gog-gmail-and-go
plan: "02"
subsystem: email-triage
tags: [gogcli, gmail, shell-script, email-triage]
dependency_graph:
  requires: ["14-01"]
  provides: ["scripts/email-triage.sh", "OPENCLAW_GMAIL_ACCOUNT env var"]
  affects: [".openclaw/agents/email-triage"]
tech_stack:
  added: ["gogcli (gog binary)", "zsh shell script Gmail triage"]
  patterns: ["json-response.sh envelope", "explicit binary paths", "auth guard with json_fail"]
key_files:
  created: ["scripts/email-triage.sh"]
  modified: [".openclaw/scripts/openclaw-env.sh"]
decisions:
  - "D-141: auth failure exits 1 with gog-auth-failed JSON (json_fail, not exit 0)"
  - "D-142: all gog calls include --no-input --non-interactive"
  - "D-143: GOG=/opt/homebrew/bin/gog explicit path"
  - "D-146: --json returns {results:[]} envelope, extract with jq '.results // []'"
  - "D-147: OPENCLAW_GMAIL_ACCOUNT is plain config (not a secret), added to openclaw-env.sh only"
  - "D-148: gmail-triage.js kept untouched as fallback"
metrics:
  duration: "~10 minutes"
  completed: "2026-05-21"
  tasks_completed: 2
  files_changed: 2
---

# Phase 14 Plan 02: email-triage.sh via gogcli Summary

Shell replacement for gmail-triage.js using gogcli: auth-guarded zsh script with explicit binary paths, JSON output envelope, and --no-input --non-interactive on all gog invocations.

## Tasks Completed

| Task | Description | Commit | Status |
|------|-------------|--------|--------|
| 1 | Add OPENCLAW_GMAIL_ACCOUNT to openclaw-env.sh | b607aab | Done |
| 2 | Create scripts/email-triage.sh | b607aab | Done |

## Verification Results

- `scripts/email-triage.sh` exists and is executable
- `scripts/email-triage.sh | jq '.ok'` returns `true` with `{"threads":[],"count":0}`
- `grep -c 'no-input' scripts/email-triage.sh` returns 1
- `grep -c 'non-interactive' scripts/email-triage.sh` returns 1
- `grep -c 'OPENCLAW_GMAIL_ACCOUNT' .openclaw/scripts/openclaw-env.sh` returns 1
- `gmail-triage.js` still exists at `~/.openclaw/agents/email-triage/scripts/gmail-triage.js`

## Deviations from Plan

None - plan executed exactly as written. The auth check (gog auth doctor) passed on first run since gog was already authenticated.

## Known Stubs

None — script fully functional. Auth guard triggers json_fail with actionable error if gog not authed.

## Self-Check: PASSED

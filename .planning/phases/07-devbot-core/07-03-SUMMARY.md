---
phase: 07-devbot-core
plan: "03"
subsystem: devbot-scripts
tags: [devbot, github-prs, shell-scripts, DEV-02, statusCheckRollup]
dependency_graph:
  requires: [07-02]
  provides: [devbot-pr-queue]
  affects: []
tech_stack:
  added: []
  patterns: [gh-pr-list-json, jq-null-guard, macos-bsd-date, iso8601-string-comparison]
key_files:
  created:
    - .openclaw/agents/devbot/scripts/devbot-pr-queue.sh
  modified:
    - .openclaw/agents/devbot/scripts/lib/json-response.sh
decisions:
  - "D-72: Single gh pr list call with --json statusCheckRollup — no N-calls-per-PR pattern"
  - "macOS BSD date used for cutoff: date -u -v\"-NHH\" (not GNU date)"
  - "ISO 8601 string comparison for staleness: updatedAt < cutoff (valid since both are RFC 3339 UTC with Z)"
  - "statusCheckRollup null-guard mandatory: repos with no GitHub Actions return null"
metrics:
  duration: "~15 minutes (includes bug investigation)"
  completed: "2026-05-21"
  tasks_completed: 1
  files_count: 2
---

# Phase 7 Plan 03: PR Queue Script Summary

**One-liner:** devbot-pr-queue.sh with single gh pr list call, statusCheckRollup null-guard, macOS BSD date staleness cutoff, returning categorized stale/failing PRs as JSON.

## What Was Built

### `scripts/devbot-pr-queue.sh`
- **Single gh call:** `gh pr list --json number,title,...,statusCheckRollup,url --limit 50` (per D-72 — no N-calls-per-PR)
- **Stale filter:** PRs with `reviewRequests.length > 0 OR reviewDecision == "CHANGES_REQUESTED"` AND `updatedAt < cutoff`
- **CI failure filter:** PRs where `statusCheckRollup != null AND statusCheckRollup has FAILURE entries`
- **Null-guard:** `statusCheckRollup != null` prevents jq errors on repos with no GitHub Actions
- **macOS BSD date:** `date -u -v"-${STALE_HOURS}H"` for cutoff computation
- **Output shape:** `{"ok":true,"data":{"stale_prs":[...],"failing_ci":[...],"repo":"...","stale_threshold_hours":N}}`
- Live test against `anujj-ti/agentic-setup`: returns `{ok:true}` with `stale_prs: 0, failing_ci: 0`

## Deviations from Plan

### Auto-fixed Bug: json_ok extra closing brace

**Rule 1 - Bug** — Extra `}` in json_ok output
**Found during:** Live test of devbot-pr-queue.sh
**Issue:** `local payload="${1:-{}}"` — In zsh, `}` in a parameter expansion default value closes the expansion early, then the second `}` is treated as a literal character appended after the variable value. This caused every json_ok call to output an extra `}`, producing invalid JSON.
**Fix:** Changed to `local default_payload='{}'` + `local payload="${1:-$default_payload}"` to avoid the brace-in-default issue.
**Files modified:** `.openclaw/agents/devbot/scripts/lib/json-response.sh`
**Commit:** 635dc13

## Commits

| Task | Commit | Description |
|------|--------|-------------|
| Task 1 + Bug fix | 635dc13 | feat(07-03): add devbot-pr-queue.sh + fix json_ok brace bug (DEV-02) |

## Known Stubs

None — script is complete and functional.

## Threat Flags

None — script is read-only (no write side effects to GitHub API).

## Self-Check: PASSED

- `devbot-pr-queue.sh` exists: FOUND
- Passes `zsh -n` syntax check: PASS
- Is executable: PASS
- `statusCheckRollup != null` null-guard present: FOUND
- `/opt/homebrew/bin/gh` explicit path: FOUND
- Single `gh pr list --json` call: FOUND (only 1 `gh pr list` command)
- Live test against `anujj-ti/agentic-setup`: PASS (`{ok:true}`)

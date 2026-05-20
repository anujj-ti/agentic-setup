---
phase: 07-devbot-core
plan: "02"
subsystem: devbot-scripts
tags: [devbot, github-issues, shell-scripts, DEV-01]
dependency_graph:
  requires: [07-01]
  provides: [devbot-issue-create, json-response-lib]
  affects: []
tech_stack:
  added: []
  patterns: [cc-openclaw-json-response, zsh-strict-mode, gh-array-args]
key_files:
  created:
    - .openclaw/agents/devbot/scripts/lib/json-response.sh
    - .openclaw/agents/devbot/scripts/devbot-issue-create.sh
  modified: []
decisions:
  - "D-76: json-response.sh convention — json_ok to stdout, json_err to both stdout and stderr"
  - "GH_ARGS zsh array used for arg building — prevents word-splitting on titles with special chars"
  - "Duplicate check uses gh issue list --search with --limit 5 to keep it fast"
metrics:
  duration: "~10 minutes"
  completed: "2026-05-21"
  tasks_completed: 2
  files_count: 2
---

# Phase 7 Plan 02: Issue Creation Script Summary

**One-liner:** devbot-issue-create.sh with mandatory duplicate check, json_ok/json_err output, and GH_ARGS array safety for DEV-01 issue creation.

## What Was Built

Two scripts implementing the DEV-01 issue creation capability:

### `scripts/lib/json-response.sh`
- `json_ok(payload)` → prints `{"ok":true,"data":<payload>}` to stdout
- `json_err(message)` → prints `{"ok":false,"error":"<message>"}` to both stdout and stderr, exits 1
- Safe to source (no side effects on load)
- Passes `zsh -n` syntax check

### `scripts/devbot-issue-create.sh`
- Arguments: `--repo OWNER/REPO --title "..." --body "..."` (required) + `--label --milestone --project --assignee` (optional)
- **Mandatory duplicate check:** `gh issue list --search "$TITLE" --repo "$REPO"` before every create; BLOCKED if open issue found with similar title
- **GH_ARGS array pattern:** Arguments built as zsh array (prevents word-splitting and shell injection on untrusted title/body input)
- **Binary path:** `/opt/homebrew/bin/gh` (never bare `gh`)
- **Output:** `{"ok":true,"data":{"issue_url":"...","issue_number":42,"repo":"OWNER/REPO"}}`
- Passes `zsh -n` syntax check, is executable

## Deviations from Plan

None — plan executed exactly as written.

## Commits

| Task | Commit | Description |
|------|--------|-------------|
| Tasks 1+2 | 82b1218 | feat(07-02): add devbot-issue-create.sh + json-response.sh lib (DEV-01) |

## Known Stubs

None — scripts are complete and functional.

## Threat Flags

None — scripts take no new network paths beyond gh CLI already present.

## Self-Check: PASSED

- `scripts/lib/json-response.sh` exists: FOUND
- `scripts/devbot-issue-create.sh` exists: FOUND
- Both pass `zsh -n` syntax check: PASS
- `json_ok` outputs `{"ok":true,...}`: PASS
- `json_err` outputs `{"ok":false,...}`: PASS
- `/opt/homebrew/bin/gh` used explicitly: FOUND
- Duplicate check (`gh issue list --search`) present: FOUND
- Both scripts executable: PASS

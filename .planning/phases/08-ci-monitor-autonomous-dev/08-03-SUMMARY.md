---
phase: 08-ci-monitor-autonomous-dev
plan: "03"
subsystem: devbot
tags: [devbot, issue-intake, autonomous-dev, beads, gh-cli]
dependency_graph:
  requires: [08-01]
  provides: [devbot-intake-issue.sh, devbot-autonomous-dev-docs]
  affects: [.openclaw/agents/devbot/SOUL.md, .openclaw/agents/devbot/TOOLS.md]
tech_stack:
  added: []
  patterns: [cc-openclaw-script, python3-json-processing, gh-cli-json-output]
key_files:
  created:
    - .openclaw/agents/devbot/scripts/devbot-intake-issue.sh
  modified:
    - .openclaw/agents/devbot/SOUL.md
    - .openclaw/agents/devbot/TOOLS.md
decisions:
  - "Used python3 with temp files for JSON parsing (not jq) for nested object extraction safety"
  - "Body truncated to 2000 chars before structured output (SECURITY.md rule T-08-07)"
  - "--dry-run flag parses cleanly with POSITIONAL array to avoid positional arg conflict"
  - "SOUL.md extended (not overwritten) — Phase 7 content preserved, new sections appended"
metrics:
  duration: "8 minutes"
  completed: "2026-05-21"
  tasks_completed: 2
  files_created: 1
  files_modified: 2
---

# Phase 8 Plan 03: DevBot Issue Intake Script Summary

DevBot extended with `devbot-intake-issue.sh` implementing `gh issue view` to structured JSON, plus autonomous development workflow documentation in SOUL.md and TOOLS.md.

## What Was Built

- **`devbot-intake-issue.sh`** — Issue intake script with: `gh issue view` JSON extraction, python3-based field normalization (labels, milestone, assignees), body truncation to 2000 chars, `--dry-run` mode for smoke testing, error handling with JSON error response on gh failure.
- **DevBot SOUL.md** — Extended with "Autonomous Development Workflow (DEV-04)" section documenting Phase A (intake) and Phase B (Beads execution), including the NEVER-create-epics and NEVER-merge-PRs rules.
- **DevBot TOOLS.md** — Extended with "Autonomous Dev Tools (DEV-04)" section including bd command reference and the 5-subtask template for reference.

## Deviations from Plan

None — plan executed exactly as written. Phase 7 SOUL.md content was preserved (appended, not overwritten).

## Commits

| Hash | Description |
|------|-------------|
| 244582f | feat(08-03): add devbot-intake-issue.sh and extend DevBot with autonomous dev workflow docs |

## Self-Check: PASSED

- [x] `devbot-intake-issue.sh` exists and is executable
- [x] `zsh -n devbot-intake-issue.sh` passes
- [x] `--dry-run` returns `{"ok": true, "dry_run": true, ...}`
- [x] SOUL.md contains "Autonomous Development" section (count >= 1)
- [x] TOOLS.md contains `bd ready --json` (count >= 1)
- [x] TOOLS.md contains `devbot-intake-issue.sh` (count >= 2)
- [x] Commit 244582f exists in git log

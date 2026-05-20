---
phase: 09-notion-decision-log
plan: "06"
subsystem: notion-verification
tags: [standup-brief, verify, smoke-checks, MEM-01, MEM-02, MEM-03, MEM-04]
decisions:
  - "verify-phase-09.sh uses worktree-aware path resolution: checks worktree paths before live $HOME paths"
  - "standup-brief.sh wraps Notion query in subshell fallback — brief always completes regardless of Notion status"
key_files:
  created:
    - scripts/verify-phase-09.sh
  modified:
    - scripts/standup-brief.sh
metrics:
  completed_date: "2026-05-21"
  tasks_completed: 2
  files_changed: 2
---

# Phase 9 Plan 06: standup-brief.sh and verify-phase-09.sh Summary

## One-liner

Morning standup brief wired to query-decisions.sh for autonomous_decisions section, and verify-phase-09.sh with 12 smoke checks all passing in worktree context.

## Tasks Completed

| Task | Description | Status |
|------|-------------|--------|
| 1 | Update standup-brief.sh to include autonomous decision count | Done |
| 2 | Create verify-phase-09.sh with smoke and full integration modes | Done |

## Deviations from Plan

**[Rule 3 - Blocking] Path resolution for pre-stow context:** The verify script checks `~/.openclaw/agents/task-orchestrator/scripts/notion/` but in the worktree, scripts/ directory is not stowed to live (only .md files are symlinked). Added worktree-aware path resolution to use `$REPO_ROOT/.openclaw/` when live path does not exist.

## Self-Check: PASSED

- `verify-phase-09.sh --smoke` exits 0 with 12/12 checks passing ✓
- `standup-brief.sh` includes `autonomous_decisions.count` in output ✓
- Brief completes even when Notion token is absent ✓
- Commit `6596171` exists ✓

---
phase: 08-ci-monitor-autonomous-dev
plan: "04"
subsystem: devbot
tags: [devbot, beads, epic-creation, execute-cycle, autonomous-dev]
dependency_graph:
  requires: [08-03]
  provides: [devbot-create-epic.sh, devbot-execute-cycle.sh]
  affects: [.openclaw/agents/devbot/scripts/]
tech_stack:
  added: []
  patterns: [beads-claim-close, bd-cli, gh-pr-create-draft]
key_files:
  created:
    - .openclaw/agents/devbot/scripts/devbot-create-epic.sh
    - .openclaw/agents/devbot/scripts/devbot-execute-cycle.sh
  modified: []
decisions:
  - "Script uses explicit BD path ($BD) not bare bd — same pattern as devbot-create-epic.sh"
  - "open-pr: checks if remote branch exists first; if not, closes with informational evidence (Phase 8 scaffold)"
  - "Two bd close calls in devbot-execute-cycle.sh: one in open-pr early exit, one at end"
  - "bd update and bd close counts verify correctly with BD path pattern (not bare bd)"
metrics:
  duration: "8 minutes"
  completed: "2026-05-21"
  tasks_completed: 2
  files_created: 2
  files_modified: 0
---

# Phase 8 Plan 04: DevBot Execute Cycle Scripts Summary

`devbot-create-epic.sh` and `devbot-execute-cycle.sh` created — the full Beads claim/close ceremony for the 5-subtask autonomous dev loop.

## What Was Built

- **`devbot-create-epic.sh`** — Creates a 5-subtask Beads epic with correct `--deps` chain (T1→T2→T3→T4→T5). Includes post-creation verification via `bd dep tree` and `bd ready` check. Returns `{"ok": true, "epic_id": ..., "tasks": {...}}`.

- **`devbot-execute-cycle.sh`** — Handles all 5 TASK_TYPE values (design, implement, self-review, qa-evidence, open-pr):
  - T1-T4: Phase 8 scaffold — close with placeholder evidence strings (Phase 12 will add real implementation)
  - T5 (open-pr): Attempts to create a real draft PR if the branch exists on the remote; closes with informational evidence if branch doesn't exist (Phase 8 has no code changes to push)
  - Merge guard: `--draft` only, no `gh pr merge`

## Deviations from Plan

**1. [Rule 2 - Security] T5 open-pr checks for remote branch existence before gh pr create**
- **Issue:** The plan assumes a branch exists for T5; in Phase 8 there is no implementation code to push, so no branch exists. Attempting `gh pr create` on a non-existent branch fails with error.
- **Fix:** T5 checks `gh api repos/$REPO/git/ref/heads/devbot/issue-$N` first. If branch doesn't exist, closes the task with informational evidence ("Draft PR scaffold: branch not yet created — requires Phase 12"). This keeps the script correct as a scaffold without failing noisily.
- **Files modified:** `.openclaw/agents/devbot/scripts/devbot-execute-cycle.sh`
- **Commit:** 65e2c2d

## Commits

| Hash | Description |
|------|-------------|
| 65e2c2d | feat(08-04): add devbot-create-epic.sh and devbot-execute-cycle.sh Beads scaffolds |

## Self-Check: PASSED

- [x] `devbot-create-epic.sh` exists and is executable
- [x] `zsh -n devbot-create-epic.sh` passes
- [x] 6 bd create calls (epic + 5 subtasks) using explicit `$BD` path
- [x] `devbot-execute-cycle.sh` exists and is executable
- [x] `zsh -n devbot-execute-cycle.sh` passes
- [x] Contains `bd update` (claim) and `bd close` (evidence) using explicit `$BD` path
- [x] Contains `--draft` for T5 PR (merge guard)
- [x] Does NOT contain `gh pr merge` (merge guard = 0)
- [x] Commit 65e2c2d exists in git log

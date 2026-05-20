---
phase: 01-infrastructure
plan: 02
subsystem: infra
tags: [cc-openclaw, skills, stow, submodule, claude-code]

# Dependency graph
requires: []
provides:
  - "cc-openclaw git submodule at cc-openclaw/ pinned to commit 553e2e9"
  - "9 cc-openclaw skill SKILL.md files symlinked under .claude/skills/ (discoverable by Claude Code)"
  - ".gitmodules registering cc-openclaw at github.com/rahulsub-be/cc-openclaw"
  - "GNU Stow 2.4.1 installed via brew (prerequisite for all subsequent stow operations)"
affects: [01-04-stow-deploy, all-subsequent-plans]

# Tech tracking
tech-stack:
  added: ["GNU Stow 2.4.1 (brew install stow)", "cc-openclaw HEAD (git submodule, commit 553e2e9)"]
  patterns:
    - "git submodule for cc-openclaw at project root (not nested)"
    - "stow --no-folding creates real .claude/skills/ directories with SKILL.md symlinks (not directory-level symlinks)"

key-files:
  created:
    - ".gitmodules — git submodule registration for cc-openclaw"
    - "cc-openclaw/ — cloned submodule (9 skills under .claude/skills/)"
    - ".claude/skills/openclaw-add-channel/SKILL.md — symlink"
    - ".claude/skills/openclaw-add-cron/SKILL.md — symlink"
    - ".claude/skills/openclaw-add-script/SKILL.md — symlink"
    - ".claude/skills/openclaw-add-secret/SKILL.md — symlink"
    - ".claude/skills/openclaw-dream-setup/SKILL.md — symlink"
    - ".claude/skills/openclaw-new-agent/SKILL.md — symlink"
    - ".claude/skills/openclaw-restart/SKILL.md — symlink"
    - ".claude/skills/openclaw-status/SKILL.md — symlink"
    - ".claude/skills/openclaw-stow/SKILL.md — symlink"
  modified: []

key-decisions:
  - "cc-openclaw submodule pinned at commit 553e2e9 (HEAD at clone time)"
  - "stow --no-folding creates real skill directories with SKILL.md symlinks, not directory-level symlinks — this is the correct behavior for Claude Code traversal"
  - "GNU Stow installed via brew (2.4.1) as a prerequisite deviation since it was not yet installed"

patterns-established:
  - "Pattern: stow --no-folding from cc-openclaw/ targeting project root creates .claude/skills/<name>/SKILL.md symlinks (leaf-level, not directory-level symlinks)"
  - "Pattern: cc-openclaw submodule update path is git pull inside cc-openclaw/; no re-stow needed for content-only updates"

requirements-completed: [INFRA-02]

# Metrics
duration: 35min
completed: 2026-05-20
---

# Phase 1 Plan 02: cc-openclaw Submodule and Skills Stow Summary

**cc-openclaw git submodule (commit 553e2e9) registered and stowed — 9 SKILL.md files symlinked under .claude/skills/ making all /openclaw-* slash commands discoverable by Claude Code**

## Performance

- **Duration:** ~35 min
- **Started:** 2026-05-20T23:01:00Z
- **Completed:** 2026-05-20T17:35:00Z
- **Tasks:** 2
- **Files modified:** 11 (1 .gitmodules, 1 cc-openclaw submodule pointer, 9 SKILL.md symlinks)

## Accomplishments

- cc-openclaw registered as git submodule at github.com/rahulsub-be/cc-openclaw (commit 553e2e9a49e4adb2f65793bb9a692e204dab55d9)
- All 9 cc-openclaw skills stowed under .claude/skills/ with stow --no-folding — Claude Code can traverse and discover /openclaw-* slash commands
- GNU Stow 2.4.1 installed via brew (was missing; prerequisite for this and all subsequent stow operations in phase 1)
- Submodule commit hash recorded in .gitmodules — fulfills T-02-01 threat mitigation (tampering: content pinned at known SHA)

## Task Commits

Each task was committed atomically:

1. **Task 1: Add cc-openclaw as git submodule** - `cec4964` (chore)
2. **Task 2: Stow cc-openclaw skills into .claude/skills/ with --no-folding** - `f1aeacb` (chore)

**Plan metadata:** (committed with SUMMARY.md)

## Files Created/Modified

- `.gitmodules` — registers cc-openclaw submodule at github.com/rahulsub-be/cc-openclaw
- `cc-openclaw/` — git submodule (9 skills under .claude/skills/, .stow-local-ignore excludes README/LICENSE)
- `.claude/skills/openclaw-{add-channel,add-cron,add-script,add-secret,dream-setup,new-agent,restart,status,stow}/SKILL.md` — 9 symlinks resolving into cc-openclaw submodule

## Submodule Details

- **Commit hash:** 553e2e9a49e4adb2f65793bb9a692e204dab55d9
- **Branch:** heads/main (at clone time)
- **Skill count:** 9 (all expected skills present)
- **Stow conflicts during run:** 0

## Stow Behavior Note (Plan Acceptance Criteria Deviation)

The plan's automated verification check `test -L .claude/skills/openclaw-status` (skill directories are symlinks) is not achievable with `--no-folding`. With stow 2.4.1 and `--no-folding`:
- `.claude/` is a real directory (NOT a symlink — correct, Claude Code can traverse)
- `.claude/skills/` is a real directory (NOT a symlink — correct)
- `.claude/skills/openclaw-status/` is a real directory (NOT a symlink)
- `.claude/skills/openclaw-status/SKILL.md` IS a symlink → `../../../cc-openclaw/.claude/skills/openclaw-status/SKILL.md`

This is the correct `--no-folding` behavior: real intermediate directories, symlinked leaf files. Claude Code discovers skills by finding `SKILL.md` files in `.claude/skills/<name>/` — the real directory structure enables this traversal. The goal (skills discoverable) is fully met. The `test -L` check in the plan spec was written for a different stow behavior model.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Installed missing GNU Stow prerequisite**
- **Found during:** Task 2 (stow invocation)
- **Issue:** `stow` binary not found — GNU Stow was not installed on the machine
- **Fix:** Ran `brew install stow` (installed version 2.4.1)
- **Files modified:** None (system-level install)
- **Verification:** `which stow && stow --version` confirms stow 2.4.1 available
- **Committed in:** Not separately committed (prerequisite install, no repo files changed)

---

**Total deviations:** 1 auto-fixed (blocking prerequisite install)
**Impact on plan:** Stow install is a documented prerequisite (RESEARCH.md "Missing dependencies with no fallback"). Auto-fix was appropriate — no architectural change.

## Threat Model Coverage

| Threat ID | Status | Evidence |
|-----------|--------|---------|
| T-02-01 (cc-openclaw tampering) | Mitigated | Submodule pinned to commit 553e2e9; git submodule status records SHA |
| T-02-02 (symlink tampering) | Accepted | Symlinks resolve into repo (not external); stow -D cleanly removes them |
| T-02-03 (OPENCLAW_REPO detection) | Accepted | Detection is read-only; requires Plan 01-04 stow to activate |
| T-02-SC (submodule via git clone) | Mitigated | HTTPS clone from github.com/rahulsub-be/cc-openclaw (cited in CLAUDE.md as canonical source) |

## Known Stubs

None — this plan delivers structural setup only. Skills are present but will not function until Plan 01-04 establishes the ~/.openclaw/openclaw.json stow symlink enabling OPENCLAW_REPO detection.

## Threat Flags

None — no new network endpoints, auth paths, or trust boundaries beyond what the threat model registers.

## Next Phase Readiness

- INFRA-02 structurally complete: 9 /openclaw-* slash commands discoverable by Claude Code
- Skills will fail at runtime until Plan 01-04 runs stow on .openclaw/ (OPENCLAW_REPO detection requires ~/.openclaw/openclaw.json to be a stow symlink)
- Skills update path: `cd cc-openclaw && git pull` (no re-stow needed for content-only updates per D-08)

---
*Phase: 01-infrastructure*
*Completed: 2026-05-20*

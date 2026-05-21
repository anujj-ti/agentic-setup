---
phase: 12-self-evolution
status: partial
verified_at: 2026-05-21
score: 7/9 must-haves verified
---

# Phase 12: Self-Evolution — Verification Report

**Phase Goal:** Task Orchestrator can propose and create new agents when pattern repetition exceeds threshold (EVOL-01), tracks pattern counts across sessions (EVOL-02), and runs 4-stage experiments before committing to new capabilities (EVOL-03).
**Verified:** 2026-05-21
**Status:** partial
**Reason for partial:** verify-phase-12.sh fails 5 checks because SOUL.md was partially stowed to live path (causing path detection to choose live path), but `check-agent-domain.sh`, `propose-experiment.js`, and `create-experiment-page.js` are not yet stowed. Scripts work correctly when invoked from the git repo source path.

## Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | Task Orchestrator SOUL.md has EVOL-01/02/03 rules and NEVER directive | VERIFIED | EVOL rules, /openclaw-new-agent reference, NEVER directive all confirmed |
| 2 | check-agent-domain.sh exists, passes syntax, returns ok:false for existing agents | VERIFIED | In git repo; syntax passes; returns `{"ok": false, "reason": "Agent already exists for domain 'devbot'..."}` when called with "devbot" |
| 3 | check-agent-domain.sh returns ok:true for novel domains | VERIFIED | Returns `{"ok": true}` for "database-monitor" |
| 4 | MEMORY.md has Pattern Counter section with PRESERVE marker | VERIFIED | `<!-- PRESERVE: pattern_counter -->` marker confirmed; Pattern Counter section and table columns confirmed |
| 5 | DREAM-ROUTINE.md has verbatim preservation instruction for pattern counter | VERIFIED | "preserve verbatim" confirmed |
| 6 | propose-experiment.js: passes node --check, exits non-zero without required args | VERIFIED | Syntax valid; exits 1 with `{"ok":false,"error":"missing required field: title"}` |
| 7 | create-experiment-page.js: passes node --check, exits non-zero without OPENCLAW_NOTION_TOKEN | VERIFIED | Syntax valid; exits 1 with `{"ok":false,"error":"OPENCLAW_NOTION_TOKEN not set"}` |
| 8 | Task Orchestrator TOOLS.md has New Agent Proposal template | VERIFIED | Confirmed |
| 9 | verify-phase-12.sh passes all 25 checks | PARTIAL | 20/25 checks pass when run from live path; 5 fail due to stow gap (see below) |

**Score:** 7/9 (excluding the 2 verify-script-based checks; all underlying artifacts verified from repo source)

## Required Artifacts

| Artifact | Status | Notes |
|----------|--------|-------|
| `.openclaw/agents/task-orchestrator/SOUL.md` | VERIFIED | EVOL-01/02/03 sections present (stowed at live path) |
| `.openclaw/agents/task-orchestrator/MEMORY.md` | VERIFIED | PRESERVE marker + Pattern Counter table present |
| `.openclaw/agents/task-orchestrator/DREAM-ROUTINE.md` | VERIFIED | Verbatim preservation instruction present |
| `.openclaw/agents/task-orchestrator/TOOLS.md` | VERIFIED | New Agent Proposal template present |
| `.openclaw/agents/task-orchestrator/scripts/check-agent-domain.sh` | VERIFIED (repo only) | In git repo; syntax valid; behavior correct; NOT yet at live ~/.openclaw/ path |
| `.openclaw/agents/task-orchestrator/scripts/propose-experiment.js` | VERIFIED (repo only) | In git repo; syntax valid; validation behavior correct; NOT yet at live path |
| `.openclaw/agents/task-orchestrator/scripts/create-experiment-page.js` | VERIFIED (repo only) | In git repo; syntax valid; env check behavior correct; NOT yet at live path |
| `scripts/verify-phase-12.sh` | PARTIAL | Exists; path detection bug causes false failures (see below) |

## Stow Gap — Root Cause

The verify script uses EVOL-01 presence in the live SOUL.md to detect "live context vs worktree context." Since SOUL.md was stowed to `~/.openclaw/` (contains EVOL-01), the script selects the live `$HOME/.openclaw/agents/task-orchestrator/scripts/` path. But this live scripts/ directory only contains `lib/` and `notion/` subdirectories — not the Phase 12 scripts (`check-agent-domain.sh`, `propose-experiment.js`, `create-experiment-page.js`). These scripts exist only in the git repo and have not been stowed yet.

**Action required:** Run stow-deploy from main branch after merge:
```
REPO_DIR="$HOME/Documents/agentic-setup" zsh scripts/stow-deploy.sh
launchctl kickstart -k gui/$(id -u)/ai.openclaw.gateway
```

After stow, re-run `zsh scripts/verify-phase-12.sh` — all 25 checks should pass.

## Verify Script Path Detection Note

The verify script's worktree-detection logic works correctly for Phase 11 (checks for code-reviewer at live path) but is incorrect for Phase 12 (checks for EVOL-01 in SOUL.md, which was already stowed). A future improvement would be to detect by the presence of `check-agent-domain.sh` instead.

## Human Action Required

### 1. Live new-agent proposal end-to-end test

**Test:** After stow-deploy, trigger Task Orchestrator with a domain that exceeds the pattern threshold; observe the EVOL-01 gate (check-agent-domain.sh), skill-reviewer review, and decision log.
**Expected:** New agent created via `/openclaw-new-agent`, decision logged to Notion, Task Orchestrator routing updated.
**Why human:** Requires live gateway, running agents, and OPENCLAW_NOTION_TOKEN.

### 2. Experiment Stage 1 live test

**Test:** Run `node ~/.openclaw/agents/task-orchestrator/scripts/propose-experiment.js --title "Test" --hypothesis "..." --metric "..." --criteria "..."` with Notion token set.
**Expected:** Experiment page created in Notion with Status=Draft.
**Why human:** Requires live Notion credentials.

---
_Verified: 2026-05-21_
_Verifier: Claude (gsd-verifier)_

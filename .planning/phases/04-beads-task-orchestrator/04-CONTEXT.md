---
phase: 04-beads-task-orchestrator
created: 2026-05-21
session_type: planning
---

# Phase 4: Beads + Task Orchestrator — Context

## Decisions

### D-50: BEADS_DIR path
**Decision:** `BEADS_DIR=$HOME/.openclaw/beads` (top-level, not inside task-orchestrator workspace)
**Rationale:** Consistent, predictable path that all agents share; simpler to reference in SOUL.md and scripts than a nested agent-workspace path. All agents in the execution tier inherit this via the gateway env injection.
**Supersedes:** RESEARCH.md recommendation of `~/.openclaw/agents/task-orchestrator/.beads` — planner locked the simpler top-level path.
**Affects:** Plans 04-01, 04-02, 04-03, 04-04 — all bd commands and SOUL.md references use this path.

### D-51: bd binary path
**Decision:** `/opt/homebrew/opt/node@24/bin/bd` in all scripts and SOUL.md references
**Rationale:** nvm node@22 already has bd 1.0.3 installed; using explicit Homebrew node@24 path avoids PATH shadowing in gateway agent processes, shell sessions, and verify scripts. Consistent with D-13 (node@24 PATH pin).
**Source:** RESEARCH.md Pitfall 1 — confirmed by live test; nvm prepends its bin to interactive shells.

### D-52: dolt install before bd (hard prerequisite order)
**Decision:** `brew install dolt` must complete before `npm install -g @beads/bd@1.0.4`
**Rationale:** bd 1.0.4 postinstall downloads the native bd binary AND requires dolt on PATH for `bd init --stealth` embedded mode. Installing bd first then dolt would require re-init.
**Source:** RESEARCH.md Environment Availability table — dolt listed as "Must install via brew install dolt in Plan 04-01."

### D-53: bd init uses --stealth --prefix tskorch --non-interactive
**Decision:** Initialize with `BEADS_DIR=$HOME/.openclaw/beads /opt/homebrew/opt/node@24/bin/bd init --stealth --prefix tskorch --non-interactive`
**Rationale:** `--stealth` = embedded Dolt (no server). `--prefix tskorch` = all task-orchestrator epics have recognizable IDs (`tskorch-<hash>`). `--non-interactive` = safe for autonomous execution. Guard against double-init: check for `$BEADS_DIR/embeddeddolt` before running.
**Source:** RESEARCH.md Pattern 1; CLAUDE.md Beads section.

### D-54: BEADS_DIR export in both openclaw-secrets.sh and openclaw-env.sh
**Decision:** Append `export BEADS_DIR="$HOME/.openclaw/beads"` to both `.openclaw/scripts/openclaw-secrets.sh` AND `.openclaw/scripts/openclaw-env.sh`; NOT in secrets.sh (not a secret, no Keychain entry needed)
**Rationale:** openclaw-secrets.sh feeds the launchd gateway env (agents inherit); openclaw-env.sh feeds interactive shell sessions (manual bd commands work). Plain path, not a secret — no Keychain entry. Precedent: PATH pin lines already appear in both files.
**Source:** RESEARCH.md Pattern 2 — "The three-file update rule" and "not a secret" note.

### D-55: Deploy cycle after secrets file update
**Decision:** After modifying openclaw-secrets.sh: run `zsh scripts/stow-deploy.sh` then `launchctl kickstart -k gui/$(id -u)/ai.openclaw.gateway`, then verify with `grep BEADS_DIR ~/.openclaw/service-env/ai.openclaw.gateway.env`
**Rationale:** stow deploys repo changes to ~/.openclaw symlinks; gateway restart triggers OpenClaw to source the updated secrets file and regenerate gateway.env. The grep verify catches Assumption A1 (if regeneration doesn't occur, the fallback is direct edit of gateway.env).
**Source:** RESEARCH.md Pattern 2 deploy cycle + Assumption A1 fallback.

### D-56: Task Orchestrator SOUL.md fully replaces Phase 3 stub
**Decision:** SOUL.md is replaced in full — the "Phase 3 Scope (Beads not yet installed)" section is removed and replaced with the "Beads-Enforced Execution Contract (MANDATORY — NO EXCEPTIONS)" section per RESEARCH.md code example.
**Rationale:** The Phase 3 stub explicitly says "do NOT attempt bd or beads commands." Leaving that language alongside the new Beads rules would create contradictory instructions that confuse the agent.

### D-57: TOOLS.md updated alongside SOUL.md in same plan
**Decision:** Task Orchestrator TOOLS.md receives a "Beads Task Tracker (Phase 4+)" section in the same plan as the SOUL.md update (Plan 04-03), not a separate plan.
**Rationale:** SOUL.md gives the rules; TOOLS.md gives the exact command syntax. An agent following the SOUL.md Beads contract without the TOOLS.md command reference would need to guess syntax. Both files are in the same agent workspace directory — no wave conflict.

### D-58: End-to-end verification creates then cleans up test epic
**Decision:** Plan 04-04 creates a real test epic (`tskorch-test` prefix or description "Phase 4 verification"), runs full claim/close cycle, verifies closed state in `bd list --json`, then documents the task IDs and output in SUMMARY. Does NOT delete the test tasks (Dolt-backed, audit trail preferred).
**Rationale:** Leaving the test epic provides a concrete reference example of the claim/close cycle for future agents to observe. Test data in a local Dolt DB is harmless.

### D-59: verify-phase-04.sh created in Plan 04-01 (Wave 1)
**Decision:** `scripts/verify-phase-04.sh` is created alongside the dolt + bd install in Plan 04-01, not deferred to a later plan.
**Rationale:** The verify script is needed in Plan 04-04 for the end-to-end check. Creating it in Wave 1 ensures it exists before it's needed; the script can be extended by later plans. RESEARCH.md Validation Architecture documents this as a "Wave 0 gap."

## Deferred Ideas

- Beads server mode (external Dolt server) — CLAUDE.md mandates embedded/stealth mode; not applicable for single-machine personal hub
- Per-repo BEADS_DIR — RESEARCH.md anti-pattern: "One Beads DB per repo" is wrong; use single shared DB
- Timeout/stuck-agent auto-recovery in SOUL.md — Phase 4 documents the detection query; automated recovery is Phase 9 concern (Notion logging prerequisite)
- WhatsApp channel provisioning — D-20 deferred

## Claude's Discretion

- Comment style in SOUL.md section headers: use markdown `##` with ALL-CAPS subheader for mandatory rules (matches Phase 3 SOUL.md convention)
- TOOLS.md structure: add new Beads section below existing tools, remove the "NOT Available in Phase 3" exclusions list (those restrictions no longer apply)
- verify-phase-04.sh check count: 6 checks matching RESEARCH.md Validation Architecture spec

---
phase: 13-synapse-integration
session: planning
date: 2026-05-21
---

# Phase 13 Context — Synapse Integration

## Decisions

**D-130:** All deterministic Synapse scripts placed in `scripts/` (repo root), not inside individual agent workspaces. Shared across all agents.

**D-131:** `synapse-checkin.sh` takes positional args: `<project_id> <bd_id> <status> <current_task>`. Status values: `start | progress | blocked | complete | failed`.

**D-132:** `synapse-record-learning.sh` uses `confidence: "low"` by default (no evidence_artifact_id required). Agents upgrading to medium/high must use the full Synapse curl protocol directly per SKILL.md rules.

**D-133:** Both scripts use a `TODO_SYNAPSE` guard: if `$SYNAPSE_TOKEN` is absent, exit 0 with a stderr warning (never exit 1 — Synapse absence must not break agent execution).

**D-134:** All 8 execution-tier agents (devbot, ci-monitor, email-triage, code-reviewer, doc-reviewer, decision-reviewer, skill-reviewer, skill-creation) get a "## Synapse (Mandatory)" section in their TOOLS.md. Pattern sourced from task-orchestrator TOOLS.md Synapse Quick Reference.

**D-135:** Project ID for all agentic-setup agents: `project.agentic-setup`. The task-orchestrator AGENTS.md currently uses `project.edullm-sat-math` — this is a pre-existing state that is NOT changed in this phase (out of scope). New TOOLS.md sections for execution-tier agents will use `project.agentic-setup`.

**D-136:** `verify-phase-13.sh` checks: (1) SYNAPSE_TOKEN in Keychain, (2) SYNAPSE_TOKEN + SYNAPSE_URL in openclaw-secrets.sh and openclaw-env.sh, (3) "Synapse (Mandatory)" string present in all 10 agent TOOLS.md files (task-orchestrator + user-orchestrator counted via AGENTS.md check), (4) both scripts exist and are executable.

**D-137:** CLAUDE.md gets a new "## Synapse Project Setup" subsection documenting how the operator creates `project.agentic-setup` in the Synapse dashboard — this unblocks consistent project_id usage across all agents.

**D-138:** Phase 13-04 (phase gate) runs verify-phase-13.sh, records 3 learnings to Synapse about the integration, and writes the SUMMARY.

## Deferred Ideas

- Upgrading task-orchestrator AGENTS.md project_id from `project.edullm-sat-math` to `project.agentic-setup` — already-deployed, running agent; not touched this phase.
- Medium/high confidence learning recording from agent scripts — agents use low-confidence wrapper script; medium/high requires direct curl (per SKILL.md rule).
- `synapse.fact.record` wrapper script — not needed for execution-tier agents whose outputs are low-confidence learnings.

## Claude's Discretion

- Exact TOOLS.md section placement: append at end of each file (after existing sections).
- verify-phase-13.sh check count: aim for 8-10 deterministic checks.
- Learning tags for phase 13 Synapse records: `["synapse", "agent-scaffolding", "openclaw"]`.

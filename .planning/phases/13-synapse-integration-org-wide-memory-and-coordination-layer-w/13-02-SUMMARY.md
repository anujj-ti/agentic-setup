---
phase: 13-synapse-integration
plan: "02"
subsystem: agent-tools
tags: [synapse, agent-scaffolding, tools-md, openclaw]
dependency_graph:
  requires: [13-01]
  provides: [synapse-section-in-all-8-agents]
  affects: [devbot, ci-monitor, email-triage, code-reviewer, document-reviewer, decision-reviewer, skill-reviewer, skill-creation]
tech_stack:
  added: []
  patterns: [synapse-mandatory-section, agent-TOOLS.md-append]
key_files:
  created: []
  modified:
    - .openclaw/agents/devbot/TOOLS.md
    - .openclaw/agents/ci-monitor/TOOLS.md
    - .openclaw/agents/email-triage/TOOLS.md
    - .openclaw/agents/code-reviewer/TOOLS.md
    - .openclaw/agents/document-reviewer/TOOLS.md
    - .openclaw/agents/decision-reviewer/TOOLS.md
    - .openclaw/agents/skill-reviewer/TOOLS.md
    - .openclaw/agents/skill-creation/TOOLS.md
decisions:
  - "D-135: all 8 execution-tier agents use project.agentic-setup (not project.edullm-sat-math)"
metrics:
  duration: "4 minutes"
  completed: "2026-05-21"
  tasks_completed: 2
  files_created: 0
  files_modified: 8
---

# Phase 13 Plan 02: Agent TOOLS.md Synapse Wiring Summary

## One-liner

Appended identical "## Synapse (Mandatory)" 4-step loop section to all 8 execution-tier agent TOOLS.md files, making Synapse a first-class tool reference visible at agent boot.

## What Was Built

All 8 execution-tier agents (devbot, ci-monitor, email-triage, code-reviewer, document-reviewer, decision-reviewer, skill-reviewer, skill-creation) now have a `## Synapse (Mandatory)` section containing:
- Step 0: brief.fetch (always first)
- Step 1: workflow.create (captures BD_ID)
- Step 2: checkin via shared `synapse-checkin.sh` script
- Step 3: record-learning via shared `synapse-record-learning.sh` script
- Step 4: close workflow

All sections reference `project.agentic-setup` per D-135. No existing content was altered — append-only.

## Verification Results

- `grep -l "Synapse (Mandatory)" .openclaw/agents/*/TOOLS.md | wc -l` → 8
- All 8 agents have `project.agentic-setup` and `synapse-checkin.sh` references: PASS

## Deviations from Plan

None - plan executed exactly as written.

## Self-Check: PASSED

- [x] All 8 agent TOOLS.md files contain "## Synapse (Mandatory)"
- [x] All reference project.agentic-setup
- [x] Commit 69a2338 verified in git log

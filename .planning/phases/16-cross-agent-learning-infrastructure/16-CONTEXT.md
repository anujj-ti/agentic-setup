# Phase 16: Cross-Agent Learning Infrastructure — Context

**Gathered:** 2026-05-22
**Status:** Ready for planning
**Mode:** Auto (no discussion needed — research complete, schema validated live)

<domain>
## Phase Boundary

Add a shared `synapse-query-learnings.sh` script and wire pre-task Synapse learning queries into all execution-tier agents (task-orchestrator, devbot, ci-monitor, email-triage). Create ci-monitor's missing AGENTS.md. Update dream routines for execution-tier agents to merge cross-silo learnings into MEMORY.md. No new agents, no new cron jobs.

</domain>

<decisions>
## Implementation Decisions

### Synapse learning.query API (validated live 2026-05-22)

- **D-301:** Correct payload: `{"project_id":"...","applies_to":["tag"],"limit":N}` — NOT `tags:`, NOT `cross_silo:` as a top-level field. Validated against live API.
- **D-302:** Response shape: `{"ok":true,"data":{"learnings":[{"id","claim","applies_to","confidence","created_at",...}]}}`. Field name is `applies_to` not `tags`.
- **D-303:** `synapse-query-learnings.sh` script lives at `~/Documents/agentic-setup/scripts/synapse-query-learnings.sh`. Takes args: `<project_id> <applies_to_tag> [limit]`. Outputs formatted bullet list to stdout (not JSON) — agents read it as context, not parse it.
- **D-304:** On Synapse unavailable (token missing, network error, non-ok response): exit 0 with empty output — never block agent startup. Non-blocking by design.
- **D-305:** Default limit: 5 learnings per query. Cross-silo: always query with `applies_to` matching the agent's domain tags.

### Agent wiring (LEARN-01, LEARN-02)

- **D-306:** Each execution-tier agent adds a "Query Synapse learnings before acting" step to their startup/session checklist in AGENTS.md. Uses `synapse-query-learnings.sh` via exec. Result injected as context for the session.
- **D-307:** Domain tags per agent: task-orchestrator → `["openclaw","agent-orchestration"]`, devbot → `["openclaw","github","ci-monitor"]` (cross-silo: queries CI Monitor learnings), ci-monitor → `["openclaw","github","ci"]`, email-triage → `["openclaw","email-triage"]`.
- **D-308:** ci-monitor has no AGENTS.md — create it in this phase with startup checklist + Synapse query step.

### Learning schema enforcement (LEARN-03)

- **D-309:** All existing Synapse sections in TOOLS.md use the shared `synapse-record-learning.sh` script which hardcodes `confidence: low`. No change needed for existing agents — they're already compliant.
- **D-310:** Add a schema reminder to task-orchestrator TOOLS.md: when recording learnings manually (not via script), always include all 4 fields: `claim`, `applies_to`, `confidence`, `evidence_artifact_id` (or omit evidence_artifact_id for low confidence).

### Dream routine merges (LEARN-04)

- **D-311:** task-orchestrator and devbot already have DREAM-ROUTINE.md. Add a "Merge top Synapse cross-silo learnings into MEMORY.md" step. Capped at 500 tokens of new content per dream cycle to stay within 2,500-token daily budget.
- **D-312:** ci-monitor dream routine: create DREAM-ROUTINE.md (it currently has none). Minimal — distill CI failure patterns, merge relevant Synapse learnings.

### Claude's Discretion

- Number of learnings to inject into context at session start (recommend 3-5)
- Whether to format learnings as a numbered list or bullet list in agent context
- ci-monitor AGENTS.md startup steps beyond Synapse (mirror existing agent patterns)

</decisions>

<canonical_refs>
## Canonical References

### Existing Synapse infrastructure (must read)
- `scripts/synapse-record-learning.sh` — existing shared learning recorder
- `scripts/synapse-checkin.sh` — existing shared check-in script
- `.openclaw/agents/task-orchestrator/TOOLS.md` — Synapse section with existing curl patterns
- `.openclaw/agents/task-orchestrator/AGENTS.md` — existing startup loop with Synapse
- `.openclaw/agents/devbot/TOOLS.md` — Synapse section
- `.openclaw/agents/ci-monitor/SOUL.md` — ci-monitor identity (no AGENTS.md yet)

### Research
- `.planning/research/SUMMARY.md` — v2.0 research, cross-agent learning section
- Live API validation: `applies_to` field, `data.learnings` response shape (D-301, D-302)

### Requirements
- `.planning/REQUIREMENTS.md` §LEARN — LEARN-01 through LEARN-04

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `scripts/synapse-record-learning.sh` — pattern to follow for synapse-query-learnings.sh
- `scripts/lib/json-response.sh` — json_ok/json_err for any new scripts
- task-orchestrator AGENTS.md Synapse section — template for other agents

### Established Patterns
- `set -euo pipefail` + JSON stdout + stderr logs
- `exit 0` on non-fatal failures (Synapse unavailable = non-blocking)
- Explicit binary paths: `/usr/bin/curl`, `/opt/homebrew/bin/jq`

### Integration Points
- AGENTS.md startup checklists in each agent — add Synapse query step
- DREAM-ROUTINE.md in task-orchestrator and devbot — add MEMORY.md merge step
- New files: ci-monitor AGENTS.md, ci-monitor DREAM-ROUTINE.md

</code_context>

<deferred>
## Deferred

- Cross-silo learning propagation graph — v2.1
- Conflict detection between contradicting learnings — v2.1
- Synapse learning quality scoring — v2.1

</deferred>

---
*Phase: 16-Cross-Agent Learning Infrastructure*
*Context gathered: 2026-05-22 (auto)*

# Phase 18: Decision Quality Risk Gate — Context

**Gathered:** 2026-05-22
**Status:** Ready for planning (auto)

<domain>
## Phase Boundary

Add risk_score (0-100) and risk_tier (low/medium/high) to every Decision Reviewer verdict. Route HIGH-tier decisions through a synchronous Telegram approval request before the Notion pre-log is written. Add a fast-pass list and `failed` verdict policy to Task Orchestrator SOUL.md so a Decision Reviewer timeout never halts overnight autonomous operation.

No new agents. Changes to: decision-reviewer SOUL.md, task-orchestrator SOUL.md, and a new risk-classifier.js script.

</domain>

<decisions>
## Implementation Decisions

### Risk scoring (RISK-01)

- **D-501:** risk_score (0-100) and risk_tier (low/medium/high) computed by Decision Reviewer in its LLM reasoning pass — no separate script needed. Score is added to every verdict including passes.
- **D-502:** Four scoring dimensions (from research): reversibility (field already in decision schema), blast radius (derivable from action specificity), external side effects (email/merge/create vs read-only), action recency (first-time vs repeated with clean history).
- **D-503:** Tier mapping: 0-30 = low (auto-proceed), 31-60 = medium (async notify), 61-100 = high (synchronous Telegram approval required before Notion write).
- **D-504:** Decision Reviewer verdict schema gains two new required fields: `risk_score: N` (integer 0-100) and `risk_tier: "low"|"medium"|"high"`. All existing verdict fields (pass/flag/reject, rationale, reversibility, evidence) are preserved.

### Telegram approval gate (RISK-02)

- **D-505:** Task Orchestrator routing: after Decision Reviewer returns verdict, check risk_tier. If HIGH → send Telegram approval request to Anuj's chat ID (1294664427) via User Orchestrator sessions_yield, wait for approve/reject. If approved → proceed to Notion pre-log. If rejected → abort action, log to Notion as "rejected by user".
- **D-506:** Approval timeout: 30 minutes. If no response → treat as `failed` verdict per D-509 (non-blocking fallback).
- **D-507:** Telegram message format: "⚠️ HIGH RISK action requires approval:\nAction: {decision}\nRisk score: {score}/100\nReason: {rationale}\nReversibility: {reversibility}\n\nReply APPROVE or REJECT"

### Fast-pass list (RISK-03)

- **D-508:** Fast-pass list in Task Orchestrator SOUL.md — known-safe LOW-risk action classes that bypass Decision Reviewer entirely (skip to Notion pre-log directly). Initial list: `gh issue comment`, `gh pr view`, `bd ready`, `bd close --reason`, Synapse learning record, Synapse checkin, read-only `gh api` calls.
- **D-509:** `failed` verdict policy in Task Orchestrator SOUL.md: if Decision Reviewer times out or returns an error → log a non-blocking audit entry to a local fallback file (`~/.openclaw/workspace-task-orchestrator/decision-review-fallback.log`) and PROCEED with the action. This prevents a Decision Reviewer failure from halting overnight autonomous operations.

### Claude's Discretion

- Exact scoring weights per dimension (research-backed: reversibility > blast radius > side effects > recency)
- Whether medium-tier triggers a Telegram notification or is silent (recommend silent for now — only HIGH blocks)

</decisions>

<canonical_refs>
## Canonical References

- `.openclaw/agents/decision-reviewer/SOUL.md` — current verdict schema, rubric
- `.openclaw/agents/task-orchestrator/SOUL.md` — Notion pre-log protocol, Beads contract
- `.planning/REQUIREMENTS.md` §RISK — RISK-01, RISK-02, RISK-03

</canonical_refs>

<code_context>
## Existing Code

- `decision-reviewer/SOUL.md` — current verdict format: `{"verdict":"pass"|"flag"|"reject","rationale":"...","reversibility":"...","evidence":"..."}`
- `task-orchestrator/SOUL.md` — Notion Pre-Log Protocol section, fast-pass concept doesn't exist yet
- `task-orchestrator/scripts/notion-log-decision.js` — current Notion logging path

</code_context>

<deferred>
## Deferred

- risk_score written to Notion as a field (needs Notion DB schema update) — v2.1
- Medium-tier async Telegram notification — v2.1
- Calibration based on observed override rate — after 2 weeks of production data

</deferred>

---
*Phase: 18-Decision Quality Risk Gate | Auto-context 2026-05-22*

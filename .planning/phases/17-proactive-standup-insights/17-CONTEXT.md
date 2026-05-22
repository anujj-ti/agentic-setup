# Phase 17: Proactive Standup Insights — Context

**Gathered:** 2026-05-22
**Status:** Ready for planning (auto)

<domain>
## Phase Boundary

Enhance the morning standup brief delivered by User Orchestrator via Telegram. Add deterministic signal-based classification (Blocked/At Risk/On Track), a ranked tackle-first list, and pattern detection — all post-processing on top of the existing `standup-brief.sh` JSON output. No changes to standup-brief.sh itself. Changes are to User Orchestrator SOUL.md and TOOLS.md (how it formats the brief) and a new `standup-insights.sh` helper script that takes the standup JSON and produces an enhanced insights section.

</domain>

<decisions>
## Implementation Decisions

### Classification signals (STANDUP-01) — deterministic, no LLM in classification path

- **D-401:** Blocked signal: issue/PR has ci_failures count > 0 AND was not updated in last 2h
- **D-402:** At Risk signal: stale_prs updatedAt > 24h ago with pending review requests
- **D-403:** On Track: everything else with recent activity
- **D-404:** Classification lives in a new `scripts/standup-insights.sh` script — pure jq + zsh, no LLM call, takes standup JSON on stdin, outputs enhanced JSON with `insights` section

### Tackle-first list (STANDUP-02)

- **D-405:** Ranked by: (1) Blocked items first, (2) At Risk items, (3) items with P0 labels or CI failure, (4) most recently updated
- **D-406:** Max 5 items. Each item includes: title, status (Blocked/At Risk/On Track), source_field (which JSON field it came from — e.g. "ci_failures[0]", "stale_prs[1]"), reason (1-sentence explanation citing the source field value)
- **D-407:** Empty tackle-first = `"tackle_first": []` (not omitted)

### Pattern detection (STANDUP-03)

- **D-408:** Pattern fires when 3+ items in the same run share a signal type (all CI failures, all stale PRs, all blocked)
- **D-409:** Pattern output: `"patterns": [{"type": "ci_failures", "count": 4, "label": "4 CI failures overnight — possible systemic issue"}]`
- **D-410:** No trend claims without 3+ days of history (deferred — IN-01 from research)

### User Orchestrator formatting (STANDUP-01/02/03)

- **D-411:** User Orchestrator SOUL.md updated: when formatting the morning standup Telegram message, call `standup-insights.sh` to get the insights section, then format it as: Tackle First list (numbered), then Patterns (if any), then the standard facts section
- **D-412:** standup-insights.sh takes standup JSON on stdin, outputs JSON with `insights.tackle_first`, `insights.patterns`, `insights.classified_items`
- **D-413:** Label-only mode: every item cites its `source_field` — no free-form interpretation, only label + source reference

### Claude's Discretion

- Exact Telegram formatting of the tackle-first list (numbered vs bullet)
- Whether patterns section is bolded or just plain text in Telegram

</decisions>

<canonical_refs>
## Canonical References

- `scripts/standup-brief.sh` — existing script, output schema: `{repo, as_of, merged_prs, ci_failures, stale_prs, autonomous_decisions, overnight_email, calendar_events}`
- `.openclaw/agents/user-orchestrator/SOUL.md` — current standup formatting rules
- `.openclaw/agents/user-orchestrator/TOOLS.md` — standup invocation pattern
- `.planning/REQUIREMENTS.md` §STANDUP — STANDUP-01, STANDUP-02, STANDUP-03

</canonical_refs>

<code_context>
## Existing Code

- `scripts/standup-brief.sh` — DO NOT modify. Only read its output.
- `scripts/lib/json-response.sh` — use json_ok/json_err
- User Orchestrator SOUL.md standup section — extend, don't replace

</code_context>

<deferred>
## Deferred

- Trend detection (needs 7+ days of standup logs) — v2.1
- Free-form LLM insight generation — after label-only mode validated

</deferred>

---
*Phase: 17-Proactive Standup Insights | Auto-context 2026-05-22*

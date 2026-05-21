# Architecture Research — v2.0 Intelligence Layer

**Researched:** 2026-05-21
**Milestone:** v2.0 Intelligence Layer (4 features)
**Confidence:** HIGH — derived entirely from live codebase inspection (Phases 1-14 complete)

---

## Current Architecture Baseline (Post Phase 14)

All 14 phases complete. Live state:

- **OpenClaw gateway** at `localhost:18789`, launchd LaunchAgent, Node 24
- **Agents (10):** user-orchestrator, task-orchestrator, devbot, ci-monitor, email-triage, code-reviewer, document-reviewer, decision-reviewer, skill-reviewer, skill-creation
- **Each agent** has SOUL.md, AGENTS.md (most), TOOLS.md, USER.md, IDENTITY.md, SECURITY.md, MEMORY.md
- **Synapse loop (Phase 13):** All execution-tier agents have a Synapse section in TOOLS.md with brief.fetch, workflow.create, checkin, learning.record. The `synapse-checkin.sh` and `synapse-record-learning.sh` shared scripts exist. No `synapse-query-learnings.sh` exists — learning.query step is inline curl in task-orchestrator AGENTS.md only
- **Decision gate (Phase 11):** task-orchestrator sessions_spawn("decision-reviewer") before every autonomous action. Decision Reviewer applies a 4-item rubric (rationale soundness, reversibility specificity, evidence observability, action specificity). No risk tier classification exists
- **Email triage (Phase 14):** email-triage.sh (gogcli) fetches threads → agent categorizes into 5 buckets (Action Required, FYI, Automated-Noise, Newsletter, Unknown) → logs to memory/triage-YYYY-MM-DD.md → yields urgent items. No priority scoring, no auto-draft replies
- **Standup brief (Phase 14):** standup-brief.sh aggregates merged PRs, CI failures, stale PRs, Notion decision count, overnight email, calendar events. No blocker surfacing, no pattern detection
- **ci-monitor has no AGENTS.md** — it was designed as fully script-driven (poll-ci.sh runs the full cycle); no session startup loop defined
- **devbot AGENTS.md** has Synapse section in TOOLS.md but no explicit learning.query step before claiming Beads work

---

## Component Changes

| Component | New/Modified | Change |
|---|---|---|
| `email-triage` SOUL.md | Modified | Add priority scoring rubric (1-5 scale: sender signals, urgency keywords, reply-needed heuristics) and draft reply rules for Action Required items |
| `email-triage` AGENTS.md | Modified | Extend startup step 3 ("Load recent categorization context") to use 7-day memory window; extract sender patterns and false positive history before categorizing |
| `email-triage` TOOLS.md | Modified | Document extended triage output schema: `priority_score`, `draft_reply` fields per message in memory log |
| `scripts/synapse-query-learnings.sh` | **New** | Shell wrapper for `synapse.learning.query` POST — follows exact pattern of `synapse-checkin.sh`. Args: `<project_id> <tags_csv> <limit> <cross_silo>`. Returns `{"ok":true,"data":{"learnings":[...]}}`. Non-blocking (exit 0 on failure) |
| `ci-monitor` AGENTS.md | **New file** | ci-monitor has no AGENTS.md today. Create with session loop: Synapse brief.fetch → query learnings tagged `ci-monitor,github` → poll-ci.sh → record learning if new failure pattern detected |
| `ci-monitor` TOOLS.md | Modified | Add learning query step after brief.fetch: inject top 3 learnings into session context before poll-ci.sh |
| `devbot` AGENTS.md | Modified | Add Synapse learning.query step scoped to `devbot,github` tags before claiming Beads work |
| `scripts/standup-brief.sh` | Modified | Add `blockers` array (PRs with CHANGES_REQUESTED older than 48h) and `patterns` array (recurring CI workflow failures) to JSON output |
| `user-orchestrator` SOUL.md or AGENTS.md | Modified | Morning standup formatting: if `blockers` array non-empty, add "Blockers" section; if `patterns` non-empty, add "Patterns detected" section |
| `task-orchestrator` SOUL.md | Modified | Add risk tier computation table in "Notion Pre-Log Protocol" section: maps action verb to LOW/MEDIUM/HIGH; require `risk_tier` field in decision payload |
| `decision-reviewer` SOUL.md | Modified | Add risk-tier-aware rubric: HIGH requires all 4 rubric items explicitly present; LOW uses fast-path (non-empty rationale + specific action); MEDIUM uses current rubric |
| `decision-reviewer` TOOLS.md | Modified | Document `risk_tier` as optional input field (absent = MEDIUM); add: record Synapse learning for HIGH-risk reject verdicts tagged `decision-quality,risk-gate` |
| `scripts/verify-phase-15.sh` through `scripts/verify-phase-18.sh` | **New** | One verification script per phase (project convention from Phases 3-14) |

---

## Data Flow Changes

### Feature 1: Smarter Email Triage

**Current flow:**
```
cron → email-triage agent session
     → email-triage.sh (gogcli) → raw threads JSON
     → agent: categorize 5 buckets
     → write memory/triage-YYYY-MM-DD.md
     → urgent items → sessions_yield → user-orchestrator → Telegram
```

**New flow:**
```
cron → email-triage agent session
     → load memory/triage-*.md (last 7 days) → extract sender patterns, false-positive history
     → email-triage.sh (gogcli) → raw threads JSON
     → agent: categorize + assign priority_score (1-5) + draft reply for Action Required
     → write memory/triage-YYYY-MM-DD.md (extended schema: priority_score, draft_reply per message)
     → priority 4-5 (urgent) → sessions_yield → user-orchestrator → Telegram immediately
     → priority 2-3 (medium) → included in next standup brief batch
```

Priority scoring is LLM judgment in the agent turn, not in email-triage.sh. The script stays deterministic (gogcli fetch + JSON). Agent adds `priority_score` and `draft_reply` to its memory log entries.

### Feature 2: Cross-Agent Learning via Synapse

**Current state (task-orchestrator only):**
```
task-orchestrator session start
  → synapse.brief.fetch
  → synapse.learning.query (inline curl in AGENTS.md Step 1)
  → task begins
```

**New state (all execution-tier agents via shared script):**
```
ci-monitor session start
  → synapse.brief.fetch
  → synapse-query-learnings.sh project.agentic-setup "ci-monitor,github" 3 true
  → top 3 learnings prepended to session context
  → poll-ci.sh
  → if new failure type: synapse-record-learning.sh (already in Phase 13)

devbot session start
  → synapse.brief.fetch
  → synapse-query-learnings.sh project.agentic-setup "devbot,github" 3 true
  → learnings applied before claiming Beads work
```

The cross-agent learning circuit:
```
ci-monitor records: "Workflow 'unit-tests' fails on Node version mismatch in anujj-ti/repo"
  → tagged: ci-monitor, github, flaky
  → stored in Synapse

devbot session (next day):
  → queries: tags="devbot,github", cross_silo=true
  → receives the ci-monitor learning
  → applies: checks Node version context before creating issue about CI failure

standup-brief (morning):
  → patterns detection finds same workflow failing 3x in last-seen-runs.json
  → surfaced in patterns[] array
  → user sees: "Pattern: unit-tests failing repeatedly (3 occurrences)"
```

### Feature 3: Proactive Standup Insights

**Current flow:**
```
cron (7:30 IST) → user-orchestrator cron trigger
  → standup-brief.sh --repo OWNER/REPO
  → JSON: {merged_prs, ci_failures, stale_prs, decisions, overnight_email, calendar_events}
  → user-orchestrator formats → Telegram
```

**New flow:**
```
cron (7:30 IST) → user-orchestrator cron trigger
  → standup-brief.sh --repo OWNER/REPO
  → JSON: {
      merged_prs, ci_failures, stale_prs, decisions, overnight_email, calendar_events,
      blockers: [                                    ← NEW
        {number, title, updatedAt, reviewDecision, stuck_hours}
      ],
      patterns: [                                   ← NEW
        {workflow_name, failure_count, last_seen, signal}
      ]
    }
  → user-orchestrator formats with "Blockers" section + "Patterns detected" section → Telegram
```

Blocker detection is pure bash: `gh pr list` filtered by `updatedAt < (now - 48h)` AND `reviewDecision == CHANGES_REQUESTED`. Pattern detection is simple: cross-reference ci_failures `workflowName` against ci-monitor's `state/last-seen-runs.json` — if same workflow appears 3+ times, it is a pattern. All logic in standup-brief.sh, no new scripts.

### Feature 4: Decision Quality Risk Gate

**Current flow:**
```
task-orchestrator decides action
  → sessions_spawn("decision-reviewer", {action, rationale, reversibility, evidence})
  → decision-reviewer: apply 4-item rubric → {verdict: pass|flag|reject}
  → if pass: log-decision.sh → execute action
  → if reject: task-orchestrator retries with must_fix applied
```

**New flow:**
```
task-orchestrator decides action
  → compute risk_tier from action verb (rule table in SOUL.md):
      HIGH:   merge PR, send email, close issue, modify config, delete file
      MEDIUM: create issue, modify file, add label, comment on PR
      LOW:    read-only queries, status checks, list operations
  → sessions_spawn("decision-reviewer", {action, rationale, reversibility, evidence, risk_tier})
  → decision-reviewer: apply risk-tier-aware rubric:
      HIGH:   all 4 rubric items must be explicitly present (strict)
      MEDIUM: standard current rubric (unchanged)
      LOW:    fast-path — non-empty rationale + specific action = pass
  → if pass: log-decision.sh → execute action
  → if HIGH-risk reject: decision-reviewer records Synapse learning
      → tagged: decision-quality, risk-gate
      → claim: "action type X rejected for rubric item Y"
  → if reject (any tier): task-orchestrator retries with must_fix applied
```

Risk tier computation is a SOUL.md rule table (LLM classification, not a script). The decision payload gains `risk_tier`; decision-reviewer gains a tiered rubric section.

---

## Build Order

### Phase 15: Smarter Email Triage
**Rationale:** Fully self-contained. No new infrastructure, no Synapse changes, no script changes. Touches only email-triage SOUL.md and AGENTS.md. Delivers immediate visible value (fewer false positives, draft replies on Action Required). Can be verified by running the agent and inspecting memory/triage output. No risk to other agents.

**What changes:** email-triage SOUL.md, email-triage AGENTS.md, email-triage TOOLS.md (schema docs)

### Phase 16: Cross-Agent Learning Infrastructure
**Rationale:** Creates `synapse-query-learnings.sh` — the shared dependency. Must precede Phase 17 if standup wants to pull Synapse-sourced patterns. Wires the query step into ci-monitor (creates its AGENTS.md, which is a known gap) and devbot. Safe to build independently of Phase 15.

**What changes:** new `scripts/synapse-query-learnings.sh`, new `ci-monitor` AGENTS.md, `ci-monitor` TOOLS.md, `devbot` AGENTS.md

### Phase 17: Proactive Standup Insights
**Rationale:** Depends on Phase 16 (ci-monitor must be recording learnings for pattern surfacing to be meaningful). Pure bash additions to standup-brief.sh. No new scripts beyond what Phase 16 provides. User-orchestrator formatting prompt change is minimal.

**What changes:** `scripts/standup-brief.sh`, user-orchestrator SOUL.md or AGENTS.md (standup formatting)

### Phase 18: Decision Quality Risk Gate
**Rationale:** Last because it modifies the critical path for ALL autonomous actions. A misconfigured rubric here blocks all task execution. Build and verify after the other three are stable and in production.

**What changes:** `task-orchestrator` SOUL.md, `decision-reviewer` SOUL.md, `decision-reviewer` TOOLS.md

---

## Integration Points

### Feature 1 — Smarter Email Triage

| Hook | File | Change |
|------|------|--------|
| Session startup memory load | `email-triage` AGENTS.md step 3 | Expand from "load most recent file" to "load last 7 days, extract sender patterns + false-positive history" |
| Categorization loop | `email-triage` SOUL.md | Add priority scoring rules (1-5) and draft reply rules for Action Required items |
| Memory schema | `email-triage` TOOLS.md | Document `priority_score` and `draft_reply` fields as mandatory for Action Required entries |

No new scripts, no cron changes, no openclaw.json changes.

### Feature 2 — Cross-Agent Learning

| Hook | File | Change |
|------|------|--------|
| Shared scripts | `scripts/synapse-query-learnings.sh` | New file — mirrors synapse-checkin.sh pattern |
| ci-monitor session loop | `ci-monitor` AGENTS.md | New file — adds brief.fetch → query → poll-ci.sh → record learning |
| ci-monitor Synapse section | `ci-monitor` TOOLS.md | Add query step after brief.fetch |
| devbot session loop | `devbot` AGENTS.md | Add learning.query step before Beads claim |

No openclaw.json changes, no cron changes, no new agent directories.

### Feature 3 — Proactive Standup Insights

| Hook | File | Change |
|------|------|--------|
| Blocker detection | `scripts/standup-brief.sh` | Add `blockers` jq filter: stale_prs where `updatedAt < 48h ago AND reviewDecision == CHANGES_REQUESTED` |
| Pattern detection | `scripts/standup-brief.sh` | Add `patterns` computation: group ci_failures by workflowName, flag count >= 3 |
| Standup formatting | `user-orchestrator` SOUL.md or AGENTS.md | Add: "if blockers non-empty, include Blockers section; if patterns non-empty, include Patterns section" |

No new scripts, no cron changes, no openclaw.json changes.

### Feature 4 — Decision Quality Risk Gate

| Hook | File | Change |
|------|------|--------|
| Risk tier computation | `task-orchestrator` SOUL.md | Add risk tier table to "Notion Pre-Log Protocol": maps action verbs to LOW/MEDIUM/HIGH; mandate `risk_tier` in decision payload |
| Tiered rubric | `decision-reviewer` SOUL.md | Add risk-tier-aware rubric section |
| Input schema | `decision-reviewer` TOOLS.md | Document `risk_tier` as optional input field; add Synapse learning on HIGH-risk reject |

No new scripts, no cron changes, no openclaw.json changes.

---

## New vs Modified Summary

### New Files (4 total)
1. `scripts/synapse-query-learnings.sh` — shared Synapse query script, mirrors synapse-checkin.sh
2. `.openclaw/agents/ci-monitor/AGENTS.md` — ci-monitor session loop (currently missing)
3. `scripts/verify-phase-15.sh` through `scripts/verify-phase-18.sh` — 4 verification scripts (project convention)

### Modified Files (10 total)
1. `.openclaw/agents/email-triage/SOUL.md` — priority scoring rubric, draft reply rules
2. `.openclaw/agents/email-triage/AGENTS.md` — 7-day memory window in startup
3. `.openclaw/agents/email-triage/TOOLS.md` — extended memory schema documentation
4. `.openclaw/agents/ci-monitor/TOOLS.md` — learning query step in Synapse section
5. `.openclaw/agents/devbot/AGENTS.md` — learning query step before Beads claim
6. `scripts/standup-brief.sh` — blockers and patterns arrays
7. `.openclaw/agents/user-orchestrator/SOUL.md` or `AGENTS.md` — standup formatting
8. `.openclaw/agents/task-orchestrator/SOUL.md` — risk tier table in Notion Pre-Log Protocol
9. `.openclaw/agents/decision-reviewer/SOUL.md` — risk-tier-aware rubric
10. `.openclaw/agents/decision-reviewer/TOOLS.md` — risk_tier input field, Synapse learning on HIGH reject

### Not Changed
- `openclaw.json` — no new agents, no new cron jobs
- `cron/jobs.json` — no schedule changes
- Any agent's IDENTITY.md, SECURITY.md, USER.md — no identity changes
- devbot scripts, ci-monitor scripts — no script-level changes
- `scripts/log-decision.sh` and Notion log format — decision payload gains a field, script is unchanged
- Beads task graph structure — no changes
- Keychain entries — no new secrets needed (SYNAPSE_TOKEN already exists)

---

## Synapse Learning Feedback Loop

**The gap today:** Phase 13 wired all agents to record learnings and check in. But `synapse.learning.query` is only called inline in task-orchestrator AGENTS.md Step 1 — no other agent queries, and no shared script exists.

**The fix:** `synapse-query-learnings.sh` (Phase 16). Takes `<project_id> <tags_csv> <limit> <cross_silo>`. Agents call it in session startup, extract `claim` strings, prepend to working context as "Prior learnings from org memory."

**Token budget:** Query with `--limit 3`. At ~50 tokens per claim, 3 learnings = ~150 tokens overhead per session. Negligible.

**The feedback circuit at steady state:**
```
ci-monitor records → Synapse stores → devbot queries + applies
                                    → standup patterns surface
                                    → user sees insight without asking
```

This is the intelligence upgrade in concrete terms: agents stop repeating the same mistakes because they query what peer agents learned before starting work.

---

## No New Infrastructure Required

All 4 features are implementable within existing constraints:
- No new OpenClaw agents
- No new cron jobs
- No new services, databases, or external dependencies
- No openclaw.json structural changes
- No new Keychain entries (SYNAPSE_TOKEN already exists)
- No new Node.js scripts (email triage stays in agent turn; standup additions are bash)
- The one new script (`synapse-query-learnings.sh`) follows the exact pattern of 2 existing scripts

The only structurally new artifact is AGENTS.md for ci-monitor, which was always a gap — the agent was designed as fully script-driven in Phase 8 and never got a session loop definition.

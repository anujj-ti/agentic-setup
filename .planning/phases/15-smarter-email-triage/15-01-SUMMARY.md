---
phase: 15-smarter-email-triage
plan: 01
subsystem: agent-prompt
tags: [email-triage, priority-scoring, noise-suppression, draft-management, SOUL.md]

# Dependency graph
requires:
  - phase: 14-gogcli-google-suite-cli-install-gogcli-wire-gog-gmail-and-go
    provides: email-triage agent with SOUL.md, Gmail integration via gogcli, categorization pass
provides:
  - Priority scoring rules (1-5 scale, 5 weighted signals) encoded in SOUL.md
  - 20% Action Required cap enforcement with demotion logic in SOUL.md
  - pct_action_required/suppressed_count/demoted_count metrics logging rule
  - Hard no-send rule (NEVER call gog gmail send) encoded in SOUL.md
  - Draft file convention ([DRAFT — NOT SENT] on line 1) encoded in SOUL.md
  - Noise suppression rule with domain-suffix matching (no regex/glob)
affects: [15-smarter-email-triage, email-triage-agent, triage-memory-format]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "SOUL.md prompt additions for LLM behavioral rules — no new infrastructure required"
    - "Priority scoring co-located with categorization pass — single LLM call for both"
    - "Post-categorization enforcement loop for cap rule — demote lowest priority_score first"

key-files:
  created: []
  modified:
    - .openclaw/agents/email-triage/SOUL.md

key-decisions:
  - "D-151: Priority scoring is a SOUL.md prompt addition — same LLM pass as categorization, zero new infrastructure"
  - "D-152: Five weighted signals top-down; first match anchors score, lower signals can only raise"
  - "D-153: Score 5=VIP+urgent or P0; 4=Action Required with deadline; 3=Action Required; 2=FYI; 1=noise"
  - "D-154: Every email row must include priority_score in triage-YYYY-MM-DD.md; missing rows are an error"
  - "D-155/D-156/D-157: 20% cap enforced post-categorization; demote lowest priority_score; log three metrics"
  - "D-160: Hard NEVER rule against gog gmail send in triage flow; draft files only"
  - "T-15-03 mitigated: noise-senders.md uses domain suffix only, no regex/glob, documented in SOUL.md"

patterns-established:
  - "Priority scoring: five signals top-down, first match anchors, lower signals can only raise"
  - "Post-categorization enforcement: cap loops demote by ascending priority_score then arrival time"
  - "Draft convention: [DRAFT — NOT SENT] on line 1 of every draft file"
  - "Metrics logging: pct_action_required/suppressed_count/demoted_count always present even if zero"

requirements-completed: [TRIAGE-01, TRIAGE-02, TRIAGE-03]

# Metrics
duration: 1min
completed: 2026-05-22
---

# Phase 15 Plan 01: Smarter Email Triage — Priority Scoring + Cap Rules

**Priority scoring (1-5 scale), 20% Action Required cap with demotion logic, and hard no-send draft-only rule added to email-triage SOUL.md as LLM prompt additions — zero new infrastructure**

## Performance

- **Duration:** 1 min
- **Started:** 2026-05-22T09:13:57Z
- **Completed:** 2026-05-22T09:14:58Z
- **Tasks:** 2 (committed together, same file)
- **Files modified:** 1

## Accomplishments

- Added Priority Scoring section to SOUL.md with 5 weighted signals in descending order and unambiguous score 1-5 mapping (D-151, D-152, D-153)
- Mandated `priority_score` column in every triage-YYYY-MM-DD.md table row; missing rows are an error (D-154)
- Added Noise Suppression + 20% Cap section with post-categorization demotion loop and three required metrics fields (D-155, D-156, D-157)
- Added Draft Reply Rule: hard NEVER against `gog gmail send`, draft file convention with `[DRAFT — NOT SENT]` on line 1, and `drafts:` list in triage summary (D-160)
- Applied T-15-03 mitigation: noise-senders.md domain-suffix matching only (no regex/glob) documented inline

## Task Commits

Each task was committed atomically:

1. **Task 1 + Task 2: Add priority scoring, 20% cap, and draft no-send rules** - `237eb8c` (feat)

_Note: Both tasks modified the same file in a single edit operation; committed together with full task coverage documented in commit message._

## Files Created/Modified

- `.openclaw/agents/email-triage/SOUL.md` - Added three new rule sections: Priority Scoring (TRIAGE-01), Noise Suppression + 20% Cap (TRIAGE-02), Draft Reply Rule (TRIAGE-03)

## Decisions Made

- Both tasks modified the same SOUL.md file sequentially; committed as a single atomic change covering all plan deliverables
- T-15-03 threat mitigation (noise-senders.md wildcard abuse) applied inline in the Noise Suppression section per threat model requirement — domain suffix matching only, explicitly documented

## Deviations from Plan

None - plan executed exactly as written. Both tasks completed in single SOUL.md edit, committed atomically. Threat model mitigation T-15-03 applied as required.

## Issues Encountered

None.

## User Setup Required

None - no external service configuration required. SOUL.md is the only artifact; it takes effect on next email-triage agent run.

## Known Stubs

None. SOUL.md rules are complete prompt text — no placeholder content or TODOs.

## Threat Flags

No new security-relevant surface beyond the plan's threat model. T-15-03 mitigation (domain-suffix only, no regex) explicitly documented in SOUL.md Noise Suppression section.

## Next Phase Readiness

- SOUL.md ready for Phase 15 Plan 02 (AGENTS.md startup checklist additions for noise-senders.md read and processed-ids.jsonl check)
- Priority scoring rules are ready to be exercised once AGENTS.md wires the memory file reads
- Draft file convention established; Plan 03 can wire TOOLS.md reference to memory/drafts/ directory

---
*Phase: 15-smarter-email-triage*
*Completed: 2026-05-22*

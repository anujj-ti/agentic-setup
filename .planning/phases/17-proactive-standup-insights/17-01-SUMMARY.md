---
phase: 17-proactive-standup-insights
plan: "01"
subsystem: standup
tags: [jq, zsh, classification, standup, insights, ci, prs]

# Dependency graph
requires:
  - phase: 14-gogcli
    provides: standup-brief.sh JSON output schema (ci_failures, stale_prs, merged_prs)
provides:
  - scripts/standup-insights.sh — pure zsh+jq classifier turning standup JSON into Blocked/At Risk/On Track signals with ranked tackle-first list and pattern detection
affects:
  - 17-02 (user-orchestrator SOUL.md — will call standup-insights.sh for formatted Telegram output)
  - 17-03 (integration plan — pipes standup-brief.sh through standup-insights.sh)

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Classification-as-shell-script: deterministic signal rules in pure jq+zsh, no LLM in classification path"
    - "TZ=UTC date -j pattern for correct macOS BSD date parsing of UTC ISO8601 timestamps"
    - "tackle_first rank via jq _rank field injection + sort_by + del pattern"
    - "Pattern detection via jq group_by + length >= threshold filter"

key-files:
  created:
    - scripts/standup-insights.sh
    - scripts/test-standup-insights.sh
  modified: []

key-decisions:
  - "TZ=UTC required for BSD date -j parsing: GitHub timestamps are UTC but macOS date interprets without TZ prefix as local time (IST in this env = 5h30m offset), producing wrong epochs"
  - "Double sort_by removed in favour of single sort_by(._rank): jq sort_by(expr1 | not | not, expr2) does not take multiple arguments — only expr1 is evaluated, the rest become an unintended pipe"
  - "DoS mitigation applied (T-17-03): ci_failures loop limited to first 20 elements matching standup-brief.sh --limit cap"

patterns-established:
  - "TZ=UTC date -j: always set TZ=UTC when calling BSD date -j for parsing GitHub/ISO8601 UTC timestamps on macOS"
  - "jq rank-sort: inject _rank field, sort_by(._rank), slice, map(del(._rank)) for stable multi-criterion sort without multi-arg sort_by"

requirements-completed:
  - STANDUP-01
  - STANDUP-02
  - STANDUP-03

# Metrics
duration: 4min
completed: 2026-05-22
---

# Phase 17 Plan 01: Proactive Standup Insights Summary

**Pure zsh+jq standup classifier: Blocked/At Risk/On Track signals with ranked tackle-first list (capped at 5) and 3+-item pattern detection — zero LLM calls in classification path**

## Performance

- **Duration:** 4 min
- **Started:** 2026-05-22T12:10:07Z
- **Completed:** 2026-05-22T12:14:00Z
- **Tasks:** 1 (TDD: RED + GREEN)
- **Files modified:** 2 created (standup-insights.sh, test-standup-insights.sh)

## Accomplishments

- `scripts/standup-insights.sh`: reads standup-brief.sh JSON on stdin, emits JSON with `insights.classified_items`, `insights.tackle_first`, `insights.patterns`
- Deterministic classification: Blocked (ci_failures older than 2h), At Risk (stale_prs older than 24h with pending review), On Track (everything else including merged_prs)
- tackle_first ranked Blocked → At Risk → ci_failures On Track → On Track, capped at 5 items, always present as `[]` even when empty
- Pattern detection fires when 3+ items share a source prefix (ci_failures or stale_prs)
- 13/13 test cases pass; all 7 plan verification steps pass

## Task Commits

1. **RED — failing test suite** - `b58d4fe` (test)
2. **GREEN — standup-insights.sh implementation** - `66c8042` (feat)

## Files Created/Modified

- `/Users/trilogy/Documents/agentic-setup/scripts/standup-insights.sh` — classification engine: Blocked/At Risk/On Track, tackle_first, patterns
- `/Users/trilogy/Documents/agentic-setup/scripts/test-standup-insights.sh` — 13-test TDD suite covering all classification rules and edge cases

## Decisions Made

- **TZ=UTC for BSD date -j**: GitHub timestamps are UTC. macOS `date -j` without `TZ=UTC` interprets the timestamp in local time (IST in this environment = UTC+5:30), producing an epoch 5h30m too early, causing all recent items to appear older than 2h/24h thresholds and thus misclassified as Blocked/At Risk. Fix: `TZ=UTC date -j -f ...`.
- **Single sort_by(._rank)**: Initial implementation used `sort_by(expr | not | not, ._rank)` expecting multi-criterion sort. jq's `sort_by` takes a single expression; the `, ._rank` part was parsed as a pipe separator causing `Cannot index boolean with string "_rank"`. Removed the redundant first sort_by expression.
- **DoS mitigation cap at 20**: ci_failures loop limited to first 20 elements per threat T-17-03 (large array denial-of-service protection).

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Fixed double sort_by producing jq type error**
- **Found during:** Task 1 (GREEN phase — first test run)
- **Issue:** `sort_by(.status == "On Track" | not | not, ._rank) | sort_by(._rank)` — the comma inside `sort_by(...)` is not multi-criterion syntax in jq; it creates a pipe from the boolean result to `._rank`, causing `Cannot index boolean with string "_rank"` on any non-empty input
- **Fix:** Removed the redundant first `sort_by` expression, keeping only `sort_by(._rank)`
- **Files modified:** scripts/standup-insights.sh
- **Verification:** Tests T2-T6 which require non-empty classified_items all pass after fix
- **Committed in:** 66c8042 (GREEN task commit)

**2. [Rule 1 - Bug] Fixed UTC timezone for BSD date -j epoch parsing**
- **Found during:** Task 1 (GREEN phase — T8 failure: recent ci_failure showing as Blocked)
- **Issue:** `date -j -f '%Y-%m-%dT%H:%M:%S'` parses input in local timezone (IST = UTC+5:30). A timestamp 30 minutes in the past (UTC) is parsed as 5h30m further in the past than actual, exceeding the 2h Blocked threshold
- **Fix:** Changed `date -j` calls to `TZ=UTC date -j` in the `iso_to_epoch` helper function
- **Files modified:** scripts/standup-insights.sh
- **Verification:** T8 (recent ci_failure → On Track) passes; T13 (stale PR within 24h → On Track) also confirms stale_prs classification correct
- **Committed in:** 66c8042 (GREEN task commit — fixed before final commit)

---

**Total deviations:** 2 auto-fixed (both Rule 1 bugs)
**Impact on plan:** Both fixes required for correct classification. Without TZ=UTC fix, all items on any non-UTC machine would misclassify. No scope creep.

## Issues Encountered

- jq multi-criterion sort_by misunderstanding: documented in decisions; resolved in same task commit.
- macOS BSD date UTC parsing: documented in decisions; the TZ=UTC pattern is now established as a required convention for this codebase.

## User Setup Required

None — pure zsh+jq, no external services, no secrets required.

## Next Phase Readiness

- `standup-insights.sh` is ready to be piped from `standup-brief.sh` output
- Expected usage: `standup-brief.sh --repo OWNER/REPO | standup-insights.sh`
- Plan 17-02 will update User Orchestrator SOUL.md to call `standup-insights.sh` and format the Telegram standup message with Tackle First list + Patterns
- Plan 17-03 will wire the end-to-end integration

---
*Phase: 17-proactive-standup-insights*
*Completed: 2026-05-22*

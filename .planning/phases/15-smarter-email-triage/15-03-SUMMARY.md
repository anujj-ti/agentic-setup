---
phase: 15-smarter-email-triage
plan: "03"
subsystem: email-triage
tags: [email-triage, idempotency, noise-suppression, mark-read, processed-ids, AGENTS.md]

# Dependency graph
requires:
  - phase: 15-smarter-email-triage
    plan: "01"
    provides: SOUL.md priority scoring, noise suppression, and draft rules
  - phase: 15-smarter-email-triage
    plan: "02"
    provides: memory/noise-senders.md and memory/processed-ids.jsonl seed files
provides:
  - AGENTS.md startup checklist: load noise-senders.md step (D-155) with miss-handling (warn, not abort)
  - AGENTS.md startup checklist: load processed-ids.jsonl step (D-162) with parse-error handling (skip line, not abort)
  - AGENTS.md memory structure section updated with all four memory files
  - email-triage.sh: skip already-processed IDs using processed-ids.jsonl skip set (D-162)
  - email-triage.sh: append newly-processed IDs to processed-ids.jsonl after triage (D-162)
  - email-triage.sh: trim processed-ids.jsonl to 500 entries after append (D-163)
  - email-triage.sh: non-fatal gog gmail mark-read call after triage completes (D-161)
affects: [15-smarter-email-triage, email-triage-agent, triage-idempotency]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Dual-layer idempotency: mark-read (primary) + processed-ids.jsonl skip set (secondary guard)"
    - "Non-fatal mark-read: failure logged to stderr, JSONL guard handles next run transparently"
    - "JSONL append + tail-trim pattern for bounded log file growth (500-entry cap)"
    - "jq --argjson skip array for in-memory ID set intersection without external state"

key-files:
  created: []
  modified:
    - .openclaw/agents/email-triage/AGENTS.md
    - scripts/email-triage.sh

key-decisions:
  - "D-161: mark-read failure is non-fatal; stderr-only log; processed-ids.jsonl is the safety net"
  - "D-162: script reads processed-ids.jsonl directly via jq; filter applied before output JSON is assembled"
  - "D-163: tail -500 trim after every append run; mv-from-tmpfile to avoid partial writes"
  - "AGENTS.md step 2+3 inserted after auth check (step 1), before email-triage.sh existence check — memory is loaded before any triage execution begins"

patterns-established:
  - "processed-ids.jsonl as secondary idempotency guard: read at startup by agent + filtered in script"
  - "Non-fatal post-action cleanup: mark-read failure does not alter JSON stdout or exit code"
  - "JSONL trim via tail + mv-tmpfile pattern: atomic replace, no partial state"

requirements-completed: [TRIAGE-02, TRIAGE-04]

# Metrics
duration: 2min
completed: 2026-05-22
---

# Phase 15 Plan 03: Smarter Email Triage — Operational Wiring

**Idempotency and noise-suppression wired into AGENTS.md startup checklist (2 new steps) and email-triage.sh (skip-filter, JSONL append, 500-entry trim, non-fatal mark-read)**

## Performance

- **Duration:** 2 min
- **Started:** 2026-05-22T09:16:56Z
- **Completed:** 2026-05-22T09:19:04Z
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments

- Added noise-senders.md load step to AGENTS.md startup checklist (step 2): reads noise patterns from memory file, warns if missing but does not abort, builds `noise_sender_patterns` set (D-155)
- Added processed-ids.jsonl load step to AGENTS.md startup checklist (step 3): reads JSONL with per-line parse-error tolerance, builds `processed_id_set` for ID skip guard (D-162)
- Updated AGENTS.md Memory Structure section to reflect all four memory files: triage logs, noise-senders.md, processed-ids.jsonl, and drafts/
- Added processed-ids.jsonl skip logic to email-triage.sh: reads file directly via jq, filters threads array to exclude already-processed IDs before output (D-162)
- Added post-triage JSONL append: records each newly-processed message ID with ISO timestamp (D-162)
- Added 500-entry trim: atomic tail+mv-tmpfile after every append run (D-163)
- Added non-fatal gog gmail mark-read call: uses `is:unread newer_than:1d` query; failure logged to stderr only, does not affect JSON output (D-161)
- DRY_RUN mode skips append and mark-read steps (consistent with pre-existing dry-run behavior)
- T-15-06 (unbounded JSONL growth) mitigated: 500-entry cap enforced on every run
- T-15-07 (malformed JSONL injection): skip-invalid-line handling documented in AGENTS.md step 3

## Task Commits

Each task was committed atomically:

1. **Task 1: Update AGENTS.md startup checklist with noise-senders and processed-ids steps** - `6f8a70a` (feat)
2. **Task 2: Add mark-read, processed-ids append, and trim to email-triage.sh** - `38bfc41` (feat)

## Files Created/Modified

- `.openclaw/agents/email-triage/AGENTS.md` - Added startup checklist steps 2 and 3 (noise-senders and processed-ids); renumbered existing steps 2-3 to 4-7; updated Memory Structure section with all four memory files
- `scripts/email-triage.sh` - Added: processed-ids.jsonl skip-set load, threads filter, JSONL append, 500-entry trim, non-fatal mark-read call; DRY_RUN skips post-triage steps

## Decisions Made

- AGENTS.md new steps inserted at positions 2 and 3 (after auth check, before email-triage.sh existence check) — memory state must be loaded before execution begins
- Script reads processed-ids.jsonl directly via jq rather than receiving skip-set as an env var — simpler contract, no inter-process state passing needed
- mark-read query uses `is:unread newer_than:1d` (same query as the search) — marks exactly the window that was searched, not a broader scope
- `LOG_STDERR="/dev/stderr"` constant used for mark-read failure redirect — consistent with existing stderr pattern in the script

## Deviations from Plan

None - plan executed exactly as written. Both tasks completed as specified. All four D-16x decisions implemented. Threat model mitigations T-15-06 and T-15-07 applied as required.

## Issues Encountered

None.

## User Setup Required

None - no external service configuration required. Both AGENTS.md and email-triage.sh changes take effect on the next email-triage agent run.

## Known Stubs

None. All wiring is complete:
- AGENTS.md steps reference the actual file paths for noise-senders.md and processed-ids.jsonl (created in Plan 15-02)
- email-triage.sh reads and writes processed-ids.jsonl at the same paths the agent startup checklist uses

## Threat Flags

No new security-relevant surface beyond the plan's threat model. T-15-06 (unbounded JSONL growth) and T-15-07 (malformed JSONL injection) mitigated as specified in threat register.

## Self-Check: PASSED

- `6f8a70a` AGENTS.md commit: FOUND
- `38bfc41` email-triage.sh commit: FOUND
- `noise-senders.md` appears 4 times in AGENTS.md: VERIFIED
- `processed-ids.jsonl` appears 3 times in AGENTS.md: VERIFIED
- `mark-read` appears 5 times in email-triage.sh: VERIFIED
- `processed-ids.jsonl` appears 10 times in email-triage.sh: VERIFIED
- `tail -500` appears 1 time in email-triage.sh: VERIFIED
- `set -euo pipefail` preserved in email-triage.sh: VERIFIED
- `json_ok` output shape preserved in email-triage.sh: VERIFIED

## Next Phase Readiness

- email-triage agent is now fully idempotent: dual-layer guard (mark-read primary + JSONL secondary) prevents duplicate processing
- noise-senders.md patterns will be applied in categorization pass once agent is run
- Plan 15-04 (TOOLS.md update) can reference the memory/drafts/ directory and the new JSONL commands

---
*Phase: 15-smarter-email-triage*
*Completed: 2026-05-22*

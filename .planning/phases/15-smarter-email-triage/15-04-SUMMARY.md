---
phase: 15-smarter-email-triage
plan: "04"
subsystem: email-triage
tags: [email-triage, documentation, TOOLS.md, draft-management, idempotency, TRIAGE-03, TRIAGE-04]
dependency_graph:
  requires:
    - 15-01  # SOUL.md established [DRAFT — NOT SENT] convention
    - 15-02  # memory/drafts/ directory and processed-ids.jsonl seed files created
  provides:
    - Updated TOOLS.md with memory/drafts/ write permission documented
    - Draft reply file format spec with [DRAFT — NOT SENT] line-1 requirement
    - Processed-IDs Management section with format spec and trim command
    - Post-triage mark-read row in gog command reference table
  affects:
    - email-triage agent runtime behavior (agent now knows it may write to memory/drafts/ and manage processed-ids.jsonl)
tech_stack:
  added: []
  patterns:
    - "TOOLS.md as agent permission boundary — read/write policy enumerates all permitted memory/ paths explicitly"
    - "Documentation-only plan: behavioral logic lives in SOUL.md/AGENTS.md; TOOLS.md records permissions and formats"
key_files:
  created: []
  modified:
    - .openclaw/agents/email-triage/TOOLS.md
decisions:
  - "T-15-09 mitigated: write policy explicitly scoped to memory/ tree only, with 'Never write outside memory/ directory tree' directive"
  - "post-triage mark-read row added with non-fatal failure note — processed-ids.jsonl is the secondary guard (D-161)"
  - "parse-error policy documented: skip malformed lines, log to stderr, never abort triage run"
metrics:
  duration: "~1 minute"
  completed_date: "2026-05-22"
  tasks_completed: 1
  tasks_total: 1
  files_created: 0
  files_modified: 1
---

# Phase 15 Plan 04: TOOLS.md Documentation Update (Draft + Processed-IDs) Summary

**One-liner:** TOOLS.md extended with explicit memory/drafts/ write permission, draft file format spec, processed-ids.jsonl management section, and post-triage mark-read command row — agent permission boundary now matches Phase 15 capabilities.

## Performance

- **Duration:** ~1 min
- **Started:** 2026-05-22T09:17:14Z
- **Completed:** 2026-05-22T09:17:53Z
- **Tasks:** 1
- **Files modified:** 1

## Accomplishments

- Updated `## Available Tools` read/write bullet to list all four memory/ paths: triage log, noise-senders.md, processed-ids.jsonl, and memory/drafts/ draft files
- Extended `## Tool Policy` with full `memory/` directory tree grant enumerating all permitted subpaths, plus an explicit "Never write outside the memory/ directory tree" directive (T-15-09 mitigation)
- Added post-triage mark-read row to the gog gmail command reference table with non-fatal failure note referencing processed-ids.jsonl as secondary guard (D-161)
- Added `## Draft Reply File Format (TRIAGE-03)` section: path convention, required file structure with `[DRAFT — NOT SENT]` on line 1, idempotent overwrite rule, and creation trigger
- Added `## Processed-IDs Management (TRIAGE-04)` section: JSONL entry format, tail-500 trim command, manual recovery instructions, and parse-error policy (skip malformed lines, never abort)

## Task Commits

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Extend TOOLS.md with draft format, processed-ids, and mark-read reference | aa960ea | `.openclaw/agents/email-triage/TOOLS.md` |

## Verification Results

All plan verification checks passed (grep counts from final TOOLS.md):
- `memory/drafts/` occurrences: 3 (Available Tools, Tool Policy, Draft Format section)
- `processed-ids.jsonl` occurrences: 6 (Tool Policy, table, Processed-IDs section x4)
- `[DRAFT — NOT SENT]` occurrences: 2 (format block + rules bullet)
- `tail -500` occurrences: 1 (trim command)

## Deviations from Plan

None — plan executed exactly as written. All five sub-actions from the task specification were applied in a single atomic edit.

## Known Stubs

None. TOOLS.md is documentation text — no data wiring or placeholder content.

## Threat Flags

No new security-relevant surface beyond the plan's threat model.
- T-15-09 (Elevation of Privilege — TOOLS.md write policy too broad): mitigated by explicit "Never write outside the memory/ directory tree" directive in the updated Tool Policy section.

## Self-Check: PASSED

- `.openclaw/agents/email-triage/TOOLS.md`: FOUND (modified)
- Commit `aa960ea`: FOUND

---
*Phase: 15-smarter-email-triage*
*Completed: 2026-05-22*

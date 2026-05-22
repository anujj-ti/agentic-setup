---
phase: 15-smarter-email-triage
plan: "02"
subsystem: email-triage
tags: [memory-files, noise-suppression, idempotency, email-triage]
dependency_graph:
  requires: []
  provides:
    - .openclaw/agents/email-triage/memory/noise-senders.md
    - .openclaw/agents/email-triage/memory/processed-ids.jsonl
    - .openclaw/agents/email-triage/memory/drafts/
  affects:
    - Plans 15-03 and 15-04 (reference these files in AGENTS.md startup checklist and SOUL.md rules)
tech_stack:
  added: []
  patterns:
    - "memory/ directory convention: editable user-facing config files co-located with agent logs"
    - "Empty JSONL seed file as idempotency guard initial state"
key_files:
  created:
    - .openclaw/agents/email-triage/memory/noise-senders.md
    - .openclaw/agents/email-triage/memory/processed-ids.jsonl
    - .openclaw/agents/email-triage/memory/drafts/.gitkeep
  modified: []
decisions:
  - "D-155: noise-senders.md lives in memory/ not directive files — editable without stow redeploy"
  - "D-162: processed-ids.jsonl starts empty; agent appends after each successful triage run"
  - "D-158: drafts/ directory created now so Plan 15-03 SOUL.md rule has a valid target path"
metrics:
  duration: "~5 minutes"
  completed_date: "2026-05-22"
  tasks_completed: 2
  tasks_total: 2
  files_created: 3
  files_modified: 0
---

# Phase 15 Plan 02: Memory Seed Files Summary

**One-liner:** Created noise-senders.md (22 seeded patterns) and empty processed-ids.jsonl as the idempotency guard seed file, plus memory/drafts/ directory for future draft reply storage.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Create memory/noise-senders.md with seeded noise patterns | 4e003c3 | `.openclaw/agents/email-triage/memory/noise-senders.md` |
| 2 | Create memory/processed-ids.jsonl as empty guard file | 302df84 | `.openclaw/agents/email-triage/memory/processed-ids.jsonl`, `.openclaw/agents/email-triage/memory/drafts/.gitkeep` |

## What Was Built

### noise-senders.md
Seeded with 22 non-comment, non-empty patterns across 5 categories:
- GitHub automated notifications (3 patterns)
- CI/CD systems (4 patterns)
- Generic no-reply prefix patterns (4 patterns: `noreply@`, `no-reply@`, `donotreply@`, `do-not-reply@`)
- Marketing and newsletters (4 patterns)
- Monitoring/alerting systems (4 patterns: `alerts@`, pagerduty.com, opsgenie.com, statuspage.io)
- Package registries and dependency bots (3 patterns)

Format header is included explaining one-per-line rule, prefix-match semantics, and the D-155 no-stow-redeploy design.

### processed-ids.jsonl
Created as a zero-byte empty file. Valid empty JSONL (zero records). Future entries will follow the format: `{"id":"<messageId>","processedAt":"<ISO8601>"}`. Trimmed to 500 entries per run per D-163.

### memory/drafts/
Directory tracked via `.gitkeep` for Plan 15-03's draft reply file destination (`memory/drafts/YYYY-MM-DD-<messageId>.md`).

## Verification Results

All plan verification checks passed:
- `noise-senders.md` exists at correct path
- `processed-ids.jsonl` exists at correct path (0 bytes)
- `memory/drafts/` directory exists
- 22 non-comment, non-empty lines (plan requires >= 5)

## Deviations from Plan

None — plan executed exactly as written.

## Known Stubs

None. These are seed/initial-state files; no data wiring is needed for them to serve their purpose. Plans 15-03 and 15-04 will add the agent logic that reads these files.

## Threat Flags

None. Both files are local disk files with no network exposure:
- `noise-senders.md` is user-editable; T-15-04 is accepted (recoverable by editing file)
- `processed-ids.jsonl` corruption mitigation (T-15-05) is deferred to Plan 15-03 AGENTS.md where the parse-error handling will be implemented

## Self-Check: PASSED

- `.openclaw/agents/email-triage/memory/noise-senders.md`: FOUND
- `.openclaw/agents/email-triage/memory/processed-ids.jsonl`: FOUND
- `.openclaw/agents/email-triage/memory/drafts/`: FOUND
- Commit `4e003c3`: FOUND (Task 1)
- Commit `302df84`: FOUND (Task 2)

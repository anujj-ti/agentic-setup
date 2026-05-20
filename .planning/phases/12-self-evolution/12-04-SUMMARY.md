---
phase: 12-self-evolution
plan: "04"
subsystem: experiment-framework
---

# Phase 12 Plan 04: Experiment Framework Scripts Summary

## One-liner

propose-experiment.js (validates all fields with measurable criteria check) and create-experiment-page.js (Notion experiment page with Status=Draft, exits 1 without env vars) implement EVOL-03 Stage 1.

## Tasks Completed

| Task | Description | Status |
|------|-------------|--------|
| 1 | Install @notionhq/client and create propose-experiment.js, create-experiment-page.js | Done |
| 2 | Update TOOLS.md with experiment framework documentation | Done |

## Self-Check: PASSED

- Both scripts pass node --check
- propose-experiment.js validation works (exits 1 on missing args)
- create-experiment-page.js exits 1 with JSON error when OPENCLAW_NOTION_TOKEN absent
- TOOLS.md has OPENCLAW_NOTION_EXPERIMENTS_DB_ID references (count: 3)
- Commit 8666f8b exists

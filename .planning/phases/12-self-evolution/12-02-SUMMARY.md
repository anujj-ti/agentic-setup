---
phase: 12-self-evolution
plan: "02"
subsystem: check-agent-domain
---

# Phase 12 Plan 02: check-agent-domain.sh and TOOLS.md Summary

## One-liner

check-agent-domain.sh returns ok:false when domain already covered (devbot test passes), TOOLS.md has 6-step EVOL-01 workflow with mandatory routing update step.

## Tasks Completed

| Task | Description | Status |
|------|-------------|--------|
| 1 | Create check-agent-domain.sh | Done |
| 2 | Update TOOLS.md with EVOL-01 workflow and proposal template | Done |

## Self-Check: PASSED

- check-agent-domain.sh syntax check passes
- Running with "devbot": ok=false
- Running with "database-monitor": ok=true
- TOOLS.md has New Agent Proposal template
- TOOLS.md has MANDATORY step 6 (routing update)
- Commit da5cea9 exists

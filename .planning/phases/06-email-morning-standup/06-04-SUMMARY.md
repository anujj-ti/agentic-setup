---
phase: 06-email-morning-standup
plan: "04"
subsystem: standup-brief
tags: [standup, github, gh-cli, cron, scripts]
dependency_graph:
  requires: []
  provides: [standup-brief-script, user-orchestrator-exec-tool]
  affects: [scripts/standup-brief.sh, .openclaw/agents/user-orchestrator/TOOLS.md, .openclaw/openclaw.json]
tech_stack:
  added: []
  patterns: [json-response-pattern, bsd-date, explicit-binary-paths, zsh-strict-mode]
key_files:
  created:
    - scripts/standup-brief.sh
  modified:
    - .openclaw/agents/user-orchestrator/TOOLS.md
    - .openclaw/openclaw.json
decisions:
  - "D-65: exec added to user-orchestrator tools.alsoAllow — CRON sessions only per TOOLS.md policy"
  - "Explicit /opt/homebrew/bin/gh and /opt/homebrew/bin/jq paths prevent nvm/PATH shadowing"
  - "BSD date format (date -u -v-24H) per CLAUDE.md macOS-only constraint"
  - "CRON SESSIONS ONLY exec exception documented in TOOLS.md with explicit policy statement"
metrics:
  duration: "~6 minutes"
  completed: "2026-05-21"
  tasks: 2
  files: 3
---

# Phase 06 Plan 04: Morning Standup Script + User Orchestrator Exec Tool Summary

standup-brief.sh created (executable, zsh strict-mode, --repo argument, BSD date, json_ok output). exec tool added to user-orchestrator openclaw.json and TOOLS.md updated with CRON-ONLY policy and standup-brief.sh invocation pattern.

## Tasks Completed

| Task | Description | Status |
|------|-------------|--------|
| 1 | Create standup-brief.sh + verify json-response.sh lib | DONE |
| 2 | Add exec to user-orchestrator in openclaw.json + update TOOLS.md | DONE |

## Artifacts Created/Modified

### scripts/standup-brief.sh

- Shebang: `#!/usr/bin/env zsh`; strict mode: `set -euo pipefail`
- Sources `$(dirname "$0")/lib/json-response.sh` for `json_ok`/`json_fail`
- `--repo OWNER/REPO` required argument; fails with `json_fail` if missing
- Explicit binary paths: `GH=/opt/homebrew/bin/gh`, `JQ=/opt/homebrew/bin/jq`
- Three gh queries with `2>/dev/null || '[]'` fallback:
  1. Merged PRs: `gh pr list --state merged --search "merged:>..."` (BSD date `-v-24H`)
  2. CI failures: `gh run list --status failure --limit 10`
  3. Stale PRs: `gh pr list --state open` piped through `jq` filter (reviewRequests > 0 or CHANGES_REQUESTED)
- Output: `json_ok` with `{repo, as_of, merged_prs, ci_failures, stale_prs}`

### .openclaw/openclaw.json — user-orchestrator updated

```json
"tools": { "alsoAllow": ["sessions_spawn", "sessions_yield", "exec"] }
```

### .openclaw/agents/user-orchestrator/TOOLS.md — updated

- exec added to Available Tools list (CRON SESSIONS ONLY annotation)
- Tool Policy updated: "exec MAY be used in cron-initiated isolated sessions to call standup-brief.sh"
- New "Standup Script Invocation" section with exact invocation command, JSON parsing instructions, Telegram format guidelines

## Verification Results

```
PASS: standup-brief.sh syntax valid (zsh -n)
PASS: standup-brief.sh executable
PASS: json_ok present
PASS: --repo arg handling
PASS: explicit gh path at /opt/homebrew/bin/gh
PASS: BSD date -v-24H format (comment + actual call — 2 occurrences; code is correct)
PASS: user-orchestrator has exec + sessions_spawn + sessions_yield in tools.alsoAllow
PASS: standup-brief.sh referenced in user-orchestrator TOOLS.md
PASS: CRON policy note in TOOLS.md
```

Note: BSD date check expected exactly 1 occurrence but found 2 (comment + actual call). Code is correct; the comment documents the pattern.

## Deviations from Plan

None — plan executed exactly as written.

## Threat Surface Scan

New execution surface: exec tool now available to user-orchestrator. Threat T-06-11 mitigated: TOOLS.md explicitly restricts exec to CRON sessions + standup-brief.sh only. SOUL.md "you do not run code" boundary preserved with explicit exception clause.

## Self-Check: PASSED

standup-brief.sh exists, executable, syntax valid. openclaw.json has exec in user-orchestrator.tools.alsoAllow. TOOLS.md contains standup-brief.sh and CRON policy note.

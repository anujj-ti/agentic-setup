---
phase: 16-cross-agent-learning-infrastructure
reviewed: 2026-05-22T00:00:00Z
depth: standard
files_reviewed: 9
files_reviewed_list:
  - scripts/synapse-query-learnings.sh
  - scripts/verify-phase-16.sh
  - .openclaw/agents/ci-monitor/AGENTS.md
  - .openclaw/agents/ci-monitor/DREAM-ROUTINE.md
  - .openclaw/agents/devbot/AGENTS.md
  - .openclaw/agents/devbot/DREAM-ROUTINE.md
  - .openclaw/agents/task-orchestrator/AGENTS.md
  - .openclaw/agents/task-orchestrator/DREAM-ROUTINE.md
  - .openclaw/agents/email-triage/AGENTS.md
findings:
  critical: 3
  warning: 5
  info: 2
  total: 10
status: issues_found
---

# Phase 16: Code Review Report

**Reviewed:** 2026-05-22T00:00:00Z
**Depth:** standard
**Files Reviewed:** 9
**Status:** issues_found

## Summary

Phase 16 introduces a shared `synapse-query-learnings.sh` script and wires it into four agents (task-orchestrator, devbot, ci-monitor, email-triage) as a mandatory startup step, with nightly dream routines in ci-monitor and devbot gaining cross-silo Synapse sections. The non-blocking contract (D-304) is the most load-bearing correctness invariant: Synapse unavailability must never stall an agent.

Three blockers were found. The most severe is that every agent invokes the shared script with `bash` while the script is written for `zsh` and uses the `print` builtin, which does not exist in bash. This breaks the D-304 guarantee in the exact failure modes it was designed to protect against (missing token, network error). The verification test CHECK 2 masks the defect by using `zsh` instead of `bash`, so the test passes while the runtime fails. The second blocker is that `python3` failures (missing interpreter, invalid LIMIT, crash) inside the script are not caught — `set -euo pipefail` propagates the non-zero exit to the caller, again violating D-304. The third blocker is a shell-injection / broken-quoting pattern in task-orchestrator AGENTS.md that corrupts the artifact upload any time a task title or summary contains an apostrophe.

---

## Critical Issues

### CR-01: Script is written for zsh but every agent invokes it with `bash` — `print` builtin is undefined, breaking D-304

**Files:**
- `scripts/synapse-query-learnings.sh:1` (shebang `#!/usr/bin/env zsh`, uses `print` at lines 11-13, 23, 45-47)
- `.openclaw/agents/ci-monitor/AGENTS.md:9-12` (`bash ~/Documents/agentic-setup/scripts/synapse-query-learnings.sh`)
- `.openclaw/agents/ci-monitor/DREAM-ROUTINE.md:41-43` (same)
- `.openclaw/agents/devbot/AGENTS.md:9,13` (same)
- `.openclaw/agents/devbot/DREAM-ROUTINE.md:13,15` (same)
- `.openclaw/agents/task-orchestrator/AGENTS.md:28,30` (same)
- `.openclaw/agents/task-orchestrator/DREAM-ROUTINE.md:14` (same)
- `.openclaw/agents/email-triage/AGENTS.md:10` (same)
- `scripts/verify-phase-16.sh:38` (uses `zsh`, masking the defect)

**Issue:** The script uses the `print` builtin (a zsh built-in, not available in bash) on lines 11-13, 23, 45, 46, 47. When bash executes these lines, it fails with `bash: print: command not found` (exit 127). Because the script has `set -euo pipefail`, any such failure terminates the script with a non-zero exit code. The two most important non-blocking paths — the empty-token guard (line 23) and the curl-failure fallback (lines 45-47) — both trigger `print` calls, so the failure happens precisely when Synapse is unavailable. This directly violates D-304.

The verification test at `verify-phase-16.sh:38` uses `zsh` to invoke the script while all agent call-sites use `bash`, so CHECK 2 passes but the runtime behavior is broken.

**Fix — option A (recommended): change all agent call-sites from `bash` to `zsh`:**
```zsh
SYNAPSE_CI=$(zsh ~/Documents/agentic-setup/scripts/synapse-query-learnings.sh \
  project.agentic-setup ci 3 2>/dev/null)
```
Apply to all eight call-sites across ci-monitor/AGENTS.md, ci-monitor/DREAM-ROUTINE.md, devbot/AGENTS.md, devbot/DREAM-ROUTINE.md, task-orchestrator/AGENTS.md, task-orchestrator/DREAM-ROUTINE.md, email-triage/AGENTS.md.

**Fix — option B: replace `print` with `echo` or `printf` in synapse-query-learnings.sh so it runs under both shells:**
```zsh
# Replace all shell-level "print" calls with "printf '%s\n'"
# Line 23:
printf '%s\n' "synapse-query-learnings: SYNAPSE_TOKEN not set — skipping" >&2
# Lines 45-47:
printf '%s\n' "synapse-query-learnings: curl failed — Synapse unreachable or auth error" >&2
printf '%s\n' "# Synapse Learnings: ${TAG}"
printf '%s\n' "(unavailable)"
```
Also fix `verify-phase-16.sh:38` to use `bash` to mirror what agents actually do:
```zsh
SYNAPSE_TOKEN="" bash "$QUERY_SH" project.agentic-setup openclaw 5 2>/dev/null
```

---

### CR-02: Unguarded `python3` calls inside `synapse-query-learnings.sh` exit non-zero under `set -euo pipefail`, violating D-304

**File:** `scripts/synapse-query-learnings.sh:30-39` (BODY assignment), `52-81` (parsing block)

**Issue:** Two `python3` sub-process calls have no `|| { ... exit 0 }` error handler.

1. **BODY assignment (lines 30-39):** `BODY=$(python3 -c "... int(sys.argv[3]) ..." "$PROJECT_ID" "$TAG" "$LIMIT")`. If `python3` is not installed, or `$LIMIT` is a non-integer string (e.g., a future caller passes a variable that ends up empty or "abc"), `python3` exits 1. Under `set -euo pipefail`, the script immediately exits 1 — breaking D-304.

2. **Parsing block (lines 52-81):** `python3 -c "..." "$TAG" "$RESULT"`. If `python3` crashes (e.g., `$RESULT` is too large for `argv`, or a code path raises an unhandled exception), the script exits non-zero.

Both cases propagate to agents as a blocking exit, when the spec says the script must exit 0 on all non-argument errors.

**Fix:**
```zsh
# Wrap BODY assignment:
BODY=$(python3 -c "
import sys, json
p, t, lim = sys.argv[1], sys.argv[2], int(sys.argv[3])
body = {'project_id': p, 'applies_to': [t], 'limit': lim}
print(json.dumps(body))
" "$PROJECT_ID" "$TAG" "$LIMIT") || {
  print "synapse-query-learnings: python3 failed building request body" >&2
  exit 0
}

# Wrap parsing block:
python3 -c "..." "$TAG" "$RESULT" || {
  print "synapse-query-learnings: python3 failed parsing response" >&2
  print "# Synapse Learnings: ${TAG}"
  print "(unavailable)"
  exit 0
}
```
Also add LIMIT validation before passing to python3:
```zsh
# After line 19:
if ! [[ "$LIMIT" =~ ^[0-9]+$ ]]; then
  print "synapse-query-learnings: LIMIT must be a positive integer, got: $LIMIT" >&2
  exit 0
fi
```

---

### CR-03: Shell variable interpolated inside `python3 -c` byte-literal in task-orchestrator AGENTS.md — single quote in task title corrupts artifact upload

**File:** `.openclaw/agents/task-orchestrator/AGENTS.md:143-144`

**Issue:**
```zsh
SUMMARY="Task: <title>\nResult: <what was built/done>\nDeviations: <any>"
SUMMARY_B64=$(python3 -c "import base64; print(base64.b64encode(b'$SUMMARY').decode())")
```
`$SUMMARY` is expanded by the shell before python3 sees it, and the result is embedded inside the Python byte-literal `b'...'`. If `$SUMMARY` contains a single quote (e.g., task title "Fix it's broken"), the Python source becomes `b'Task: Fix it's broken'`, which is a `SyntaxError`. The artifact upload is silently skipped (or the whole Step 7 block exits non-zero under `set -e`), losing the Synapse learning record for that task run. Real task titles from GitHub issues, PR descriptions, and email subjects routinely contain apostrophes.

**Fix — use stdin instead of interpolation:**
```zsh
SUMMARY="Task: <title>\nResult: <what was built/done>\nDeviations: <any>"
SUMMARY_B64=$(printf '%s' "$SUMMARY" | python3 -c "import sys,base64; print(base64.b64encode(sys.stdin.buffer.read()).decode())")
```
This eliminates the quoting issue entirely because the data travels through stdin, not through shell string interpolation.

---

## Warnings

### WR-01: `verify-phase-16.sh` mixes human-readable text and JSON on stdout, breaking machine parsability

**File:** `scripts/verify-phase-16.sh:22-23, 126-127, 130, 133`

**Issue:** The `pass()` and `fail()` functions (lines 22-23) print `CHECK N (...): PASS/FAIL` to stdout. Lines 126-127 print a blank line and a summary sentence to stdout. The JSON payload then follows on lines 130 or 133, also on stdout. A caller capturing output with `RESULT=$(zsh verify-phase-16.sh)` and running `jq '.ok'` against it will fail because the output is not valid JSON. CLAUDE.md specifies stdout must be JSON only; human-readable logs go to stderr.

**Fix:** Redirect the non-JSON output to stderr:
```zsh
pass() { print "CHECK $1 ($2): PASS" >&2; PASS=$(( PASS + 1 )) }
fail() { print "CHECK $1 ($2): FAIL — $3" >&2; FAIL=$(( FAIL + 1 )) }
# ...
print "" >&2
print "Phase 16 verification: $((PASS))/$((PASS + FAIL)) checks passed" >&2
# The JSON lines (130, 133) stay on stdout — they are already correct.
```

---

### WR-02: Cross-silo tag mismatch — devbot queries `ci-monitor` tag but ci-monitor never writes with that tag

**Files:**
- `.openclaw/agents/devbot/AGENTS.md:13` (queries tag `ci-monitor`)
- `.openclaw/agents/devbot/DREAM-ROUTINE.md:15` (queries tag `ci-monitor`)
- `.openclaw/agents/ci-monitor/TOOLS.md:108` (uses placeholder `<domain-tag>`)
- `.openclaw/agents/ci-monitor/DREAM-ROUTINE.md:41-43` (queries `ci` and `github` — never writes)

**Issue:** The LEARN-02 cross-silo benefit is that devbot reads CI Monitor learnings to inform PR triage. DevBot queries the `ci-monitor` tag, but CI Monitor's TOOLS.md instructs the agent to record learnings with `"openclaw,<domain-tag>"` where `<domain-tag>` is a fill-in-the-blank placeholder. Nothing in the ci-monitor agent definition establishes `ci-monitor` as the tag it writes with. In practice, CI Monitor will likely write with `ci` or `openclaw`, and DevBot's cross-silo query will return zero results indefinitely. CHECK 7 in verify-phase-16.sh only tests for the string `ci-monitor` appearing anywhere in devbot/AGENTS.md — it does not verify the learning is actually receivable.

**Fix:** Add an explicit domain-tag specification to the ci-monitor learning recording instructions:
```markdown
# In .openclaw/agents/ci-monitor/TOOLS.md (Step 3 learning record):
bash ~/Documents/agentic-setup/scripts/synapse-record-learning.sh \
  project.agentic-setup "$BD_ID" \
  "non-obvious reusable insight about CI failure pattern" \
  "ci-monitor,ci,openclaw"
```
The `ci-monitor` tag must be included so devbot's cross-silo query returns results.

---

### WR-03: `SYNAPSE_TOKEN` value is visible in process listing via `curl -H "Authorization: Bearer $SYNAPSE_TOKEN"`

**File:** `scripts/synapse-query-learnings.sh:42-43`

**Issue:**
```zsh
RESULT=$(/usr/bin/curl -sS -X POST "${SYNAPSE_URL}/..." \
  -H "Authorization: Bearer $SYNAPSE_TOKEN" \
```
The Synapse token is passed as a curl `-H` argument. On a multi-user system or with process monitoring tools, `ps aux` reveals the full command line including the header value, exposing the bearer token. This is a lower severity concern on a single-user macOS machine, but the project's security model (Keychain only, never in logs) is violated when the token appears in the process table.

**Fix:** Use curl's `--oauth2-bearer` flag or pass credentials via a config file or stdin:
```zsh
RESULT=$(/usr/bin/curl -sS -X POST "${SYNAPSE_URL}/..." \
  --oauth2-bearer "$SYNAPSE_TOKEN" \
  -H "Content-Type: application/json" \
  -d "$BODY" 2>/dev/null)
```
Or use `--config -` to pass headers via stdin to prevent token appearing in `ps` output.

---

### WR-04: task-orchestrator DREAM-ROUTINE `Pattern Counter` preservation rule creates an irresolvable conflict with the 2,500-token hard cap

**File:** `.openclaw/agents/task-orchestrator/DREAM-ROUTINE.md:11, 60-67`

**Issue:** Line 11 states: "NEVER generate a distillation longer than 2,500 tokens. If you find yourself about to exceed this limit, truncate and stop." Lines 60-67 state: "The Pattern Counter MUST be preserved verbatim... Do NOT compress the table rows... This section is protected... NEVER subject it to the distillation logic." The only resolution given is "compress OTHER sections first" (line 67), but if the Pattern Counter itself grows to approach or exceed 2,500 tokens (unbounded table growth over many weeks), both rules cannot be satisfied simultaneously. An LLM agent facing this conflict will resolve it inconsistently — sometimes violating the token budget, sometimes silently truncating the protected section.

**Fix:** Add an explicit upper size limit for the Pattern Counter section itself:
```markdown
## Pattern Counter Preservation (EVOL-02 — MANDATORY)
...
**Hard limit:** The Pattern Counter section MUST NOT exceed 500 tokens. If it approaches 500 tokens, merge rows with count < 3 into an `Other patterns` catch-all row before copying. This keeps the section preservable within any budget scenario.
```

---

### WR-05: `task-orchestrator` AGENTS.md and DREAM-ROUTINE.md use `project.edullm-sat-math` while all other agents use `project.agentic-setup` — cross-agent learning is siloed by project ID

**Files:**
- `.openclaw/agents/task-orchestrator/AGENTS.md:15,29,31,68,149,157,171` (uses `project.edullm-sat-math`)
- `.openclaw/agents/task-orchestrator/DREAM-ROUTINE.md:15` (uses `project.edullm-sat-math`)
- `.openclaw/agents/devbot/AGENTS.md:10,14`, `.openclaw/agents/ci-monitor/AGENTS.md:10,12`, `.openclaw/agents/email-triage/AGENTS.md:11` (use `project.agentic-setup`)

**Issue:** Synapse stores learnings scoped to a project ID. Task Orchestrator records all its learnings under `project.edullm-sat-math`. When DevBot and CI Monitor query `project.agentic-setup`, they will never see learnings recorded by Task Orchestrator, and vice versa. The phase's cross-agent learning goal (LEARN-01, LEARN-02) is only partially achieved. CLAUDE.md acknowledges this inconsistency ("will be unified in a future phase") but it is a functional gap in the current implementation — not merely cosmetic — because the cross-silo learning path is broken for any task orchestrator learnings.

**Fix:** Update task-orchestrator AGENTS.md and DREAM-ROUTINE.md to use `project.agentic-setup` consistently with all other agents. The note in CLAUDE.md acknowledging the discrepancy confirms this is a known deferred item — it should be resolved now that the learning infrastructure is being wired.

---

## Info

### IN-01: `synapse-query-learnings.sh` passes `$RESULT` as a shell argument (`sys.argv[2]`) rather than via stdin — fragile for large payloads

**File:** `scripts/synapse-query-learnings.sh:81`

**Issue:** The full curl response is passed to the Python parsing block as a command-line argument: `python3 -c "..." "$TAG" "$RESULT"`. While the macOS `ARG_MAX` is 1 MB and this is unlikely to be exceeded with `limit=5`, passing potentially large JSON blobs through `argv` is a fragile pattern. A Synapse API change that returns verbose metadata per learning could silently approach or exceed the limit. The idiomatic pattern for this kind of data handoff is stdin.

**Fix:**
```zsh
# Replace the final python3 block (lines 52-81):
printf '%s' "$RESULT" | python3 -c "
import sys, json
tag = sys.argv[1]
raw = sys.stdin.read()
# ... rest of parsing logic unchanged ...
" "$TAG"
```

---

### IN-02: `verify-phase-16.sh` does not test the email-triage DREAM-ROUTINE for the 500-token Synapse cap (no DREAM-ROUTINE.md exists for email-triage)

**File:** `scripts/verify-phase-16.sh:79-88`

**Issue:** Checks 9 and 10 verify that ci-monitor and devbot have DREAM-ROUTINE.md files (LEARN-04). Email-triage has no DREAM-ROUTINE.md and no corresponding check. The phase plan (LEARN-04) targets ci-monitor and devbot specifically, so this is not an outright omission from the phase spec, but it means the email-triage agent has no dream routine with the 500-token cap constraint, no MEMORY.md for cross-silo learnings, and no long-term pattern accumulation. Future phases adding email-triage dream functionality will lack a structural baseline. Document this gap in the phase context if it is intentional scope deferral.

**Fix (documentation only):** Add a comment to `verify-phase-16.sh` noting that email-triage dream routine is out of scope for Phase 16:
```zsh
# NOTE: email-triage DREAM-ROUTINE.md is out of scope for Phase 16 (LEARN-04 covers ci-monitor and devbot only).
# Phase 17+ should add email-triage dream routine with the D-311 Synapse cap.
```

---

_Reviewed: 2026-05-22T00:00:00Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_

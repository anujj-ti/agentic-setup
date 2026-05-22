---
phase: 15-smarter-email-triage
reviewed: 2026-05-22T12:00:00Z
depth: quick
files_reviewed: 4
files_reviewed_list:
  - scripts/email-triage.sh
  - .openclaw/agents/email-triage/SOUL.md
  - .openclaw/agents/email-triage/AGENTS.md
  - .openclaw/agents/email-triage/TOOLS.md
findings:
  critical: 0
  warning: 2
  info: 1
  total: 3
status: issues_found
---

# Phase 15: Code Review Report (Final Pass)

**Reviewed:** 2026-05-22T12:00:00Z
**Depth:** quick
**Files Reviewed:** 4
**Status:** issues_found

## Summary

Final-pass review after two rounds of fixes. All previously-confirmed blockers are resolved:

- SOUL.md Responsibility 1: now correctly names `email-triage.sh` via gogcli (line 11) — confirmed clean
- SOUL.md Operational Rule 1: legacy OAuth2 env var requirement removed; Rule 1 now documents gogcli token management — confirmed clean
- SOUL.md Operational Rule 4: now instructs exec of `scripts/email-triage.sh` — confirmed clean
- AGENTS.md steps 5 and 6: now labeled `[Legacy — skip on gogcli path]` with no unconditional Stop directives — confirmed clean
- `email-triage.sh` dead `SKIP_IDS` variable: not present in current file — confirmed clean

No secrets, dangerous functions, debug artifacts, or empty catch blocks found via pattern scan.

Three residual findings remain. Two are warnings: TOOLS.md line 23 still grants exec permission to `gmail-triage.js` as a named allowed command, which contradicts the exec-is-for-email-triage-sh-only policy; and `email-triage.sh` line 98 re-expands `${OPENCLAW_GMAIL_ACCOUNT:-...}` inline instead of using the `$ACCOUNT` variable already set at line 15, so an operator who changes the default in one place will silently leave the other stale. One info item: AGENTS.md step 4 contains an orphaned bullet that names `email-triage.sh` outside any numbered prose, which creates a parsing ambiguity for an LLM reading the checklist.

---

## Warnings

### WR-01: TOOLS.md line 23 still permits exec of `gmail-triage.js` — contradicts exec policy

**File:** `.openclaw/agents/email-triage/TOOLS.md:23`
**Issue:** The Tool Policy section states:
```
- Never exec any command other than `scripts/email-triage.sh` (primary) or `scripts/gmail-triage.js` (legacy fallback only)
```
The exec tool is scoped in TOOLS.md:5-10 to `scripts/email-triage.sh` invocation only. Line 23 carves out an explicit second permission for `gmail-triage.js`. An agent that has auth-failed on gogcli may interpret this as a valid fallback and attempt to exec the legacy Node.js script — which is not a supported execution path in Phase 14+ and requires Node.js OAuth2 env vars that are not set in the current deployment. The legacy runbook in TOOLS.md:131 is correctly marked superseded; line 23 is not.

**Fix:**
```markdown
# Line 23 — remove gmail-triage.js from permitted exec targets:
- Never exec any command other than `scripts/email-triage.sh`. No other exec usage is permitted.
```

### WR-02: `email-triage.sh` mark-read call re-expands `OPENCLAW_GMAIL_ACCOUNT` inline instead of using `$ACCOUNT`

**File:** `scripts/email-triage.sh:98`
**Issue:** Line 15 sets `ACCOUNT="${OPENCLAW_GMAIL_ACCOUNT:-echo.sys.bot@gmail.com}"` as the canonical account variable. Every other `gog` call in the script uses `"$ACCOUNT"` (lines 26, 36, 40). Line 98 (mark-read) re-expands the default inline:
```zsh
--account "${OPENCLAW_GMAIL_ACCOUNT:-echo.sys.bot@gmail.com}" \
```
If the default email address ever changes (or if `OPENCLAW_GMAIL_ACCOUNT` is set to a different value at runtime), line 98 will behave consistently only if the env var is set — if the env var is absent, the hardcoded default on line 98 overrides whatever `$ACCOUNT` resolved to on line 15 (they are the same string today, but a future change to line 15 will not propagate to line 98). This is a latent inconsistency.

**Fix:**
```zsh
# Line 98 — use the already-resolved $ACCOUNT variable:
$GOG gmail mark-read \
  --account "$ACCOUNT" \
  --query "is:unread newer_than:1d" \
  --no-input --non-interactive 2>>"$LOG_STDERR" || \
  print "[warn] mark-read failed — processed-ids.jsonl guard will catch duplicates next run" >&2
```

---

## Info

### IN-01: AGENTS.md step 4 contains an orphaned bullet that an LLM may misread as a numbered sub-step

**File:** `.openclaw/agents/email-triage/AGENTS.md:35`
**Issue:** After the prose body of numbered step 4 (processed-IDs guard), there is a dangling bullet:
```
   - **email-triage.sh** (primary, Phase 14+): zsh script using gogcli; outputs `{"ok":true,"data":{"threads":[...],"count":N}}`
```
This bullet is not part of any list; it appears to be a leftover fragment from a refactor that merged two separate steps. It adds no instruction and sits between step 4's conclusion and step 5's heading, making the checklist ambiguous — an LLM counting checklist items may treat it as an implicit "step 4b" or may interpret it as a conditional that triggers only on the gogcli path.

**Fix:** Remove the orphaned bullet entirely. The expected output format for `email-triage.sh` is already documented in TOOLS.md:39 and AGENTS.md:50-51.

---

_Reviewed: 2026-05-22T12:00:00Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: quick_

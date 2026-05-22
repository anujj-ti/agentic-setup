---
phase: 17-proactive-standup-insights
reviewed: 2026-05-22T00:00:00Z
depth: standard
files_reviewed: 4
files_reviewed_list:
  - scripts/standup-insights.sh
  - scripts/verify-phase-17.sh
  - .openclaw/agents/user-orchestrator/SOUL.md
  - .openclaw/agents/user-orchestrator/TOOLS.md
findings:
  critical: 2
  warning: 4
  info: 0
  total: 6
status: issues_found
---

# Phase 17: Code Review Report

**Reviewed:** 2026-05-22T00:00:00Z
**Depth:** standard
**Files Reviewed:** 4
**Status:** issues_found

## Summary

Reviewed `standup-insights.sh` (classification engine), `verify-phase-17.sh` (smoke tests), `SOUL.md` (agent identity and rules), and `TOOLS.md` (agent invocation reference).

The core classification logic is sound: the `iso_to_epoch` helper handles the common GitHub UTC-Z timestamp format correctly, jq `sort_by` for tackle-first ordering is correct, the `group_by(split("[")[0])` pattern for pattern detection works as confirmed by live execution, and no LLM calls exist in the classification path. The verify script uses the correct `ZSH=/bin/zsh` variable. SOUL.md's no-send and label-only (D-413) rules are properly encoded and not violated by TOOLS.md.

Two blockers exist: `TOOLS.md` hardcodes `/opt/homebrew/bin/zsh` which does not exist on this machine (actual path is `/bin/zsh`), causing every agent-executed standup invocation to fail at runtime. Additionally, `standup-insights.sh` lines 34–35 extract `stale_prs` and `merged_prs` without the `|| json_fail` error guard present on line 32 for `ci_failures`, meaning a jq failure there exits the script with a non-JSON stderr error instead of a structured `ok:false` response.

---

## Critical Issues

### CR-01: `/opt/homebrew/bin/zsh` does not exist — all TOOLS.md agent invocations fail

**File:** `.openclaw/agents/user-orchestrator/TOOLS.md:36,57,58`
**Issue:** TOOLS.md hardcodes `/opt/homebrew/bin/zsh` in three places — the standalone standup-brief.sh invocation (line 36) and both lines of the Phase 17 insights invocation (lines 57–58). The binary is not at that path; macOS system zsh lives at `/bin/zsh`. Running `ls /opt/homebrew/bin/zsh` confirms absence. The verify script correctly uses `ZSH=/bin/zsh` (line 10), exposing the inconsistency. When the OpenClaw agent executes these command strings literally during a morning cron session, both `standup-brief.sh` and `standup-insights.sh` invocations will produce `zsh: no such file or directory: /opt/homebrew/bin/zsh` on stderr and return a non-zero exit. The standup message will never be sent.

**Fix:** Replace all three occurrences of `/opt/homebrew/bin/zsh` in TOOLS.md with `/bin/zsh`:

```diff
-/opt/homebrew/bin/zsh ~/Documents/agentic-setup/scripts/standup-brief.sh --repo anujj-ti/agentic-setup
+/bin/zsh ~/Documents/agentic-setup/scripts/standup-brief.sh --repo anujj-ti/agentic-setup

-STANDUP_JSON=$(  /opt/homebrew/bin/zsh ~/Documents/agentic-setup/scripts/standup-brief.sh --repo anujj-ti/agentic-setup )
-INSIGHTS_JSON=$( printf '%s' "$STANDUP_JSON" | /opt/homebrew/bin/zsh ~/Documents/agentic-setup/scripts/standup-insights.sh )
+STANDUP_JSON=$(  /bin/zsh ~/Documents/agentic-setup/scripts/standup-brief.sh --repo anujj-ti/agentic-setup )
+INSIGHTS_JSON=$( printf '%s' "$STANDUP_JSON" | /bin/zsh ~/Documents/agentic-setup/scripts/standup-insights.sh )
```

---

### CR-02: `stale_prs` and `merged_prs` extraction lack `|| json_fail` guard — silent non-JSON exit under `set -euo pipefail`

**File:** `scripts/standup-insights.sh:34-35`
**Issue:** Lines 32–33 guard `CI_FAILURES` extraction with `|| json_fail "invalid-json" "..."`. Lines 34–35 have no such guard for `STALE_PRS` and `MERGED_PRS`:

```zsh
STALE_PRS=$(printf '%s' "$RAW_INPUT" | $JQ '.data.stale_prs // []')
MERGED_PRS=$(printf '%s' "$RAW_INPUT" | $JQ '.data.merged_prs // []')
```

Under `set -euo pipefail`, if either jq call exits non-zero (e.g., a null byte in input, jq binary error), the script exits immediately — no JSON written to stdout, jq's own error goes to stderr. Any caller checking `$?` will see non-zero but receive no parseable `{"ok":false,...}` envelope. The fallback in TOOLS.md (`if false, use STANDUP_JSON only`) relies on receiving a structured `ok:false` response; a raw non-zero exit with no output bypasses that fallback and may leave the caller hanging.

**Fix:** Add guards matching the CI_FAILURES pattern:

```zsh
STALE_PRS=$(printf '%s' "$RAW_INPUT" | $JQ '.data.stale_prs // []') || \
  json_fail "invalid-json" "Could not extract stale_prs from standup JSON"
MERGED_PRS=$(printf '%s' "$RAW_INPUT" | $JQ '.data.merged_prs // []') || \
  json_fail "invalid-json" "Could not extract merged_prs from standup JSON"
```

---

## Warnings

### WR-01: `standup-insights.sh` silently processes `ok:false` input as if it were a valid standup

**File:** `scripts/standup-insights.sh:32-35`
**Issue:** After the JSON syntax check on line 28, the script immediately extracts `.data.ci_failures`, `.data.stale_prs`, and `.data.merged_prs` without verifying `.ok == true`. If `standup-brief.sh` fails and returns `{"ok":false,"error":"gh-not-found"}`, all three arrays resolve to `[]` via the `// []` fallback, and the script emits a successful-looking `{"ok":true,"data":{"insights":{"classified_items":[],...}}}`. The user receives "Nothing critical — clear runway." in Telegram when in reality the standup data collection failed entirely.

**Fix:** Add an explicit `ok` check after line 28:

```zsh
if ! printf '%s' "$RAW_INPUT" | $JQ -e '.ok == true' >/dev/null 2>&1; then
  json_fail "upstream-failed" "standup-brief.sh returned ok:false — not processing failed input"
fi
```

---

### WR-02: `iso_to_epoch` silently returns `0` for timestamps with non-UTC timezone offsets

**File:** `scripts/standup-insights.sh:48-55`
**Issue:** The strip logic removes fractional seconds (`%%.*`) and a trailing `Z` (`%Z`), but does not handle ISO 8601 timestamps with explicit UTC offset notation like `2026-05-22T01:00:00+00:00` or `2026-05-22T01:00:00-07:00`. Such a timestamp leaves the offset suffix intact, BSD `date -j` fails to parse the trailing `+00:00`, and `|| echo "0"` returns epoch 0. An epoch of 0 always satisfies `CREATED_EPOCH < TWO_H_AGO_EPOCH`, so the item is silently classified `"On Track"` — it will never surface as `"Blocked"` or `"At Risk"`. GitHub's API exclusively emits `Z`-suffixed UTC timestamps today, but this fragility means any upstream change or future data source would silently misclassify without error.

**Fix:** Normalize `+HH:MM` and `-HH:MM` offsets before parsing, or at minimum detect and warn:

```zsh
iso_to_epoch() {
  local ts="$1"
  local clean="${ts%%.*}"
  clean="${clean%Z}"
  # Strip explicit UTC offset (+00:00 / -HH:MM) if present
  clean="${clean%+[0-9][0-9]:[0-9][0-9]}"
  clean="${clean%-[0-9][0-9]:[0-9][0-9]}"
  TZ=UTC date -j -f '%Y-%m-%dT%H:%M:%S' "${clean}" '+%s' 2>/dev/null || echo "0"
}
```

---

### WR-03: `stale_prs` and `merged_prs` loops have no size cap — asymmetric DoS mitigation

**File:** `scripts/standup-insights.sh:97-146`
**Issue:** T-17-03 applies a 20-element cap to the `ci_failures` loop (lines 63–66), but the `stale_prs` loop (lines 97–126) and `merged_prs` loop (lines 129–146) have no equivalent guard. `standup-brief.sh` fetches up to 30 `stale_prs` (via `--limit 30`) and 20 `merged_prs` (via `--limit 20`). Each loop iteration spawns two `jq` subprocesses — one to extract the item and one to accumulate `CLASSIFIED_JSON`. A malicious or corrupted standup JSON with 30 `stale_prs` therefore spawns 60 jq processes that `ci_failures` would not. The cap comment at line 62 references `T-17-03` but the threat model only named `ci_failures` — the omission is inconsistent and should be addressed explicitly even if the upstream `--limit` bounds are trusted.

**Fix:** Add symmetric caps before each loop:

```zsh
# Apply cap to stale_prs (symmetric with T-17-03)
if (( STALE_COUNT > 30 )); then
  STALE_PRS=$(printf '%s' "$STALE_PRS" | $JQ '.[0:30]')
  STALE_COUNT=30
fi

# Apply cap to merged_prs
if (( MERGED_COUNT > 20 )); then
  MERGED_PRS=$(printf '%s' "$MERGED_PRS" | $JQ '.[0:20]')
  MERGED_COUNT=20
fi
```

---

### WR-04: TOOLS.md retains a pre-Phase-17 bare standup-brief.sh invocation example — creates ambiguous agent guidance

**File:** `.openclaw/agents/user-orchestrator/TOOLS.md:33-50`
**Issue:** The section "Standup Script Invocation" (lines 33–50) shows the pre-Phase-17 workflow: call `standup-brief.sh` alone, parse its JSON directly. The "Insights Enhancement (Phase 17)" section immediately follows (lines 52–81) showing the two-step pipeline. An LLM agent parsing TOOLS.md may interpret the first section as still-authoritative guidance and invoke only `standup-brief.sh`, producing a brief without insights classification, silently bypassing Phase 17 entirely. The first section is superseded but not marked as deprecated or removed.

**Fix:** Mark the legacy section as superseded or remove it:

```markdown
## Standup Script Invocation ~~(pre-Phase 17 — superseded; see "Insights Enhancement" below)~~

> **Deprecated by Phase 17.** Use the two-step pipeline in "Insights Enhancement" below.
> Retained only for reference. Do NOT use this invocation in cron sessions.
```

Or remove lines 33–50 entirely since the Phase 17 section is self-contained and includes the correct invocation.

---

_Reviewed: 2026-05-22T00:00:00Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_

---
phase: 18-decision-quality-risk-gate
reviewed: 2026-05-22T00:00:00Z
depth: standard
files_reviewed: 3
files_reviewed_list:
  - .openclaw/agents/decision-reviewer/SOUL.md
  - .openclaw/agents/task-orchestrator/SOUL.md
  - scripts/verify-phase-18.sh
findings:
  critical: 3
  warning: 4
  info: 2
  total: 9
status: issues_found
---

# Phase 18: Decision Quality Risk Gate — Code Review Report

**Reviewed:** 2026-05-22T00:00:00Z
**Depth:** standard
**Files Reviewed:** 3
**Status:** issues_found

## Summary

Three files implement the Decision Quality Risk Gate: the Decision Reviewer agent directive (SOUL.md), the Task Orchestrator routing logic (SOUL.md), and a structural verification script. The risk scoring arithmetic is sound (four dimensions sum correctly to 100) and the non-blocking guarantee for agent failures is correctly implemented. However, three blockers were found: the scoring sub-ranges produce pervasive tier ambiguity at both boundaries (48% of dimension combinations span a tier boundary), the `bd close` fast-pass entry uses a prefix that never matches actual Beads command format, and a cross-reference inside Step 4 points in the wrong direction ("above" when the target section is below). Four warnings concern timeout conflation between two distinct windows, malformed-verdict 30-minute overhead, verify-script CHECK 4 not validating tier-name assignments, and verify-script CHECK 9 covering only 3 of 7 fast-pass entries.

## Critical Issues

### CR-01: Risk scoring sub-ranges span tier boundaries — 48% of combinations are ambiguous

**File:** `.openclaw/agents/decision-reviewer/SOUL.md:56-79`

**Issue:** The scoring ranges within each dimension are wide enough that the same decision can be legitimately scored to land on either side of a tier boundary. Exhaustive enumeration of all 128 combinations of sub-range labels shows 62 of them (48%) span either the 30/31 or 60/61 boundary. For example, `irreversible + single-repo + notion-write + seen-before` produces a valid range of 53–68, which spans the medium/high boundary at 60/61. The agent is instructed to "score each dimension using the ranges above; sum the four scores to produce risk_score" but receives no tiebreaker rule for this extremely common case. A decision that is borderline medium can be scored as high or low depending on which end of the sub-range the reviewer picks, making the tier assignment non-deterministic and defeating the purpose of D-503.

Concrete example that crosses both thresholds:
- `complex-revert (20-30) + read-only (0) + notion-write (3-5) + seen-before (0-3)` → 23–38 (spans 30/31)
- `irreversible (35-40) + single-repo (15-20) + notion-write (3-5) + seen-before (0-3)` → 53–68 (spans 60/61)

**Fix:** Add a tiebreaker rule to the Scoring Instructions. The simplest correct fix is to use the **midpoint** of each sub-range when the applicable category is clearly identified, and to apply a **fail-high** rule when the computed total falls within ±3 of a tier boundary:

```markdown
### Tiebreaker Rule (D-503 amendment)
When a dimension score is not fully determined by its sub-range:
1. Use the midpoint of the applicable sub-range as the default value.
2. If the computed risk_score falls within ±3 of a tier boundary (27–33 or 57–63),
   round UP to the higher tier. Bias toward more scrutiny, not less.
```

---

### CR-02: `bd close` fast-pass entry prefix never matches actual Beads command format

**File:** `.openclaw/agents/task-orchestrator/SOUL.md:278`

**Issue:** The fast-pass list entry reads:
```
- `bd close --reason` — closes an already-claimed task with factual evidence; reversible
```
The matching rule (line 283) is: the `decision` field must **start with** the listed prefix (case-insensitive). However, the canonical Beads execution contract in the same file (lines 88–90) formats the close command as:
```zsh
BEADS_DIR=$BEADS_DIR $BD close $TASK_ID --reason "..." --continue --json
```
A `decision` field derived from this command would read something like `"bd close T7 --reason evidence string"`. This string does **not** start with `"bd close --reason"` because the task ID comes between `close` and `--reason`. As a result, the fast-pass entry is effectively dead code — every `bd close` call will be routed through Decision Reviewer regardless, adding review overhead to the most frequent operation in the autonomous execution cycle.

**Fix:** Change the fast-pass prefix to match the actual command format:

```markdown
- `bd close` — closes an already-claimed task; includes --reason evidence flag; reversible
```

This matches `"bd close T7 --reason ..."`, `"bd close T7 --continue --json"`, and all variants. If granularity is desired to require the `--reason` flag, add a note rather than encoding it in the prefix: "fast-pass only when decision payload includes evidence in the rationale or evidence fields."

---

### CR-03: Stale cross-reference in Step 4 — "Failed Verdict Policy section above" points downward

**File:** `.openclaw/agents/task-orchestrator/SOUL.md:332`

**Issue:** Step 4 of the HIGH-tier Telegram approval block (line 332) reads:
```
- If timeout (30 min, no response): invoke the Failed Verdict Policy
  (see Failed Verdict Policy section above) — log to decision-review-fallback.log and PROCEED.
```
The Failed Verdict Policy section is defined at line 334 — two lines **below** line 332, not above it. An agent reading this document linearly would look upward for the policy definition and fail to find it, potentially halting on a timeout event or applying incorrect fallback behavior.

**Fix:** Change "above" to "below":
```markdown
- If timeout (30 min, no response): invoke the Failed Verdict Policy
  (see Failed Verdict Policy section below) — log to decision-review-fallback.log and PROCEED.
```

---

## Warnings

### WR-01: Timeout conflation — D-506's 30-minute window is misapplied to Decision Reviewer session failures

**File:** `.openclaw/agents/task-orchestrator/SOUL.md:336`

**Issue:** The Failed Verdict Policy header reads: "If Decision Reviewer returns an error response, **times out (30-minute window per D-506)**, or the session fails to complete". D-506 is explicitly the Telegram *user response* window. The Decision Reviewer's own verdict latency is documented separately in `decision-reviewer/SOUL.md` line 37: "The Task Orchestrator enforces a **2-minute timeout**."

There are two distinct timeouts in play:
1. Decision Reviewer verdict timeout: 2 minutes (per DR SOUL.md)
2. Telegram user response timeout: 30 minutes (D-506)

The Task Orchestrator SOUL.md defines no mechanism for enforcing the 2-minute DR verdict window. If the Decision Reviewer session hangs, the orchestrator has no defined time limit to trigger the fallback — it could wait indefinitely before the Failed Verdict Policy fires. The 30-minute window is cited for DR session failures, but that window belongs to Telegram.

**Fix:** Split the Failed Verdict Policy header into two distinct triggers with their own timeouts:

```markdown
#### Failed Verdict Policy (RISK-03)

Triggers (two distinct scenarios):
- **Decision Reviewer session failure or verdict timeout**: If Decision Reviewer does not
  return a verdict within **2 minutes** (per DR SOUL.md speed mandate), treat as error
  and proceed per steps 1–3 below.
- **Telegram user approval timeout (D-506)**: If no APPROVE/REJECT received within
  **30 minutes** of sending the Step 4 Telegram message, proceed per steps 1–3 below.
```

---

### WR-02: Malformed verdict (absent `risk_tier`) triggers unnecessary 30-minute Telegram wait

**File:** `.openclaw/agents/task-orchestrator/SOUL.md:298-302`

**Issue:** When the Decision Reviewer omits `risk_tier` from its response, the orchestrator defaults to `"high"` (line 298/302) and routes through the HIGH-tier Telegram approval flow (Step 4). If this occurs during an overnight autonomous session and no human is available to respond, the orchestrator waits the full 30-minute D-506 window before the Failed Verdict Policy fires. This is the worst-case handling for a formatting error that should be trivially distinguishable from a genuine high-risk action.

**Fix:** Add a distinct branch for malformed verdicts before the risk-tier routing table:

```markdown
**Malformed verdict handling:** If `risk_tier` is absent AND `verdict` is `pass` or `flag`,
treat as `medium` (proceed without Telegram gate) and log a warning to decision-review-fallback.log:
`"reason":"malformed-verdict-missing-risk_tier","action":"defaulted-to-medium"`.
Only treat absent `risk_tier` as `high` if the verdict itself is also absent or unparseable.
```

---

### WR-03: `verify-phase-18.sh` CHECK 4 validates range strings but not tier-name assignments

**File:** `scripts/verify-phase-18.sh:51-55`

**Issue:** CHECK 4 passes as long as the strings "61-100", "31-60", and "0-30" appear anywhere in the SOUL.md. It does not verify that these ranges are paired with the correct tier names ("high", "medium", "low" respectively). A broken mapping such as `0-30: high` or a transposed table would pass CHECK 4. Since the tier mapping drives the entire Telegram-gate routing decision, an incorrect name assignment is a production correctness defect that this check would silently miss.

**Fix:** Replace the three individual `grep -q` calls with checks that verify the range and its tier label appear on the same line:

```zsh
# CHECK 4: tier ranges AND names present on same lines
{ grep -q "0-30.*low\|low.*0-30" "$DR_SOUL" 2>/dev/null && \
  grep -q "31-60.*medium\|medium.*31-60" "$DR_SOUL" 2>/dev/null && \
  grep -q "61-100.*high\|high.*61-100" "$DR_SOUL" 2>/dev/null; }
```

---

### WR-04: `verify-phase-18.sh` CHECK 9 covers only 3 of 7 fast-pass entries; 4 go unverified

**File:** `scripts/verify-phase-18.sh:88-92`

**Issue:** CHECK 9 verifies the presence of `gh issue comment`, `bd ready`, and `synapse.learning.record` in the Task Orchestrator SOUL.md. The remaining four fast-pass entries — `gh pr view`, `bd close --reason`, `synapse.checkin status=start`, and the read-only `gh api` entry — are not tested. Any of these could be silently deleted or corrupted without CHECK 9 catching it.

**Fix:** Extend CHECK 9 to cover all listed entries:

```zsh
# CHECK 9: all fast-pass entries present
{ grep -q "gh issue comment" "$TO_SOUL" 2>/dev/null && \
  grep -q "gh pr view" "$TO_SOUL" 2>/dev/null && \
  grep -q "bd ready" "$TO_SOUL" 2>/dev/null && \
  grep -q "bd close" "$TO_SOUL" 2>/dev/null && \
  grep -qE "synapse\.learning\.record|Synapse learning record" "$TO_SOUL" 2>/dev/null && \
  grep -qE "synapse\.checkin|Synapse checkin" "$TO_SOUL" 2>/dev/null; }
```

---

## Info

### IN-01: `verify-phase-18.sh` omits `-e` from strict mode, violating project shell convention

**File:** `scripts/verify-phase-18.sh:8`

**Issue:** The shebang is `#!/usr/bin/env zsh` and strict mode is `set -uo pipefail`. The project convention defined in `CLAUDE.md` requires `set -euo pipefail`. The omission of `-e` is technically intentional here — the script deliberately allows `grep` to return exit code 1 (no match) without aborting, since `check_result()` captures `$?` to distinguish pass from fail. However, it creates a convention deviation that could confuse future maintainers into thinking the omission was accidental, and leaves non-grep failures (e.g., a missing `jq` in a future check) silently ignored.

**Fix:** Either add a comment explaining the intentional `-e` omission, or restructure checks to use `|| true` so `-e` can be restored:

```zsh
set -euo pipefail
# Note: individual grep commands use '|| true' to prevent -e from aborting on no-match
grep -q "risk_score" "$DR_SOUL" 2>/dev/null || true
check_result 1 "RISK-01 risk_score field" $?
```

---

### IN-02: Reversibility sub-ranges have gaps (16–19, 31–34) and an overlap at score 5

**File:** `.openclaw/agents/decision-reviewer/SOUL.md:56-61`

**Issue:** The Reversibility dimension sub-ranges are:
- no-state-change: 0–5
- simple-revert: 5–15
- complex-revert: 20–30
- irreversible: 35–40

There are two unreachable gaps (16–19 and 31–34) and one overlap point: score 5 belongs to both `no-state-change` (max) and `simple-revert` (min). The gaps prevent certain total scores from being reachable by rubric; the overlap means a score of exactly 5 is technically ambiguous about which category applies. While the practical impact is low (the agent must pick a category first, then score within it), the imprecision undermines the stated goal of unambiguous tier assignment.

**Fix:** Remove the ambiguity by making the sub-ranges exclusive and gap-free:
```markdown
| Reversibility sub-range  | Points |
|--------------------------|--------|
| irreversible             | 35–40  |
| complex-revert           | 21–34  |
| simple-revert            | 6–20   |
| no-state-change          | 0–5    |
```
This eliminates the gaps and makes all 40 integer values reachable.

---

_Reviewed: 2026-05-22T00:00:00Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_

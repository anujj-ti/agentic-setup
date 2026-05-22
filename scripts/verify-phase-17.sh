#!/usr/bin/env zsh
# verify-phase-17.sh — 10-check automated smoke test for Phase 17: Proactive Standup Insights
# Validates standup-insights.sh classification, tackle-first, pattern detection,
# and User Orchestrator config updates from Plans 17-01 and 17-02.
# Usage: zsh scripts/verify-phase-17.sh
# Exit 0 = all checks pass; Exit 1 = one or more checks failed.

# --- Explicit binary paths (per CLAUDE.md) ---
JQ=/opt/homebrew/bin/jq
ZSH=/bin/zsh
INSIGHTS="$HOME/Documents/agentic-setup/scripts/standup-insights.sh"
SOUL="$HOME/.openclaw/agents/user-orchestrator/SOUL.md"
TOOLS="$HOME/.openclaw/agents/user-orchestrator/TOOLS.md"

PASS_COUNT=0
FAIL_COUNT=0

pass() {
  print "  PASS"
  PASS_COUNT=$((PASS_COUNT + 1))
}

fail() {
  print "  FAIL: $1"
  FAIL_COUNT=$((FAIL_COUNT + 1))
}

# --- Runtime timestamps (BSD date, macOS) ---
FOUR_H_AGO=$(date -u -v-4H '+%Y-%m-%dT%H:%M:%SZ')
THIRTY_SIX_H_AGO=$(date -u -v-36H '+%Y-%m-%dT%H:%M:%SZ')

# --- Build fixture JSON at runtime ---

EMPTY_STANDUP=$($JQ -n '{
  ok: true,
  data: {
    repo: "test/repo",
    as_of: "2026-05-22T03:00:00Z",
    merged_prs: [],
    ci_failures: [],
    stale_prs: [],
    autonomous_decisions: {count: 0, since: "", summary: [], notion_configured: true},
    overnight_email: {count: 0, threads: [], gog_available: false},
    calendar_events: []
  }
}')

BLOCKED_STANDUP=$($JQ -n --arg ca "$FOUR_H_AGO" '{
  ok: true,
  data: {
    repo: "test/repo",
    as_of: "2026-05-22T03:00:00Z",
    merged_prs: [],
    ci_failures: [
      {name: "build", conclusion: "failure", headBranch: "main", url: "https://github.com/test/run/1", createdAt: $ca}
    ],
    stale_prs: [],
    autonomous_decisions: {count: 0, since: "", summary: [], notion_configured: true},
    overnight_email: {count: 0, threads: [], gog_available: false},
    calendar_events: []
  }
}')

AT_RISK_STANDUP=$($JQ -n --arg ua "$THIRTY_SIX_H_AGO" '{
  ok: true,
  data: {
    repo: "test/repo",
    as_of: "2026-05-22T03:00:00Z",
    merged_prs: [],
    ci_failures: [],
    stale_prs: [
      {number: 42, title: "Fix auth bug", updatedAt: $ua, reviewDecision: "CHANGES_REQUESTED"}
    ],
    autonomous_decisions: {count: 0, since: "", summary: [], notion_configured: true},
    overnight_email: {count: 0, threads: [], gog_available: false},
    calendar_events: []
  }
}')

EIGHT_BLOCKED_STANDUP=$($JQ -n --arg ca "$FOUR_H_AGO" '{
  ok: true,
  data: {
    repo: "test/repo",
    as_of: "2026-05-22T03:00:00Z",
    merged_prs: [],
    ci_failures: ([range(8)] | map({name: ("run-" + (. | tostring)), conclusion: "failure", headBranch: "main", url: ("https://github.com/test/run/" + (. | tostring)), createdAt: $ca})),
    stale_prs: [],
    autonomous_decisions: {count: 0, since: "", summary: [], notion_configured: true},
    overnight_email: {count: 0, threads: [], gog_available: false},
    calendar_events: []
  }
}')

FOUR_FAILURES_STANDUP=$($JQ -n --arg ca "$FOUR_H_AGO" '{
  ok: true,
  data: {
    repo: "test/repo",
    as_of: "2026-05-22T03:00:00Z",
    merged_prs: [],
    ci_failures: ([range(4)] | map({name: ("run-" + (. | tostring)), conclusion: "failure", headBranch: "main", url: ("https://github.com/test/run/" + (. | tostring)), createdAt: $ca})),
    stale_prs: [],
    autonomous_decisions: {count: 0, since: "", summary: [], notion_configured: true},
    overnight_email: {count: 0, threads: [], gog_available: false},
    calendar_events: []
  }
}')

# ---------------------------------------------------------------------------
# CHECK 1: standup-insights.sh exists and is executable
# ---------------------------------------------------------------------------
print "CHECK 1: standup-insights.sh exists and is executable"
if [[ -x "$INSIGHTS" ]]; then
  pass
else
  fail "standup-insights.sh not found or not executable at $INSIGHTS"
fi

# ---------------------------------------------------------------------------
# CHECK 2: standup-insights.sh passes zsh -n (syntax check)
# ---------------------------------------------------------------------------
print "CHECK 2: standup-insights.sh syntax check (zsh -n)"
if $ZSH -n "$INSIGHTS" 2>/dev/null; then
  pass
else
  fail "standup-insights.sh has syntax errors (zsh -n failed)"
fi

# ---------------------------------------------------------------------------
# CHECK 3: Empty standup → ok:true, tackle_first=[], patterns=[]
# ---------------------------------------------------------------------------
print "CHECK 3: Empty standup → ok:true, tackle_first=[], patterns=[] (STANDUP-01 null case)"
RESULT3=$(printf '%s' "$EMPTY_STANDUP" | $ZSH "$INSIGHTS" 2>/dev/null) || true
if printf '%s' "$RESULT3" | $JQ -e '.ok == true and (.data.insights.tackle_first | length) == 0 and (.data.insights.patterns | length) == 0' >/dev/null 2>&1; then
  pass
else
  fail "empty standup did not produce ok:true with empty tackle_first and patterns — got: $(printf '%s' "$RESULT3" | $JQ -c '.data.insights // "null"' 2>/dev/null)"
fi

# ---------------------------------------------------------------------------
# CHECK 4: 1 ci_failure (createdAt 4h ago) → status=="Blocked" in classified_items
# ---------------------------------------------------------------------------
print "CHECK 4: 1 ci_failure (4h old) → classified_items[0].status == \"Blocked\" (D-401)"
RESULT4=$(printf '%s' "$BLOCKED_STANDUP" | $ZSH "$INSIGHTS" 2>/dev/null) || true
if printf '%s' "$RESULT4" | $JQ -e '.data.insights.classified_items[0].status == "Blocked"' >/dev/null 2>&1; then
  pass
else
  fail "expected Blocked status for 4h-old ci_failure — got: $(printf '%s' "$RESULT4" | $JQ -r '.data.insights.classified_items[0].status // "null"' 2>/dev/null)"
fi

# ---------------------------------------------------------------------------
# CHECK 5: 1 stale_pr (updatedAt 36h ago, CHANGES_REQUESTED) → status=="At Risk"
# ---------------------------------------------------------------------------
print "CHECK 5: 1 stale_pr (36h old, CHANGES_REQUESTED) → classified_items[0].status == \"At Risk\" (D-402)"
RESULT5=$(printf '%s' "$AT_RISK_STANDUP" | $ZSH "$INSIGHTS" 2>/dev/null) || true
if printf '%s' "$RESULT5" | $JQ -e '.data.insights.classified_items[0].status == "At Risk"' >/dev/null 2>&1; then
  pass
else
  fail "expected At Risk status for 36h-old stale PR — got: $(printf '%s' "$RESULT5" | $JQ -r '.data.insights.classified_items[0].status // "null"' 2>/dev/null)"
fi

# ---------------------------------------------------------------------------
# CHECK 6: tackle_first is always an array (even on empty standup) (D-407)
# ---------------------------------------------------------------------------
print "CHECK 6: tackle_first is always an array even on empty standup (D-407)"
RESULT6=$(printf '%s' "$EMPTY_STANDUP" | $ZSH "$INSIGHTS" 2>/dev/null) || true
if printf '%s' "$RESULT6" | $JQ -e '(.data.insights.tackle_first | type) == "array"' >/dev/null 2>&1; then
  pass
else
  fail "tackle_first is not an array on empty standup — got type: $(printf '%s' "$RESULT6" | $JQ -r '(.data.insights.tackle_first | type) // "missing"' 2>/dev/null)"
fi

# ---------------------------------------------------------------------------
# CHECK 7: tackle_first capped at 5 items when 8 Blocked items provided (D-405)
# ---------------------------------------------------------------------------
print "CHECK 7: tackle_first capped at 5 items when 8 Blocked ci_failures (D-405)"
RESULT7=$(printf '%s' "$EIGHT_BLOCKED_STANDUP" | $ZSH "$INSIGHTS" 2>/dev/null) || true
if printf '%s' "$RESULT7" | $JQ -e '(.data.insights.tackle_first | length) <= 5' >/dev/null 2>&1; then
  pass
else
  fail "tackle_first exceeded 5 items — got: $(printf '%s' "$RESULT7" | $JQ '.data.insights.tackle_first | length' 2>/dev/null)"
fi

# ---------------------------------------------------------------------------
# CHECK 8: 4 ci_failures → patterns[0].count==4 (D-408, STANDUP-03)
# ---------------------------------------------------------------------------
print "CHECK 8: 4 ci_failures → patterns[0].count == 4 (D-408, STANDUP-03)"
RESULT8=$(printf '%s' "$FOUR_FAILURES_STANDUP" | $ZSH "$INSIGHTS" 2>/dev/null) || true
if printf '%s' "$RESULT8" | $JQ -e '.data.insights.patterns[0].count == 4' >/dev/null 2>&1; then
  pass
else
  fail "expected pattern count 4 for 4 ci_failures — got: $(printf '%s' "$RESULT8" | $JQ -c '.data.insights.patterns // "null"' 2>/dev/null)"
fi

# ---------------------------------------------------------------------------
# CHECK 9: SOUL.md contains "standup-insights.sh" reference (D-411)
# ---------------------------------------------------------------------------
print "CHECK 9: SOUL.md contains \"standup-insights.sh\" reference (D-411)"
if grep -q "standup-insights.sh" "$SOUL" 2>/dev/null; then
  pass
else
  fail "standup-insights.sh not found in SOUL.md at $SOUL"
fi

# ---------------------------------------------------------------------------
# CHECK 10: TOOLS.md contains "standup-insights.sh" reference (D-412)
# ---------------------------------------------------------------------------
print "CHECK 10: TOOLS.md contains \"standup-insights.sh\" reference (D-412)"
if grep -q "standup-insights.sh" "$TOOLS" 2>/dev/null; then
  pass
else
  fail "standup-insights.sh not found in TOOLS.md at $TOOLS"
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
print ""
print "Results: $PASS_COUNT passed, $FAIL_COUNT failed"
if (( FAIL_COUNT == 0 )); then
  print "Phase 17 verification: ALL CHECKS PASSED"
  exit 0
else
  print "Phase 17 verification: $FAIL_COUNT CHECK(S) FAILED"
  exit 1
fi

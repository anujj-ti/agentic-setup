#!/usr/bin/env zsh
# test-standup-insights.sh — Test suite for standup-insights.sh
# Run from the agentic-setup root directory
# Usage: zsh scripts/test-standup-insights.sh
set -euo pipefail

SCRIPT_DIR="$(dirname "$0")"
JQ=/opt/homebrew/bin/jq
INSIGHTS="$SCRIPT_DIR/standup-insights.sh"
PASS=0
FAIL=0

run_test() {
  local test_name="$1"
  local input="$2"
  local jq_check="$3"

  local output
  output=$(printf '%s' "$input" | zsh "$INSIGHTS" 2>/dev/null) || {
    print "FAIL [$test_name]: script exited non-zero unexpectedly" >&2
    FAIL=$((FAIL + 1))
    return
  }

  if printf '%s' "$output" | $JQ -e "$jq_check" >/dev/null 2>&1; then
    print "PASS [$test_name]"
    PASS=$((PASS + 1))
  else
    print "FAIL [$test_name]: jq check failed: $jq_check"
    print "  output: $output" >&2
    FAIL=$((FAIL + 1))
  fi
}

run_fail_test() {
  local test_name="$1"
  local input="$2"

  local output
  local exit_code=0
  output=$(printf '%s' "$input" | zsh "$INSIGHTS" 2>/dev/null) || exit_code=$?

  if [[ $exit_code -ne 0 ]]; then
    print "PASS [$test_name]: exited non-zero as expected"
    PASS=$((PASS + 1))
  else
    local ok
    ok=$(printf '%s' "$output" | $JQ -r '.ok' 2>/dev/null || echo "parse-error")
    if [[ "$ok" == "false" ]]; then
      print "PASS [$test_name]: returned ok:false as expected"
      PASS=$((PASS + 1))
    else
      print "FAIL [$test_name]: expected failure but got ok:true"
      FAIL=$((FAIL + 1))
    fi
  fi
}

# Compute timestamps for test data
NOW_EPOCH=$(date +%s)
# 3h ago (older than 2h threshold) → should be Blocked
THREE_H_AGO=$(date -u -v-3H '+%Y-%m-%dT%H:%M:%SZ')
# 30 minutes ago (within 2h threshold) → should be On Track
THIRTY_MIN_AGO=$(date -u -v-30M '+%Y-%m-%dT%H:%M:%SZ')
# 36h ago (older than 24h threshold) → should be At Risk
THIRTY_SIX_H_AGO=$(date -u -v-36H '+%Y-%m-%dT%H:%M:%SZ')
# 12h ago (within 24h threshold) → On Track stale PR
TWELVE_H_AGO=$(date -u -v-12H '+%Y-%m-%dT%H:%M:%SZ')

# --- Test fixtures ---

EMPTY_STANDUP=$(cat <<EOF
{"ok":true,"data":{"repo":"test/repo","as_of":"2026-05-22T03:00:00Z","merged_prs":[],"ci_failures":[],"stale_prs":[],"autonomous_decisions":{"count":0,"since":"","summary":[],"notion_configured":true},"overnight_email":{"count":0,"threads":[],"gog_available":false},"calendar_events":[]}}
EOF
)

ONE_CI_FAILURE_OLD=$(cat <<EOF
{"ok":true,"data":{"repo":"test/repo","as_of":"2026-05-22T03:00:00Z","merged_prs":[],"ci_failures":[{"name":"CI / build","conclusion":"failure","headBranch":"feature/auth","url":"https://github.com/test/repo/actions/runs/1","createdAt":"${THREE_H_AGO}"}],"stale_prs":[],"autonomous_decisions":{"count":0,"since":"","summary":[],"notion_configured":true},"overnight_email":{"count":0,"threads":[],"gog_available":false},"calendar_events":[]}}
EOF
)

ONE_CI_FAILURE_RECENT=$(cat <<EOF
{"ok":true,"data":{"repo":"test/repo","as_of":"2026-05-22T03:00:00Z","merged_prs":[],"ci_failures":[{"name":"CI / build","conclusion":"failure","headBranch":"main","url":"https://github.com/test/repo/actions/runs/2","createdAt":"${THIRTY_MIN_AGO}"}],"stale_prs":[],"autonomous_decisions":{"count":0,"since":"","summary":[],"notion_configured":true},"overnight_email":{"count":0,"threads":[],"gog_available":false},"calendar_events":[]}}
EOF
)

ONE_STALE_PR_AT_RISK=$(cat <<EOF
{"ok":true,"data":{"repo":"test/repo","as_of":"2026-05-22T03:00:00Z","merged_prs":[],"ci_failures":[],"stale_prs":[{"number":42,"title":"Add OAuth flow","updatedAt":"${THIRTY_SIX_H_AGO}","reviewDecision":"CHANGES_REQUESTED"}],"autonomous_decisions":{"count":0,"since":"","summary":[],"notion_configured":true},"overnight_email":{"count":0,"threads":[],"gog_available":false},"calendar_events":[]}}
EOF
)

FOUR_CI_FAILURES=$(cat <<EOF
{"ok":true,"data":{"repo":"test/repo","as_of":"2026-05-22T03:00:00Z","merged_prs":[],"ci_failures":[{"name":"CI / build","conclusion":"failure","headBranch":"feature/a","url":"https://github.com/test/repo/actions/runs/1","createdAt":"${THREE_H_AGO}"},{"name":"CI / test","conclusion":"failure","headBranch":"feature/b","url":"https://github.com/test/repo/actions/runs/2","createdAt":"${THREE_H_AGO}"},{"name":"CI / lint","conclusion":"failure","headBranch":"feature/c","url":"https://github.com/test/repo/actions/runs/3","createdAt":"${THREE_H_AGO}"},{"name":"CI / deploy","conclusion":"failure","headBranch":"feature/d","url":"https://github.com/test/repo/actions/runs/4","createdAt":"${THREE_H_AGO}"}],"stale_prs":[],"autonomous_decisions":{"count":0,"since":"","summary":[],"notion_configured":true},"overnight_email":{"count":0,"threads":[],"gog_available":false},"calendar_events":[]}}
EOF
)

# 2 Blocked (ci_failures old) + 1 At Risk (stale PR) = Blocked before At Risk
BLOCKED_BEFORE_AT_RISK=$(cat <<EOF
{"ok":true,"data":{"repo":"test/repo","as_of":"2026-05-22T03:00:00Z","merged_prs":[],"ci_failures":[{"name":"CI / build","conclusion":"failure","headBranch":"feature/a","url":"https://github.com/test/repo/actions/runs/1","createdAt":"${THREE_H_AGO}"},{"name":"CI / test","conclusion":"failure","headBranch":"feature/b","url":"https://github.com/test/repo/actions/runs/2","createdAt":"${THREE_H_AGO}"}],"stale_prs":[{"number":42,"title":"PR at risk","updatedAt":"${THIRTY_SIX_H_AGO}","reviewDecision":"CHANGES_REQUESTED"}],"autonomous_decisions":{"count":0,"since":"","summary":[],"notion_configured":true},"overnight_email":{"count":0,"threads":[],"gog_available":false},"calendar_events":[]}}
EOF
)

# 8 qualifying items — should be capped at 5
EIGHT_FAILURES=$(cat <<EOF
{"ok":true,"data":{"repo":"test/repo","as_of":"2026-05-22T03:00:00Z","merged_prs":[],"ci_failures":[{"name":"CI 1","conclusion":"failure","headBranch":"f1","url":"u1","createdAt":"${THREE_H_AGO}"},{"name":"CI 2","conclusion":"failure","headBranch":"f2","url":"u2","createdAt":"${THREE_H_AGO}"},{"name":"CI 3","conclusion":"failure","headBranch":"f3","url":"u3","createdAt":"${THREE_H_AGO}"},{"name":"CI 4","conclusion":"failure","headBranch":"f4","url":"u4","createdAt":"${THREE_H_AGO}"},{"name":"CI 5","conclusion":"failure","headBranch":"f5","url":"u5","createdAt":"${THREE_H_AGO}"},{"name":"CI 6","conclusion":"failure","headBranch":"f6","url":"u6","createdAt":"${THREE_H_AGO}"},{"name":"CI 7","conclusion":"failure","headBranch":"f7","url":"u7","createdAt":"${THREE_H_AGO}"},{"name":"CI 8","conclusion":"failure","headBranch":"f8","url":"u8","createdAt":"${THREE_H_AGO}"}],"stale_prs":[],"autonomous_decisions":{"count":0,"since":"","summary":[],"notion_configured":true},"overnight_email":{"count":0,"threads":[],"gog_available":false},"calendar_events":[]}}
EOF
)

ONE_MERGED_PR=$(cat <<EOF
{"ok":true,"data":{"repo":"test/repo","as_of":"2026-05-22T03:00:00Z","merged_prs":[{"number":99,"title":"Fix login bug","mergedAt":"${TWELVE_H_AGO}","mergedBy":{"login":"anujj-ti"}}],"ci_failures":[],"stale_prs":[],"autonomous_decisions":{"count":0,"since":"","summary":[],"notion_configured":true},"overnight_email":{"count":0,"threads":[],"gog_available":false},"calendar_events":[]}}
EOF
)

# Stale PR within 24h → On Track
STALE_PR_RECENT=$(cat <<EOF
{"ok":true,"data":{"repo":"test/repo","as_of":"2026-05-22T03:00:00Z","merged_prs":[],"ci_failures":[],"stale_prs":[{"number":55,"title":"Recent PR","updatedAt":"${TWELVE_H_AGO}","reviewDecision":"REVIEW_REQUIRED"}],"autonomous_decisions":{"count":0,"since":"","summary":[],"notion_configured":true},"overnight_email":{"count":0,"threads":[],"gog_available":false},"calendar_events":[]}}
EOF
)

# --- Run Tests ---

print "\n=== standup-insights.sh test suite ==="

# Test 1: empty input → ok:true, empty arrays
run_test "T1: empty standup → classified_items=[], tackle_first=[], patterns=[]" \
  "$EMPTY_STANDUP" \
  '.ok == true and (.data.insights.classified_items | length) == 0 and (.data.insights.tackle_first | length) == 0 and (.data.insights.patterns | length) == 0'

# Test 2: 1 ci_failure (3h ago) → Blocked
run_test "T2: ci_failure 3h ago → Blocked" \
  "$ONE_CI_FAILURE_OLD" \
  '.ok == true and .data.insights.classified_items[0].status == "Blocked" and .data.insights.classified_items[0].source_field == "ci_failures[0]"'

# Test 3: 1 stale_pr (36h ago, CHANGES_REQUESTED) → At Risk
run_test "T3: stale_pr 36h old CHANGES_REQUESTED → At Risk" \
  "$ONE_STALE_PR_AT_RISK" \
  '.ok == true and .data.insights.classified_items[0].status == "At Risk" and .data.insights.classified_items[0].source_field == "stale_prs[0]"'

# Test 4: 4 ci_failures → patterns contains count:4 entry
run_test "T4: 4 ci_failures → patterns[0].count == 4" \
  "$FOUR_CI_FAILURES" \
  '.ok == true and (.data.insights.patterns | map(select(.type == "ci_failures")) | .[0].count) == 4'

# Test 5: Blocked before At Risk in tackle_first
run_test "T5: tackle_first Blocked before At Risk" \
  "$BLOCKED_BEFORE_AT_RISK" \
  '.ok == true and .data.insights.tackle_first[0].status == "Blocked"'

# Test 6: cap at 5 when 8 qualify
run_test "T6: tackle_first capped at 5 with 8 qualifying items" \
  "$EIGHT_FAILURES" \
  '.ok == true and (.data.insights.tackle_first | length) <= 5'

# Test 7: tackle_first always present as array
run_test "T7: tackle_first always present as array (empty standup)" \
  "$EMPTY_STANDUP" \
  '.ok == true and (.data.insights.tackle_first | type) == "array"'

# Test 8: recent ci_failure (30min ago) → On Track
run_test "T8: recent ci_failure → On Track" \
  "$ONE_CI_FAILURE_RECENT" \
  '.ok == true and .data.insights.classified_items[0].status == "On Track"'

# Test 9: invalid JSON → ok:false
run_fail_test "T9: invalid JSON on stdin → exits non-zero or ok:false" \
  "not-valid-json{{"

# Test 10: fewer than 3 same-signal items → patterns=[]
run_test "T10: 1 ci_failure → patterns=[]" \
  "$ONE_CI_FAILURE_OLD" \
  '.ok == true and (.data.insights.patterns | length) == 0'

# Test 11: merged_prs → On Track
run_test "T11: merged_prs → On Track with correct source_field" \
  "$ONE_MERGED_PR" \
  '.ok == true and .data.insights.classified_items[0].status == "On Track" and .data.insights.classified_items[0].source_field == "merged_prs[0]"'

# Test 12: tackle_first items have required fields (title, status, source_field, reason)
run_test "T12: tackle_first items have title/status/source_field/reason" \
  "$ONE_CI_FAILURE_OLD" \
  '.ok == true and (.data.insights.tackle_first[0] | has("title") and has("status") and has("source_field") and has("reason"))'

# Test 13: stale PR within 24h → On Track
run_test "T13: stale PR within 24h → On Track" \
  "$STALE_PR_RECENT" \
  '.ok == true and .data.insights.classified_items[0].status == "On Track"'

print "\n=== Results: $PASS passed, $FAIL failed ==="
if [[ $FAIL -gt 0 ]]; then
  exit 1
fi

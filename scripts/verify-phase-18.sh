#!/usr/bin/env zsh
# verify-phase-18.sh — 10-check structural verification for Phase 18: Decision Quality Risk Gate
# Validates RISK-01 (risk scoring in decision-reviewer), RISK-02 (Telegram approval gate),
# and RISK-03 (fast-pass list + failed verdict policy) across both SOUL.md files.
# Usage: zsh scripts/verify-phase-18.sh
# Exit 0 = all checks pass; Exit N = N checks failed.

set -uo pipefail

DR_SOUL="$HOME/Documents/agentic-setup/.openclaw/agents/decision-reviewer/SOUL.md"
TO_SOUL="$HOME/Documents/agentic-setup/.openclaw/agents/task-orchestrator/SOUL.md"
PASS=0
FAIL=0

check_result() {
  local num="$1"
  local label="$2"
  local code="$3"
  if (( code == 0 )); then
    print "CHECK $num ($label): PASS"
    PASS=$(( PASS + 1 ))
  else
    print "CHECK $num ($label): FAIL — grep did not match expected content in SOUL.md"
    FAIL=$(( FAIL + 1 ))
  fi
}

# ---------------------------------------------------------------------------
# RISK-01 checks — decision-reviewer SOUL.md
# ---------------------------------------------------------------------------

# CHECK 1: risk_score field present
print "CHECK 1 (RISK-01 risk_score field):"
grep -q "risk_score" "$DR_SOUL" 2>/dev/null
check_result 1 "RISK-01 risk_score field" $?

# CHECK 2: risk_tier field present
print "CHECK 2 (RISK-01 risk_tier field):"
grep -q "risk_tier" "$DR_SOUL" 2>/dev/null
check_result 2 "RISK-01 risk_tier field" $?

# CHECK 3: all four scoring dimensions present
print "CHECK 3 (RISK-01 four dimensions):"
{ grep -q "Reversibility" "$DR_SOUL" 2>/dev/null && \
  grep -qE "Blast radius|blast_radius|blast radius" "$DR_SOUL" 2>/dev/null && \
  grep -qE "External side effects|side.effects" "$DR_SOUL" 2>/dev/null && \
  grep -qE "Action recency|action.recency" "$DR_SOUL" 2>/dev/null; }
check_result 3 "RISK-01 four dimensions" $?

# CHECK 4: all three tier ranges present
print "CHECK 4 (RISK-01 tier mapping):"
{ grep -q "61-100" "$DR_SOUL" 2>/dev/null && \
  grep -q "31-60" "$DR_SOUL" 2>/dev/null && \
  grep -q "0-30" "$DR_SOUL" 2>/dev/null; }
check_result 4 "RISK-01 tier mapping" $?

# CHECK 5: D-111 output format block includes risk_score in JSON schema
print "CHECK 5 (RISK-01 D-111 schema updated):"
grep -q '"risk_score"' "$DR_SOUL" 2>/dev/null
check_result 5 "RISK-01 D-111 schema updated" $?

# ---------------------------------------------------------------------------
# RISK-02 checks — task-orchestrator SOUL.md
# ---------------------------------------------------------------------------

# CHECK 6: Anuj's Telegram chat ID present
print "CHECK 6 (RISK-02 Telegram chat ID):"
grep -q "1294664427" "$TO_SOUL" 2>/dev/null
check_result 6 "RISK-02 Telegram chat ID" $?

# CHECK 7: both APPROVE and REJECT response branches documented
print "CHECK 7 (RISK-02 APPROVE/REJECT):"
{ grep -q "APPROVE" "$TO_SOUL" 2>/dev/null && \
  grep -q "REJECT" "$TO_SOUL" 2>/dev/null; }
check_result 7 "RISK-02 APPROVE/REJECT" $?

# CHECK 8: D-507 message format fields present (Risk score + Reversibility)
print "CHECK 8 (RISK-02 D-507 message format):"
{ grep -q "Risk score" "$TO_SOUL" 2>/dev/null && \
  grep -q "Reversibility" "$TO_SOUL" 2>/dev/null; }
check_result 8 "RISK-02 D-507 message format" $?

# ---------------------------------------------------------------------------
# RISK-03 checks — task-orchestrator SOUL.md
# ---------------------------------------------------------------------------

# CHECK 9: three representative fast-pass entries present
print "CHECK 9 (RISK-03 fast-pass list):"
{ grep -q "gh issue comment" "$TO_SOUL" 2>/dev/null && \
  grep -q "bd ready" "$TO_SOUL" 2>/dev/null && \
  grep -qE "synapse\.learning\.record|Synapse learning record" "$TO_SOUL" 2>/dev/null; }
check_result 9 "RISK-03 fast-pass list" $?

# CHECK 10: fallback log path present in failed verdict policy
print "CHECK 10 (RISK-03 fallback log path):"
grep -q "decision-review-fallback.log" "$TO_SOUL" 2>/dev/null
check_result 10 "RISK-03 fallback log path" $?

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
print ""
print "Phase 18 verification: $PASS passed, $FAIL failed"
if (( FAIL == 0 )); then
  print "Phase 18 verification: ALL CHECKS PASSED"
  exit 0
else
  exit $FAIL
fi

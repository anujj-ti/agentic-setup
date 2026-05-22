#!/usr/bin/env zsh
# verify-phase-15.sh — Phase 15 Smarter Email Triage structural verification gate
# Runs 10 structural checks covering TRIAGE-01 through TRIAGE-04.
# Exits 0 only if all 10 checks pass. Exits 1 if any check fails.
# Runtime behavior is NOT tested here (requires a live Gmail account).
set -euo pipefail

PASS=0
FAIL=0

SOUL="/Users/trilogy/Documents/agentic-setup/.openclaw/agents/email-triage/SOUL.md"
AGENTS_MD="/Users/trilogy/Documents/agentic-setup/.openclaw/agents/email-triage/AGENTS.md"
TOOLS_MD="/Users/trilogy/Documents/agentic-setup/.openclaw/agents/email-triage/TOOLS.md"
TRIAGE_SH="/Users/trilogy/Documents/agentic-setup/scripts/email-triage.sh"
NOISE_SENDERS="/Users/trilogy/.openclaw/agents/email-triage/memory/noise-senders.md"
PROCESSED_IDS="/Users/trilogy/.openclaw/agents/email-triage/memory/processed-ids.jsonl"
DRAFTS_DIR="/Users/trilogy/.openclaw/agents/email-triage/memory/drafts"

pass() { print "CHECK $1 ($2): PASS"; (( PASS++ )) }
fail() { print "CHECK $1 ($2): FAIL — $3"; (( FAIL++ )) }

# CHECK 1: SOUL.md has priority scoring with score signals (TRIAGE-01)
if [[ -f "$SOUL" ]] && \
   grep -q "priority_score" "$SOUL" && \
   grep -q "Score 5" "$SOUL" && \
   grep -q "Score 1" "$SOUL"; then
  pass 1 "TRIAGE-01 — SOUL.md priority_score rule"
else
  if [[ ! -f "$SOUL" ]]; then
    fail 1 "TRIAGE-01 — SOUL.md priority_score rule" "SOUL.md not found at $SOUL"
  elif ! grep -q "priority_score" "$SOUL"; then
    fail 1 "TRIAGE-01 — SOUL.md priority_score rule" "priority_score not found in SOUL.md"
  elif ! grep -q "Score 5" "$SOUL"; then
    fail 1 "TRIAGE-01 — SOUL.md priority_score rule" "'Score 5' not found in SOUL.md score mapping table"
  else
    fail 1 "TRIAGE-01 — SOUL.md priority_score rule" "'Score 1' not found in SOUL.md score mapping table"
  fi
fi

# CHECK 2: SOUL.md has the canonical triage table format with priority_score column (TRIAGE-01)
if [[ -f "$SOUL" ]] && grep -q "| priority_score | category | sender | subject | summary |" "$SOUL"; then
  pass 2 "TRIAGE-01 — SOUL.md table format"
else
  if [[ ! -f "$SOUL" ]]; then
    fail 2 "TRIAGE-01 — SOUL.md table format" "SOUL.md not found at $SOUL"
  else
    fail 2 "TRIAGE-01 — SOUL.md table format" "'| priority_score | category | sender | subject | summary |' header not found in SOUL.md"
  fi
fi

# CHECK 3: SOUL.md has the 20% cap rule (TRIAGE-02)
if [[ -f "$SOUL" ]] && \
   grep -q "pct_action_required" "$SOUL" && \
   grep -q "20%" "$SOUL"; then
  pass 3 "TRIAGE-02 — SOUL.md 20% cap rule"
else
  if [[ ! -f "$SOUL" ]]; then
    fail 3 "TRIAGE-02 — SOUL.md 20% cap rule" "SOUL.md not found at $SOUL"
  elif ! grep -q "pct_action_required" "$SOUL"; then
    fail 3 "TRIAGE-02 — SOUL.md 20% cap rule" "pct_action_required metric not found in SOUL.md"
  else
    fail 3 "TRIAGE-02 — SOUL.md 20% cap rule" "'20%' cap threshold not found in SOUL.md"
  fi
fi

# CHECK 4: SOUL.md has hard no-send rule and [DRAFT — NOT SENT] convention (TRIAGE-02 + TRIAGE-03)
if [[ -f "$SOUL" ]] && \
   grep -q "NEVER call" "$SOUL" && \
   grep -q "\[DRAFT — NOT SENT\]" "$SOUL"; then
  pass 4 "TRIAGE-02 + TRIAGE-03 — SOUL.md no-send rule"
else
  if [[ ! -f "$SOUL" ]]; then
    fail 4 "TRIAGE-02 + TRIAGE-03 — SOUL.md no-send rule" "SOUL.md not found at $SOUL"
  elif ! grep -q "NEVER call" "$SOUL"; then
    fail 4 "TRIAGE-02 + TRIAGE-03 — SOUL.md no-send rule" "'NEVER call' directive not found in SOUL.md"
  else
    fail 4 "TRIAGE-02 + TRIAGE-03 — SOUL.md no-send rule" "'[DRAFT — NOT SENT]' header convention not found in SOUL.md"
  fi
fi

# CHECK 5: noise-senders.md exists in deployed location and is seeded with >= 5 patterns (TRIAGE-02)
if [[ -f "$NOISE_SENDERS" ]]; then
  NOISE_COUNT=$(grep -v '^#' "$NOISE_SENDERS" | grep -v '^[[:space:]]*$' | wc -l | tr -d ' ')
  if grep -q "noreply@" "$NOISE_SENDERS" && [[ "$NOISE_COUNT" -ge 5 ]]; then
    pass 5 "TRIAGE-02 — noise-senders.md exists and is seeded ($NOISE_COUNT patterns)"
  elif ! grep -q "noreply@" "$NOISE_SENDERS"; then
    fail 5 "TRIAGE-02 — noise-senders.md exists and is seeded" "noreply@ pattern not present in $NOISE_SENDERS"
  else
    fail 5 "TRIAGE-02 — noise-senders.md exists and is seeded" "only $NOISE_COUNT non-comment entries found (need >= 5)"
  fi
else
  fail 5 "TRIAGE-02 — noise-senders.md exists and is seeded" "file not found at $NOISE_SENDERS — run: zsh scripts/stow-deploy.sh"
fi

# CHECK 6: processed-ids.jsonl exists and drafts/ directory exists (TRIAGE-04)
if [[ -f "$PROCESSED_IDS" ]] && [[ -d "$DRAFTS_DIR" ]]; then
  pass 6 "TRIAGE-04 — processed-ids.jsonl and drafts/ directory exist"
else
  if [[ ! -f "$PROCESSED_IDS" ]] && [[ ! -d "$DRAFTS_DIR" ]]; then
    fail 6 "TRIAGE-04 — processed-ids.jsonl and drafts/ directory exist" "both $PROCESSED_IDS and $DRAFTS_DIR missing — run: zsh scripts/stow-deploy.sh"
  elif [[ ! -f "$PROCESSED_IDS" ]]; then
    fail 6 "TRIAGE-04 — processed-ids.jsonl and drafts/ directory exist" "processed-ids.jsonl not found at $PROCESSED_IDS"
  else
    fail 6 "TRIAGE-04 — processed-ids.jsonl and drafts/ directory exist" "drafts/ directory not found at $DRAFTS_DIR"
  fi
fi

# CHECK 7: AGENTS.md startup checklist references memory files (TRIAGE-04)
if [[ -f "$AGENTS_MD" ]] && \
   grep -q "noise-senders.md" "$AGENTS_MD" && \
   grep -q "processed-ids.jsonl" "$AGENTS_MD"; then
  pass 7 "TRIAGE-04 — AGENTS.md startup steps"
else
  if [[ ! -f "$AGENTS_MD" ]]; then
    fail 7 "TRIAGE-04 — AGENTS.md startup steps" "AGENTS.md not found at $AGENTS_MD"
  elif ! grep -q "noise-senders.md" "$AGENTS_MD"; then
    fail 7 "TRIAGE-04 — AGENTS.md startup steps" "noise-senders.md startup step not found in AGENTS.md"
  else
    fail 7 "TRIAGE-04 — AGENTS.md startup steps" "processed-ids.jsonl startup step not found in AGENTS.md"
  fi
fi

# CHECK 8: email-triage.sh has mark-read wired and references processed-ids.jsonl (TRIAGE-04)
if [[ -f "$TRIAGE_SH" ]] && \
   grep -q "mark-read" "$TRIAGE_SH" && \
   grep -q "processed-ids.jsonl" "$TRIAGE_SH"; then
  pass 8 "TRIAGE-04 — email-triage.sh mark-read wired"
else
  if [[ ! -f "$TRIAGE_SH" ]]; then
    fail 8 "TRIAGE-04 — email-triage.sh mark-read wired" "email-triage.sh not found at $TRIAGE_SH"
  elif ! grep -q "mark-read" "$TRIAGE_SH"; then
    fail 8 "TRIAGE-04 — email-triage.sh mark-read wired" "'mark-read' not found in email-triage.sh (D-161 not implemented)"
  else
    fail 8 "TRIAGE-04 — email-triage.sh mark-read wired" "'processed-ids.jsonl' not found in email-triage.sh (D-162 not implemented)"
  fi
fi

# CHECK 9: email-triage.sh has 500-entry trim (TRIAGE-04)
if [[ -f "$TRIAGE_SH" ]] && grep -q "tail -500" "$TRIAGE_SH"; then
  pass 9 "TRIAGE-04 — email-triage.sh 500-entry trim"
else
  if [[ ! -f "$TRIAGE_SH" ]]; then
    fail 9 "TRIAGE-04 — email-triage.sh 500-entry trim" "email-triage.sh not found at $TRIAGE_SH"
  else
    fail 9 "TRIAGE-04 — email-triage.sh 500-entry trim" "'tail -500' trim not found in email-triage.sh (D-163 not implemented)"
  fi
fi

# CHECK 10: TOOLS.md documents draft format and processed-ids (TRIAGE-03 + TRIAGE-04)
if [[ -f "$TOOLS_MD" ]] && \
   grep -q "memory/drafts/" "$TOOLS_MD" && \
   grep -q "\[DRAFT — NOT SENT\]" "$TOOLS_MD" && \
   grep -q "processed-ids.jsonl" "$TOOLS_MD"; then
  pass 10 "TRIAGE-03 + TRIAGE-04 — TOOLS.md draft format documented"
else
  if [[ ! -f "$TOOLS_MD" ]]; then
    fail 10 "TRIAGE-03 + TRIAGE-04 — TOOLS.md draft format documented" "TOOLS.md not found at $TOOLS_MD"
  elif ! grep -q "memory/drafts/" "$TOOLS_MD"; then
    fail 10 "TRIAGE-03 + TRIAGE-04 — TOOLS.md draft format documented" "'memory/drafts/' not found in TOOLS.md (Plan 15-04 not complete)"
  elif ! grep -q "\[DRAFT — NOT SENT\]" "$TOOLS_MD"; then
    fail 10 "TRIAGE-03 + TRIAGE-04 — TOOLS.md draft format documented" "'[DRAFT — NOT SENT]' header convention not found in TOOLS.md"
  else
    fail 10 "TRIAGE-03 + TRIAGE-04 — TOOLS.md draft format documented" "'processed-ids.jsonl' not found in TOOLS.md"
  fi
fi

print ""
print "Phase 15 verification: $((PASS))/$((PASS + FAIL)) checks passed"
[[ $FAIL -eq 0 ]]

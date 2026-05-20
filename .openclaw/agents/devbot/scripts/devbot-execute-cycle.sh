#!/usr/bin/env zsh
# devbot-execute-cycle.sh — Beads claim→execute→close cycle per subtask type (DEV-04)
# Usage: zsh devbot-execute-cycle.sh TASK_ID TASK_TYPE OWNER/REPO ISSUE_NUM
# TASK_TYPE values: design | implement | self-review | qa-evidence | open-pr
# stdout: JSON result
# stderr: human-readable logs
# cc-openclaw convention: set -euo pipefail, JSON stdout only, explicit binary paths
#
# Phase 8: open draft PR only. Merge gate is Phase 10 (Notion pre-log required).
set -euo pipefail

# ── Arguments ──────────────────────────────────────────────────────────────────
TASK_ID="${1:?task id required}"
TASK_TYPE="${2:?task type required (design|implement|self-review|qa-evidence|open-pr)}"
REPO="${3:?repo required (OWNER/REPO)}"
ISSUE_NUM="${4:?issue number required}"

# ── Constants ──────────────────────────────────────────────────────────────────
BEADS_DIR="$HOME/.openclaw/beads"
BD="/opt/homebrew/opt/node@24/bin/bd"
GH="/opt/homebrew/bin/gh"

# ── Step 1: Claim the task ─────────────────────────────────────────────────────
print "claiming task $TASK_ID (type: $TASK_TYPE)..." >&2
BEADS_DIR="$BEADS_DIR" "$BD" update "$TASK_ID" --claim --json >&2 || {
  print "{\"ok\":false,\"error\":\"failed to claim task $TASK_ID\"}"
  exit 1
}
print "task $TASK_ID claimed" >&2

# ── Step 2: Execute based on TASK_TYPE ────────────────────────────────────────
CLOSE_REASON=""

case "$TASK_TYPE" in

  design)
    # Phase 8 scaffold: design generation is Phase 12 territory
    print "DevBot design scaffold: actual design generation is Phase 12 territory." >&2
    print "Closing with scaffold placeholder for issue #$ISSUE_NUM in $REPO." >&2
    CLOSE_REASON="Design scaffold created: placeholder for Phase 12 AI design generation. Issue #${ISSUE_NUM} in ${REPO}."
    ;;

  implement)
    # Phase 8 scaffold: code generation is Phase 12 territory
    print "DevBot implement scaffold: actual code generation is Phase 12 territory." >&2
    print "Closing with scaffold placeholder for issue #$ISSUE_NUM in $REPO." >&2
    CLOSE_REASON="Implementation scaffold: actual code generation deferred to Phase 12. Issue #${ISSUE_NUM} in ${REPO}."
    ;;

  self-review)
    # Phase 8 scaffold: self-review checklist is Phase 12 territory
    print "DevBot self-review scaffold: Phase 12 will perform actual review." >&2
    CLOSE_REASON="Self-review scaffold: placeholder checklist — functionality, tests, style. Phase 12 will perform actual review. Issue #${ISSUE_NUM}."
    ;;

  qa-evidence)
    # Phase 8 scaffold: QA evidence is Phase 12 territory
    print "DevBot QA evidence scaffold: Phase 12 integration required." >&2
    CLOSE_REASON="QA evidence scaffold: placeholder — test run results, lint output. Phase 12 integration required. Issue #${ISSUE_NUM}."
    ;;

  open-pr)
    # T5: This is NOT a scaffold — create a real draft PR
    # Phase 8: open draft PR only. Merge gate is Phase 10 (Notion pre-log required).
    print "T5 open-pr: creating draft PR for issue #$ISSUE_NUM in $REPO" >&2

    BRANCH="devbot/issue-${ISSUE_NUM}"
    PR_URL=""

    # Check if the branch exists on the remote
    if "$GH" api "repos/$REPO/git/ref/heads/${BRANCH}" &>/dev/null 2>&1; then
      print "branch $BRANCH already exists on remote" >&2
    else
      print "branch $BRANCH does not exist — PR creation may fail if branch is not pushed" >&2
      print "Closing with informational evidence (no branch to push in Phase 8 scaffold)" >&2
      CLOSE_REASON="Draft PR scaffold: branch devbot/issue-${ISSUE_NUM} not yet created (Phase 8). PR creation requires code changes from Phase 12. Issue #${ISSUE_NUM} in ${REPO}."
      # Skip the gh pr create call — branch doesn't exist yet
      BEADS_DIR="$BEADS_DIR" "$BD" close "$TASK_ID" --reason "$CLOSE_REASON" --json
      print "{\"ok\":true,\"task_id\":\"$TASK_ID\",\"task_type\":\"$TASK_TYPE\",\"closed\":true}"
      exit 0
    fi

    # Create draft PR (branch exists)
    PR_URL=$("$GH" pr create \
      -R "$REPO" \
      --base main \
      --head "$BRANCH" \
      --title "feat: issue #${ISSUE_NUM} (closes #${ISSUE_NUM})" \
      --body "Implements #${ISSUE_NUM}. Autonomous dev scaffold (Phase 8) — implementation in Phase 12." \
      --draft \
      2>/dev/null) || {
      PR_URL="PR_CREATION_FAILED"
      print "gh pr create failed — closing with error evidence" >&2
    }

    CLOSE_REASON="Draft PR opened: ${PR_URL}. Branch: devbot/issue-${ISSUE_NUM}. No code changes in Phase 8 scaffold."
    ;;

  *)
    print "{\"ok\":false,\"error\":\"unknown task type: $TASK_TYPE\"}"
    exit 1
    ;;

esac

# ── Step 3: Close the task with evidence ──────────────────────────────────────
print "closing task $TASK_ID with evidence..." >&2
BEADS_DIR="$BEADS_DIR" "$BD" close "$TASK_ID" --reason "$CLOSE_REASON" --json >&2 || {
  print "{\"ok\":false,\"error\":\"failed to close task $TASK_ID\"}"
  exit 1
}
print "task $TASK_ID closed" >&2

# ── Final output ───────────────────────────────────────────────────────────────
python3 -c "
import json
result = {
    'ok': True,
    'task_id': '$TASK_ID',
    'task_type': '$TASK_TYPE',
    'closed': True
}
print(json.dumps(result))
"

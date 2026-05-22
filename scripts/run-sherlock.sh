#!/usr/bin/env zsh
# run-sherlock.sh — invoke Sherlock from OpenClaw agents or any script context
# Usage: zsh run-sherlock.sh "<research question>" [--notion] [--output /path/to/file.md]
# stdout: research report (markdown)
# stderr: progress logs
# exit: 0 on success, 1 on failure
set -euo pipefail

QUESTION=""
SAVE_TO_NOTION=false
OUTPUT_FILE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --notion) SAVE_TO_NOTION=true; shift ;;
    --output) OUTPUT_FILE="$2"; shift 2 ;;
    *) QUESTION="$1"; shift ;;
  esac
done

[[ -z "$QUESTION" ]] && { print "run-sherlock.sh: missing research question" >&2; exit 1; }

CLAUDE=/Users/trilogy/.local/bin/claude
PROJECT_DIR=/Users/trilogy/Documents/agentic-setup

print "Running Sherlock: $QUESTION" >&2

# Run Sherlock headlessly — explicit tool allowlist, no dangerously-skip-permissions
REPORT=$("$CLAUDE" -p "/sherlock \"$QUESTION\"" \
  --allowedTools "WebSearch,WebFetch,Bash(bd *),Bash(BEADS_DIR=*),Bash(export BEADS_DIR=*),Read,Write" \
  --add-dir "$PROJECT_DIR" \
  2>/dev/null)

if [[ -z "$REPORT" ]]; then
  print "run-sherlock.sh: Sherlock returned empty output" >&2
  exit 1
fi

# Save to output file if requested
if [[ -n "$OUTPUT_FILE" ]]; then
  print "$REPORT" > "$OUTPUT_FILE"
  print "Research saved to $OUTPUT_FILE" >&2
fi

# Save to Notion if requested
if [[ "$SAVE_TO_NOTION" == "true" ]]; then
  NOTION_TOKEN=$(security find-generic-password -s 'openclaw.notion-token' -a 'trilogy' -w 2>/dev/null || true)
  SYNAPSE_TOKEN=$(security find-generic-password -s 'openclaw.synapse-token' -a 'trilogy' -w 2>/dev/null || true)
  SYNAPSE_URL="https://cnu.synapse-os.ai"

  if [[ -n "$SYNAPSE_TOKEN" ]]; then
    # Record as a Synapse learning
    CLAIM=$(print "$REPORT" | head -5 | tr '\n' ' ' | cut -c1-200)
    /usr/bin/curl -s -X POST "$SYNAPSE_URL/v1/intent/synapse.learning.record" \
      -H "Authorization: Bearer $SYNAPSE_TOKEN" \
      -H "Content-Type: application/json" \
      -d "{
        \"project_id\": \"project.agentic-setup\",
        \"bd_id\": \"sherlock-$(date +%s)\",
        \"learnings\": [{
          \"claim\": \"Sherlock research: $QUESTION — $CLAIM\",
          \"applies_to\": [\"research\", \"openclaw\"],
          \"confidence\": \"low\"
        }]
      }" >/dev/null 2>&1 || print "Synapse log failed (non-fatal)" >&2
    print "Research recorded to Synapse" >&2
  fi
fi

# Always print report to stdout
print "$REPORT"

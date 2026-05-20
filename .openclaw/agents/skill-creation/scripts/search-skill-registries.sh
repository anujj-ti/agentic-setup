#!/usr/bin/env zsh
# search-skill-registries.sh — best-effort registry search for skill patterns (D-113)
# Usage: search-skill-registries.sh "<pattern_description>"
# Output: human-readable search evidence to stdout (always exits 0)
# All three registries are best-effort — unreachable = "no results" (never a failure)
set -euo pipefail

if [[ $# -lt 1 || -z "${1:-}" ]]; then
  printf '{"ok":false,"error":"usage: search-skill-registries.sh \"<pattern_description>\""}\n'
  exit 1
fi

PATTERN_DESCRIPTION="$1"

printf '## Registry Search Evidence\n'
printf 'Pattern: "%s"\n' "$PATTERN_DESCRIPTION"
printf '\n'

# --- SEARCH 1: GitHub starred repos ---
GH="/opt/homebrew/bin/gh"
GH_STARRED='[]'
GH_COUNT=0

if [[ -x "$GH" ]]; then
  GH_STARRED=$("$GH" api /user/starred --paginate \
    --jq '[.[] | select(.description // "" | test("skill|claude|openclaw|agent"; "i")) | {name:.name, url:.html_url, description:.description}]' \
    2>/dev/null || echo "[]") || GH_STARRED='[]'
  GH_COUNT=$(printf '%s' "$GH_STARRED" | /opt/homebrew/bin/jq 'length' 2>/dev/null || echo "0")
fi

printf '- GitHub starred repos: %s potential matches found\n' "$GH_COUNT"
if [[ "$GH_COUNT" -gt 0 ]]; then
  printf '%s' "$GH_STARRED" | /opt/homebrew/bin/jq -r '.[] | "  * \(.name): \(.url)"' 2>/dev/null || true
fi

# --- SEARCH 2: agentskills.io (follows 308 redirect per research) ---
ENCODED=$(python3 -c "import urllib.parse,sys; print(urllib.parse.quote(sys.argv[1]))" "$PATTERN_DESCRIPTION" 2>/dev/null || printf '%s' "$PATTERN_DESCRIPTION")
AGENTSKILLS=$(curl -s --max-time 5 --location "https://agentskills.io/api/search?q=${ENCODED}" 2>/dev/null || echo "{}") || AGENTSKILLS="{}"
AS_STATUS=$(printf '%s' "$AGENTSKILLS" | /opt/homebrew/bin/jq -r 'if . == {} then "no results or unreachable" else "response received" end' 2>/dev/null || echo "unreachable")
printf '- agentskills.io: searched (result: %s)\n' "$AS_STATUS"

# --- SEARCH 3: ClawHub (unreachable as of 2026-05-21 per research) ---
printf '- ClawHub (clawhub.dev): unreachable as of 2026-05-21 research -- no results logged\n'

printf '\n'
printf '- Conclusion: review results above -- reuse/adapt if match found, author new if no match\n'

exit 0

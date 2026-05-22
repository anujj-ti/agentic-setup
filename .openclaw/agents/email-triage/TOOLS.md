# TOOLS.md — Email Triage Agent

## Available Tools

- **exec**: for `scripts/email-triage.sh` invocation ONLY — do not exec arbitrary system commands
- **read/write**: for `memory/` log files, `memory/drafts/` draft files, `memory/noise-senders.md`, and `memory/processed-ids.jsonl`

## Tool Policy

exec is granted only for Gmail script execution — specifically, calling `scripts/email-triage.sh` to fetch unread mail via gogcli. No other exec usage is permitted.

read/write is granted for all files under the `memory/` directory tree, including:
- `memory/triage-YYYY-MM-DD.md` — daily categorization log
- `memory/noise-senders.md` — noise sender list (read-only at runtime)
- `memory/processed-ids.jsonl` — idempotency log (read at startup, append after each run)
- `memory/drafts/YYYY-MM-DD-<messageId>.md` — draft reply files (write after categorization, never send)

Never write outside the `memory/` directory tree.

- stdout = JSON only for scripts; stderr = human logs
- Node.js path: `/opt/homebrew/opt/node@24/bin/node`
- Never use exec for file operations — use the read/write tool instead
- Never exec any command other than `scripts/gmail-triage.js`

## Environment

- agentDir: `/Users/trilogy/.openclaw/agents/email-triage`
- scripts dir: `/Users/trilogy/.openclaw/agents/email-triage/scripts`
- Node: `/opt/homebrew/opt/node@24/bin/node`
- OpenClaw gateway: `http://localhost:18789`

## Email Triage Script Invocation (Primary — Phase 14+)

Call `email-triage.sh` from the exec tool as follows:
```
zsh /Users/trilogy/Documents/agentic-setup/scripts/email-triage.sh
```

**Before calling:** Confirm `OPENCLAW_GMAIL_ACCOUNT` is set in the environment (default: echo.sys.bot@gmail.com). If the script returns `{"ok":false,"error":"gog-auth-failed"}`, follow the gogcli Re-Auth Runbook below.

Expected output: `{"ok":true,"data":{"threads":[...],"count":N}}`

### gog gmail command reference

All commands require `--no-input --non-interactive` (D-142 — prevents TTY hang in agent context).

| Operation | Command |
|-----------|---------|
| Search unread (24h) | `gog gmail search 'is:unread newer_than:1d' --account echo.sys.bot@gmail.com --max 20 --json --no-input --non-interactive` |
| Get message body | `gog gmail get <messageId> --sanitize-content --json --no-input --non-interactive` |
| Mark as read (by query) | `gog gmail mark-read --account echo.sys.bot@gmail.com --query 'label:triaged is:unread' --no-input --non-interactive` |
| Mark as read (post-triage, all fetched unread) | `gog gmail mark-read --account echo.sys.bot@gmail.com --query 'is:unread newer_than:1d' --no-input --non-interactive` |
| Send reply | `gog gmail send --account echo.sys.bot@gmail.com --to "addr" --subject "Subj" --body "Body" --no-input --non-interactive --json` |

JSON output note: `--json` returns `{"results":[...]}` envelope — extract array with `jq '.results // []'` (D-146).

Note: The post-triage mark-read form is used by email-triage.sh (D-161). mark-read failure is non-fatal — processed-ids.jsonl is the secondary guard.

## Draft Reply File Format (TRIAGE-03)

Draft files live at: `memory/drafts/YYYY-MM-DD-<messageId>.md`

Date is the triage run date (not the email date). messageId is the Gmail message ID from the gog output.

**Required file structure (line 1 MUST be exactly as shown):**

```
[DRAFT — NOT SENT]
To: <original-sender-address>
Subject: Re: <original-subject>

<reply body suggestion>
```

Rules:
- Line 1 must be exactly `[DRAFT — NOT SENT]` — no variation
- Never call `gog gmail send` to deliver draft content — user initiates sending
- Draft creation is triggered by Action Required classification after 20% cap enforcement
- If a draft already exists for a messageId (from a previous run where mark-read failed), overwrite it — idempotent

## Processed-IDs Management (TRIAGE-04)

File location: `memory/processed-ids.jsonl`

**Entry format (one JSON object per line):**
```json
{"id":"<gmailMessageId>","processedAt":"<ISO8601-UTC>"}
```

**Trim command (run after append to keep file at max 500 entries):**
```zsh
tail -500 memory/processed-ids.jsonl > /tmp/processed-ids-trim.jsonl && \
  mv /tmp/processed-ids-trim.jsonl memory/processed-ids.jsonl
```

**Manual recovery:** If the file grows beyond 500 entries due to a script failure, run the trim command above from the agent's working directory. The file should never exceed 500 lines under normal operation (D-163).

**Parse-error policy:** On startup, skip any line that is not valid JSON — log a warning to stderr and continue. Do not abort triage due to a malformed processed-ids line.

## gogcli Re-Auth Runbook (Phase 14+)

Run this when `gog auth doctor --check --account echo.sys.bot@gmail.com` exits non-zero.

### A: Download Desktop OAuth client JSON

1. Go to https://console.cloud.google.com
2. APIs & Services → Credentials → find "gogcli-agent-hub" Desktop app credential
3. Download the JSON file

### B: Store credentials and re-authorize

```zsh
/opt/homebrew/bin/gog auth credentials ~/Downloads/client_secret_*.json
/opt/homebrew/bin/gog auth add echo.sys.bot@gmail.com --services gmail,calendar
```

A browser window opens — sign in as echo.sys.bot@gmail.com and approve Gmail + Calendar scopes.

### C: Verify

```zsh
/opt/homebrew/bin/gog auth doctor --check --account echo.sys.bot@gmail.com
# Exits 0 = success
```

### D: Token expiry note

Tokens expire after 7 days if the OAuth consent screen app is in "Testing" mode.
Fix: Google Cloud Console → APIs & Services → OAuth consent screen → Publish App → In production.

## OAuth2 Re-Auth Runbook (Legacy — gmail-triage.js)

> **Superseded by Phase 14.** The primary invocation is now `email-triage.sh` via gogcli. This runbook remains valid only for re-enabling `gmail-triage.js` if gogcli authorization fails during transition.

Run this when the refresh token is missing or expired. You need a browser and access to Google Cloud Console.

### A: Prerequisites (one-time setup — skip if already done)

1. Go to `console.cloud.google.com` — sign in as or on behalf of `echo.sys.bot@gmail.com`
2. Enable Gmail API: APIs & Services → Library → search "Gmail API" → Enable
3. Configure OAuth consent screen: APIs & Services → OAuth consent screen → External → App name = "AI Operations Hub" → User support email = `echo.sys.bot@gmail.com` → Save
4. Add test user: OAuth consent screen → Test users → + Add Users → `echo.sys.bot@gmail.com` → Save
5. Create Desktop App credential: Credentials → + Create Credentials → OAuth client ID → Application type: **Desktop app** → Name = "Email Triage Agent" → Create
6. Copy the **Client ID** and **Client Secret**

### B: Store credentials in Keychain

```zsh
security add-generic-password -s 'openclaw.gmail-client-id' \
  -a echo.sys.bot@gmail.com -w 'YOUR_CLIENT_ID_HERE' -U

security add-generic-password -s 'openclaw.gmail-client-secret' \
  -a echo.sys.bot@gmail.com -w 'YOUR_CLIENT_SECRET_HERE' -U
```

Replace `YOUR_CLIENT_ID_HERE` and `YOUR_CLIENT_SECRET_HERE` with actual values. The `-U` flag upserts (safe to re-run).

### C: Run the authorization script

```zsh
# Source env vars (picks up credentials from Keychain)
source ~/.openclaw/scripts/openclaw-env.sh

# Navigate to agent scripts directory and run
cd ~/.openclaw/agents/email-triage/scripts
/opt/homebrew/opt/node@24/bin/node oauth2-setup.js
```

A browser window will open automatically. Sign in as `echo.sys.bot@gmail.com`. Approve the requested scopes: **View, send, and modify Gmail messages**.

The terminal will confirm:
```
Refresh token stored in Keychain as openclaw.gmail-triage-refresh-token
```

### D: Verify and restart

```zsh
# Verify token is in Keychain
security find-generic-password -s 'openclaw.gmail-triage-refresh-token' -w >/dev/null && echo "TOKEN PRESENT" || echo "TOKEN MISSING"

# Redeploy and restart gateway to propagate new env var
zsh ~/agentic-setup/scripts/stow-deploy.sh
launchctl kickstart -k gui/$(id -u)/ai.openclaw.gateway
```

### E: Verify agent can reach Gmail

```zsh
# Source env and test the triage script directly
source ~/.openclaw/scripts/openclaw-env.sh
/opt/homebrew/opt/node@24/bin/node ~/.openclaw/agents/email-triage/scripts/gmail-triage.js
# Expected: {"ok":true,"data":{"messages":[...],"count":N}}
```

If `count` is 0, the inbox has no unread messages — this is correct behavior, not an error.

### F: Token expiry notes

- Refresh tokens for personal Gmail accounts do not expire unless explicitly revoked or the app is removed from account access
- If you revoke access: APIs & Services → Credentials → delete the credential, then re-create it and run from Step A
- If Google revokes due to inactivity (rare for actively-used tokens): re-run from Step C
- If you see "Token has been expired or revoked" from `gmail-triage.js`: re-run from Step C

## Keychain Key Reference

| Key name | Env var | Purpose |
|----------|---------|---------|
| `openclaw.gmail-client-id` | `OPENCLAW_GMAIL_CLIENT_ID` | GCP OAuth2 app Client ID |
| `openclaw.gmail-client-secret` | `OPENCLAW_GMAIL_CLIENT_SECRET` | GCP OAuth2 app Client Secret |
| `openclaw.gmail-triage-refresh-token` | `OPENCLAW_GMAIL_TRIAGE_REFRESH_TOKEN` | Gmail API refresh token for echo.sys.bot@gmail.com |
| `token:default:echo.sys.bot@gmail.com` | (gogcli internal) | gogcli OAuth2 refresh token — managed by gog auth, not openclaw secrets pipeline |


---
## Synapse (Mandatory)

Every non-trivial task (file changes, API calls, artifact creation) must use the full loop.
Env vars injected by launchd via openclaw-secrets.sh: $SYNAPSE_TOKEN, $SYNAPSE_URL.

### Step 0 — Fetch briefs (ALWAYS first)
```zsh
/usr/bin/curl -sS -X POST "$SYNAPSE_URL/v1/intent/synapse.brief.fetch" \
  -H "Authorization: Bearer $SYNAPSE_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"project_id": "project.agentic-setup", "include_acked": false}'
```
Ack each brief: POST synapse.brief.ack with the brief_id.

### Step 1 — Open a workflow
```zsh
WF=$(/usr/bin/curl -sS -X POST "$SYNAPSE_URL/v1/intent/synapse.workflow.create" \
  -H "Authorization: Bearer $SYNAPSE_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"project_id": "project.agentic-setup", "workflow_class": "investigation", "title": "<task description>"}')
BD_ID=$(echo "$WF" | python3 -c "import sys,json; print(json.load(sys.stdin)['data']['bd_id'])")
```

### Step 2 — Check in (use the shared script)
```zsh
# Arguments: <project_id> <bd_id> <status> <current_task>
bash ~/Documents/agentic-setup/scripts/synapse-checkin.sh \
  project.agentic-setup "$BD_ID" progress "what I just did"
```
Status values: start | progress | blocked | complete | failed

### Step 3 — Record learnings (use the shared script)
```zsh
# Arguments: <project_id> <bd_id> <claim> <applies_to_tags_csv>
bash ~/Documents/agentic-setup/scripts/synapse-record-learning.sh \
  project.agentic-setup "$BD_ID" \
  "non-obvious reusable insight" \
  "openclaw,<domain-tag>"
```

### Step 4 — Close the workflow
```zsh
bash ~/Documents/agentic-setup/scripts/synapse-checkin.sh \
  project.agentic-setup "$BD_ID" complete "task completed: <outcome summary>"
```

Full protocol: ~/.claude/skills/synapse/SKILL.md

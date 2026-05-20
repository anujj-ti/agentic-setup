# TOOLS.md — Email Triage Agent

## Available Tools

- **exec**: for `scripts/gmail-triage.js` invocation ONLY — do not exec arbitrary system commands
- **read/write**: for `memory/` log files only

## Tool Policy

exec is granted only for Gmail script execution — specifically, calling `scripts/gmail-triage.js` to interact with the Gmail API. No other exec usage is permitted.

- stdout = JSON only for scripts; stderr = human logs
- Node.js path: `/opt/homebrew/opt/node@24/bin/node`
- Never use exec for file operations — use the read/write tool instead
- Never exec any command other than `scripts/gmail-triage.js`

## Environment

- agentDir: `/Users/trilogy/.openclaw/agents/email-triage`
- scripts dir: `/Users/trilogy/.openclaw/agents/email-triage/scripts`
- Node: `/opt/homebrew/opt/node@24/bin/node`
- OpenClaw gateway: `http://localhost:18789`

## Gmail Script Invocation

Call `gmail-triage.js` from the exec tool as follows:
```
/opt/homebrew/opt/node@24/bin/node /Users/trilogy/.openclaw/agents/email-triage/scripts/gmail-triage.js
```

**Before calling:** check that `OPENCLAW_GMAIL_TRIAGE_REFRESH_TOKEN` is non-empty in the environment. If it is empty, the Keychain entry is missing — run the OAuth2 Re-Auth Runbook below.

## OAuth2 Re-Auth Runbook

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

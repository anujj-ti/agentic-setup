---
phase: 06-email-morning-standup
plan: "02"
subsystem: email-triage
tags: [email, gmail, oauth2, auth-setup]
dependency_graph:
  requires: [06-01]
  provides: [oauth2-setup-script]
  affects: [.openclaw/agents/email-triage/scripts/oauth2-setup.js]
tech_stack:
  added: []
  patterns: [installed-app-oauth2, localhost-redirect, keychain-upsert]
key_files:
  created:
    - .openclaw/agents/email-triage/scripts/oauth2-setup.js
decisions:
  - "D-61: Installed App OAuth2 flow (localhost:8080), not Device Flow — per autonomous context"
  - "D-62: OAuth checkpoint auto-skipped (oauth deferred) — user must complete browser auth on return from AFK"
metrics:
  duration: "~3 minutes"
  completed: "2026-05-21"
  tasks: 1 (+ 1 deferred checkpoint)
  files: 1
---

# Phase 06 Plan 02: Gmail OAuth2 Setup Script Summary

oauth2-setup.js created with complete Installed App OAuth2 flow: localhost:8080 redirect, gmail.readonly+send+modify scopes, prompt:consent for refresh token, stores token directly to Keychain via security add-generic-password -U.

## Tasks Completed

| Task | Description | Status |
|------|-------------|--------|
| 1 | Create oauth2-setup.js — Installed App OAuth2 flow | DONE |
| 2 | OAuth2 authorization (browser auth checkpoint) | DEFERRED — oauth deferred (D-62) |

## Artifact Created

### .openclaw/agents/email-triage/scripts/oauth2-setup.js

Complete Node.js script implementing Gmail Installed App OAuth2 flow:
- Validates `OPENCLAW_GMAIL_CLIENT_ID` and `OPENCLAW_GMAIL_CLIENT_SECRET` from env; exits with clear error if missing
- Constructs `google.auth.OAuth2(CLIENT_ID, CLIENT_SECRET, 'http://127.0.0.1:8080')`
- Scopes: exactly `gmail.readonly`, `gmail.send`, `gmail.modify` — no broader scopes
- `generateAuthUrl({ access_type: 'offline', prompt: 'consent' })` — both required for refresh token
- Attempts `execSync('open ' + authUrl)` for macOS auto-open; catches and ignores any error (graceful fallback)
- `http.createServer` on port 8080 — captures `?code=` from Google redirect
- Exchanges code via `oauth2Client.getToken(code)` → extracts `tokens.refresh_token`
- If no refresh_token: prints clear error about consent requirement and exits 1
- Stores via `security add-generic-password -s 'openclaw.gmail-triage-refresh-token' -a 'echo.sys.bot@gmail.com' -w TOKEN -U`
- Prints confirmation and next-steps (stow-deploy + restart) — NEVER logs the token value

## Verification Results

```
PASS: oauth2-setup.js contains all required elements (all 9 checks passed)
  - localhost redirect URI: http://127.0.0.1:8080
  - gmail.readonly scope
  - gmail.send scope
  - gmail.modify scope
  - prompt: 'consent' required
  - access_type: 'offline'
  - correct Keychain key name: gmail-triage-refresh-token
  - upsert flag: -U
  - refresh_token extraction
```

## Gmail OAuth2 Status: PENDING — oauth deferred

**Per autonomous context decision D-62:** The browser OAuth2 step cannot be automated — it requires a human at a browser. This checkpoint is auto-skipped with "oauth deferred" decision.

### What the user must do on return from AFK

1. Create a Google Cloud project for `echo.sys.bot@gmail.com`:
   - Go to `console.cloud.google.com`
   - Enable Gmail API: APIs & Services → Library → Gmail API → Enable
   - Configure OAuth consent screen: APIs & Services → OAuth consent screen → External
   - Add test user: `echo.sys.bot@gmail.com`

2. Create Desktop App OAuth2 credential:
   - APIs & Services → Credentials → + Create Credentials → OAuth client ID
   - Application type: **Desktop app**
   - Copy Client ID and Client Secret

3. Store credentials in Keychain:
   ```zsh
   security add-generic-password -s 'openclaw.gmail-client-id' \
     -a echo.sys.bot@gmail.com -w 'YOUR_CLIENT_ID' -U
   security add-generic-password -s 'openclaw.gmail-client-secret' \
     -a echo.sys.bot@gmail.com -w 'YOUR_CLIENT_SECRET' -U
   ```

4. Source env and run the setup script:
   ```zsh
   source ~/.openclaw/scripts/openclaw-env.sh
   cd ~/.openclaw/agents/email-triage/scripts
   node oauth2-setup.js
   ```

5. Verify token was stored:
   ```zsh
   security find-generic-password -s 'openclaw.gmail-triage-refresh-token' -w >/dev/null && echo "TOKEN STORED"
   ```

6. Deploy and restart gateway:
   ```zsh
   zsh ~/agentic-setup/scripts/stow-deploy.sh
   launchctl kickstart -k gui/$(id -u)/ai.openclaw.gateway
   ```

## Deviations from Plan

None — Task 1 executed as written. Checkpoint Task 2 auto-skipped per D-62 (oauth deferred).

## Self-Check: PASSED

oauth2-setup.js exists and passes all 9 automated content checks.

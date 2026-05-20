# TOOLS.md — Email Triage Agent

## Available Tools

- **exec**: for `scripts/gmail-triage.js` invocation ONLY — do not exec arbitrary system commands
- **read/write**: for `memory/` log files only

## Tool Policy

- exec is granted only for Gmail script execution — specifically `scripts/gmail-triage.js`
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

**Before calling:** check that `OPENCLAW_GMAIL_TRIAGE_REFRESH_TOKEN` is non-empty in the environment. If it is empty, the Keychain entry is missing — run the OAuth2 re-auth runbook below.

## OAuth2 Re-Auth Runbook

See Plan 06-03 for the complete runbook. Short version: run `node scripts/oauth2-setup.js` from the agent scripts directory when the refresh token is missing or expired.

Full location: `.planning/phases/06-email-morning-standup/06-03-SUMMARY.md` and the updated TOOLS.md from Plan 06-03.

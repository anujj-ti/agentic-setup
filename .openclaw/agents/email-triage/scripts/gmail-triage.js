#!/usr/bin/env node
/**
 * gmail-triage.js — Fetch unread Gmail messages for email-triage agent
 *
 * NOTE: This script requires OPENCLAW_GMAIL_TRIAGE_REFRESH_TOKEN in env.
 * Run scripts/oauth2-setup.js once to populate Keychain, then openclaw-secrets.sh
 * sources it automatically.
 *
 * stdout = JSON only ({"ok":true,"data":{...}} or {"ok":false,"error":"..."})
 * stderr = human-readable logs
 */

'use strict';

const { google } = require('googleapis');

// --- Credential validation ---
const clientId = process.env.OPENCLAW_GMAIL_CLIENT_ID;
const clientSecret = process.env.OPENCLAW_GMAIL_CLIENT_SECRET;
const refreshToken = process.env.OPENCLAW_GMAIL_TRIAGE_REFRESH_TOKEN;

if (!clientId) {
  console.log(JSON.stringify({ ok: false, error: 'OPENCLAW_GMAIL_CLIENT_ID is not set. Run: source ~/.openclaw/scripts/openclaw-secrets.sh' }));
  process.exit(1);
}
if (!clientSecret) {
  console.log(JSON.stringify({ ok: false, error: 'OPENCLAW_GMAIL_CLIENT_SECRET is not set. Run: source ~/.openclaw/scripts/openclaw-secrets.sh' }));
  process.exit(1);
}
if (!refreshToken) {
  console.log(JSON.stringify({ ok: false, error: 'OPENCLAW_GMAIL_TRIAGE_REFRESH_TOKEN is not set. Run scripts/oauth2-setup.js to bootstrap Gmail access, then restart the gateway.' }));
  process.exit(1);
}

async function main() {
  // --- OAuth2 client setup ---
  // Redirect URI is required by the constructor but not used for headless refresh token flow
  const oauth2Client = new google.auth.OAuth2(
    clientId,
    clientSecret,
    'http://127.0.0.1:8080'
  );

  // setCredentials with refresh_token — googleapis handles access token refresh automatically
  oauth2Client.setCredentials({
    refresh_token: refreshToken,
  });

  const gmail = google.gmail({ version: 'v1', auth: oauth2Client });

  process.stderr.write('Fetching unread messages from inbox...\n');

  // List unread messages in inbox (max 50)
  const listResult = await gmail.users.messages.list({
    userId: 'me',
    q: 'is:unread in:inbox',
    maxResults: 50,
  });

  const messages = listResult.data.messages || [];
  const count = messages.length;

  process.stderr.write(`Found ${count} unread messages.\n`);

  // Output structured JSON to stdout
  console.log(JSON.stringify({
    ok: true,
    data: {
      messages,
      count,
    },
  }));
}

main().catch((err) => {
  process.stderr.write(`Error: ${err.message}\n`);
  console.log(JSON.stringify({ ok: false, error: err.message }));
  process.exit(1);
});

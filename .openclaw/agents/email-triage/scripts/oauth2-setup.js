#!/usr/bin/env node
/**
 * RUN ONCE MANUALLY to bootstrap Gmail access for echo.sys.bot@gmail.com.
 * Prerequisites:
 *   (1) Set OPENCLAW_GMAIL_CLIENT_ID and OPENCLAW_GMAIL_CLIENT_SECRET env vars from Keychain.
 *   (2) Gmail API enabled for this GCP project.
 *   (3) echo.sys.bot@gmail.com added as OAuth consent screen test user.
 * Command: node scripts/oauth2-setup.js
 */

'use strict';

const { google } = require('googleapis');
const http = require('http');
const { URL } = require('url');
const { execSync } = require('child_process');

// --- Read credentials from env ---
const CLIENT_ID = process.env.OPENCLAW_GMAIL_CLIENT_ID;
const CLIENT_SECRET = process.env.OPENCLAW_GMAIL_CLIENT_SECRET;

if (!CLIENT_ID) {
  console.error('ERROR: OPENCLAW_GMAIL_CLIENT_ID is not set.');
  console.error('Load it from Keychain with:');
  console.error("  source ~/.openclaw/scripts/openclaw-env.sh");
  console.error('Or set it manually:');
  console.error("  export OPENCLAW_GMAIL_CLIENT_ID=$(security find-generic-password -s 'openclaw.gmail-client-id' -w)");
  process.exit(1);
}
if (!CLIENT_SECRET) {
  console.error('ERROR: OPENCLAW_GMAIL_CLIENT_SECRET is not set.');
  console.error('Load it from Keychain with:');
  console.error("  source ~/.openclaw/scripts/openclaw-env.sh");
  console.error('Or set it manually:');
  console.error("  export OPENCLAW_GMAIL_CLIENT_SECRET=$(security find-generic-password -s 'openclaw.gmail-client-secret' -w)");
  process.exit(1);
}

// --- OAuth2 configuration ---
const REDIRECT_URI = 'http://127.0.0.1:8080';
const SCOPES = [
  'https://www.googleapis.com/auth/gmail.readonly',
  'https://www.googleapis.com/auth/gmail.send',
  'https://www.googleapis.com/auth/gmail.modify',
];

// --- Construct OAuth2 client ---
const oauth2Client = new google.auth.OAuth2(CLIENT_ID, CLIENT_SECRET, REDIRECT_URI);

// --- Generate authorization URL ---
// prompt:'consent' is REQUIRED to receive refresh_token on every authorization
const authUrl = oauth2Client.generateAuthUrl({
  access_type: 'offline',
  prompt: 'consent',
  scope: SCOPES,
});

console.log('\n=== GMAIL OAUTH2 SETUP ===\n');
console.log('Open this URL in your browser (sign in as echo.sys.bot@gmail.com):');
console.log('\n' + authUrl + '\n');

// Attempt to auto-open in macOS browser — catch and ignore any error (fallback to manual copy-paste)
try {
  execSync('open ' + JSON.stringify(authUrl));
  console.log('(Browser window opened automatically)');
} catch (_err) {
  console.log('(Could not auto-open browser — please copy and paste the URL above)');
}

console.log('\nWaiting for authorization callback on http://127.0.0.1:8080 ...\n');

// --- Start localhost server to capture the authorization code ---
const server = http.createServer(async (req, res) => {
  // Only handle the first incoming redirect request
  const reqUrl = new URL(req.url, 'http://127.0.0.1:8080');
  const code = reqUrl.searchParams.get('code');

  if (!code) {
    res.writeHead(400, { 'Content-Type': 'text/html' });
    res.end('<html><body><h2>No authorization code found in redirect. Please try again.</h2></body></html>');
    return;
  }

  // Send success response to browser immediately
  res.writeHead(200, { 'Content-Type': 'text/html' });
  res.end('<html><body><h2>Authorization complete. You can close this window.</h2></body></html>');

  // Close the server (we only need one request)
  server.close();

  try {
    // Exchange authorization code for tokens
    const { tokens } = await oauth2Client.getToken(code);

    const refreshToken = tokens.refresh_token;
    if (!refreshToken) {
      console.error("\nERROR: No refresh_token received from Google.");
      console.error("Ensure prompt:'consent' is set and that this is a fresh authorization.");
      console.error('If the account already authorized this app, revoke access first:');
      console.error('  https://myaccount.google.com/permissions');
      process.exit(1);
    }

    // Store refresh token in Keychain (never log the value — security rule)
    // -U flag = upsert: update if exists, create if absent
    execSync(
      "security add-generic-password -s 'openclaw.gmail-triage-refresh-token' -a 'echo.sys.bot@gmail.com' -w '" +
        refreshToken.replace(/'/g, "'\\''") +
        "' -U"
    );

    console.log('\nRefresh token stored in Keychain as openclaw.gmail-triage-refresh-token');
    console.log('\nNext steps:');
    console.log('  1. Run stow-deploy.sh + restart gateway for the env var to propagate to the agent:');
    console.log('       zsh ~/agentic-setup/scripts/stow-deploy.sh');
    console.log('       launchctl kickstart -k gui/$(id -u)/ai.openclaw.gateway');
    console.log('  2. Verify the token is set:');
    console.log("       security find-generic-password -s 'openclaw.gmail-triage-refresh-token' -w >/dev/null && echo 'TOKEN PRESENT'");
    console.log('\nSetup complete.\n');
    process.exit(0);
  } catch (err) {
    console.error('\nERROR during token exchange:', err.message);
    process.exit(1);
  }
});

server.listen(8080, '127.0.0.1', () => {
  // Server is listening — waiting for redirect from Google
});

server.on('error', (err) => {
  if (err.code === 'EADDRINUSE') {
    console.error('\nERROR: Port 8080 is already in use.');
    console.error('Kill the process using port 8080 and try again:');
    console.error('  lsof -i :8080');
    console.error('  kill -9 <PID>');
  } else {
    console.error('\nServer error:', err.message);
  }
  process.exit(1);
});

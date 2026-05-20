'use strict';
// query-decisions.js — retrieves decisions since a timestamp (MEM-02)
// Usage: node query-decisions.js [--since <ISO8601>]
// TODO_NOTION guard: exits 0 with skipped:true when token absent (D-93).

const path = require('path');
const fs = require('fs');

// --- TODO_NOTION guard (D-93) ---
const token = process.env.OPENCLAW_NOTION_TOKEN;
if (!token || token === 'TODO_NOTION' || token.trim() === '') {
  process.stdout.write(JSON.stringify({
    ok: true,
    skipped: true,
    reason: 'OPENCLAW_NOTION_TOKEN not configured'
  }) + '\n');
  process.exit(0);
}

// --- Load config.json ---
const configPath = path.join(__dirname, '..', 'config.json');
let config;
try {
  config = JSON.parse(fs.readFileSync(configPath, 'utf8'));
} catch (err) {
  process.stdout.write(JSON.stringify({ ok: false, error: 'Failed to read config.json: ' + err.message }) + '\n');
  process.exit(0);
}

const NOTION_DECISIONS_DB_ID = config.NOTION_DECISIONS_DB_ID;
if (!NOTION_DECISIONS_DB_ID || NOTION_DECISIONS_DB_ID === 'TODO_SET_THIS') {
  process.stdout.write(JSON.stringify({
    ok: true,
    skipped: true,
    reason: 'NOTION_DECISIONS_DB_ID not configured in config.json'
  }) + '\n');
  process.exit(0);
}

// --- Init @notionhq/client (D-91) ---
const { Client } = require('@notionhq/client');
const notion = new Client({ auth: token, notionVersion: '2026-03-11' });

// --- Determine --since timestamp (D-96) ---
const args = process.argv.slice(2);
let sinceISO = null;

for (let i = 0; i < args.length; i++) {
  if (args[i] === '--since' && args[i + 1]) {
    sinceISO = args[++i];
  }
}

if (!sinceISO) {
  // Try last-session.json from user-orchestrator workspace
  const sessionFile = path.join(process.env.HOME || '/tmp', '.openclaw', 'workspace-user-orchestrator', 'last-session.json');
  try {
    const sessionData = JSON.parse(fs.readFileSync(sessionFile, 'utf8'));
    if (sessionData && sessionData.session_end) {
      sinceISO = sessionData.session_end;
    }
  } catch (err) {
    // File missing or malformed — fall through to default
  }
}

if (!sinceISO) {
  // Default: 24 hours ago
  sinceISO = new Date(Date.now() - 86400000).toISOString();
}

// --- queryDecisionsSince ---
async function queryDecisionsSince(since) {
  // CRITICAL: use timestamp filter with created_time (NOT property filter — pitfall from research)
  const response = await notion.databases.query({
    database_id: NOTION_DECISIONS_DB_ID,
    filter: {
      timestamp: 'created_time',
      created_time: { on_or_after: since }
    },
    sorts: [{ timestamp: 'created_time', direction: 'ascending' }]
  });

  return response.results.map(page => ({
    id: page.id,
    url: page.url,
    created_time: page.created_time,
    decision: (page.properties.decision && page.properties.decision.rich_text[0])
      ? page.properties.decision.rich_text[0].text.content
      : '',
    rationale: (page.properties.rationale && page.properties.rationale.rich_text[0])
      ? page.properties.rationale.rich_text[0].text.content
      : '',
    reversibility: (page.properties.reversibility && page.properties.reversibility.select)
      ? page.properties.reversibility.select.name
      : 'unknown',
    revert_status: (page.properties.revert_status && page.properties.revert_status.select)
      ? page.properties.revert_status.select.name
      : 'active'
  }));
}

// --- Main ---
(async () => {
  try {
    const decisions = await queryDecisionsSince(sinceISO);
    process.stdout.write(JSON.stringify({
      ok: true,
      decisions: decisions,
      count: decisions.length,
      since: sinceISO
    }) + '\n');
    process.exit(0);
  } catch (err) {
    // Non-blocking per D-93
    process.stdout.write(JSON.stringify({ ok: false, error: err.message }) + '\n');
    process.exit(0);
  }
})();

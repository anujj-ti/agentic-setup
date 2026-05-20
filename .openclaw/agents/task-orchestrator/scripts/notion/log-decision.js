'use strict';
// log-decision.js — pre-execution decision logger (MEM-01)
// Reads JSON from stdin, creates a Notion decision log page.
// TODO_NOTION guard: exits 0 with skipped=true when token is absent (D-93).
// Usage: echo '<json>' | node log-decision.js [--dry-run]

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

// --- Init @notionhq/client (per D-91: notionVersion 2026-03-11) ---
const { Client } = require('@notionhq/client');
const notion = new Client({ auth: token, notionVersion: '2026-03-11' });

// --- Helpers ---
function truncate(s, n) {
  n = n || 1990;
  if (!s) return '';
  const str = String(s);
  if (str.length <= n) return str;
  return str.slice(0, n - 3) + '...';
}

const VALID_REVERSIBILITY = ['reversible', 'irreversible', 'unknown'];

// --- Main ---
const isDryRun = process.argv.includes('--dry-run');

let inputData = '';
process.stdin.resume();
process.stdin.setEncoding('utf8');
process.stdin.on('data', chunk => { inputData += chunk; });
process.stdin.on('end', async () => {
  let payload;
  try {
    payload = JSON.parse(inputData || '{}');
  } catch (err) {
    payload = {};
  }

  const decision = truncate(payload.decision || '', 1990);
  const rationale = truncate(payload.rationale || '', 1990);
  const evidence = truncate(payload.evidence || '', 1990);
  const agentId = truncate(payload.agent_id || 'task-orchestrator', 1990);
  const reversibility = VALID_REVERSIBILITY.includes(payload.reversibility)
    ? payload.reversibility
    : 'unknown';

  const name = '[DECISION] ' + (decision.length > 97 ? decision.slice(0, 97) + '...' : decision);
  const timestamp = new Date().toISOString();

  const notionPayload = {
    parent: { database_id: NOTION_DECISIONS_DB_ID },
    properties: {
      Name: { title: [{ text: { content: name } }] },
      decision: { rich_text: [{ text: { content: decision } }] },
      rationale: { rich_text: [{ text: { content: rationale } }] },
      evidence: { rich_text: [{ text: { content: evidence } }] },
      reversibility: { select: { name: reversibility } },
      revert_status: { select: { name: 'active' } },
      timestamp: { date: { start: timestamp } },
      agent_id: { rich_text: [{ text: { content: agentId } }] }
    }
  };

  if (isDryRun) {
    process.stdout.write(JSON.stringify({ ok: true, dry_run: true, payload: notionPayload }) + '\n');
    process.exit(0);
  }

  try {
    const result = await notion.pages.create(notionPayload);
    process.stdout.write(JSON.stringify({
      ok: true,
      page_id: result.id,
      url: result.url
    }) + '\n');
    process.exit(0);
  } catch (err) {
    // Non-blocking per D-93 — exit 0 even on API errors
    process.stdout.write(JSON.stringify({ ok: false, error: err.message }) + '\n');
    process.exit(0);
  }
});

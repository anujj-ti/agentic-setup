'use strict';
// create-experiment-page.js — creates a Notion experiment page with Status=Draft (EVOL-03)
// Usage: node create-experiment-page.js --title <text> --hypothesis <text> --method <text> --successCriteria <text> [--started <ISO8601>]
// On success: prints ONLY the bare Notion page ID to stdout (no JSON wrapper)
// On failure: stderr for details, {"ok":false,"error":"..."} to stdout, exits 1
// Required env vars: OPENCLAW_NOTION_TOKEN, OPENCLAW_NOTION_EXPERIMENTS_DB_ID

// --- Check required env vars ---
const token = process.env.OPENCLAW_NOTION_TOKEN;
if (!token || token.trim() === '') {
  process.stderr.write('OPENCLAW_NOTION_TOKEN not set\n');
  process.stdout.write(JSON.stringify({
    ok: false,
    error: 'OPENCLAW_NOTION_TOKEN not set — see TOOLS.md for setup'
  }) + '\n');
  process.exit(1);
}

const dbId = process.env.OPENCLAW_NOTION_EXPERIMENTS_DB_ID;
if (!dbId || dbId.trim() === '') {
  process.stderr.write('OPENCLAW_NOTION_EXPERIMENTS_DB_ID not set — see TOOLS.md for setup\n');
  process.stdout.write(JSON.stringify({
    ok: false,
    error: 'OPENCLAW_NOTION_EXPERIMENTS_DB_ID not set — security add-generic-password -s openclaw.notion-experiments-db-id -a openclaw -w <db-id>'
  }) + '\n');
  process.exit(1);
}

// --- Parse CLI args ---
const args = process.argv.slice(2);
let title = null;
let hypothesis = null;
let method = null;
let successCriteria = null;
let started = new Date().toISOString();

for (let i = 0; i < args.length; i++) {
  if (args[i] === '--title' && args[i + 1]) title = args[++i];
  else if (args[i] === '--hypothesis' && args[i + 1]) hypothesis = args[++i];
  else if (args[i] === '--method' && args[i + 1]) method = args[++i];
  else if (args[i] === '--successCriteria' && args[i + 1]) successCriteria = args[++i];
  else if (args[i] === '--started' && args[i + 1]) started = args[++i];
}

if (!title || !hypothesis || !method || !successCriteria) {
  process.stderr.write('Missing required args: --title --hypothesis --method --successCriteria\n');
  process.stdout.write(JSON.stringify({ ok: false, error: 'missing required args' }) + '\n');
  process.exit(1);
}

// --- truncate helper ---
function truncate(s, n) {
  n = n || 1990;
  if (!s) return '';
  const str = String(s);
  return str.length <= n ? str : str.slice(0, n - 3) + '...';
}

// --- Init @notionhq/client (D-91: notionVersion 2026-03-11) ---
const { Client } = require('@notionhq/client');
const notion = new Client({ auth: token, notionVersion: '2026-03-11' });

// --- Main ---
(async () => {
  try {
    const page = await notion.pages.create({
      parent: { database_id: dbId },
      properties: {
        Title: { title: [{ text: { content: truncate(title) } }] },
        Status: { select: { name: 'Draft' } },
        Hypothesis: { rich_text: [{ text: { content: truncate(hypothesis) } }] },
        Method: { rich_text: [{ text: { content: truncate(method) } }] },
        'Success Criteria': { rich_text: [{ text: { content: truncate(successCriteria) } }] },
        Started: { date: { start: started } }
      }
    });
    // Print ONLY the bare page ID to stdout (caller captures via $(...))
    process.stdout.write(page.id + '\n');
    process.exit(0);
  } catch (err) {
    process.stderr.write('Notion API error: ' + err.message + '\n');
    process.stdout.write(JSON.stringify({ ok: false, error: err.message }) + '\n');
    process.exit(1);
  }
})();

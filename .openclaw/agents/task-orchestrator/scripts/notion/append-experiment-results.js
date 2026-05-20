'use strict';
// append-experiment-results.js — appends results blocks to a Notion experiment page (MEM-04)
// Usage: node append-experiment-results.js --page-id <id> --results <text>
// TODO_NOTION guard: exits 0 with skipped:true when token absent (D-93).

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

// --- Parse CLI args ---
const args = process.argv.slice(2);
let pageId = null;
let resultsText = null;

for (let i = 0; i < args.length; i++) {
  if (args[i] === '--page-id' && args[i + 1]) {
    pageId = args[++i];
  } else if (args[i] === '--results' && args[i + 1]) {
    resultsText = args[++i];
  }
}

if (!pageId) {
  process.stdout.write(JSON.stringify({ ok: false, error: '--page-id required' }) + '\n');
  process.exit(0);
}

if (!resultsText) {
  process.stdout.write(JSON.stringify({ ok: false, error: '--results required' }) + '\n');
  process.exit(0);
}

// --- Init @notionhq/client (D-91) ---
const { Client } = require('@notionhq/client');
const notion = new Client({ auth: token, notionVersion: '2026-03-11' });

// --- truncate helper ---
function truncate(s, n) {
  n = n || 1990;
  if (!s) return '';
  const str = String(s);
  if (str.length <= n) return str;
  return str.slice(0, n - 3) + '...';
}

// --- appendResults ---
async function appendResults(pid, results) {
  const heading = 'Execution Results — ' + new Date().toISOString();
  return notion.blocks.children.append({
    block_id: pid,
    children: [
      {
        object: 'block',
        type: 'heading_2',
        heading_2: { rich_text: [{ text: { content: heading } }] }
      },
      {
        object: 'block',
        type: 'paragraph',
        paragraph: { rich_text: [{ text: { content: truncate(results) } }] }
      }
    ]
  });
}

// --- Main ---
(async () => {
  try {
    const result = await appendResults(pageId, resultsText);
    process.stdout.write(JSON.stringify({ ok: true, page_id: pageId }) + '\n');
    process.exit(0);
  } catch (err) {
    process.stdout.write(JSON.stringify({ ok: false, error: err.message }) + '\n');
    process.exit(0);
  }
})();

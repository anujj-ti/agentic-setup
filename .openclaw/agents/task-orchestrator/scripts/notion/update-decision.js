'use strict';
// update-decision.js — updates revert_status on an existing Notion page (MEM-03)
// Usage: node update-decision.js --page-id <id> --revert-status <active|reverted|pending_revert>
// TODO_NOTION guard: exits 0 with skipped=true when token absent (D-93).

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
let revertStatus = null;

for (let i = 0; i < args.length; i++) {
  if (args[i] === '--page-id' && args[i + 1]) {
    pageId = args[++i];
  } else if (args[i] === '--revert-status' && args[i + 1]) {
    revertStatus = args[++i];
  }
}

if (!pageId) {
  process.stdout.write(JSON.stringify({ ok: false, error: '--page-id required' }) + '\n');
  process.exit(0);
}

const VALID_STATUSES = ['active', 'reverted', 'pending_revert'];
if (!revertStatus || !VALID_STATUSES.includes(revertStatus)) {
  process.stdout.write(JSON.stringify({
    ok: false,
    error: '--revert-status must be active|reverted|pending_revert'
  }) + '\n');
  process.exit(0);
}

// --- Init @notionhq/client (per D-91: notionVersion 2026-03-11) ---
const { Client } = require('@notionhq/client');
const notion = new Client({ auth: token, notionVersion: '2026-03-11' });

// --- updateRevertStatus ---
async function updateRevertStatus(pageIdArg, status) {
  return notion.pages.update({
    page_id: pageIdArg,
    properties: {
      revert_status: { select: { name: status } }
    }
  });
}

// --- Main ---
(async () => {
  try {
    const result = await updateRevertStatus(pageId, revertStatus);
    process.stdout.write(JSON.stringify({ ok: true, page_id: result.id }) + '\n');
    process.exit(0);
  } catch (err) {
    // Non-blocking per D-93
    process.stdout.write(JSON.stringify({ ok: false, error: err.message }) + '\n');
    process.exit(0);
  }
})();

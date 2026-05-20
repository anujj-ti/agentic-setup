'use strict';
// notion-update-page.js — updates a Notion page with merge commit SHA post-merge
// Usage: node notion-update-page.js --pageId <id> --mergeCommitSha <sha>
// On success: prints {"ok":true} to stdout
// On failure: prints {"ok":false,"error":"..."} to stdout

const token = process.env.OPENCLAW_NOTION_TOKEN;
if (!token || token.trim() === '') {
  process.stderr.write('OPENCLAW_NOTION_TOKEN not set — Phase 9 prerequisite missing\n');
  process.exit(1);
}

const dbId = process.env.OPENCLAW_NOTION_DECISIONS_DB_ID;
if (!dbId || dbId.trim() === '') {
  process.stderr.write('OPENCLAW_NOTION_DECISIONS_DB_ID not set — Phase 9 prerequisite missing\n');
  process.exit(1);
}

// --- Parse CLI args ---
const args = process.argv.slice(2);
let pageId = null;
let mergeCommitSha = null;

for (let i = 0; i < args.length; i++) {
  if (args[i] === '--pageId' && args[i + 1]) pageId = args[++i];
  else if (args[i] === '--mergeCommitSha' && args[i + 1]) mergeCommitSha = args[++i];
}

if (!pageId || !mergeCommitSha) {
  process.stdout.write(JSON.stringify({ ok: false, error: '--pageId and --mergeCommitSha required' }) + '\n');
  process.exit(0);
}

// --- Init @notionhq/client ---
const { Client } = require('@notionhq/client');
const notion = new Client({ auth: token, notionVersion: '2026-03-11' });

// --- Main ---
(async () => {
  try {
    await notion.pages.update({
      page_id: pageId,
      properties: {
        MergeCommitSha: { rich_text: [{ text: { content: mergeCommitSha } }] }
      }
    });
    process.stdout.write(JSON.stringify({ ok: true }) + '\n');
    process.exit(0);
  } catch (err) {
    process.stdout.write(JSON.stringify({ ok: false, error: err.message }) + '\n');
    process.exit(0);
  }
})();

'use strict';
// notion-log-decision.js — writes a decision log entry to Notion and prints bare page ID to stdout
// Usage: node notion-log-decision.js --action <text> --rationale <text> --reversibility <text> --evidence <text>
// On success: prints ONLY the bare page ID to stdout (no JSON wrapper)
// On failure: writes error to stderr and exits 1
// Required env vars: OPENCLAW_NOTION_TOKEN, OPENCLAW_NOTION_DECISIONS_DB_ID

// --- Check required env vars ---
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
let action = null;
let rationale = null;
let reversibility = null;
let evidence = null;

for (let i = 0; i < args.length; i++) {
  if (args[i] === '--action' && args[i + 1]) action = args[++i];
  else if (args[i] === '--rationale' && args[i + 1]) rationale = args[++i];
  else if (args[i] === '--reversibility' && args[i + 1]) reversibility = args[++i];
  else if (args[i] === '--evidence' && args[i + 1]) evidence = args[++i];
}

if (!action || !rationale || !reversibility || !evidence) {
  process.stderr.write('Usage: notion-log-decision.js --action <text> --rationale <text> --reversibility <text> --evidence <text>\n');
  process.exit(1);
}

// --- truncate helper ---
function truncate(s, n) {
  n = n || 1990;
  if (!s) return '';
  const str = String(s);
  if (str.length <= n) return str;
  return str.slice(0, n - 3) + '...';
}

// --- Init @notionhq/client (D-91: notionVersion 2026-03-11) ---
const { Client } = require('@notionhq/client');
const notion = new Client({ auth: token, notionVersion: '2026-03-11' });

// --- Main ---
(async () => {
  try {
    const timestamp = new Date().toISOString();
    const name = '[DECISION] ' + action.slice(0, 97);

    const page = await notion.pages.create({
      parent: { database_id: dbId },
      properties: {
        Name: { title: [{ text: { content: name } }] },
        Action: { rich_text: [{ text: { content: truncate(action) } }] },
        Timestamp: { date: { start: timestamp } },
        Rationale: { rich_text: [{ text: { content: truncate(rationale) } }] },
        Evidence: { rich_text: [{ text: { content: truncate(evidence) } }] },
        Reversibility: { rich_text: [{ text: { content: truncate(reversibility) } }] },
        Status: { select: { name: 'executed' } }
      }
    });
    // Print ONLY the bare page ID to stdout (calling shell script captures via $(...))
    process.stdout.write(page.id + '\n');
    process.exit(0);
  } catch (err) {
    process.stderr.write('Notion API error: ' + err.message + '\n');
    process.exit(1);
  }
})();

'use strict';
// create-experiment.js — creates a structured Notion experiment page (MEM-04)
// Usage: echo '{"hypothesis":"...","method":"...","success_criteria":"..."}' | node create-experiment.js [--dry-run]
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

const NOTION_EXPERIMENTS_PAGE_ID = config.NOTION_EXPERIMENTS_PAGE_ID;
if (!NOTION_EXPERIMENTS_PAGE_ID || NOTION_EXPERIMENTS_PAGE_ID === 'TODO_SET_THIS') {
  process.stdout.write(JSON.stringify({
    ok: true,
    skipped: true,
    reason: 'NOTION_EXPERIMENTS_PAGE_ID not configured in config.json'
  }) + '\n');
  process.exit(0);
}

// --- Init @notionhq/client (D-91) ---
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

function makeHeading2(text) {
  return {
    object: 'block',
    type: 'heading_2',
    heading_2: { rich_text: [{ text: { content: truncate(text) } }] }
  };
}

function makeParagraph(text) {
  return {
    object: 'block',
    type: 'paragraph',
    paragraph: { rich_text: [{ text: { content: truncate(text) } }] }
  };
}

const isDryRun = process.argv.includes('--dry-run');

// --- Read stdin ---
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

  const hypothesis = payload.hypothesis || '';
  const method = payload.method || '';
  const successCriteria = payload.success_criteria || '';

  if (!hypothesis || !method || !successCriteria) {
    process.stdout.write(JSON.stringify({
      ok: false,
      error: 'hypothesis, method, success_criteria required'
    }) + '\n');
    process.exit(0);
  }

  const experimentName = 'Experiment: ' + hypothesis.slice(0, 97);

  const notionPayload = {
    parent: { page_id: NOTION_EXPERIMENTS_PAGE_ID },
    properties: {
      Name: { title: [{ text: { content: experimentName } }] }
    },
    children: [
      makeHeading2('Hypothesis'),
      makeParagraph(hypothesis),
      makeHeading2('Method'),
      makeParagraph(method),
      makeHeading2('Success Criteria'),
      makeParagraph(successCriteria),
      makeHeading2('Results'),
      makeParagraph('Pending — experiment in progress.')
    ]
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
    process.stdout.write(JSON.stringify({ ok: false, error: err.message }) + '\n');
    process.exit(0);
  }
});

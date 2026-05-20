'use strict';
// revert-decision.js — 4-step revert workflow orchestrator (MEM-03)
// Usage: node revert-decision.js --page-id <id> [--rollback-cmd <zsh_cmd>] [--dry-run]
// TODO_NOTION guard: exits 0 with skipped:true when token absent (D-93).

const path = require('path');
const { execSync } = require('child_process');

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
let rollbackCmd = null;
let isDryRun = false;

for (let i = 0; i < args.length; i++) {
  if (args[i] === '--page-id' && args[i + 1]) {
    pageId = args[++i];
  } else if (args[i] === '--rollback-cmd' && args[i + 1]) {
    rollbackCmd = args[++i];
  } else if (args[i] === '--dry-run') {
    isDryRun = true;
  }
}

if (!pageId) {
  process.stdout.write(JSON.stringify({ ok: false, error: '--page-id required' }) + '\n');
  process.exit(0);
}

// --- Resolve SCRIPT_DIR for sibling shell wrappers ---
const SCRIPT_DIR = __dirname;

// --- Helper: run a shell script and return parsed JSON output ---
function runShellScript(scriptName, scriptArgs, stdinData) {
  const scriptPath = path.join(SCRIPT_DIR, scriptName);
  let cmd = `/usr/bin/env zsh "${scriptPath}" ${scriptArgs.join(' ')}`;
  const opts = { timeout: 30000 };
  if (stdinData) {
    opts.input = JSON.stringify(stdinData);
  }
  try {
    const output = execSync(cmd, opts).toString().trim();
    return JSON.parse(output || '{}');
  } catch (err) {
    return { ok: false, error: err.message };
  }
}

// --- Dry-run mode ---
if (isDryRun) {
  process.stdout.write(JSON.stringify({
    ok: true,
    dry_run: true,
    plan: [
      { step: 1, action: 'update-decision.sh --page-id ' + pageId + ' --revert-status pending_revert' },
      { step: 2, action: rollbackCmd ? 'execute rollback: ' + rollbackCmd : 'skip rollback (no --rollback-cmd provided)' },
      { step: 3, action: 'log-decision.sh with [REVERT] prefix in decision field' },
      { step: 4, action: 'update-decision.sh --page-id ' + pageId + ' --revert-status reverted' }
    ]
  }) + '\n');
  process.exit(0);
}

// --- Execute 4-step revert workflow ---
(async () => {
  let stepFailed = null;
  let rollbackEvidence = 'Manual rollback — no command provided';
  let revertPageId = null;

  // Step 1: mark original as pending_revert
  const step1Result = runShellScript('update-decision.sh', ['--page-id', pageId, '--revert-status', 'pending_revert']);
  if (!step1Result.ok && !step1Result.skipped) {
    stepFailed = 'step_1';
    process.stderr.write('Step 1 failed: ' + (step1Result.error || 'unknown') + '\n');
  }

  // Step 2: execute rollback command (optional)
  if (rollbackCmd) {
    try {
      const cmdOutput = execSync(rollbackCmd, { timeout: 30000 }).toString().trim();
      const truncated = cmdOutput.length > 1990 ? cmdOutput.slice(0, 1987) + '...' : cmdOutput;
      rollbackEvidence = truncated || 'Rollback executed (no output)';
    } catch (err) {
      process.stderr.write('Step 2 rollback command failed: ' + err.message + '\n');
      rollbackEvidence = 'Rollback failed: ' + err.message.slice(0, 200);
      if (!stepFailed) stepFailed = 'step_2';
    }
  }

  // Step 3: log the revert as a new decision entry
  const revertPayload = {
    decision: '[REVERT] ' + pageId,
    rationale: 'User requested revert',
    evidence: rollbackEvidence.slice(0, 1990),
    reversibility: 'reversible',
    agent_id: 'task-orchestrator'
  };
  const step3Result = runShellScript('log-decision.sh', [], revertPayload);
  if (step3Result.ok && !step3Result.skipped && step3Result.page_id) {
    revertPageId = step3Result.page_id;
  } else if (!step3Result.ok) {
    process.stderr.write('Step 3 Notion log failed: ' + (step3Result.error || 'unknown') + '\n');
    if (!stepFailed) stepFailed = 'step_3';
  }

  // Step 4: mark original as reverted
  const step4Result = runShellScript('update-decision.sh', ['--page-id', pageId, '--revert-status', 'reverted']);
  if (!step4Result.ok && !step4Result.skipped) {
    process.stderr.write('Step 4 failed: ' + (step4Result.error || 'unknown') + '\n');
    if (!stepFailed) stepFailed = 'step_4';
  }

  if (stepFailed) {
    process.stdout.write(JSON.stringify({
      ok: false,
      step_failed: stepFailed,
      error: 'One or more revert steps failed — see stderr for details',
      original_page_id: pageId,
      revert_entry_id: revertPageId || null,
      rollback_output: rollbackEvidence
    }) + '\n');
  } else {
    process.stdout.write(JSON.stringify({
      ok: true,
      original_page_id: pageId,
      revert_entry_id: revertPageId || null,
      rollback_output: rollbackEvidence
    }) + '\n');
  }
  process.exit(0);
})();

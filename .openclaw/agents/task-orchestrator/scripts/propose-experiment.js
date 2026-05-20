'use strict';
// propose-experiment.js — validates experiment proposal fields before page creation (EVOL-03)
// Usage: node propose-experiment.js --title <text> --hypothesis <text> --method <text> --successCriteria <text> [--started <ISO8601>]
// On validation success: prints validated payload JSON to stdout, exits 0
// On validation failure: prints {"ok":false,"error":"..."} to stdout, exits 1

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

// Validate required fields
if (!title) {
  process.stdout.write(JSON.stringify({ ok: false, error: 'missing required field: title' }) + '\n');
  process.exit(1);
}
if (!hypothesis) {
  process.stdout.write(JSON.stringify({ ok: false, error: 'missing required field: hypothesis' }) + '\n');
  process.exit(1);
}
if (!method) {
  process.stdout.write(JSON.stringify({ ok: false, error: 'missing required field: method' }) + '\n');
  process.exit(1);
}
if (!successCriteria) {
  process.stdout.write(JSON.stringify({ ok: false, error: 'missing required field: successCriteria' }) + '\n');
  process.exit(1);
}

// hypothesis: must be at least 20 characters (basic specificity check)
if (hypothesis.length < 20) {
  process.stdout.write(JSON.stringify({
    ok: false,
    error: 'hypothesis must be at least 20 characters (too vague)'
  }) + '\n');
  process.exit(1);
}

// successCriteria: must contain at least one measurable word
const measurableWords = ['number', '%', 'within', 'count', 'rate', 'zero', 'all', 'none', '<', '>', '<=', '>=', 'ms', 'seconds', 'minutes'];
const hasMeasurable = measurableWords.some(word => successCriteria.toLowerCase().includes(word));
if (!hasMeasurable) {
  process.stdout.write(JSON.stringify({
    ok: false,
    error: 'success criteria must contain a measurable outcome (e.g., %, count, rate, zero, within N)'
  }) + '\n');
  process.exit(1);
}

// All validations passed
process.stdout.write(JSON.stringify({
  ok: true,
  validated: true,
  title: title,
  hypothesis: hypothesis,
  method: method,
  successCriteria: successCriteria,
  started: started
}) + '\n');
process.exit(0);

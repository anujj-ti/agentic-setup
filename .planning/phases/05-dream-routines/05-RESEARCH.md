# Phase 5: Dream Routines — Research

**Researched:** 2026-05-21
**Domain:** OpenClaw memory distillation, cron scheduling, agent lifecycle
**Confidence:** HIGH

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| ORCH-06 | Dream routine runs nightly for both orchestrators: distills daily interactions into MEMORY.md with 2,500-token daily cap and 7,500-token rolling 3-day digest; `memory/archives/` directory exists and receives distillation archives | Fully covered — skill, cron schema, token budget enforcement, archive structure all verified from SKILL.md |
</phase_requirements>

---

## Summary

Phase 5 configures nightly memory distillation for both the User Orchestrator and Task Orchestrator. The `/openclaw-dream-setup` skill encodes everything needed: it creates `DREAM-ROUTINE.md` (the agent's instruction file for the nightly run), adds two QMD path entries to `openclaw.json` for semantic search indexing, creates a cron job entry in `jobs.json`, and ensures the `memory/archives/` directory exists. Token budget enforcement is **prose-based in DREAM-ROUTINE.md**, not a config field — the agent reads the budget instruction ("max 2,500 tokens") from the file and the LLM self-enforces it during distillation.

The most important discovery: the `memory/archives/` directories **already exist** in both live agents (`~/.openclaw/agents/user-orchestrator/memory/archives/` and `~/.openclaw/agents/task-orchestrator/memory/archives/`). This means the mkdir step is already done. What this phase must add is: `DREAM-ROUTINE.md` for each agent, the cron jobs in `.openclaw/cron/jobs.json`, QMD path entries in `openclaw.json`, and the startup memory-load instructions in each agent's `AGENTS.md`.

A second important discovery: the `.openclaw/cron/` directory does **not yet exist** in the repo at `/Users/trilogy/Documents/agentic-setup/.openclaw/cron/`. It must be created before `jobs.json` can be added and stowed.

**Primary recommendation:** Follow `/openclaw-dream-setup` step-by-step for each agent. Do not hand-roll the cron job schema — the `kind/expr` format in the SKILL.md is canonical (not the flat `cron/tz` format mentioned in Phase 1 research, which was a simplified illustration). Stagger the two cron jobs by 5 minutes to prevent concurrent LLM load.

---

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Nightly memory distillation | Agent runtime (OpenClaw cron) | — | The cron wakes the agent in an isolated session; the agent reads its own DREAM-ROUTINE.md and writes to its own memory/ directory |
| Token budget enforcement | Agent (LLM self-enforcement) | DREAM-ROUTINE.md prose rule | No config field; the agent reads the budget constraint from DREAM-ROUTINE.md and applies it during generation |
| Daily log source | Agent workspace (memory/YYYY-MM-DD.md) | — | Ephemeral, gitignored; agent writes during working sessions, dream routine reads at distillation time |
| Archive pipeline | Agent runtime (file I/O) | — | Agent moves distillations older than 3 days to memory/archives/ as part of the dream routine |
| QMD semantic indexing | OpenClaw gateway (memory.qmd.paths) | openclaw.json config | Gateway indexes memory/ and agent-root *.md files for semantic retrieval across sessions |
| Cron scheduling | OpenClaw gateway (cron runner) | jobs.json | Gateway reads jobs.json on each cron tick; jobs.json managed via repo + stow |

---

## Standard Stack

No external packages to install. This phase is pure configuration — flat files, cron JSON entries, and prose directives.

| Artifact | Type | Purpose |
|----------|------|---------|
| `DREAM-ROUTINE.md` | Agent directive file | Nightly instruction set for distillation process; token budget rules; distillation format |
| `.openclaw/cron/jobs.json` | Gateway config | Holds one cron job per agent; gateway reads on each tick |
| `openclaw.json` `memory.qmd.paths` | Gateway config | QMD index paths that the gateway uses for semantic memory retrieval |
| `memory/archives/` | Directory | Receives distillations older than 3 days; already exists in both live agents |

**No new npm packages. No installation step needed for this phase.**

---

## Package Legitimacy Audit

*Phase 5 installs no external packages. Section not applicable.*

---

## Architecture Patterns

### System Architecture Diagram

```
Working Session
    │
    │  agent writes memory/YYYY-MM-DD.md during session
    ▼
memory/YYYY-MM-DD.md   MEMORY.md (long-term)
         │                   │
         └─────────┬─────────┘
                   │ 23:00 IST (user-orchestrator)
                   │ 23:05 IST (task-orchestrator)
                   ▼
        OpenClaw cron wakes agent
        (sessionTarget: isolated)
                   │
                   ▼
        Agent reads DREAM-ROUTINE.md
                   │
                   ▼
        Distills to memory/YYYY-MM-DD-DISTILLED.md
        (max 2,500 tokens — LLM self-enforced)
                   │
                   ▼
        Updates memory/MEMORY-DIGEST.md
        (3-day rolling window, max 7,500 tokens)
                   │
                   ▼
        Archives distillations older than 3 days
        → memory/archives/YYYY-MM-DD-DISTILLED.md
                   │
                   ▼
        Delivery: announce to "last" channel
```

### Recommended Repository Structure After Phase 5

```
.openclaw/
├── openclaw.json                     # + memory.qmd.paths entries for both agents
├── cron/
│   └── jobs.json                     # Two new dream routine cron jobs
└── agents/
    ├── user-orchestrator/
    │   ├── MEMORY.md                 # Already exists (empty)
    │   ├── DREAM-ROUTINE.md          # Created by this phase
    │   └── AGENTS.md                 # Updated with memory load steps
    └── task-orchestrator/
        ├── MEMORY.md                 # Already exists (empty)
        ├── DREAM-ROUTINE.md          # Created by this phase
        └── AGENTS.md                 # Updated with memory load steps
```

```
~/.openclaw/agents/              # Live (stow-managed symlinks)
    user-orchestrator/
        memory/
            archives/            # Already exists
            MEMORY-DIGEST.md     # Created on first dream run
            YYYY-MM-DD.md        # Written during working sessions (gitignored)
    task-orchestrator/
        memory/
            archives/            # Already exists
```

### Pattern 1: Dream Routine Cron Job Schema

**What:** The canonical cron job entry structure as defined in cc-openclaw SKILL.md. The `schedule.kind` + `schedule.expr` form is the correct nested schema — not the flat `schedule.cron` shorthand shown in some older documentation.

**When to use:** Any time a nightly or recurring dream distillation job is added.

**Example (User Orchestrator):**
```json
{
  "id": "<python3-generated-uuid>",
  "agentId": "user-orchestrator",
  "name": "User Orchestrator Dream Routine",
  "enabled": true,
  "createdAtMs": <epoch-ms>,
  "schedule": {
    "kind": "cron",
    "expr": "0 23 * * *",
    "tz": "Asia/Kolkata"
  },
  "sessionTarget": "isolated",
  "wakeMode": "now",
  "payload": {
    "kind": "agentTurn",
    "message": "Run your nightly dream routine. Read DREAM-ROUTINE.md and follow the process exactly. Read today's daily log from memory/, distill it, update the rolling digest, and archive old distillations.",
    "model": "anthropic/claude-sonnet-4-6",
    "timeoutSeconds": 120
  },
  "delivery": {
    "mode": "announce",
    "channel": "last"
  }
}
```

**Example (Task Orchestrator — staggered 5 min later):**
```json
{
  "id": "<python3-generated-uuid>",
  "agentId": "task-orchestrator",
  "name": "Task Orchestrator Dream Routine",
  "enabled": true,
  "createdAtMs": <epoch-ms>,
  "schedule": {
    "kind": "cron",
    "expr": "5 23 * * *",
    "tz": "Asia/Kolkata"
  },
  "sessionTarget": "isolated",
  "wakeMode": "now",
  "payload": {
    "kind": "agentTurn",
    "message": "Run your nightly dream routine. Read DREAM-ROUTINE.md and follow the process exactly. Read today's daily log from memory/, distill it, update the rolling digest, and archive old distillations.",
    "model": "anthropic/claude-sonnet-4-6",
    "timeoutSeconds": 120
  },
  "delivery": {
    "mode": "announce",
    "channel": "last"
  }
}
```

**Source:** [VERIFIED: cc-openclaw/SKILL.md] — `openclaw-dream-setup` and `openclaw-add-cron` SKILL.md files, read directly from repo.

### Pattern 2: DREAM-ROUTINE.md Content

**What:** The prose instruction file the agent reads at the start of each isolated dream session. Token budgets are encoded here — the agent applies them during LLM generation.

**When to use:** One file per agent; content is nearly identical for both orchestrators.

```markdown
# DREAM-ROUTINE.md

## Trigger
Nightly cron at 23:00 Asia/Kolkata (user-orchestrator) / 23:05 Asia/Kolkata (task-orchestrator).

## Process
1. Read today's `memory/YYYY-MM-DD.md`
2. Read `MEMORY.md` for long-term context
3. Distill to `memory/YYYY-MM-DD-DISTILLED.md` (max 2,500 tokens)
4. Update `memory/MEMORY-DIGEST.md` (3-day rolling window, max 7,500 tokens)
5. Archive distillations older than 3 days to `memory/archives/`

## Distillation Format
# Distilled — YYYY-MM-DD

### Decisions
- <decision, who, context>

### Project Updates
- <project>: <change>

### New Context
- <new info worth remembering>

### Completed
- <finished tasks>

### Blockers
- <unresolved issues>

### Tomorrow
- <items needing attention>

## Rules
- NEVER include credentials or secrets
- Stay within 2,500 token budget for the daily distillation
- Stay within 7,500 token budget for MEMORY-DIGEST.md total
- Focus on what CHANGED, not status quo
- If no daily log exists, skip gracefully
```

**Source:** [VERIFIED: cc-openclaw/SKILL.md] — verbatim from `openclaw-dream-setup` Step 3.

### Pattern 3: QMD Path Entries for openclaw.json

**What:** The memory index entries that the OpenClaw gateway uses for semantic retrieval across sessions. These must be added to `openclaw.json` under `memory.qmd.paths`.

**When to use:** After DREAM-ROUTINE.md is in place, before stow.

```json
"memory": {
  "qmd": {
    "paths": [
      {
        "path": "/Users/trilogy/.openclaw/agents/user-orchestrator/memory",
        "name": "user-orchestrator-memory",
        "pattern": "**/*.md"
      },
      {
        "path": "/Users/trilogy/.openclaw/agents/user-orchestrator",
        "name": "user-orchestrator-docs",
        "pattern": "*.md"
      },
      {
        "path": "/Users/trilogy/.openclaw/agents/task-orchestrator/memory",
        "name": "task-orchestrator-memory",
        "pattern": "**/*.md"
      },
      {
        "path": "/Users/trilogy/.openclaw/agents/task-orchestrator",
        "name": "task-orchestrator-docs",
        "pattern": "*.md"
      }
    ]
  }
}
```

**Important:** Use the literal `/Users/trilogy/...` path — never `~` or `$HOME`. The gateway does not expand shell variables in JSON config. [VERIFIED: cc-openclaw/SKILL.md] Step 6, which explicitly says "Replace `$HOME` with the user's actual home directory path."

### Pattern 4: Programmatic cron job creation (no interactive skill)

The `/openclaw-dream-setup` and `/openclaw-add-cron` skills are Claude Code slash commands — they invoke the LLM to read the SKILL.md and execute the steps. The planner can instruct the executor to follow the SKILL.md steps directly, which is equivalent to running the skill.

**Steps the executor must follow (from SKILL.md — no interactive prompt needed):**

1. Detect OPENCLAW_REPO:
   ```bash
   OPENCLAW_REPO=$(readlink ~/.openclaw/openclaw.json 2>/dev/null | sed 's|/.openclaw/openclaw.json||')
   ```

2. Generate a UUID per job:
   ```bash
   python3 -c "import uuid; print(uuid.uuid4())"
   ```

3. Get current epoch milliseconds:
   ```bash
   python3 -c "import time; print(int(time.time() * 1000))"
   ```

4. Create `.openclaw/cron/` directory in repo (does not exist yet):
   ```bash
   mkdir -p "$OPENCLAW_REPO/.openclaw/cron"
   ```

5. Write `jobs.json` with both entries:
   ```bash
   # Read, construct, write using jq or Python — never hand-edit
   ```

6. Stow:
   ```bash
   rm -f ~/.openclaw/cron/jobs.json
   cd "$OPENCLAW_REPO" && stow --no-folding -t ~ .
   ```

**Source:** [VERIFIED: cc-openclaw/SKILL.md] — Steps 5–8 of `openclaw-dream-setup` SKILL.md.

### Anti-Patterns to Avoid

- **Using `schedule.cron` flat key:** Phase 1 research showed a simplified `{"cron": "0 9 * * *", "tz": "..."}` flat structure. The SKILL.md canonical form uses `{"kind": "cron", "expr": "...", "tz": "..."}`. Use the SKILL.md form — it is the authoritative source.
- **Using `~` or `$HOME` in QMD paths:** The gateway reads openclaw.json as a JSON file, not a shell script. Shell variables are not expanded. Always use the literal home path `/Users/trilogy/`.
- **Omitting `tz` from the schedule:** Without `tz`, the gateway defaults to UTC. The cron would fire at 23:00 UTC = 04:30 IST next day — not nightly in the user's timezone.
- **Running both dream routines at the same time:** Concurrent isolated sessions both calling the LLM at 23:00 IST doubles the gateway load and risks rate-limit collisions. Stagger by 5 minutes.
- **Committing `jobs.json` to git:** The gateway owns `~/.openclaw/cron/jobs.json` at runtime and overwrites it on startup. Only the repo version (stowed symlink source) should be tracked. `jobs.json` at `~/.openclaw/cron/` is ephemeral.
- **Using `model: anthropic/claude-sonnet-4-5` in the payload:** The current agent model configured in this repo is `anthropic/claude-sonnet-4-6`. Use the same model in dream routine payloads for consistency. [ASSUMED — SKILL.md shows claude-sonnet-4-5 as a default but the repo uses claude-sonnet-4-6]
- **Relying on MEMORY.md for memory before Phase 5:** Both AGENTS.md files already note "Review memory/MEMORY.md for recent context (once available in Phase 5)" — this phase activates that noop placeholder.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Token counting/truncation | Custom script that counts tokens and truncates the distillation | LLM self-enforcement via DREAM-ROUTINE.md prose budget instruction | The LLM generates text constrained by the instruction; there is no token counter API in this stack |
| Rolling digest management | Script that reads 3 days of logs and concatenates them | Agent follows DREAM-ROUTINE.md step 4: "Update MEMORY-DIGEST.md (3-day rolling window)" | The agent understands date logic; scripted concatenation would require parsing YYYY-MM-DD filenames |
| Archive cleanup | Cron job that runs `find` + `mv` after distillation | Agent follows DREAM-ROUTINE.md step 5: "Archive distillations older than 3 days to memory/archives/" | Agent uses file tools during the dream session; no separate cron needed |
| UUID generation | Custom ID scheme | `python3 -c "import uuid; print(uuid.uuid4())"` | OpenClaw requires standard UUID format in job `id` field |

**Key insight:** Dream routines are agent-executed, not script-executed. The LLM doing the distillation is also the enforcer of the token budget and the archive pipeline. This is intentional — it keeps the logic in readable prose (DREAM-ROUTINE.md) rather than fragile shell scripts.

---

## Runtime State Inventory

*Not applicable — this is a greenfield configuration phase with no renames or migrations.*

However, two relevant pre-existing state items must be noted:

| Category | Items Found | Action Required |
|----------|-------------|------------------|
| Stored data | `~/.openclaw/agents/user-orchestrator/memory/archives/` exists (empty); `~/.openclaw/agents/task-orchestrator/memory/archives/` exists (empty) | No action — directories are ready. Do NOT re-run mkdir for these paths. |
| Stored data | MEMORY.md files are empty stubs in both live agents | Dream routine will fill them on first run; no migration needed |
| Live service config | `openclaw.json` has no `memory.qmd.paths` section | Phase 5 must add QMD entries before stow |
| OS-registered state | `~/.openclaw/cron/jobs.json.bak` exists; live `jobs.json` absent | jobs.json is managed by stow symlink; the .bak is a backup of the empty jobs list from Phase 1 startup |
| Build artifacts | `.openclaw/cron/` directory does not exist in the git repo | Phase 5 must `mkdir -p .openclaw/cron/` before writing jobs.json |

---

## Common Pitfalls

### Pitfall 1: Missing cron/ directory in repo

**What goes wrong:** `stow --no-folding` cannot create `~/.openclaw/cron/jobs.json` as a symlink if `.openclaw/cron/` does not exist in the repo. Stow creates a directory at the target only if the source directory exists first.

**Why it happens:** Phase 1–3 never needed a `cron/jobs.json` in the repo (the gateway started with an empty jobs list). Phase 5 is the first phase that adds cron jobs.

**How to avoid:** `mkdir -p .openclaw/cron/` in the repo before writing `jobs.json`. Commit the directory with a `.gitkeep` placeholder or with `jobs.json` itself.

**Warning signs:** `stow: ERROR: existing target is not a directory: .openclaw/cron` or the symlink not appearing at `~/.openclaw/cron/jobs.json`.

### Pitfall 2: No daily log on first run — dream routine errors

**What goes wrong:** On the very first night after setup, `memory/YYYY-MM-DD.md` does not exist because the agent has not had a working session that day. A naive dream routine fails if it tries to `Read` a file that doesn't exist.

**Why it happens:** The DREAM-ROUTINE.md process step 1 says "Read today's daily log" — but the file may not exist.

**How to avoid:** DREAM-ROUTINE.md already includes a mitigation rule: "If no daily log exists, skip gracefully." The planner must include this rule verbatim in the DREAM-ROUTINE.md file. [VERIFIED: cc-openclaw/SKILL.md] Step 3 "Rules" section.

**Warning signs:** Gateway logs show agent session error on first dream run.

### Pitfall 3: jobs.json stow conflict (inherited from Phase 1)

**What goes wrong:** If the gateway has run since last stow, `~/.openclaw/cron/jobs.json` is a plain file (gateway writes to it). Stow fails with "existing target is not owned by stow."

**Why it happens:** Same root cause as Phase 1 Pitfall 1 — gateway overwrites the symlink with a plain file on every startup.

**How to avoid:** Always run `rm -f ~/.openclaw/cron/jobs.json` immediately before `stow --no-folding -t ~ .`. This is baked into `scripts/stow-deploy.sh`.

**Warning signs:** `ERROR: stow: existing target is not owned by stow: cron/jobs.json`

### Pitfall 4: Token budget not enforced — oversized distillation

**What goes wrong:** The dream routine writes a 5,000-token distillation file because the LLM generated a verbose summary.

**Why it happens:** Token budget enforcement is LLM self-enforcement only. If the DREAM-ROUTINE.md rule says "max 2,500 tokens" but the agent is in a verbose mode, the budget is advisory.

**How to avoid:** Write the budget rule as a hard constraint in the RULES section: "NEVER generate a distillation longer than 2,500 tokens. If you find yourself about to exceed this limit, truncate and stop." Verification (Phase 5 Success Criterion 3) uses `wc -w` as a proxy count.

**Warning signs:** `wc -w ~/.openclaw/agents/user-orchestrator/memory/YYYY-MM-DD-DISTILLED.md` returns > ~1875 words (2,500 tokens ≈ ~1875 words at typical compression). Exact token count requires the tokenizer.

### Pitfall 5: QMD path uses ~ or $HOME

**What goes wrong:** Gateway fails to index memory files for semantic search. `/openclaw-status` may show QMD paths as unresolved.

**Why it happens:** `openclaw.json` is parsed as JSON, not shell. Shell expansion does not occur.

**How to avoid:** Use the literal path `/Users/trilogy/.openclaw/agents/...` — never `~` or `$HOME`. [VERIFIED: cc-openclaw/SKILL.md] Step 6 explicit note.

---

## Code Examples

### Generate UUID and epoch-ms for jobs.json

```bash
# Source: cc-openclaw/openclaw-dream-setup/SKILL.md Step 5
UUID=$(python3 -c "import uuid; print(uuid.uuid4())")
EPOCH_MS=$(python3 -c "import time; print(int(time.time() * 1000))")
echo "UUID: $UUID"
echo "Epoch ms: $EPOCH_MS"
```

### Build jobs.json with two dream routine entries

```bash
#!/usr/bin/env zsh
set -euo pipefail

OPENCLAW_REPO=$(readlink ~/.openclaw/openclaw.json 2>/dev/null | sed 's|/.openclaw/openclaw.json||')
UUID_UO=$(python3 -c "import uuid; print(uuid.uuid4())")
UUID_TO=$(python3 -c "import uuid; print(uuid.uuid4())")
EPOCH_MS=$(python3 -c "import time; print(int(time.time() * 1000))")

mkdir -p "$OPENCLAW_REPO/.openclaw/cron"

python3 -c "
import json, sys
jobs = {
  'version': 1,
  'jobs': [
    {
      'id': '$UUID_UO',
      'agentId': 'user-orchestrator',
      'name': 'User Orchestrator Dream Routine',
      'enabled': True,
      'createdAtMs': $EPOCH_MS,
      'schedule': {'kind': 'cron', 'expr': '0 23 * * *', 'tz': 'Asia/Kolkata'},
      'sessionTarget': 'isolated',
      'wakeMode': 'now',
      'payload': {
        'kind': 'agentTurn',
        'message': 'Run your nightly dream routine. Read DREAM-ROUTINE.md and follow the process exactly. Read today\\'s daily log from memory/, distill it, update the rolling digest, and archive old distillations.',
        'model': 'anthropic/claude-sonnet-4-6',
        'timeoutSeconds': 120
      },
      'delivery': {'mode': 'announce', 'channel': 'last'}
    },
    {
      'id': '$UUID_TO',
      'agentId': 'task-orchestrator',
      'name': 'Task Orchestrator Dream Routine',
      'enabled': True,
      'createdAtMs': $EPOCH_MS,
      'schedule': {'kind': 'cron', 'expr': '5 23 * * *', 'tz': 'Asia/Kolkata'},
      'sessionTarget': 'isolated',
      'wakeMode': 'now',
      'payload': {
        'kind': 'agentTurn',
        'message': 'Run your nightly dream routine. Read DREAM-ROUTINE.md and follow the process exactly. Read today\\'s daily log from memory/, distill it, update the rolling digest, and archive old distillations.',
        'model': 'anthropic/claude-sonnet-4-6',
        'timeoutSeconds': 120
      },
      'delivery': {'mode': 'announce', 'channel': 'last'}
    }
  ]
}
print(json.dumps(jobs, indent=2))
" > "$OPENCLAW_REPO/.openclaw/cron/jobs.json"

echo "jobs.json written to $OPENCLAW_REPO/.openclaw/cron/jobs.json" >&2
```

### Stow and verify

```bash
# Source: cc-openclaw/openclaw-dream-setup/SKILL.md Step 8
OPENCLAW_REPO=$(readlink ~/.openclaw/openclaw.json 2>/dev/null | sed 's|/.openclaw/openclaw.json||')
rm -f ~/.openclaw/cron/jobs.json
cd "$OPENCLAW_REPO" && stow --no-folding -t ~ .

# Verify symlink restored
ls -la ~/.openclaw/cron/jobs.json
# Should show: ~/.openclaw/cron/jobs.json -> .../agentic-setup/.openclaw/cron/jobs.json
```

### Verify dream routines in /openclaw-status

```bash
/opt/homebrew/bin/openclaw gateway status --json 2>/dev/null | python3 -c "
import json, sys
d = json.load(sys.stdin)
jobs = d.get('cron', {}).get('jobs', [])
dream_jobs = [j for j in jobs if 'Dream Routine' in j.get('name', '')]
for j in dream_jobs:
    print(f\"  {j['agentId']}: {j['schedule']['expr']} tz={j['schedule']['tz']} enabled={j['enabled']}\")
if not dream_jobs:
    print('ERROR: No dream routine jobs found')
    sys.exit(1)
"
```

### Verify token cap (proxy via word count)

```bash
# 2,500 tokens ≈ 1,875 words at ~1.33 tokens/word average
# Word count is a proxy — exact token count requires Anthropic tokenizer
TODAY=$(date +%Y-%m-%d)
DISTILLED="$HOME/.openclaw/agents/user-orchestrator/memory/${TODAY}-DISTILLED.md"
if [[ -f "$DISTILLED" ]]; then
  WC=$(wc -w < "$DISTILLED")
  echo "Word count: $WC (budget proxy: ≤1875 words ≈ ≤2500 tokens)"
  [[ "$WC" -le 1875 ]] && echo "PASS" || echo "WARN: may exceed 2500 token budget"
else
  echo "No distilled file yet — first run pending"
fi
```

### Verify archive file creation (after first run)

```bash
ls ~/.openclaw/agents/user-orchestrator/memory/archives/ 2>/dev/null \
  && echo "archives dir populated" \
  || echo "archives dir empty (expected until first run)"

ls ~/.openclaw/agents/task-orchestrator/memory/archives/ 2>/dev/null \
  && echo "archives dir populated" \
  || echo "archives dir empty (expected until first run)"
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Flat `schedule.cron` key | Nested `schedule.kind` + `schedule.expr` | OpenClaw 2026.x cron schema | Use `kind/expr` — flat form is a simplified illustration from older docs |
| Manual DREAM-ROUTINE.md authoring | `/openclaw-dream-setup` skill | cc-openclaw launch | Skill encodes token budgets, QMD wiring, archive pipeline, stagger timing |
| Global QMD indexing | Per-agent QMD paths in `memory.qmd.paths` | OpenClaw memory system | Scoped indexing avoids cross-agent memory contamination |

**Deprecated/outdated:**
- Flat `schedule.cron` shorthand: Appears in Phase 1 research illustrations but the canonical schema from both SKILL.md files uses `kind/expr`. Treat as outdated.

---

## Open Questions

1. **Can the gateway actually receive the `delivery.channel: "last"` directive for task-orchestrator (which has no Telegram channel)?**
   - What we know: Task Orchestrator has no channel binding in `openclaw.json`. User Orchestrator is bound to Telegram.
   - What's unclear: Whether `"channel": "last"` resolves to nothing (silent), falls back to Telegram, or errors for an unbound agent.
   - Recommendation: For task-orchestrator's dream job, set `"channel": "telegram"` explicitly or omit the delivery block entirely and test on first run. If the gateway errors, switch to `"mode": "silent"`.

2. **Does the Phase 1 INFRA-06 test cron job still exist in live jobs.json?**
   - What we know: `~/.openclaw/cron/jobs.json.bak` shows `{"version": 1, "jobs": []}` — the backup is empty. The live `jobs.json` is absent (managed by stow, currently not stowed because the repo has no `cron/` dir).
   - What's unclear: Whether a test cron job was ever actually committed to the repo from Phase 1, Plan 01-05 (that plan is still "not started" per ROADMAP).
   - Recommendation: Phase 5 starts fresh — create `jobs.json` with only the two dream routine entries. When Phase 1 Plan 01-05 eventually runs, it will add the test cron job alongside them.

3. **Model version for dream routine payload**
   - What we know: The SKILL.md default is `anthropic/claude-sonnet-4-5`; the live agents use `anthropic/claude-sonnet-4-6`.
   - What's unclear: Whether the payload model must match the agent's configured model or can differ.
   - Recommendation: Use `anthropic/claude-sonnet-4-6` in the payload to match the existing agent configuration. [ASSUMED]

---

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| OpenClaw gateway | Cron runner | ✓ | 2026.5.18 | — |
| Python 3 | UUID + epoch generation | ✓ | System python3 | Use `uuidgen` CLI + `date +%s%3N` for epoch |
| GNU Stow | Deploy cron/jobs.json | ✓ | Latest via brew | — |
| `jq` | JSON verification | ✓ | Latest via brew | Python3 can substitute |
| `~/.openclaw/agents/*/memory/archives/` | Archive destination | ✓ (both exist) | — | `mkdir -p` if absent |

**Missing dependencies:** None blocking.

---

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | Shell smoke tests (zsh, no test runner) |
| Config file | none |
| Quick run command | `zsh scripts/verify-phase-05.sh` |
| Full suite command | `zsh scripts/verify-phase-05.sh` |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| ORCH-06 | Dream cron jobs exist for both agents in openclaw-status | smoke | `openclaw gateway status --json \| python3 -c "..."` (see Code Examples) | ❌ Wave 0 |
| ORCH-06 | Archives directory exists for both agents | smoke | `test -d ~/.openclaw/agents/user-orchestrator/memory/archives && test -d ~/.openclaw/agents/task-orchestrator/memory/archives` | ✅ (already exists) |
| ORCH-06 | DREAM-ROUTINE.md present for both agents | smoke | `test -f ~/.openclaw/agents/user-orchestrator/DREAM-ROUTINE.md && test -f ~/.openclaw/agents/task-orchestrator/DREAM-ROUTINE.md` | ❌ Wave 0 |
| ORCH-06 | jobs.json symlink is valid stow symlink | smoke | `test -L ~/.openclaw/cron/jobs.json` | ❌ Wave 0 |
| ORCH-06 | Cron jobs have correct timezone (Asia/Kolkata, not UTC) | smoke | `jq '.jobs[].schedule.tz' ~/.openclaw/cron/jobs.json \| grep -v UTC` | ❌ Wave 0 |
| ORCH-06 | Daily distillation ≤ 2,500 tokens (post-first-run) | manual | `wc -w` proxy check on DISTILLED.md | manual |
| ORCH-06 | 3-day digest ≤ 7,500 tokens (post-first-run) | manual | `wc -w` proxy check on MEMORY-DIGEST.md | manual |

### Sampling Rate
- **Per task commit:** `test -f ~/.openclaw/agents/user-orchestrator/DREAM-ROUTINE.md && test -L ~/.openclaw/cron/jobs.json`
- **Per wave merge:** `zsh scripts/verify-phase-05.sh`
- **Phase gate:** Full suite green before `/gsd:verify-work`; post-first-run token checks require a separate manual verification session the morning after first cron execution

### Wave 0 Gaps
- [ ] `scripts/verify-phase-05.sh` — covers all automated ORCH-06 checks above

---

## Security Domain

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no | — |
| V3 Session Management | no | — |
| V4 Access Control | yes | `sessionTarget: isolated` — dream session has no access to other agents or channels |
| V5 Input Validation | no | No external input processed |
| V6 Cryptography | no | — |

### Known Threat Patterns for Dream Routines

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Secret leakage into distillation | Information Disclosure | DREAM-ROUTINE.md Rule: "NEVER include credentials or secrets" — agent instruction enforced |
| Memory poisoning via daily log | Tampering | Daily logs are gitignored and written only by the same agent that reads them; no external write path |
| Runaway session cost | Denial of Service | `timeoutSeconds: 120` hard limit in cron payload |

---

## Sources

### Primary (HIGH confidence)
- `cc-openclaw/.claude/skills/openclaw-dream-setup/SKILL.md` — read directly from repo; defines DREAM-ROUTINE.md content, cron job schema, QMD path entries, stagger timing, token budgets
- `cc-openclaw/.claude/skills/openclaw-add-cron/SKILL.md` — read directly from repo; confirms `schedule.kind/expr/tz` canonical schema, `isolated` session target, delivery block
- `/Users/trilogy/Documents/agentic-setup/.planning/ROADMAP.md` — Phase 5 success criteria
- `/Users/trilogy/Documents/agentic-setup/.planning/REQUIREMENTS.md` — ORCH-06 definition
- `CLAUDE.md` — memory budget constraints (2,500 daily / 7,500 rolling digest)
- Live filesystem inspection: `memory/archives/` exists in both agents; no `cron/` in repo; timezone is Asia/Kolkata

### Secondary (MEDIUM confidence)
- `/Users/trilogy/Documents/agentic-setup/.planning/phases/01-infrastructure/01-RESEARCH.md` — cron job structure examples (used as cross-reference; note flat `schedule.cron` form is illustrative, not canonical)
- `/Users/trilogy/Documents/agentic-setup/.openclaw/openclaw.json` — current config; no `memory.qmd.paths` section yet confirmed

### Tertiary (LOW confidence)
- None

---

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | Dream routine payload should use `anthropic/claude-sonnet-4-6` (matching live agent config) instead of SKILL.md default `claude-sonnet-4-5` | Pattern 1: Cron Job Schema | Dream routine runs on older model; minor quality difference, no failure |
| A2 | `delivery.channel: "last"` for task-orchestrator resolves silently (not an error) given it has no channel binding | Open Question 1 | Gateway may error on first run; mitigated by Open Question 1 recommendation |

**If this table is empty:** Not empty — two assumptions need validation during execution.

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — no external packages; all config patterns directly read from SKILL.md
- Architecture: HIGH — skill defines the canonical flow; runtime state verified on live filesystem
- Pitfalls: HIGH — inherited from Phase 1 research (jobs.json stow conflict) plus new Phase 5 specific items discovered in SKILL.md
- Token budget mechanism: HIGH — confirmed as LLM self-enforcement, not a config field
- Archive directory: HIGH — confirmed to already exist at live path; no mkdir needed
- Schedule schema: HIGH — `kind/expr` form read directly from SKILL.md; flat form identified as illustrative only
- Delivery block for task-orchestrator: LOW — unbound agent channel behavior not documented in available sources

**Research date:** 2026-05-21
**Valid until:** 2026-08-21 (90 days — OpenClaw config schemas are stable)

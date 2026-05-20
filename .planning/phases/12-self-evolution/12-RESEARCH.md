# Phase 12: Self-Evolution — Research

**Researched:** 2026-05-21
**Domain:** Pattern-repeat detection in agent memory, automatic Skill Creation trigger, experiment framework, mandatory /openclaw-new-agent enforcement
**Confidence:** MEDIUM-HIGH

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| EVOL-01 | Task Orchestrator scaffolds new agents via `/openclaw-new-agent` when a domain repeats that no existing agent covers — proposal reviewed by Decision Reviewer before execution | Covered — mechanism is counter in Task Orchestrator MEMORY.md + Decision Reviewer gate + `/openclaw-new-agent` skill invocation |
| EVOL-02 | When a procedural pattern repeats ≥2 times, Skill Creation agent is triggered automatically — full cycle (propose → search → author → review → stow) completes without user intervention | Covered — counter stored in Task Orchestrator operational memory; threshold = 2; Skill Creation session spawned on second occurrence |
| EVOL-03 | Experiment framework: Task Orchestrator proposes experiment, spawns agents, collects results, logs full cycle to Notion with Document Reviewer validation before page is finalized | Covered — experiment lifecycle defined; Notion page structure specified; Document Reviewer is the gate before finalization |
</phase_requirements>

---

## Summary

Phase 12 is the final phase and has no new infrastructure dependencies — it is entirely a behavioral configuration phase for the Task Orchestrator. All three EVOL requirements are implemented by updating the Task Orchestrator's SOUL.md with new rules and corresponding operational procedures in TOOLS.md and MEMORY.md.

The self-evolution capabilities are built on three primitives already established in prior phases: (1) Beads task graphs for structured execution, (2) sessions_spawn for agent delegation, and (3) `/openclaw-new-agent` and Skill Creation agent from Phase 11. Phase 12 adds the *trigger logic* — how the Task Orchestrator decides when to fire these capabilities.

**Pattern-repeat detection** (EVOL-02) is the simplest mechanism: the Task Orchestrator maintains a `pattern_counter` section in its MEMORY.md (a plain Markdown table). When it executes a procedure, it checks the table for a matching pattern name and increments the count. When count reaches 2, it adds a Beads task to the current epic to trigger Skill Creation. The counter lives in MEMORY.md (the same file the nightly dream routine distills) so counts survive across sessions.

**New agent proposal** (EVOL-01) is triggered by the Task Orchestrator observing repeated domain requests across multiple Beads epics with no matching agent in `openclaw.json agents.list`. The proposal is a structured document sent to Decision Reviewer via sessions_spawn. Only after `{"verdict": "pass"}` does the Task Orchestrator invoke `/openclaw-new-agent`. The mandatory rule is enforced in SOUL.md: "NEVER create directive files for a new agent manually. `/openclaw-new-agent` is the ONLY permitted scaffolding path."

**Experiment framework** (EVOL-03) follows a four-stage lifecycle: (1) Task Orchestrator writes an experiment proposal Notion page (hypothesis, method, success criteria) before any agents are spawned; (2) agents execute in Beads task graph; (3) results are collected as Beads close reasons; (4) Task Orchestrator writes the results section of the Notion experiment page, then Document Reviewer reviews the completed page before it is marked "Final." The Document Reviewer gate means the Notion page is in "Draft" status until reviewer passes it.

**The mandatory `/openclaw-new-agent` rule** is verified by attempting to create a new agent via direct file creation (writing SOUL.md manually) — this should be detectable in the verify script because the new agent's `agentDir` would appear in `~/.openclaw/agents/` but its entry would be absent from `openclaw.json` (since stow would not have run). The SOUL.md rule creates the behavioral constraint; the verify step creates the observable test.

**Primary recommendation:** Five plans: (1) add self-evolution rules to Task Orchestrator SOUL.md; (2) implement agent proposal workflow with Decision Reviewer gate; (3) implement pattern-repeat counter mechanism; (4) implement experiment framework with Notion lifecycle; (5) verify the `/openclaw-new-agent` enforcement gate.

---

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Pattern-repeat counting | Task Orchestrator MEMORY.md (persistent counter table) | Nightly dream routine (distills and preserves counts) | Memory.md survives sessions; dream routine prevents count loss during distillation |
| New agent domain detection | Task Orchestrator (observes Beads epic domains over time) | — | Task Orchestrator sees all delegated work; it knows when no sub-agent matches a domain |
| Agent proposal document | Task Orchestrator (authors proposal) | Decision Reviewer (reviews) | Same decision review gate as all autonomous decisions (Phase 11) |
| Agent scaffolding execution | `/openclaw-new-agent` skill (only permitted path) | Task Orchestrator (invoker) | Skill encodes correct scaffolding procedure; manual file creation is prohibited |
| Skill trigger | Task Orchestrator (fires after pattern count ≥ 2) | Skill Creation agent (Phase 11) | Trigger logic is in Task Orchestrator SOUL.md; execution is delegated to Skill Creation |
| Experiment proposal Notion page | Task Orchestrator (writes before execution starts) | Document Reviewer (validates after results) | Pre-execution page creation ensures experiment is logged even if agents fail mid-run |
| Experiment execution | Beads task graph (Task Orchestrator creates) | Execution-tier sub-agents (claim/close) | Standard Beads pattern — no deviation from established execution model |
| Experiment results write + review | Task Orchestrator (writes results) → Document Reviewer (gates finalization) | — | Two-step: Task Orchestrator writes results; Document Reviewer approves before Notion page moves to "Final" |

---

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| `/openclaw-new-agent` skill | HEAD (cc-openclaw) | Only permitted agent scaffolding path | EVOL-01 enforcement; CLAUDE.md mandated; all prior phases use this |
| Beads (`bd`) | 1.0.4 | Experiment task graph + sub-agent orchestration | Established in Phase 4; SOUL.md contract |
| `@notionhq/client` | 5.22.0 | Experiment Notion page creation and update | CLAUDE.md mandated; established in Phase 9/10 |
| Task Orchestrator MEMORY.md | — (plain Markdown) | Pattern-repeat counter persistence | Survives session boundaries; distilled nightly; simple, no new infrastructure |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| `jq` | System (brew) | Parse openclaw.json for existing agent list during domain gap check | Agent domain detection — scan `agents.list[].id` |

### No new packages needed
Phase 12 adds no new npm dependencies or CLI tools. All capabilities are implemented via SOUL.md rule updates, MEMORY.md counter additions, and behavioral configuration changes.

---

## Package Legitimacy Audit

*Phase 12 installs no external packages. All capabilities are implemented via SOUL.md rule updates and existing tooling from prior phases. Section not applicable.*

---

## Architecture Patterns

### System Architecture Diagram

```
Task Orchestrator (receives delegated task)
      │
      ├─── Pattern detection (every task execution)
      │         └─ check MEMORY.md pattern_counter table
      │         └─ if count == 1: increment → continue
      │         └─ if count == 2: trigger Skill Creation (see below)
      │
      ├─── Domain gap detection (every new epic creation)
      │         └─ jq .agents.list[].id from openclaw.json
      │         └─ if no agent matches domain: author proposal doc
      │         └─ sessions_spawn(decision-reviewer, proposal) → verdict
      │         └─ if pass: invoke /openclaw-new-agent skill
      │         └─ if reject: log Decision Reviewer feedback, do not create agent
      │
      ├─── Skill trigger (on pattern count == 2)
      │         └─ add Beads subtask: "trigger skill creation for pattern X"
      │         └─ sessions_spawn(skill-creation, pattern_description)
      │         └─ Skill Creation runs Phase 11 pipeline:
      │              registry search → author → Skill Reviewer → /openclaw-stow
      │
      └─── Experiment framework
                └─ write Notion page BEFORE any agent spawns (Draft status)
                └─ create Beads epic for experiment steps
                └─ sub-agents execute, close tasks with evidence
                └─ Task Orchestrator writes results section to Notion page
                └─ sessions_spawn(document-reviewer, "review experiment page URL")
                └─ if pass: mark Notion page "Final"
                └─ if reject: revise results section, re-submit
```

### Recommended Project Structure
Changes in this phase are entirely to existing files — no new agent directories.
```
.openclaw/agents/task-orchestrator/
├── SOUL.md         # UPDATED: EVOL rules — pattern counter, /openclaw-new-agent mandate,
│                   #          experiment lifecycle, Decision Reviewer gate for new agents
├── MEMORY.md       # UPDATED: add pattern_counter section (empty table initially)
└── TOOLS.md        # UPDATED: agent domain check command, pattern counter update procedure,
                    #          experiment Notion page template
```

### Pattern 1: MEMORY.md Pattern Counter Table
**What:** The Task Orchestrator maintains a running counter of observed procedural patterns directly in MEMORY.md, in a section that the dream routine is instructed to preserve (not distill away).
**When to use:** Initialized in Plan 12-03; updated by Task Orchestrator on every task completion.
**Example (MEMORY.md addition):**
```markdown
## Pattern Counter
<!-- PRESERVE: dream routine must not distill or truncate this section -->

| Pattern | Count | Last Seen | Trigger Fired? |
|---------|-------|-----------|----------------|
| manual-pr-description-formatting | 1 | 2026-05-21 | no |
| github-issue-label-assignment | 2 | 2026-05-21 | yes — Skill Creation triggered |

<!-- Threshold: count >= 2 triggers Skill Creation agent session -->
```
*Source: derived from EVOL-02 (threshold = 2) [CITED: .planning/REQUIREMENTS.md]; MEMORY.md format from Phase 5 dream routine pattern [CITED: .planning/phases/05-dream-routines/05-RESEARCH.md]*

**Key: Dream routine preservation rule.** The `<!-- PRESERVE -->` comment instructs the dream routine model to keep this section verbatim. Without this, the 2,500-token distillation budget may overwrite counters when MEMORY.md grows large.

### Pattern 2: Agent Domain Gap Detection
**What:** Before proposing a new agent, Task Orchestrator verifies that no existing agent covers the domain by reading `openclaw.json agents.list`.
**When to use:** EVOL-01 trigger — when a domain has appeared in 2+ consecutive Beads epics with no matching agent.
**Example:**
```zsh
#!/usr/bin/env zsh
set -euo pipefail

# Read current agent IDs from live openclaw.json
AGENT_IDS=$(jq -r '.agents.list[].id' "$HOME/.openclaw/openclaw.json" | sort)
echo "Existing agents: $AGENT_IDS" >&2

# Check if proposed domain already has an agent
PROPOSED_DOMAIN="$1"
MATCH=$(echo "$AGENT_IDS" | grep -i "$PROPOSED_DOMAIN" || echo "")

if [[ -n "$MATCH" ]]; then
  echo "{\"ok\":false,\"reason\":\"Agent already exists for domain: ${MATCH}\"}"
  exit 0
fi

# No match found — proceed to proposal doc
echo "{\"ok\":true,\"action\":\"proceed_to_proposal\"}"
```
*Source: `jq` against live openclaw.json [VERIFIED: local tool output and file structure]*

### Pattern 3: New Agent Proposal Document Structure
**What:** Task Orchestrator authors a structured proposal before invoking `/openclaw-new-agent`. Decision Reviewer evaluates this proposal.
**When to use:** Every time Task Orchestrator identifies a domain gap.
**Example (proposal sent to Decision Reviewer via sessions_spawn):**
```markdown
## New Agent Proposal

**Proposed agent ID:** data-pipeline-agent
**Domain:** ETL pipeline monitoring and data validation tasks
**Evidence of need:**
- Beads epic bd-1234: "validate CSV upload schema" — no matching agent; Task Orchestrator handled directly
- Beads epic bd-1289: "check Postgres pipeline lag" — no matching agent; DevBot used but lacks domain context
- Pattern count: 2 epics in 5 days with no domain-matched agent

**Proposed SOUL.md focus:** Data pipeline health monitoring, schema validation, database query scripts
**Model:** anthropic/claude-sonnet-4-6
**Sub-agent of:** task-orchestrator
**Channel:** none

**Reversibility:** Agent can be removed by deleting directive files + removing from openclaw.json + stow
**Rationale:** Two epics requiring specialized data knowledge in 5 days meets the threshold for dedicated agent
```

### Pattern 4: SOUL.md Additions for EVOL Rules
**What:** The Task Orchestrator SOUL.md additions that encode all three EVOL behaviors as mandatory rules.
**When to use:** Plan 12-01.
**Example:**
```markdown
## Self-Evolution Rules (EVOL — Phase 12)

### Agent Creation (EVOL-01)
- NEVER create agent directive files manually (writing SOUL.md, IDENTITY.md etc. directly)
- `/openclaw-new-agent` is the ONLY permitted path for agent scaffolding — no exceptions
- Before invoking `/openclaw-new-agent`: (a) verify no existing agent covers the domain via jq on openclaw.json; (b) author a proposal document; (c) send to Decision Reviewer via sessions_spawn; (d) only invoke `/openclaw-new-agent` after `{"verdict": "pass"}`

### Pattern Repeat (EVOL-02)
- After every task completion: identify the procedural pattern (2-5 word description)
- Check MEMORY.md pattern_counter table for that pattern
- If count == 0 or absent: add with count = 1, last_seen = today
- If count == 1: increment to 2, add Beads subtask "trigger skill creation for pattern: <name>"
- If count >= 2 and trigger_fired == yes: no action (skill already created)
- Pattern names must be stable across sessions — use the same wording consistently

### Experiment Framework (EVOL-03)
- Experiment lifecycle has 4 mandatory stages (IN ORDER):
  1. Write Notion experiment page (Draft) BEFORE spawning any agents — page must exist
  2. Create Beads epic + subtasks for experiment execution
  3. Sub-agents execute; close tasks with factual evidence strings
  4. Write results to Notion page → send to Document Reviewer → if pass: mark Final
- NEVER mark experiment page Final without Document Reviewer passing the write-up
- If experiment agents fail mid-run: experiment page remains Draft with partial results noted
```

### Pattern 5: Experiment Notion Page Structure
**What:** Consistent Notion page template for every experiment, created before execution starts.
**When to use:** Every EVOL-03 experiment trigger.
```markdown
# Experiment: [Short Name]

**Status:** Draft
**Hypothesis:** [specific, falsifiable statement]
**Method:** [steps the agents will execute]
**Success Criteria:** [measurable outcomes that determine pass/fail]
**Started:** [ISO8601 timestamp]
**Completed:** [TBD]

---

## Execution Log
[Beads epic ID: bd-XXXX]
[Sub-tasks and their close reasons — filled in during execution]

---

## Results
[Filled in by Task Orchestrator after epic closes]

---

## Document Reviewer Verdict
[Filled in after Document Reviewer session — verdict must be "pass" before page is Final]
```
*Source: EVOL-03 requirements: "hypothesis, method, success criteria, execution steps, results" [CITED: .planning/REQUIREMENTS.md]*

### Pattern 6: Verifying the /openclaw-new-agent Enforcement Gate
**What:** The verification for EVOL-01 enforcement — attempt to create a new agent via manual file creation and confirm the Task Orchestrator notices and refuses.
**When to use:** Plan 12-05 verify script.
**Test logic:**
```zsh
#!/usr/bin/env zsh
# Attempt to create a fake agent by writing a SOUL.md directly
# (NOT via /openclaw-new-agent — this is the violation)
mkdir -p /tmp/test-agent-violation
cat > /tmp/test-agent-violation/SOUL.md <<'EOF'
# SOUL.md — Test Agent (created without /openclaw-new-agent)
EOF

# Verify: this agent does NOT appear in openclaw.json (stow was never run)
AGENT_IN_CONFIG=$(jq '.agents.list[] | select(.id == "test-agent-violation")' \
  "$HOME/.openclaw/openclaw.json")

if [[ -z "$AGENT_IN_CONFIG" ]]; then
  echo "PASS: manually created agent is not registered in openclaw.json"
  echo "PASS: /openclaw-new-agent enforcement verified — manual creation is inert"
else
  echo "FAIL: manual agent somehow registered in openclaw.json"
  exit 1
fi

# Cleanup
rm -rf /tmp/test-agent-violation
```
The test proves the constraint: without `/openclaw-new-agent` (which runs stow and updates openclaw.json), a manually created agent directory is inert — it cannot receive sessions or be delegated to.

### Anti-Patterns to Avoid
- **Storing pattern counters in Beads:** Beads is an execution tracker, not a memory store. Counters must live in MEMORY.md where the dream routine can distill them and they survive gateway restarts.
- **Starting experiment execution before Notion page exists:** If the experiment page is created after execution, a mid-run failure leaves no audit trail. Page creation is stage 1, not stage 4.
- **Triggering Skill Creation on count == 1:** The threshold is explicitly ≥ 2 (EVOL-02). A single occurrence may be a one-off. Count 1 means "watch this pattern." Count 2 means "this is recurring, automate it."
- **Dream routine distilling away the pattern counter:** The dream routine's 2,500-token budget will compress MEMORY.md. Without a `<!-- PRESERVE -->` directive, counter data may be summarized as "some patterns were tracked" and the actual counts are lost. This must be explicitly addressed in the dream routine instructions.
- **Invoking `/openclaw-new-agent` without Decision Reviewer pass:** The gate exists to prevent impulsive agent creation. Every proposal — even when the Task Orchestrator is confident — must pass through Decision Reviewer. This is the EVOL-01 contract.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Agent scaffolding | Write directive files + edit openclaw.json manually | `/openclaw-new-agent` skill | Skill encodes correct structure, stow sequence, SECURITY.md template, openclaw.json wiring — manual approach misses steps |
| Pattern persistence | Separate SQLite or JSON file for counters | MEMORY.md counter table | MEMORY.md already persists across sessions; adding a separate datastore adds infrastructure complexity with no benefit |
| Experiment page versioning | Custom revision history system | Notion Draft → Final workflow + Document Reviewer gate | Notion's built-in page history provides revision tracking; the two-status approach (Draft/Final) provides the gate without custom infrastructure |
| Agent domain coverage check | LLM reasoning about which agents exist | `jq` on `openclaw.json agents.list` | Ground truth is the config file — not agent memory, not LLM inference |

---

## Common Pitfalls

### Pitfall 1: Pattern Counter Names Drift Across Sessions
**What goes wrong:** Task Orchestrator describes the same pattern with different wording in different sessions ("pr-description-formatting" vs "format-pull-request-description") — counter never reaches 2 because the names don't match.
**Why it happens:** LLMs use varied phrasing. Without a naming convention, the same pattern accumulates separate rows and no row ever hits the threshold.
**How to avoid:** Task Orchestrator SOUL.md should instruct: "When recording a pattern, first check the existing table for a semantically equivalent entry. If one exists, increment that row — do not create a new row. Use the existing pattern name verbatim." The wording in TOOLS.md should also provide a pattern naming convention: lowercase, hyphens, 2-4 words.
**Warning signs:** Pattern counter table has 10+ rows, all at count 1, with semantically similar names.

### Pitfall 2: Experiment Notion Page Created But Missing Required Fields
**What goes wrong:** Task Orchestrator creates the experiment page but omits the `success_criteria` field — Document Reviewer correctly rejects it, but the experiment agents have already started executing against a malformed brief.
**Why it happens:** Page creation happens before execution, so a malformed page is not caught until Document Reviewer reviews the completed page.
**How to avoid:** Task Orchestrator SOUL.md must list the 5 required fields (hypothesis, method, success criteria, started timestamp, Notion page ID) as mandatory before `Status: Draft` is set. A validation check script should verify the page has all 5 fields before the experiment Beads epic is created.
**Warning signs:** Document Reviewer rejects experiment page with "missing success criteria section."

### Pitfall 3: New Agent Created But Task Orchestrator SOUL.md Not Updated With Routing Hint
**What goes wrong:** `/openclaw-new-agent` creates the agent and registers it in openclaw.json, but Task Orchestrator SOUL.md has no routing hint for the new domain. The agent is never delegated to because the Task Orchestrator doesn't know to use it.
**Why it happens:** `/openclaw-new-agent` doesn't update the Task Orchestrator's SOUL.md — that is a separate step.
**How to avoid:** The new agent proposal workflow must include a final step: "After `/openclaw-new-agent` succeeds, update Task Orchestrator SOUL.md `## Agent Routing` section with the new agent ID and its domain." This is part of the EVOL-01 workflow, not optional.
**Warning signs:** New agent appears in `/openclaw-status` but never receives any sessions_spawn delegations.

### Pitfall 4: Dream Routine Resets Pattern Counter
**What goes wrong:** After the nightly dream routine runs, the MEMORY.md pattern counter section is gone — the distillation compressed it to "historical patterns tracked" and lost the actual counts.
**Why it happens:** The dream routine operates on a 2,500-token budget and may compress structured tables.
**How to avoid:** Two safeguards: (1) add `<!-- PRESERVE: pattern_counter — do not distill -->` comment in MEMORY.md around the counter table; (2) update the dream routine DREAM-ROUTINE.md to include "Pattern counter section: PRESERVE VERBATIM — do not summarize."
**Warning signs:** After first nightly run, the pattern counter table is absent or summarized in MEMORY.md.

### Pitfall 5: Verify Script False-Positive on /openclaw-new-agent Gate
**What goes wrong:** The verify script creates a temp directory in `~/.openclaw/agents/` (instead of `/tmp/`) and accidentally registers a real partial agent in the live workspace.
**Why it happens:** Test scaffolding written carelessly.
**How to avoid:** All verify-phase-12.sh test artifacts must be created in `/tmp/`, never in `~/.openclaw/` or `~/Documents/agentic-setup/`. Cleanup with `trap` or explicit `rm -rf /tmp/test-*` at script end.
**Warning signs:** `/openclaw-status` shows a new agent after verification runs.

---

## Code Examples

### Read Existing Agent List for Domain Check
```zsh
# Task Orchestrator checking whether any agent covers "data-pipeline" domain
AGENT_IDS=$(jq -r '.agents.list[].id' "$HOME/.openclaw/openclaw.json")
echo "$AGENT_IDS"
# data-pipeline NOT in list? → proceed to proposal
```

### Increment Pattern Counter in MEMORY.md
```zsh
# Task Orchestrator updating MEMORY.md pattern_counter table after recognizing a pattern
# This is LLM-directed — the agent reads MEMORY.md, finds the row, increments count
# The counter section must have the <!-- PRESERVE --> marker to survive dream distillation
PATTERN_NAME="pr-description-formatting"
# Agent reads MEMORY.md, finds or creates row for $PATTERN_NAME, increments count
# If new count == 2: add Beads subtask for Skill Creation trigger
```

### Experiment Page Creation Before Execution
```javascript
// Source: @notionhq/client 5.22.0 pattern (same as Phase 10 Notion writes)
const page = await notion.pages.create({
  parent: { database_id: process.env.OPENCLAW_NOTION_EXPERIMENTS_DB_ID },
  properties: {
    'Title':            { title: [{ text: { content: 'Experiment: PR Auto-Labels' } }] },
    'Status':           { select: { name: 'Draft' } },
    'Hypothesis':       { rich_text: [{ text: { content: '...' } }] },
    'Method':           { rich_text: [{ text: { content: '...' } }] },
    'Success Criteria': { rich_text: [{ text: { content: '...' } }] },
    'Started':          { date: { start: new Date().toISOString() } }
  }
});
// page.id stored in Beads epic metadata — referenced throughout execution
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| User manually scaffolds new agents | Task Orchestrator proposes + Decision Reviewer approves + `/openclaw-new-agent` executes | Phase 12 | User reviews on return; can revert via stow -D |
| Skill creation is always manual | Pattern repeat counter triggers automatic Skill Creation | Phase 12 | Recurring procedures become skills without user intervention |
| Experiments are informal (run and forget) | Structured Notion experiment page created before execution, Document Reviewer validates write-up | Phase 12 | Every experiment is auditable; results documented before page is finalized |

---

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `<!-- PRESERVE -->` HTML comment in MEMORY.md is respected by the dream routine LLM and prevents counter table distillation | Pattern 1, Pitfall 4 | Pattern counters are lost on first nightly run; EVOL-02 never reaches count = 2 across sessions |
| A2 | `jq -r '.agents.list[].id'` on the live openclaw.json at `$HOME/.openclaw/openclaw.json` reliably reflects the current registered agent set | Pattern 2, Code Examples | If openclaw.json is stale (stow not run), domain check sees old agent list; may miss agents added in the same session |
| A3 | Notion experiments database ID will be provisioned in Phase 9 or as a prerequisite of Phase 12 planning | Pattern 5 | `OPENCLAW_NOTION_EXPERIMENTS_DB_ID` env var won't exist; experiment page creation fails at runtime |
| A4 | Task Orchestrator pattern identification is consistent enough across sessions to produce stable pattern names when the SOUL.md rubric instructs it | Pattern 1, Pitfall 1 | Pattern names drift; counters fragment; EVOL-02 threshold never reached naturally |

---

## Open Questions

1. **Dream routine preservation of structured counter data**
   - What we know: Dream routine has a 2,500-token budget per session; MEMORY.md is distilled nightly
   - What's unclear: Whether `<!-- PRESERVE -->` HTML comments in Markdown are reliably interpreted by the dream routine model as preservation directives
   - Recommendation: Plan 12-03 must update the dream routine DREAM-ROUTINE.md instruction file to explicitly state "Section ## Pattern Counter: preserve this section verbatim — do not summarize or compress"

2. **Notion experiments database — separate from decisions database?**
   - What we know: Phase 9 creates a decisions database; Phase 12 needs an experiments database (different schema: hypothesis, method, status, results)
   - What's unclear: Whether Phase 9 provisions the experiments database or whether Phase 12 must create it
   - Recommendation: Plan 12-04 should verify `OPENCLAW_NOTION_EXPERIMENTS_DB_ID` is in Keychain; if not, create the database as a prerequisite task in Wave 1

3. **Pattern counter granularity — what counts as a "pattern"?**
   - What we know: EVOL-02 says "procedural pattern" — this is intentionally vague
   - What's unclear: Whether "creating a GitHub issue" and "creating a labeled GitHub issue" are the same pattern or different
   - Recommendation: Task Orchestrator SOUL.md EVOL rules should include: "Pattern granularity rule: patterns are at the PROCEDURE level, not the PARAMETERS level. 'create GitHub issue' and 'create labeled GitHub issue' are the same pattern: 'github-issue-create'."

---

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| `/openclaw-new-agent` skill | EVOL-01 agent scaffolding | ✓ | HEAD | — |
| `bd` CLI (Beads) | Experiment Beads epics, pattern trigger tasks | ✓ | 1.0.4 (from Phase 4) | — |
| `@notionhq/client` | Experiment Notion page creation | install needed in Phase 9/10 | 5.22.0 | — |
| `OPENCLAW_NOTION_EXPERIMENTS_DB_ID` | Experiment page parent database | Phase 9 or 12 prerequisite | — | Create Notion database in Wave 1 of Phase 12 if Phase 9 did not |
| Decision Reviewer agent | EVOL-01 proposal review | Phase 11 prerequisite | — | Phase 11 must be complete |
| Document Reviewer agent | EVOL-03 experiment write-up validation | Phase 11 prerequisite | — | Phase 11 must be complete |
| Skill Creation agent | EVOL-02 automatic skill authoring | Phase 11 prerequisite | — | Phase 11 must be complete |
| `jq` | Domain gap check | ✓ | system (brew) | — |

**Missing dependencies with no fallback:** All three Phase 11 reviewer agents (Decision Reviewer, Document Reviewer, Skill Creation) are hard prerequisites. Phase 12 cannot be planned without Phase 11 complete.

**Missing dependencies with fallback:**
- `OPENCLAW_NOTION_EXPERIMENTS_DB_ID` — Plan 12-04 Wave 1 creates the database if Phase 9 did not provision it

---

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | zsh scripts + manual verification |
| Config file | none |
| Quick run command | `zsh scripts/verify-phase-12.sh` |
| Full suite command | `zsh scripts/verify-phase-12.sh --all` |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| EVOL-01 | New agent proposal routes through Decision Reviewer | integration | synthetic domain gap proposal via sessions_spawn | Wave 0 |
| EVOL-01 | `/openclaw-new-agent` is ONLY permitted path — manual creation is inert | integration (negative test) | create temp SOUL.md manually, verify absent from openclaw.json | Wave 0 |
| EVOL-02 | Pattern counter increments on second occurrence | integration | simulate pattern X twice in MEMORY.md, verify Skill Creation task added to Beads | Wave 0 |
| EVOL-03 | Experiment Notion page exists BEFORE Beads epic is created | integration | timestamp comparison between page created_at and epic creation | Wave 0 |
| EVOL-03 | Document Reviewer gates experiment page finalization | integration | complete experiment, submit for review, verify Draft → Final only after pass | Wave 0 |

### Wave 0 Gaps
- [ ] `scripts/verify-phase-12.sh` — covers EVOL-01 (positive + negative), EVOL-02, EVOL-03 (pre-execution page + finalization gate)

---

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no | — |
| V3 Session Management | no | — |
| V4 Access Control | yes | `/openclaw-new-agent` mandate; Decision Reviewer gate for all new agent creation |
| V5 Input Validation | yes | Pattern names sanitized before Beads task description injection |
| V6 Cryptography | no | — |

### Known Threat Patterns

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Agent proliferation (unreviewed agent creation) | Elevation of Privilege | Decision Reviewer gate required before `/openclaw-new-agent` invocation |
| Experiment page as junk log (vague results) | Repudiation | Document Reviewer must pass experiment write-up — vague results are a reject |
| Pattern counter manipulation (premature skill trigger) | Spoofing | Counter lives in MEMORY.md, not in an external system — only the Task Orchestrator updates it via session context |

---

## Sources

### Primary (HIGH confidence)
- Task Orchestrator SOUL.md live file — Beads contract, sessions_spawn pattern, MEMORY.md reference [VERIFIED: local file /Users/trilogy/.openclaw/agents/task-orchestrator/SOUL.md]
- DREAM-ROUTINE.md pattern (Phase 5) — token budget, distillation behavior, MEMORY.md archive flow [CITED: .planning/phases/05-dream-routines/05-RESEARCH.md]
- `/openclaw-new-agent` SKILL.md — mandatory scaffolding steps, stow+restart sequence [VERIFIED: local file /Users/trilogy/Documents/agentic-setup/.claude/skills/openclaw-new-agent/SKILL.md]
- REQUIREMENTS.md EVOL-01, EVOL-02, EVOL-03 — full requirement text [CITED: .planning/REQUIREMENTS.md]
- `jq` on live openclaw.json — verified agent ID field path `.agents.list[].id` [VERIFIED: local tool output]
- `@notionhq/client` 5.22.0 — `npm view @notionhq/client version` = 5.22.0 [VERIFIED: npm registry + CLAUDE.md]

### Secondary (MEDIUM confidence)
- Phase 11 research — Decision Reviewer and Document Reviewer verdict schema, sessions_spawn close reason pattern [CITED: .planning/phases/11-quality-pipeline/11-RESEARCH.md]
- Phase 4 CONTEXT.md — Beads task creation and epic pattern [CITED: .planning/phases/04-beads-task-orchestrator]

### Tertiary (LOW confidence / ASSUMED)
- Dream routine model behavior regarding `<!-- PRESERVE -->` HTML comments — this is inferred from how LLMs treat markdown annotations; not formally documented in cc-openclaw [ASSUMED]

---

## Metadata

**Confidence breakdown:**
- Agent proposal and Decision Reviewer gate: HIGH — same pattern as Phase 11 Decision Reviewer
- Pattern counter in MEMORY.md: MEDIUM — mechanism is sound but dream routine preservation behavior is assumed
- Experiment framework: HIGH — Notion + Beads + Document Reviewer all established in prior phases
- `/openclaw-new-agent` enforcement test: HIGH — test logic is mechanical (file exists but not in openclaw.json)

**Research date:** 2026-05-21
**Valid until:** 2026-07-21

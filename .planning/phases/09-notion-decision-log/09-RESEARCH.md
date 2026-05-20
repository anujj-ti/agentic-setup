# Phase 9: Notion Decision Log — Research

**Researched:** 2026-05-21
**Domain:** Notion API (`@notionhq/client` 5.22.0), decision log database schema, pre-execution logging pattern, AFK scaffolding, experiment page structure
**Confidence:** HIGH

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| MEM-01 | Task Orchestrator logs every autonomous decision to a Notion database immediately after execution — log entry contains: timestamp, decision taken, rationale, evidence, reversibility status | Fully covered — `notion.pages.create` API verified; database property schema defined; `notionVersion: "2026-03-11"` constructor parameter confirmed in Client.ts |
| MEM-02 | User can review a chronological list of all autonomous decisions taken since last session (surfaced in morning standup brief and on demand via Telegram) | Fully covered — `notion.databases.query` with `timestamp: "created_time"` filter and `created_time.on_or_after` operator verified from official Notion filter reference |
| MEM-03 | User can mark any logged decision as "reverted" and the Task Orchestrator takes appropriate rollback steps and logs the revert as a new decision entry | Covered — `notion.pages.update` changes `revert_status` select property to "reverted"; revert action is a new `pages.create` entry with `decision_type: "revert"` |
| MEM-04 | Task Orchestrator logs experiment proposals, execution steps, and results to dedicated Notion pages — each experiment gets its own structured page with hypothesis, method, criteria, results | Covered — Notion page with block children (headings + paragraphs) for structured experiment template; `notion.blocks.children.append` adds results post-execution |
</phase_requirements>

---

## Summary

Phase 9 wires the Task Orchestrator to a Notion database for pre-execution decision logging. The integration token is not yet available (user is AFK and has not yet created the Notion integration), so the scaffolding strategy is: build everything, leave one `TODO_NOTION` placeholder in the Task Orchestrator's SOUL.md and the logging script, and gate execution on a `checkpoint:human-verify` step in the plan that requires the user to create the integration, store the token, and share the database.

The `@notionhq/client` 5.22.0 is the official Notion SDK from `github.com/makenotion/notion-sdk-js` — confirmed on npm registry (published 2026-05-19, created 2021, 97 versions, no postinstall scripts). It is installed **locally in the agent's scripts directory** (`npm install` in `.openclaw/agents/task-orchestrator/scripts/`), not globally. `notionVersion: "2026-03-11"` is passed at Client construction to use the latest Notion API version (default is `2025-09-03`).

The decision log is a Notion database with seven properties: `Name` (title), `timestamp` (date), `decision` (rich_text), `rationale` (rich_text), `evidence` (rich_text), `reversibility` (select: reversible/irreversible/unknown), `revert_status` (select: active/reverted/pending_revert). The "what did you do while I was away?" query uses `databases.query` with `filter.timestamp = created_time` + `on_or_after: <last_session_ISO8601>`.

Experiment pages use Notion's page + block children model: a top-level page is created in a dedicated experiments section with structured heading + paragraph blocks for hypothesis, method, success criteria. Results are appended post-execution via `blocks.children.append`. This matches the structured page pattern in the Notion API.

**Primary recommendation:** Plans run in this sequence — 09-01 (create database schema document + human checkpoint for Notion setup), 09-02 (implement `log-decision.js` and wire into Task Orchestrator SOUL.md), 09-03 (implement `query-decisions.js` for on-demand retrieval), 09-04 (implement revert workflow), 09-05 (experiment page creation), 09-06 (integrate decision count into morning standup).

---

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Pre-execution decision logging | Task Orchestrator scripts (`log-decision.js`) | Notion API | Task Orchestrator owns the decision; script executes the Notion write before action proceeds |
| Decision retrieval (since last session) | Task Orchestrator scripts (`query-decisions.js`) | User Orchestrator (formats + delivers to Telegram) | Task Orchestrator queries Notion by timestamp; User Orchestrator formats the response for the user |
| Revert status update | Task Orchestrator scripts (`update-decision.js`) | — | `notion.pages.update` changes `revert_status` select; separate from action reversal which is a new log entry |
| Experiment page creation | Task Orchestrator scripts (`create-experiment.js`) | — | Notion page with block children; structured template written at experiment start |
| Experiment results append | Task Orchestrator scripts (`append-experiment-results.js`) | — | `notion.blocks.children.append` adds results section post-execution |
| Notion token management | macOS Keychain (`openclaw.notion-token`) | `openclaw-secrets.sh` → `OPENCLAW_NOTION_TOKEN` env var | CLAUDE.md mandate: secrets in Keychain only; never in files |
| Database ID management | Agent config file (`scripts/config.json`) | SOUL.md reference | The Notion database ID is not a secret but must be stored somewhere accessible to scripts |
| Morning standup integration | Task Orchestrator `query-decisions.js` → User Orchestrator | Phase 6 morning standup cron | Phase 6 morning standup already queries Task Orchestrator; this phase adds decision count to that query |

---

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| `@notionhq/client` | 5.22.0 | Official Notion SDK — `pages.create`, `databases.query`, `pages.update`, `blocks.children.append` | CLAUDE.md mandated; official SDK from `makenotion` org; handles retries, rate-limits, pagination. Published 2026-05-19; created 2021; 97 versions; no postinstall scripts. [VERIFIED: npm registry + makenotion/notion-sdk-js GitHub] |
| Node.js | 24 (node@24) | Runtime for all Notion SDK scripts | OpenClaw requirement; all Phase 4+ scripts use `/opt/homebrew/opt/node@24/bin/node` |
| `jq` | System (brew) | JSON parsing in shell wrappers that call Node.js scripts | cc-openclaw convention for script output handling |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| `python3` | System (macOS) | ISO 8601 timestamp generation for `log-decision.js` inputs | `python3 -c "from datetime import datetime, timezone; print(datetime.now(timezone.utc).isoformat())"` |

### No additional npm packages
`@notionhq/client` has no required peer dependencies. It bundles its own `node-fetch` equivalent. [VERIFIED: npm view @notionhq/client peerDependencies — no peerDeps]

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| `@notionhq/client` | Custom `curl` + Notion REST API | CLAUDE.md explicitly states "No reason to raw-dog the Notion API"; SDK handles retries on 429/500/503, pagination cursors, rate-limit back-off automatically |
| Local `npm install` in scripts dir | Global `npm install -g @notionhq/client` | CLAUDE.md explicitly forbids global installs for agent libraries: "Agent scripts should own their dependencies, not share a global namespace" |
| Notion database for decisions | Markdown files in git | Notion provides the user-facing review surface, revert marking UI, and the "what did you do while I was away?" query that returns structured data; git logs are not user-friendly for this |

### Installation

```bash
# Install @notionhq/client locally in the Task Orchestrator scripts directory
# Source: @notionhq/client README (makenotion/notion-sdk-js)
cd /Users/trilogy/.openclaw/agents/task-orchestrator/scripts
/opt/homebrew/opt/node@24/bin/npm install @notionhq/client@5.22.0
```

**IMPORTANT:** Install to the live workspace path (`~/.openclaw/agents/task-orchestrator/scripts/`), not to the git repo. The `node_modules/` directory is in the agent workspace, not in git. The `package.json` IS committed to git (so the dependency is reproducible), but `node_modules/` is gitignored.

---

## Package Legitimacy Audit

> slopcheck 1.x incorrectly identified `@notionhq/client` as a PyPI package and returned [SLOP]. This is a false positive: slopcheck queried the wrong registry. The package is a scoped npm package from the `makenotion` organization. Manual verification was performed instead.

| Package | Registry | Age | Downloads | Source Repo | slopcheck | Disposition |
|---------|----------|-----|-----------|-------------|-----------|-------------|
| `@notionhq/client` | npm (scoped) | 5 yrs (created 2021-05-13) | Not shown by `npm view` (scoped packages) | `github.com/makenotion/notion-sdk-js` | slopcheck FALSE POSITIVE (wrong registry) | Approved — manually verified via `npm view @notionhq/client` + official makenotion GitHub org + CLAUDE.md citation |

**Packages removed due to slopcheck [SLOP] verdict:** none (slopcheck returned false positive due to wrong registry; manual verification passed)
**Packages flagged as suspicious [SUS]:** none

**slopcheck note:** slopcheck queried PyPI for an npm scoped package. The package `@notionhq/client` is published by `makenotion` (Notion's official GitHub org), has been live for 5 years, has 97 published versions, no postinstall scripts, and is explicitly referenced in CLAUDE.md as the mandated library. Manual registry verification supersedes the false-positive slopcheck result.

---

## Architecture Patterns

### System Architecture Diagram

```
                DECISION LOGGING FLOW (MEM-01)
                ──────────────────────────────
Task Orchestrator (before executing action)
      │
      ├── Compose decision payload:
      │     { timestamp, decision, rationale, evidence, reversibility }
      │
      ▼
scripts/log-decision.js
  ├── Read OPENCLAW_NOTION_TOKEN from env
  ├── Read NOTION_DECISION_DB_ID from scripts/config.json
  ├── notion.pages.create({ parent: {database_id}, properties: {...} })
  └── stdout: {"ok": true, "page_id": "abc123", "url": "https://notion.so/..."}
      │
      └── [on success] Task Orchestrator proceeds with action
      └── [on failure] Task Orchestrator logs error to stderr, proceeds anyway
                       (logging failure must not block the action)

                DECISION RETRIEVAL FLOW (MEM-02)
                ─────────────────────────────────
User: "What did you do while I was away?"
      │
User Orchestrator → sessions_spawn → Task Orchestrator
      │
      ▼
scripts/query-decisions.js --since <ISO8601>
  ├── notion.databases.query({
  │     database_id: NOTION_DECISION_DB_ID,
  │     filter: { timestamp: "created_time", created_time: { on_or_after: <ISO> } },
  │     sorts: [{ timestamp: "created_time", direction: "ascending" }]
  │   })
  └── stdout: {"ok": true, "decisions": [...], "count": N}
      │
      └── Task Orchestrator → User Orchestrator → Telegram: formatted list

                REVERT WORKFLOW (MEM-03)
                ─────────────────────────
User: "Revert decision page_id=abc123"
      │
User Orchestrator → Task Orchestrator
      │
      ├── scripts/update-decision.js --page-id abc123 --revert-status pending_revert
      │     notion.pages.update({ page_id, properties: { revert_status: { select: { name: "pending_revert" } } } })
      │
      ├── Task Orchestrator executes rollback (e.g., gh pr close, git revert)
      │
      ├── scripts/log-decision.js  (new entry: decision_type = "revert", evidence = rollback result)
      │
      └── scripts/update-decision.js --page-id abc123 --revert-status reverted

                EXPERIMENT PAGE FLOW (MEM-04)
                ──────────────────────────────
Task Orchestrator: start experiment
      │
      ▼
scripts/create-experiment.js
  ├── notion.pages.create({
  │     parent: { page_id: NOTION_EXPERIMENTS_PAGE_ID },
  │     properties: { Name: { title: [{ text: { content: "Experiment: <hypothesis>" } }] } },
  │     children: [ heading(Hypothesis), para(hypothesis_text),
  │                 heading(Method), para(method_text),
  │                 heading(Success Criteria), para(criteria_text),
  │                 heading(Execution Steps), para("TBD — running"),
  │                 heading(Results), para("TBD — pending") ]
  │   })
  └── stdout: {"ok": true, "page_id": "xyz456", "url": "..."}
      │
      └── [post-execution] scripts/append-experiment-results.js --page-id xyz456
            notion.blocks.children.append( results content )
```

### Recommended Project Structure

```
.openclaw/agents/task-orchestrator/scripts/
├── lib/
│   └── json-response.sh                 # cc-openclaw output convention
├── notion/
│   ├── log-decision.js                  # MEM-01: pre-execution log entry
│   ├── query-decisions.js               # MEM-02: retrieve since timestamp
│   ├── update-decision.js               # MEM-03: set revert_status
│   ├── create-experiment.js             # MEM-04: experiment page + initial blocks
│   └── append-experiment-results.js     # MEM-04: append results post-execution
├── config.json                          # NOTION_DECISION_DB_ID, NOTION_EXPERIMENTS_PAGE_ID
│                                        # (NOT a secret — IDs are not credentials)
└── package.json                         # { "dependencies": { "@notionhq/client": "5.22.0" } }

# node_modules/ lives in the LIVE workspace (not git):
# ~/.openclaw/agents/task-orchestrator/scripts/node_modules/
```

### Notion Database Schema for Decision Log (MEM-01)

**Database name:** `Autonomous Decision Log`

| Property Name | Notion Type | Values | Notes |
|---------------|-------------|--------|-------|
| `Name` | title | Auto-named: `[DECISION] <decision summary>` | Required by Notion; used as page title in UI |
| `timestamp` | date | ISO 8601 UTC (e.g., `2026-05-21T10:30:00.000Z`) | Time the decision was logged (pre-execution) |
| `decision` | rich_text | Free text: what the agent decided to do | max ~2000 chars |
| `rationale` | rich_text | Why the agent made this decision | Evidence-based reasoning |
| `evidence` | rich_text | Factual evidence supporting the decision | e.g., "gh pr checks: all 3 checks passed" |
| `reversibility` | select | `reversible`, `irreversible`, `unknown` | User-facing filter for audit |
| `revert_status` | select | `active`, `reverted`, `pending_revert` | Default: `active`; updated by MEM-03 workflow |

### Pattern 1: Client Initialization

**What:** Initialize `@notionhq/client` with token from env and latest API version.

**When to use:** Top of every Notion script file.

```javascript
// Source: makenotion/notion-sdk-js README (verified) + CLAUDE.md (notionVersion: "2026-03-11")
// Source: Client.ts ClientOptions — notionVersion is a valid constructor param [VERIFIED: GitHub]
const { Client } = require("@notionhq/client")

const notion = new Client({
  auth: process.env.OPENCLAW_NOTION_TOKEN,   // From Keychain via openclaw-secrets.sh
  notionVersion: "2026-03-11",               // Latest API version (default: 2025-09-03)
})
```

### Pattern 2: Log Decision Entry (MEM-01)

**What:** Create a decision log page entry in the Notion database before executing an autonomous action.

**When to use:** Task Orchestrator calls this BEFORE taking any autonomous action. If logging fails (Notion unavailable), the error is recorded to stderr and the action proceeds — logging failure must not block operations.

```javascript
// Source: developers.notion.com/reference/post-page (verified via WebFetch)
// Source: @notionhq/client README (verified via npm view readme)
async function logDecision({ decision, rationale, evidence, reversibility }) {
  const timestamp = new Date().toISOString()
  
  const response = await notion.pages.create({
    parent: { database_id: process.env.NOTION_DECISION_DB_ID },
    properties: {
      Name: {
        title: [{ text: { content: `[DECISION] ${decision.slice(0, 100)}` } }]
      },
      timestamp: {
        date: { start: timestamp }
      },
      decision: {
        rich_text: [{ text: { content: decision } }]
      },
      rationale: {
        rich_text: [{ text: { content: rationale } }]
      },
      evidence: {
        rich_text: [{ text: { content: evidence } }]
      },
      reversibility: {
        select: { name: reversibility }   // "reversible" | "irreversible" | "unknown"
      },
      revert_status: {
        select: { name: "active" }
      }
    }
  })
  
  return { page_id: response.id, url: response.url }
}
```

### Pattern 3: Query Decisions Since Timestamp (MEM-02)

**What:** Retrieve all autonomous decisions logged after a given ISO 8601 timestamp. Used for "what did you do while I was away?" and morning standup count.

**When to use:** Called by Task Orchestrator with `--since <last_session_ISO>`.

```javascript
// Source: developers.notion.com/reference/post-database-query-filter (verified via WebFetch)
// timestamp filter: does NOT use "property" field — uses "timestamp" key directly
async function queryDecisionsSince(sinceISO) {
  const response = await notion.databases.query({
    database_id: process.env.NOTION_DECISION_DB_ID,
    filter: {
      timestamp: "created_time",         // Built-in timestamp, NOT a property name
      created_time: {
        on_or_after: sinceISO            // ISO 8601 format: "2026-05-20T00:00:00.000Z"
      }
    },
    sorts: [
      { timestamp: "created_time", direction: "ascending" }
    ]
  })
  
  return response.results.map(page => ({
    id: page.id,
    url: page.url,
    created_time: page.created_time,
    decision: page.properties.decision?.rich_text?.[0]?.text?.content ?? "",
    rationale: page.properties.rationale?.rich_text?.[0]?.text?.content ?? "",
    reversibility: page.properties.reversibility?.select?.name ?? "unknown",
    revert_status: page.properties.revert_status?.select?.name ?? "active"
  }))
}
```

**CRITICAL NOTE:** The `timestamp` filter does NOT accept a `property` field. The API throws an error if you provide one. The correct top-level key is `timestamp: "created_time"` with a sibling `created_time` object. [VERIFIED: developers.notion.com/reference/post-database-query-filter]

### Pattern 4: Update Revert Status (MEM-03)

**What:** Mark a decision as `pending_revert` (user wants to revert), then `reverted` (after rollback completes).

**When to use:** Task Orchestrator receives revert instruction from User Orchestrator.

```javascript
// Source: @notionhq/client README — notion.pages.update (verified)
async function updateRevertStatus(pageId, status) {
  // status: "pending_revert" | "reverted" | "active"
  await notion.pages.update({
    page_id: pageId,
    properties: {
      revert_status: {
        select: { name: status }
      }
    }
  })
}
```

### Pattern 5: Create Experiment Page (MEM-04)

**What:** Create a structured Notion page for an experiment with heading + paragraph blocks for each section.

**When to use:** Task Orchestrator creates this at experiment proposal time, before any execution begins.

```javascript
// Source: developers.notion.com/reference/post-page (verified via WebFetch)
// Block children: heading_2 + paragraph pattern for structured experiments
async function createExperimentPage({ hypothesis, method, successCriteria }) {
  const response = await notion.pages.create({
    parent: { page_id: process.env.NOTION_EXPERIMENTS_PAGE_ID },
    properties: {
      Name: {
        title: [{ text: { content: `Experiment: ${hypothesis.slice(0, 100)}` } }]
      }
    },
    children: [
      { object: "block", type: "heading_2",
        heading_2: { rich_text: [{ text: { content: "Hypothesis" } }] } },
      { object: "block", type: "paragraph",
        paragraph: { rich_text: [{ text: { content: hypothesis } }] } },

      { object: "block", type: "heading_2",
        heading_2: { rich_text: [{ text: { content: "Method" } }] } },
      { object: "block", type: "paragraph",
        paragraph: { rich_text: [{ text: { content: method } }] } },

      { object: "block", type: "heading_2",
        heading_2: { rich_text: [{ text: { content: "Success Criteria" } }] } },
      { object: "block", type: "paragraph",
        paragraph: { rich_text: [{ text: { content: successCriteria } }] } },

      { object: "block", type: "heading_2",
        heading_2: { rich_text: [{ text: { content: "Results" } }] } },
      { object: "block", type: "paragraph",
        paragraph: { rich_text: [{ text: { content: "Pending — experiment in progress." } }] } }
    ]
  })
  
  return { page_id: response.id, url: response.url }
}
```

### Pattern 6: AFK Scaffolding Strategy (Token Not Yet Available)

**What:** User is AFK. Notion integration token does not exist yet. The scaffolding builds everything except the live connection, and leaves a human checkpoint that gates execution.

**Implementation approach:**

1. All `log-decision.js` scripts check for `OPENCLAW_NOTION_TOKEN` at startup:
   ```javascript
   if (!process.env.OPENCLAW_NOTION_TOKEN) {
     console.error("TODO_NOTION: OPENCLAW_NOTION_TOKEN not set. Run /openclaw-add-secret notion-token <value>")
     process.exit(0)  // Exit 0, not 1 — logging failure must not block actions
   }
   ```

2. Task Orchestrator SOUL.md gets a stub Notion rule:
   ```markdown
   ## Notion Decision Logging (TODO_NOTION — Phase 9)
   Before executing any autonomous action, run scripts/notion/log-decision.js.
   If it exits 0 with no page_id (token not yet configured), proceed anyway.
   Once OPENCLAW_NOTION_TOKEN is set, all decisions will be logged automatically.
   ```

3. Plan 09-01 includes a `checkpoint:human-verify` step requiring:
   - User creates a Notion integration at https://www.notion.so/my-integrations
   - User creates the Decision Log database and shares it with the integration
   - User runs `/openclaw-add-secret notion-token <integration_token>`
   - User adds `NOTION_DECISION_DB_ID` and `NOTION_EXPERIMENTS_PAGE_ID` to `scripts/config.json`

### Anti-Patterns to Avoid

- **Blocking actions on Notion failures:** The decision log is an audit trail, not a gate. If Notion is unreachable (rate limit, downtime, token expired), the agent must proceed and log the failure to stderr. Only Phase 10 (autonomous merge) uses Notion as an explicit gate.
- **Using `property` key in timestamp filter:** The `timestamp` filter type does NOT accept a `property` field. The Notion API throws an error. Use `{ timestamp: "created_time", created_time: { on_or_after: "..." } }` directly.
- **Rich text > 2000 chars:** Notion rich_text properties have a 2000-character limit per text element. Truncate or split long rationale/evidence strings.
- **Storing NOTION_DECISION_DB_ID in Keychain:** The database ID is not a secret (it's visible in the Notion URL). Store it in `scripts/config.json` for easy access, not in Keychain. Only the integration token is a secret.
- **Global npm install:** `npm install -g @notionhq/client` violates CLAUDE.md. Install locally: `cd ~/.openclaw/agents/task-orchestrator/scripts && npm install @notionhq/client@5.22.0`.
- **`notionVersion` in the Notion-Version HTTP header (not the constructor):** The `@notionhq/client` SDK accepts `notionVersion` as a Client constructor option, not as a header. The SDK handles the header internally. Do not add a custom `Notion-Version` header.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Notion HTTP client | Custom `curl` + Notion REST | `@notionhq/client` 5.22.0 | SDK handles retries (429/500/503), pagination cursors, rate-limit back-off, token injection. CLAUDE.md mandated. |
| Pagination for `databases.query` | Manual cursor loop | `notion.databases.query` with built-in cursor handling | SDK handles `next_cursor` automatically when using `notion.databases.query` with `page_size` |
| Timestamp filter construction | Custom date comparison logic | `filter.timestamp = "created_time"` + `on_or_after` | Notion handles the comparison server-side; ISO 8601 string is sufficient |
| Retry on rate limit | `setTimeout` retry loop | SDK built-in retry (configured via `retry` constructor option) | SDK retries up to 2 times with exponential back-off by default |

**Key insight:** The Notion SDK is lightweight (no compile step, CommonJS `require` works in Node.js scripts) and eliminates the entire HTTP transport layer. Every line of raw `curl` Notion code would be rebuilding what the SDK already provides.

---

## AFK Token Strategy

This section captures the specific pattern for scaffolding Notion integration when the token does not yet exist.

**Problem:** Phase 9 cannot be fully verified until the user creates a Notion integration and provides the token. But the scaffolding (scripts, SOUL.md updates, database schema definition) can be done now.

**Strategy:**

| Step | Who does it | When |
|------|------------|------|
| Write all `scripts/notion/*.js` files with `TODO_NOTION` guard | Claude Code (automated) | Phase 9 execution |
| Write `scripts/config.json` with placeholder IDs | Claude Code (automated) | Phase 9 execution |
| Update Task Orchestrator SOUL.md with Notion logging rule | Claude Code (automated) | Phase 9 execution |
| **HUMAN CHECKPOINT**: Create Notion integration | User | After Phase 9 scaffolding |
| **HUMAN CHECKPOINT**: Create Decision Log database, share with integration | User | After integration created |
| **HUMAN CHECKPOINT**: Run `/openclaw-add-secret notion-token <token>` | User | After database created |
| **HUMAN CHECKPOINT**: Add real IDs to `scripts/config.json` | User | After database created |
| Run `npm install @notionhq/client@5.22.0` in scripts dir | Claude Code (post-checkpoint) | After user provides token |
| Verify `log-decision.js` returns `{"ok": true, "page_id": "..."}` | Claude Code (automated) | Post-checkpoint verification |

**TODO_NOTION guard pattern:**
```javascript
// All Notion scripts must begin with this guard
if (!process.env.OPENCLAW_NOTION_TOKEN || process.env.OPENCLAW_NOTION_TOKEN === "TODO_NOTION") {
  process.stdout.write(JSON.stringify({ ok: true, skipped: true, reason: "OPENCLAW_NOTION_TOKEN not configured" }) + "\n")
  process.exit(0)  // Exit 0 — logging must not block actions
}
```

---

## Common Pitfalls

### Pitfall 1: `timestamp` Filter Rejects `property` Field

**What goes wrong:** `notion.databases.query` throws `APIResponseError: "property" field is not allowed for timestamp filter type`.

**Why it happens:** The `timestamp` filter type is for built-in Notion metadata (created_time, last_edited_time), not a database property. The API spec is different from property filters.

**How to avoid:** Use exactly this structure:
```javascript
filter: {
  timestamp: "created_time",
  created_time: { on_or_after: isoString }
}
// NOT: filter: { property: "timestamp", ... }
```

**Warning signs:** `APIResponseError` with "property is not allowed".

### Pitfall 2: Rich Text 2000-Character Limit

**What goes wrong:** `notion.pages.create` throws a validation error when `evidence` or `rationale` exceeds 2000 characters.

**Why it happens:** Notion enforces a 2000-character limit per text object in rich_text arrays. Long LLM-generated rationale strings hit this.

**How to avoid:** Truncate all string inputs before creating the properties object:
```javascript
const truncate = (s, n=1990) => s.length > n ? s.slice(0, n) + "..." : s
```

**Warning signs:** `ValidationError` in the Notion SDK response.

### Pitfall 3: `@notionhq/client` Not Found in Node.js Script

**What goes wrong:** `require("@notionhq/client")` throws `MODULE_NOT_FOUND` even though you installed it.

**Why it happens:** The package was installed in a different directory from where the script runs. Node.js `require` walks up from the script file's directory to find `node_modules/`.

**How to avoid:** Install `@notionhq/client` in the SAME directory as the scripts: `cd ~/.openclaw/agents/task-orchestrator/scripts && /opt/homebrew/opt/node@24/bin/npm install @notionhq/client@5.22.0`. The script at `scripts/notion/log-decision.js` resolves `node_modules/` by walking up to `scripts/node_modules/` — which is correct.

**Warning signs:** `Error: Cannot find module '@notionhq/client'` at script runtime.

### Pitfall 4: Integration Token Not Shared with Database

**What goes wrong:** `notion.databases.query` or `notion.pages.create` returns `APIResponseError: Could not find database`.

**Why it happens:** Creating a Notion integration token and creating a database are separate steps. The integration must explicitly be given access to the database via "Share" in the Notion UI.

**How to avoid:** After creating the database, click "Share" in Notion and add the integration by name. This is a one-time manual step documented in Plan 09-01's human checkpoint.

**Warning signs:** `ObjectNotFound` error from Notion API even with valid token and database ID.

### Pitfall 5: Default Notion API Version Misses 2026-03-11 Features

**What goes wrong:** Some Notion API features added in the 2026-03-11 version are unavailable when using the default `2025-09-03`.

**Why it happens:** The `@notionhq/client` constructor defaults to `notionVersion: "2025-09-03"` (`Client.defaultNotionVersion`). Without explicit override, the default version is used.

**How to avoid:** Always pass `notionVersion: "2026-03-11"` in the Client constructor:
```javascript
const notion = new Client({
  auth: process.env.OPENCLAW_NOTION_TOKEN,
  notionVersion: "2026-03-11"
})
```

**Warning signs:** Features documented in Notion API 2026-03-11 changelog behave unexpectedly.

---

## Code Examples

### Verified: @notionhq/client initialization
```javascript
// Source: makenotion/notion-sdk-js README (verified via npm view @notionhq/client readme)
// Source: CLAUDE.md — notionVersion: "2026-03-11"
// Source: Client.ts ClientOptions interface [VERIFIED: GitHub makenotion/notion-sdk-js]
const { Client } = require("@notionhq/client")
const notion = new Client({
  auth: process.env.OPENCLAW_NOTION_TOKEN,
  notionVersion: "2026-03-11"
})
```

### Verified: pages.create for database entry
```javascript
// Source: developers.notion.com/reference/post-page [VERIFIED via WebFetch]
const page = await notion.pages.create({
  parent: { database_id: "YOUR_DATABASE_ID" },
  properties: {
    Name: { title: [{ text: { content: "Entry title" } }] },
    timestamp: { date: { start: new Date().toISOString() } },
    decision: { rich_text: [{ text: { content: "What was decided" } }] },
    reversibility: { select: { name: "reversible" } },
    revert_status: { select: { name: "active" } }
  }
})
// response.id = page ID, response.url = Notion page URL
```

### Verified: databases.query with created_time filter
```javascript
// Source: developers.notion.com/reference/post-database-query-filter [VERIFIED via WebFetch]
// CRITICAL: timestamp filter does NOT use "property" field
const results = await notion.databases.query({
  database_id: "YOUR_DATABASE_ID",
  filter: {
    timestamp: "created_time",
    created_time: { on_or_after: "2026-05-20T00:00:00.000Z" }
  },
  sorts: [{ timestamp: "created_time", direction: "ascending" }]
})
```

### Verified: pages.update for revert_status
```javascript
// Source: @notionhq/client README (notion.pages.update method) [VERIFIED via npm view readme]
await notion.pages.update({
  page_id: "PAGE_ID",
  properties: {
    revert_status: { select: { name: "reverted" } }
  }
})
```

### Verified: Notion secret storage convention
```zsh
# Source: CLAUDE.md secrets pipeline + /openclaw-add-secret skill
# Service name: openclaw.notion-token (lowercase, hyphens)
# Env var name: OPENCLAW_NOTION_TOKEN (uppercase, underscores)
/openclaw-add-secret notion-token <integration_token>
# Propagates to: openclaw-secrets.sh, openclaw-env.sh, secrets.sh
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Manual decision documentation in Markdown | Pre-execution Notion log entry (automated) | Phase 9 | Decisions are logged BEFORE execution, not after — enables true async review |
| `npm install -g notion` (community packages) | `@notionhq/client` from `makenotion` org | 2021 (SDK launch) | Official SDK; community packages are unmaintained or unofficial |
| Raw Notion API v1 with manual pagination | `@notionhq/client` with auto-retry and auto-pagination | SDK 0.1.0+ | No manual cursor tracking needed for most queries |
| Notion API `2021-05-13` (v1 initial) | `2026-03-11` (latest) | Multiple releases | Latest version required for most recent schema features |

**Deprecated/outdated:**
- `notionhq` (npm, no `@` scope) — unmaintained community package; always use `@notionhq/client`
- `notion-client` (npm) — third-party; uses unofficial Notion internal API; fragile
- Notion API `Notion-Version: 2021-05-13` — missing database query features added in later versions

---

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | The Notion integration token (`OPENCLAW_NOTION_TOKEN`) does not yet exist — user is AFK and has not created the integration | AFK Token Strategy | If the token already exists, the human checkpoint in Plan 09-01 is simpler; no risk to plan correctness |
| A2 | `NOTION_DECISION_DB_ID` is stored in `scripts/config.json` (not in Keychain) because database IDs are not sensitive credentials | Architecture Patterns | If the user considers database IDs sensitive, they should be moved to Keychain; low risk |
| A3 | The Notion `databases.query` `on_or_after` filter works with full ISO 8601 timestamps including time component (not just date strings) | Pattern 3 | Notion API docs confirm "millisecond precision" for timestamp filters, so full ISO 8601 is correct [VERIFIED: developers.notion.com filter reference] |
| A4 | Phase 8 (DevBot autonomous dev) is complete before Phase 9 begins; Task Orchestrator exists and has a `scripts/` directory | Architecture | Plans would need to create the scripts dir if Phase 8 is not yet complete; low risk since Phase 8 precedes Phase 9 in ROADMAP.md |

---

## Open Questions

1. **Where does the "last session timestamp" come from for MEM-02?**
   - What we know: `query-decisions.js --since <ISO>` needs a timestamp. The User Orchestrator or Task Orchestrator needs to track when Anuj last interacted with the system.
   - What's unclear: Is there an existing "session start" timestamp stored anywhere? The User Orchestrator has a MEMORY.md — does it log session start times?
   - Recommendation: Plan 09-03 should implement a simple `last-session.json` file in the User Orchestrator workspace that records session start/end timestamps. The `--since` argument defaults to the timestamp in `last-session.json`.

2. **Should the Notion database be created by the agent (via `notion.databases.create`) or manually by the user?**
   - What we know: `notion.databases.create` requires a parent page ID. Creating the database programmatically is possible but requires the user to first create a parent page and share it with the integration.
   - What's unclear: Which approach is simpler for the user.
   - Recommendation: User creates the database manually in Notion (easier, no API complexity for one-time setup), then shares it with the integration and adds its ID to `scripts/config.json`. Document the schema from RESEARCH.md so the user knows exactly what properties to create.

3. **Should `log-decision.js` be a shell script wrapper or a pure Node.js script?**
   - What we know: Other deterministic scripts are `zsh` with JSON stdout. Node.js is needed for `@notionhq/client`. The cc-openclaw pattern is shell scripts.
   - Recommendation: Thin shell wrapper (`log-decision.sh`) that calls `node scripts/notion/log-decision.js` with `set -euo pipefail` and passes the JSON result to stdout. This keeps the cc-openclaw convention at the shell layer while using Node.js for the Notion SDK.

---

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Node.js 24 | `@notionhq/client` scripts | Yes | `/opt/homebrew/opt/node@24/bin/node` | — |
| `@notionhq/client` 5.22.0 | All Notion scripts | Not yet installed | — | Install: `npm install @notionhq/client@5.22.0` in scripts dir |
| `OPENCLAW_NOTION_TOKEN` | All Notion scripts | Not yet set | — | Human checkpoint in Plan 09-01 |
| Notion database (Decision Log) | MEM-01, MEM-02, MEM-03 | Not yet created | — | Human checkpoint in Plan 09-01 |
| Notion page (Experiments section) | MEM-04 | Not yet created | — | Human checkpoint in Plan 09-01 |

**Missing dependencies with no fallback:**
- Notion integration token (`OPENCLAW_NOTION_TOKEN`) — all Notion scripts are no-ops until this is set. Scripts use `TODO_NOTION` guard and exit 0, so actions are not blocked.
- Notion database and experiments page — must be created by user during Plan 09-01 human checkpoint.

**Missing dependencies with fallback:**
- `@notionhq/client` npm package — not yet installed, but installation is deterministic: `cd ~/.openclaw/agents/task-orchestrator/scripts && /opt/homebrew/opt/node@24/bin/npm install @notionhq/client@5.22.0`. Plan 09-02 includes this step after the human checkpoint.

---

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | Node.js scripts with `--dry-run` flag + shell verification |
| Config file | `scripts/verify-phase-09.sh` (to be created in final wave) |
| Quick run command | `zsh scripts/verify-phase-09.sh --smoke` |
| Full suite command | `zsh scripts/verify-phase-09.sh` |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| MEM-01a | `log-decision.js` creates Notion page | integration | `node scripts/notion/log-decision.js --dry-run` | No — Wave 0 |
| MEM-01b | Notion page contains all 7 required properties | integration | `node scripts/notion/log-decision.js --verify-schema` | No — Wave 0 |
| MEM-01c | Log entry exists BEFORE action (timing order) | manual | Review Notion page created_time vs action execution log | No — manual only |
| MEM-02a | `query-decisions.js --since <ISO>` returns decisions list | integration | `node scripts/notion/query-decisions.js --since 2026-05-20T00:00:00Z` | No — Wave 0 |
| MEM-02b | Empty result for timestamp with no decisions | unit | `node scripts/notion/query-decisions.js --since 2030-01-01T00:00:00Z` | No — Wave 0 |
| MEM-03a | `update-decision.js --revert-status reverted` updates page | integration | `node scripts/notion/update-decision.js --page-id <id> --revert-status reverted` | No — Wave 0 |
| MEM-04a | `create-experiment.js` creates page with 4 heading blocks | integration | `node scripts/notion/create-experiment.js --dry-run` | No — Wave 0 |

### Sampling Rate
- **Per task commit:** `zsh scripts/verify-phase-09.sh --smoke` (TODO_NOTION guard check + script syntax validation via `node --check`)
- **Per wave merge:** `zsh scripts/verify-phase-09.sh` (all automated checks — requires Notion token post-checkpoint)
- **Phase gate:** All 4 MEM requirements verified with live Notion database before `/gsd:verify-work`

### Wave 0 Gaps
- [ ] `scripts/notion/log-decision.js` — covers MEM-01
- [ ] `scripts/notion/query-decisions.js` — covers MEM-02
- [ ] `scripts/notion/update-decision.js` — covers MEM-03
- [ ] `scripts/notion/create-experiment.js` — covers MEM-04
- [ ] `scripts/config.json` — NOTION_DECISION_DB_ID, NOTION_EXPERIMENTS_PAGE_ID placeholders
- [ ] `package.json` in scripts dir — `{ "dependencies": { "@notionhq/client": "5.22.0" } }`
- [ ] `scripts/verify-phase-09.sh` — smoke + integration tests

*(Note: All Node.js scripts require Notion token — smoke tests use `TODO_NOTION` guard path before token is set)*

---

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | Yes | Integration token in Keychain as `openclaw.notion-token`; never in files or git history |
| V4 Access Control | Yes | Notion integration scoped to specific database only (via Notion "Share" UI); principle of least privilege |
| V5 Input Validation | Yes | Rich text truncated to 1990 chars; no user-controlled input in Notion API calls — all inputs from agent-internal decisions |
| V6 Cryptography | No | No cryptographic operations; Notion token is stored in macOS Keychain (AES-256 encrypted) |

### Known Threat Patterns

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Integration token in git history | Information Disclosure | Keychain only (`/openclaw-add-secret notion-token`); `scripts/config.json` contains non-secret IDs only |
| Notion API token exposure in logs | Information Disclosure | SDK logs at WARN level by default (no token in logs); never echo token to stdout |
| Database ID in git (non-secret) | Information Disclosure (low) | Database IDs are not credentials; stored in `scripts/config.json` committed to git is acceptable |
| Decision log blocks actions (availability) | Denial of Service | `TODO_NOTION` guard + exit 0 on token-absent; logging never blocks agent execution |

---

## Sources

### Primary (HIGH confidence)
- `npm view @notionhq/client` (local npm, verified 2026-05-21) — version 5.22.0, published 2026-05-19, created 2021-05-13, repo: github.com/makenotion/notion-sdk-js, no postinstall scripts
- `npm view @notionhq/client readme` (local npm) — Client constructor, `auth` option, `notionVersion` option, `pages.create`, `databases.query` usage
- `github.com/makenotion/notion-sdk-js/main/src/Client.ts` (WebFetch verified) — `ClientOptions.notionVersion` confirmed as valid parameter; `defaultNotionVersion = "2025-09-03"` confirmed
- `developers.notion.com/reference/post-page` (WebFetch verified) — `pages.create` request body structure: `parent.database_id`, `properties` with title/rich_text/date/select types
- `developers.notion.com/reference/post-database-query-filter` (WebFetch verified) — `timestamp` filter: `{ timestamp: "created_time", created_time: { on_or_after: "<ISO>" } }`; "property" field NOT allowed for timestamp filters
- `/Users/trilogy/Documents/agentic-setup/CLAUDE.md` — `@notionhq/client` 5.22.0 mandated, `notionVersion: "2026-03-11"`, local install only, `OPENCLAW_NOTION_TOKEN` Keychain key

### Secondary (MEDIUM confidence)
- `developers.notion.com/reference/post-database-query` — sort by `created_time` ascending confirmed

### Tertiary (LOW confidence)
- Notion `blocks.children.append` for experiment results — method exists in `@notionhq/client` SDK (seen in README examples); specific block schema for heading_2 and paragraph types assumed from Notion block documentation [ASSUMED]

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — `@notionhq/client` 5.22.0 verified on npm, Client.ts constructor confirmed, CLAUDE.md mandated
- Architecture: HIGH — Notion API endpoints verified via WebFetch; timestamp filter structure verified from official docs
- Pitfalls: HIGH — timestamp filter "no property field" rule verified from official docs; 2000-char limit is documented Notion constraint

**Research date:** 2026-05-21
**Valid until:** 2026-06-21 (30 days — Notion API is stable; `@notionhq/client` releases frequently but patch-level only)

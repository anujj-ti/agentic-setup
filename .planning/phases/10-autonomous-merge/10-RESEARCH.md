# Phase 10: Autonomous Merge — Research

**Researched:** 2026-05-21
**Domain:** GitHub CLI PR merge, Notion pre-log gate, merge revert workflow, DevBot SECURITY.md enforcement
**Confidence:** HIGH

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| DEV-05 | DevBot agent can merge PRs that have passed CI and quality review — merger logs the decision to Notion before executing the merge; user can see and revert any autonomous merge | Fully covered — `gh pr merge`, `gh pr view --json mergeCommit`, `gh pr reopen`, `git revert -m 1` all verified locally on gh 2.69.0; Notion pre-log write pattern confirmed via @notionhq/client 5.22.0 |
</phase_requirements>

---

## Summary

Phase 10 adds one guarded capability to DevBot: the ability to merge a CI-passing PR only after a Notion decision log entry has been created and confirmed for that specific merge. The key invariant is **Notion write precedes gh merge** — this is enforced at the code level in DevBot's merge script, not just as a policy in SOUL.md.

The merge flow is: (1) confirm CI passing via `gh pr view --json statusCheckRollup`, (2) write Notion log entry and capture the returned page ID, (3) only if the write succeeds and returns a page ID, invoke `gh pr merge --squash --delete-branch`. The page ID is embedded in the merge commit subject as provenance. Without a successful Notion write, the script exits non-zero before merge executes.

The revert flow is fully mechanical: `gh pr view --json mergeCommit` retrieves the merge commit SHA, `git revert -m 1 <sha>` creates a revert commit (the `-m 1` flag is required for merge commits to identify which parent is the mainline), and `gh pr reopen <number>` reopens the PR. The revert itself is logged as a new Notion decision entry with `reversibility: "reverted"` and a pointer back to the original log entry.

**Primary recommendation:** Four plans: (1) add the merge security rule to DevBot SOUL.md and SECURITY.md; (2) implement `devbot-merge.sh` with Notion pre-log + `gh pr merge`; (3) implement `devbot-revert-merge.sh`; (4) verify the gate by attempting a merge without a Notion entry.

---

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| CI check status before merge | DevBot script (`gh pr view --json statusCheckRollup`) | — | Pure data query — LLM is not involved in the pass/fail decision |
| Notion pre-log write | DevBot script (`notion-log-decision.js` or inline JS) | @notionhq/client 5.22.0 | Atomic write with confirmed page ID return; script exits on failure before merge |
| PR merge execution | DevBot script (`gh pr merge --squash`) | gh CLI | Deterministic — only runs after Notion page ID is confirmed |
| Merge commit SHA retrieval | DevBot script (`gh pr view --json mergeCommit`) | — | Needed for revert workflow; recorded in Notion log entry at merge time |
| Merge revert | DevBot script (`git revert -m 1` + `gh pr reopen`) | — | Two-step: code revert + PR state restoration |
| Revert logging | DevBot script (Notion write for revert event) | — | Revert is a new decision entry; links back to original by Notion page ID |
| Security enforcement | DevBot SECURITY.md + SOUL.md | — | SECURITY.md rule: `gh pr merge` MUST NOT be called without a confirmed Notion page ID in scope |

---

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| `gh` CLI | 2.69.0 installed, 2.92.0 in CLAUDE.md | PR merge, CI status check, PR reopen | CLAUDE.md-mandated GitHub CLI; `gh pr merge`, `gh pr view`, `gh pr reopen` all confirmed working on 2.69.0 |
| `@notionhq/client` | 5.22.0 | Notion decision log pre-write | CLAUDE.md-mandated Notion client; API version `2026-03-11`; install per-agent not globally |
| `git` | System (brew) | `git revert -m 1 <sha>` for merge commit reversal | Standard git; `-m 1` flag required for merge commits |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| `jq` | System (brew) | Extract `statusCheckRollup` and `mergeCommit` from `gh pr view --json` | All gh JSON output piped through jq |

### Installation
```bash
# In DevBot scripts directory — NOT globally (CLAUDE.md mandate)
cd ~/.openclaw/agents/devbot/scripts
npm init -y
npm install @notionhq/client
```

### Version verification
```
@notionhq/client: 5.22.0 (npm view @notionhq/client version — verified 2026-05-21)
gh CLI:           2.69.0 installed (gh --version — verified 2026-05-21)
```

---

## Package Legitimacy Audit

| Package | Registry | Age | Downloads | Source Repo | slopcheck | Disposition |
|---------|----------|-----|-----------|-------------|-----------|-------------|
| `@notionhq/client` | npm | ~4 yrs | High (official SDK) | github.com/makenotion/notion-sdk-js | N/A | Approved — official Notion SDK, CLAUDE.md mandated |

*slopcheck not run — `@notionhq/client` is confirmed as the official Notion-published SDK, listed in CLAUDE.md with a pinned version. Registry existence via `npm view @notionhq/client version` returns `5.22.0` [VERIFIED: npm registry].*

---

## Architecture Patterns

### System Architecture Diagram

```
Task Orchestrator
      │  sessions_spawn("merge PR #42")
      ▼
DevBot agent
      │
      ├─── 1. gh pr view #42 --json statusCheckRollup
      │         └── all checks passed? → continue / abort
      │
      ├─── 2. notion-log-decision.js
      │         └── writes decision entry → returns pageId
      │         └── failure? → exit 1 (merge NEVER executes)
      │
      ├─── 3. gh pr merge 42 --squash --delete-branch
      │         --subject "Merge PR #42 [notion:pageId]"
      │         └── success → captures mergeCommit SHA
      │
      └─── 4. gh pr view 42 --json mergeCommit → record SHA in Notion
           └── return { ok: true, pageId, mergeCommitSha } to Task Orchestrator


Revert flow (triggered by user marking decision for revert in Notion):
Task Orchestrator reads Notion entry → finds mergeCommitSha + PR number
      │
      ├─── git revert -m 1 <mergeCommitSha> --no-edit
      ├─── git push origin HEAD
      ├─── gh pr reopen <number> --comment "Reverted: merge commit <sha>"
      └─── notion-log-decision.js (new entry: action=revert, links=original pageId)
```

### Recommended Project Structure
```
.openclaw/agents/devbot/
├── SOUL.md          # updated: merge rules + mandatory Notion gate
├── SECURITY.md      # updated: explicit no-merge-without-notion-page-id rule
├── TOOLS.md         # updated: merge + revert command reference
└── scripts/
    ├── lib/
    │   └── json-response.sh
    ├── package.json             # @notionhq/client dependency
    ├── devbot-merge.sh          # CI check + Notion pre-log + gh pr merge
    ├── notion-log-decision.js   # @notionhq/client write, returns pageId
    └── devbot-revert-merge.sh   # git revert + gh pr reopen + Notion log
```

### Pattern 1: Notion Pre-Log Gate (Enforced in Script)
**What:** The merge script captures the Notion page ID before invoking `gh pr merge`. If the write fails, the script exits non-zero and merge never runs.
**When to use:** Every `gh pr merge` invocation — no exceptions.
**Example:**
```zsh
#!/usr/bin/env zsh
set -euo pipefail

PR_NUMBER="$1"

# Step 1: CI check
STATUS=$(gh pr view "$PR_NUMBER" --json statusCheckRollup --jq '.statusCheckRollup | map(.state) | all(. == "SUCCESS")')
[[ "$STATUS" == "true" ]] || { echo '{"ok":false,"error":"CI not passing"}' ; exit 1 }

# Step 2: Notion pre-log (MUST succeed before merge)
PAGE_ID=$(node scripts/notion-log-decision.js \
  --action "merge PR #${PR_NUMBER}" \
  --rationale "CI passing, quality review passed" \
  --reversibility "reversible via git revert -m 1" \
  --evidence "statusCheckRollup: all SUCCESS")
[[ -n "$PAGE_ID" ]] || { echo '{"ok":false,"error":"Notion pre-log failed"}' ; exit 1 }

# Step 3: Merge — only reachable after confirmed Notion page ID
gh pr merge "$PR_NUMBER" --squash --delete-branch \
  --subject "Merge PR #${PR_NUMBER} [notion:${PAGE_ID}]"

# Step 4: Capture merge commit SHA and update Notion entry
MERGE_SHA=$(gh pr view "$PR_NUMBER" --json mergeCommit --jq '.mergeCommit.oid')
node scripts/notion-update-page.js --pageId "$PAGE_ID" --mergeCommitSha "$MERGE_SHA"

echo "{\"ok\":true,\"pageId\":\"${PAGE_ID}\",\"mergeCommitSha\":\"${MERGE_SHA}\"}"
```
*Source: verified logic built from `gh pr merge --help` and `gh pr view --json` fields confirmed locally [VERIFIED: local tool output]; Notion write pattern from @notionhq/client 5.22.0 [CITED: CLAUDE.md + npmjs.com/package/@notionhq/client]*

### Pattern 2: Merge Revert via `git revert -m 1`
**What:** Reverting a merge commit requires `-m 1` to specify the mainline parent. Without it, git refuses to revert because it cannot determine which side of the merge was the "main" line.
**When to use:** Every merge revert in DevBot.
**Example:**
```zsh
#!/usr/bin/env zsh
set -euo pipefail

MERGE_SHA="$1"
PR_NUMBER="$2"
ORIGINAL_PAGE_ID="$3"

git revert -m 1 "$MERGE_SHA" --no-edit
git push origin HEAD

gh pr reopen "$PR_NUMBER" \
  --comment "Merge reverted. Commit: ${MERGE_SHA}. See Notion: ${ORIGINAL_PAGE_ID}"

# Log revert as new decision entry
node scripts/notion-log-decision.js \
  --action "revert merge PR #${PR_NUMBER}" \
  --rationale "User requested revert via Notion decision log" \
  --reversibility "permanent — creates new revert commit" \
  --evidence "originalPageId:${ORIGINAL_PAGE_ID}, mergeCommitSha:${MERGE_SHA}"

echo "{\"ok\":true,\"revertedSha\":\"${MERGE_SHA}\",\"prNumber\":\"${PR_NUMBER}\"}"
```
*Source: `git revert --help` confirmed `-m 1` requirement for merge commits [VERIFIED: local tool output]; `gh pr reopen --help` confirmed [VERIFIED: local tool output]*

### Pattern 3: Notion Decision Entry Shape
**What:** Consistent property schema for all merge-related decision log entries.
```javascript
// Source: @notionhq/client 5.22.0 docs + CLAUDE.md Notion API version
const { Client } = require('@notionhq/client');
const notion = new Client({
  auth: process.env.OPENCLAW_NOTION_TOKEN,
  notionVersion: '2026-03-11'
});

async function logDecision({ action, rationale, reversibility, evidence }) {
  const page = await notion.pages.create({
    parent: { database_id: process.env.OPENCLAW_NOTION_DECISIONS_DB_ID },
    properties: {
      'Action':         { title: [{ text: { content: action } }] },
      'Timestamp':      { date: { start: new Date().toISOString() } },
      'Rationale':      { rich_text: [{ text: { content: rationale } }] },
      'Evidence':       { rich_text: [{ text: { content: evidence } }] },
      'Reversibility':  { rich_text: [{ text: { content: reversibility } }] },
      'Status':         { select: { name: 'executed' } }
    }
  });
  return page.id; // This is what the merge script checks for
}
```
*Source: @notionhq/client 5.22.0 [CITED: npmjs.com/package/@notionhq/client]; API version 2026-03-11 [CITED: CLAUDE.md]*

### Anti-Patterns to Avoid
- **Logging after merge:** Creating the Notion entry after `gh pr merge` defeats the pre-log requirement and leaves an unlogged window if merge succeeds but Notion write fails.
- **Using `--admin` flag:** `gh pr merge --admin` bypasses branch protection rules. Never use in autonomous merge flows — it bypasses the CI gate.
- **`git reset --hard` for reverting:** Rewriting history is destructive. Always use `git revert -m 1` which creates a new commit and preserves history.
- **Hardcoding Notion database ID:** Use `OPENCLAW_NOTION_DECISIONS_DB_ID` env var loaded from Keychain via `openclaw-secrets.sh`. Never hardcode in scripts.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| PR merge | Custom GitHub REST API call | `gh pr merge` | gh handles auth, rate limiting, merge queue; REST requires manual token management |
| Notion page write | Raw `curl` to Notion REST API | `@notionhq/client` | SDK handles retries, rate limits, pagination; CLAUDE.md explicitly mandates it |
| CI status aggregation | Parse individual check run events | `gh pr view --json statusCheckRollup` | `statusCheckRollup` aggregates all checks per PR head commit in one call |
| Merge commit revert | Manual cherry-pick or `reset --hard` | `git revert -m 1 <sha>` | History-safe; creates new commit; auditable; `-m 1` is the correct flag for merge commits |

---

## Common Pitfalls

### Pitfall 1: Notion Write Succeeds But Returns No Page ID
**What goes wrong:** `notion.pages.create()` returns an object; if the `id` field is not explicitly checked, the script may proceed to merge thinking the log succeeded.
**Why it happens:** JavaScript async failure modes — if the call throws, `set -euo pipefail` catches it, but if the API returns a degraded response, the check is needed at the application level.
**How to avoid:** Always check `[[ -n "$PAGE_ID" ]]` after the node script exits and treat empty string as failure. Exit 1 before merge.
**Warning signs:** Notion page ID is an empty string or undefined in script output.

### Pitfall 2: Reverting a Merge Commit Without `-m 1`
**What goes wrong:** `git revert <merge-sha>` fails with "error: commit <sha> is a merge but no -m option was given."
**Why it happens:** Merge commits have two parents; git cannot determine which side to treat as the mainline without explicit direction.
**How to avoid:** Always use `git revert -m 1 <sha>` — parent 1 is always the base branch (main/master), which is the correct mainline.
**Warning signs:** git exits non-zero with the -m option error message.

### Pitfall 3: `gh pr reopen` Fails if Branch Was Deleted
**What goes wrong:** If `gh pr merge --delete-branch` was used (recommended), the PR's head branch no longer exists. `gh pr reopen` still works (it reopens the PR state), but the user cannot push new commits to the original branch without recreating it.
**Why it happens:** GitHub allows reopening PRs even after branch deletion, but the branch itself is gone.
**How to avoid:** Document in TOOLS.md that revert workflow reopens the PR but does NOT recreate the head branch. The user must push to a new branch or recreate the original branch. This is a known limitation.
**Warning signs:** `gh pr reopen` succeeds but subsequent `git push` to the original branch name fails.

### Pitfall 4: OPENCLAW_NOTION_DECISIONS_DB_ID Not in Environment
**What goes wrong:** `notion-log-decision.js` cannot find the database to write to and throws an API error — merge is blocked (which is correct behavior) but the error message is confusing.
**Why it happens:** Phase 9 creates the Notion database and its ID must be stored in Keychain as `openclaw.notion-decisions-db-id` and loaded into the gateway environment via `openclaw-secrets.sh`.
**How to avoid:** Plan 10-02 must verify the env var is set before writing the merge script. Add to DevBot TOOLS.md: the required env vars and where they are sourced.
**Warning signs:** `notion-log-decision.js` exits with "Could not find database with ID undefined."

---

## Code Examples

### Check CI Passing for a PR
```zsh
# Source: gh pr view --help (JSON fields: statusCheckRollup) — verified locally
PR_NUMBER=42
STATUS_JSON=$(/opt/homebrew/bin/gh pr view "$PR_NUMBER" --json statusCheckRollup)
ALL_PASS=$(echo "$STATUS_JSON" | jq '[.statusCheckRollup[].state] | all(. == "SUCCESS")')
# $ALL_PASS is "true" only if all checks are SUCCESS
```

### Retrieve Merge Commit SHA After Merge
```zsh
# Source: gh pr view --help (JSON field: mergeCommit) — verified locally
MERGE_SHA=$(/opt/homebrew/bin/gh pr view "$PR_NUMBER" --json mergeCommit --jq '.mergeCommit.oid')
```

### SECURITY.md Addition for DevBot
```markdown
## Autonomous Merge Gate (DEV-05)
- MUST NOT invoke `gh pr merge` without a confirmed Notion page ID in scope
- The Notion pre-log script must exit 0 and return a non-empty page ID before merge proceeds
- If Notion write fails for any reason: exit 1, report BLOCKED to Task Orchestrator, do NOT merge
- NEVER use `--admin` flag — it bypasses CI requirements
- NEVER use `--auto` flag for autonomous merges — it defers CI check to GitHub and removes our control
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Merge then log | Pre-log then merge | Phase 10 (now) | Eliminates window where action executes without audit trail |
| Manual merge decision | Automated merge after Notion confirmation | Phase 10 (now) | User reviews log on return, can revert without being present |

---

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | Phase 9 creates the Notion decisions database and its ID is stored in Keychain before Phase 10 runs | Architecture Patterns (Pattern 3) | OPENCLAW_NOTION_DECISIONS_DB_ID env var won't exist; Plan 10-02 must verify Phase 9 prerequisite |
| A2 | DevBot has an existing `scripts/lib/json-response.sh` from Phase 8 plans | Standard Stack (Installation) | Package.json may not exist; Plan 10-01 may need to create it |

---

## Open Questions

1. **Notion database ID availability**
   - What we know: Phase 9 is responsible for creating the Notion decisions DB
   - What's unclear: Whether Phase 9 plans store the DB ID in Keychain under a specific key name
   - Recommendation: Plan 10-02 should document the expected env var name (`OPENCLAW_NOTION_DECISIONS_DB_ID`) and add a prerequisite check that fails fast with a clear error if absent

2. **Squash vs merge vs rebase strategy**
   - What we know: `gh pr merge` supports `--squash`, `--merge`, `--rebase`
   - What's unclear: Project preference for merge strategy (affects how `git revert -m 1` works — squash creates a single commit that is trivially revertable; merge commit requires the `-m 1` flag)
   - Recommendation: Default to `--squash` — creates a single commit per PR, simplest to revert (no `-m 1` needed for squash commits since they are not merge commits). Document this in TOOLS.md.

---

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| `gh` CLI | PR merge, CI status, PR reopen | ✓ | 2.69.0 | Upgrade to 2.92.0 per CLAUDE.md in Phase 7 |
| `git` | `git revert -m 1` | ✓ | system | — |
| `jq` | JSON parsing in scripts | ✓ | system (brew) | — |
| `node` (24) | `notion-log-decision.js` | ✓ | 24.x (nvm) | — |
| `@notionhq/client` | Notion pre-log write | install needed | 5.22.0 | — |
| `OPENCLAW_NOTION_TOKEN` | Notion auth | Phase 9 prerequisite | — | Phase 9 must store in Keychain |
| `OPENCLAW_NOTION_DECISIONS_DB_ID` | Target database for log | Phase 9 prerequisite | — | Phase 9 must store in Keychain |

---

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | zsh scripts + manual verification (no unit test framework for shell scripts) |
| Config file | none |
| Quick run command | `zsh scripts/verify-phase-10.sh` |
| Full suite command | `zsh scripts/verify-phase-10.sh` |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| DEV-05 | Notion pre-log entry created before `gh pr merge` executes | integration | `zsh scripts/verify-phase-10.sh --gate-check` | Wave 0 |
| DEV-05 | Merge blocked if Notion write fails | integration (negative test) | `zsh scripts/verify-phase-10.sh --blocked-test` | Wave 0 |
| DEV-05 | User can find merge in Notion log with mergeCommitSha | manual | query Notion DB, verify entry exists with sha | manual |
| DEV-05 | Revert workflow reopens PR and creates revert commit | integration | `zsh scripts/verify-phase-10.sh --revert-test` on test repo | Wave 0 |

### Wave 0 Gaps
- [ ] `scripts/verify-phase-10.sh` — gate check + negative test + revert test

---

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no | — |
| V3 Session Management | no | — |
| V4 Access Control | yes | SECURITY.md rule: merge gate requires Notion page ID |
| V5 Input Validation | yes | PR number and Notion page ID validated before use in shell |
| V6 Cryptography | no | — |

### Known Threat Patterns

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Merge without audit log | Repudiation | Notion pre-log required; script exits non-zero if write fails |
| Token in merge commit subject | Information Disclosure | Use only page ID (non-secret), never embed token in commit messages |
| `gh pr merge --admin` bypassing CI | Elevation of Privilege | SECURITY.md explicitly prohibits `--admin` flag |

---

## Sources

### Primary (HIGH confidence)
- `gh pr merge --help` — merge flags, `--squash`/`--merge`/`--rebase`/`--auto`/`--admin` [VERIFIED: local tool output]
- `gh pr view --help` JSON fields — `mergeCommit`, `statusCheckRollup`, `state` confirmed [VERIFIED: local tool output]
- `gh pr reopen --help` — reopen a PR by number [VERIFIED: local tool output]
- `git revert --help` — `-m <parent-number>` flag required for merge commits [VERIFIED: local tool output]
- `@notionhq/client` v5.22.0 — `npm view @notionhq/client version` returns 5.22.0 [VERIFIED: npm registry + CLAUDE.md]
- CLAUDE.md — `@notionhq/client` 5.22.0, `notionVersion: "2026-03-11"`, Keychain naming conventions [CITED: ./CLAUDE.md]

### Secondary (MEDIUM confidence)
- Phase 7 CONTEXT.md (D-75, D-76) — DevBot sessions_spawn-only pattern, json-response.sh convention [CITED: .planning/phases/07-devbot-core/07-CONTEXT.md]
- Phase 9 REQUIREMENTS.md — MEM-01 decision log schema (timestamp, decision, rationale, evidence, reversibility) [CITED: .planning/REQUIREMENTS.md]

---

## Metadata

**Confidence breakdown:**
- gh CLI commands: HIGH — verified locally on installed version
- Notion pre-log pattern: HIGH — @notionhq/client is CLAUDE.md mandated, API well-documented
- Revert flow: HIGH — git revert -m 1 is standard and verified; gh pr reopen confirmed
- Phase dependency on Phase 9: ASSUMED — DB ID availability from Phase 9 Keychain setup

**Research date:** 2026-05-21
**Valid until:** 2026-07-21 (stable APIs)

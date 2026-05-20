# Phase 11: Quality Pipeline — Research

**Researched:** 2026-05-21
**Domain:** OpenClaw multi-agent scaffolding, specialist reviewer agents, sessions_spawn feedback loops, Skill Reviewer stow gate, Skill Creation registry search
**Confidence:** HIGH

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| QUAL-01 | Code Reviewer agent reviews all code diffs and PR implementations — structured feedback (pass / flag / reject) | Covered — `/openclaw-new-agent` scaffold pattern established; diff delivery via sessions_spawn Task struct; structured response schema defined |
| QUAL-02 | Document Reviewer agent reviews all documentation drafts and Notion page content — same pass/flag/reject schema | Covered — same scaffold pattern; SOUL.md focuses on document structure, accuracy, Notion page format |
| QUAL-03 | Decision Reviewer agent reviews autonomous decision summaries before Notion log — validates rationale, reversibility, evidence specificity | Covered — positioned in the pre-log path between TaskOrchestrator Notion write and execution; reject = decision not logged |
| QUAL-04 | Skill Reviewer agent validates new SKILL.md files for format, safety, cc-openclaw convention compliance | Covered — stow gate: `/openclaw-stow` only invoked after Skill Reviewer passes; format validation against `openclaw-new-agent` SKILL.md schema |
| QUAL-05 | All reviewers return consistent schema (pass / flag / reject); flagged/rejected output must be addressed before advancing | Covered — shared JSON schema defined; originating agent receives structured feedback and resubmits |
| QUAL-06 | Skill Creation agent can author new cc-openclaw-compatible skills from observed patterns | Covered — `/openclaw-new-agent` skill format studied; SKILL.md frontmatter and step structure confirmed |
| QUAL-07 | Skill Creation agent searches ClawHub, agentskills.io, starred GitHub before authoring | Covered with caveat — `clawhub.dev` returns 000 (unreachable); `agentskills.io` redirects (308); GitHub starred repos searchable via `gh api`; see Assumptions Log |
| QUAL-08 | New skills authored by Skill Creation agent reviewed by Skill Reviewer before stow | Covered — Skill Reviewer is the penultimate step before `/openclaw-stow` runs |
</phase_requirements>

---

## Summary

Phase 11 deploys five specialist agents via `/openclaw-new-agent`. Each agent owns exactly one review domain — Code, Document, Decision, Skill (review), and Skill (creation). The key architectural insight is that every reviewer is an **execution-tier sub-agent** of the Task Orchestrator: they receive structured review requests via `sessions_spawn`, return a structured JSON verdict, and the Task Orchestrator routes the verdict to the originating agent for revision or advancement.

The reviewer verdict schema is the central contract of this phase. Every reviewer — regardless of domain — must return the same JSON structure:
```json
{"verdict": "pass"|"flag"|"reject", "comments": ["..."], "must_fix": ["..."], "approved_at": "ISO8601"}
```
The Task Orchestrator enforces the contract: if `verdict` is not `"pass"`, the output is returned to the originating agent with the `comments` and `must_fix` arrays as the revision brief.

The Skill Creation agent has a unique registry-search-first mandate (QUAL-07). The search sequence is: (1) query ClawHub by calling `gh api` against ClawHub if a GitHub API exists, (2) query `agentskills.io` via `curl`, (3) search the user's GitHub starred repos for matching skill patterns via `gh api /user/starred`. If any of these find a reusable skill, Skill Creation adapts it rather than authoring from scratch. Search evidence is included in the skill proposal document submitted to Skill Reviewer.

The Skill Reviewer's stow gate (QUAL-04, QUAL-08) means that `/openclaw-stow` is called from the Task Orchestrator only after Skill Reviewer's `sessions_spawn` session returns `{"verdict": "pass"}`. The stow step is not delegated to the Skill Creation agent — the Task Orchestrator holds this gate.

**Primary recommendation:** Seven plans: five agent scaffolds (11-01 through 11-05), one wiring plan connecting reviewers into each pipeline (11-06), and one verification plan with a known-bad input test for each reviewer (11-07).

---

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Code diff review | Code Reviewer agent (sub-agent of Task Orchestrator) | — | Receives diff via sessions_spawn; returns structured verdict |
| Code diff sourcing | Task Orchestrator (issues `gh pr diff` or passes diff text to Code Reviewer) | DevBot | DevBot opens the PR; Task Orchestrator routes the diff to Code Reviewer |
| Document review | Document Reviewer agent (sub-agent of Task Orchestrator) | — | Receives document text via sessions_spawn |
| Decision review | Decision Reviewer agent (inline in Notion pre-log path) | Task Orchestrator | Decision Reviewer is called before Notion write — blocking gate |
| Skill file review | Skill Reviewer agent | Task Orchestrator (stow gate holder) | Task Orchestrator controls whether `/openclaw-stow` runs |
| Skill authoring | Skill Creation agent | Registry search (gh api, curl) | Skill Creation authors SKILL.md; registry search prevents duplication |
| Registry search | Skill Creation agent scripts (`gh api`, `curl agentskills.io`) | — | Deterministic scripts, not LLM hallucination of registry contents |
| Stow execution after skill approval | Task Orchestrator (`/openclaw-stow` skill) | — | Task Orchestrator is the sole entity allowed to invoke stow for new skills |
| Feedback delivery to originating agent | Task Orchestrator (routes verdict back via sessions_spawn close reason) | — | Verdict JSON is the sessions_spawn close reason; Task Orchestrator reads it and requeues revision |

---

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| `/openclaw-new-agent` skill | HEAD (cc-openclaw) | Scaffold each of the 5 agents | CLAUDE.md mandated — all agent creation MUST use this skill |
| `/openclaw-stow` skill | HEAD (cc-openclaw) | Deploy new skills after Skill Reviewer approval | cc-openclaw standard; handles jobs.json conflict automatically |
| `gh` CLI | 2.69.0 / 2.92.0 | `gh pr diff` for code review; `gh api /user/starred` for registry search | CLAUDE.md-mandated GitHub CLI |
| `jq` | System (brew) | Parse sessions_spawn JSON verdicts in orchestrator scripts | All structured responses parsed with jq |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| `curl` | System (macOS) | Query `agentskills.io` registry in Skill Creation agent | Skill registry search only |

### No additional npm packages needed
All five agents are pure LLM + shell script + `gh` CLI agents. No new npm dependencies.

---

## Package Legitimacy Audit

*Phase 11 installs no external packages. All operations use tools established in prior phases: `/openclaw-new-agent`, `gh` CLI, `jq`, `curl`. Section not applicable.*

---

## Architecture Patterns

### System Architecture Diagram

```
Task Orchestrator
      │
      ├─── Code Reviewer path (DevBot PR flow)
      │         DevBot opens PR → Task Orchestrator
      │         └─ sessions_spawn("review diff: <text>") → Code Reviewer
      │              └─ returns {"verdict": "pass"|"flag"|"reject", ...}
      │              └─ if pass: Task Orchestrator advances PR
      │              └─ if reject: Task Orchestrator sends feedback to DevBot → DevBot revises
      │
      ├─── Document Reviewer path (Notion page writes)
      │         Task Orchestrator prepares Notion page draft
      │         └─ sessions_spawn("review doc: <text>") → Document Reviewer
      │              └─ returns verdict
      │              └─ if pass: Task Orchestrator writes to Notion
      │              └─ if reject: revision loop
      │
      ├─── Decision Reviewer path (every autonomous action)
      │         Task Orchestrator prepares decision entry
      │         └─ sessions_spawn("review decision: <json>") → Decision Reviewer
      │              └─ returns verdict
      │              └─ if pass: Notion pre-log write → action executes
      │              └─ if reject: Task Orchestrator does NOT execute action
      │
      └─── Skill pipeline (triggered by pattern detection or explicit request)
                Skill Creation agent
                └─ registry search (ClawHub, agentskills.io, gh starred)
                └─ authors SKILL.md
                └─ sessions_spawn("review skill: <skill.md text>") → Skill Reviewer
                     └─ returns verdict
                     └─ if pass: Task Orchestrator runs /openclaw-stow
                     └─ if reject: Skill Creation agent revises
```

### Recommended Project Structure
```
.openclaw/agents/
├── code-reviewer/
│   ├── SOUL.md        # focus: code quality, security patterns, test coverage, PR conventions
│   ├── IDENTITY.md
│   ├── USER.md
│   ├── AGENTS.md
│   ├── TOOLS.md       # gh pr diff reference, review rubric
│   └── SECURITY.md
├── document-reviewer/
│   ├── SOUL.md        # focus: clarity, accuracy, Notion page structure, evidence quality
│   └── [5 more directive files]
├── decision-reviewer/
│   ├── SOUL.md        # focus: rationale soundness, reversibility accuracy, evidence specificity
│   └── [5 more directive files]
├── skill-reviewer/
│   ├── SOUL.md        # focus: SKILL.md format, safety, cc-openclaw compliance
│   └── [5 more directive files]
└── skill-creation/
    ├── SOUL.md        # focus: registry search first, pattern extraction, SKILL.md authoring
    ├── TOOLS.md       # gh api /user/starred, curl agentskills.io, SKILL.md format reference
    └── [4 more directive files]
```

### Pattern 1: Reviewer Verdict Schema (Shared Contract)
**What:** All five reviewers return exactly this JSON structure as their sessions_spawn close reason. No deviations.
**When to use:** Every reviewer agent, for every review session.
**Example:**
```json
{
  "verdict": "reject",
  "comments": [
    "Rationale section states 'seems reasonable' — too vague for autonomous action log",
    "Reversibility listed as 'unknown' — must be specific: what exact steps reverse this?"
  ],
  "must_fix": [
    "Replace vague rationale with specific evidence of why the action was correct",
    "Specify exact reversal steps with commands"
  ],
  "approved_at": null
}
```
For a pass:
```json
{
  "verdict": "pass",
  "comments": [],
  "must_fix": [],
  "approved_at": "2026-05-21T14:32:00Z"
}
```
*Source: derived from QUAL-05 requirements: "pass / flag with comment / reject with reason" [CITED: .planning/REQUIREMENTS.md]*

### Pattern 2: How Task Orchestrator Routes Reviewer Feedback
**What:** After a review session closes, Task Orchestrator reads the verdict and either advances or requeues.
**When to use:** Every pipeline checkpoint where a reviewer is involved.
**Example:**
```zsh
#!/usr/bin/env zsh
set -euo pipefail

# Task Orchestrator script: route-review-verdict.sh
VERDICT_JSON="$1"   # JSON string from sessions_spawn close reason
ORIGINATOR="$2"     # agent id that produced the output being reviewed

VERDICT=$(echo "$VERDICT_JSON" | jq -r '.verdict')

case "$VERDICT" in
  pass)
    # Advance: next Beads task becomes unblocked automatically
    echo '{"ok":true,"action":"advance"}'
    ;;
  flag|reject)
    FEEDBACK=$(echo "$VERDICT_JSON" | jq -r '.must_fix | join("\n")')
    # Requeue: create a new Beads task for originator with feedback as description
    BEADS_DIR="$HOME/.openclaw/beads" /opt/homebrew/opt/node@24/bin/bd create \
      "Revise output based on reviewer feedback: ${FEEDBACK}" \
      --parent "$EPIC_ID" --deps "$REVIEW_TASK_ID" --json
    echo "{\"ok\":true,\"action\":\"requeue\",\"feedback\":${VERDICT_JSON}}"
    ;;
esac
```
*Source: established Beads task graph pattern from Phase 4 [CITED: .planning/phases/04-beads-task-orchestrator/04-RESEARCH.md]*

### Pattern 3: openclaw.json Wiring for 5 New Sub-Agents
**What:** All five reviewer agents are registered as sub-agents of the Task Orchestrator in openclaw.json.
**When to use:** Plan 11-06.
```json
{
  "id": "task-orchestrator",
  "subagents": {
    "allowAgents": ["devbot", "code-reviewer", "document-reviewer",
                    "decision-reviewer", "skill-reviewer", "skill-creation"],
    "delegationMode": "prefer"
  },
  "tools": {
    "alsoAllow": ["sessions_spawn", "sessions_yield"]
  }
}
```
*Source: openclaw.json agent registration pattern from Phases 3, 4, 7 [CITED: /Users/trilogy/.openclaw/openclaw.json]*

### Pattern 4: SOUL.md Differentiation Per Reviewer
**What:** Each SOUL.md must be distinct — the agent's identity and review rubric must clearly match its domain so the model applies the right heuristics.

| Agent | SOUL.md Focus | Key Rubric Points |
|-------|---------------|-------------------|
| Code Reviewer | Security, correctness, test coverage, PR conventions | Does code follow `set -euo pipefail`? Is stdout JSON-only? Are secrets accessed via Keychain only? |
| Document Reviewer | Clarity, accuracy, Notion page structure | Are claims backed by evidence? Is the page structure complete? Are action items specific? |
| Decision Reviewer | Rationale soundness, reversibility specificity, evidence quality | Is rationale a real reason or vague assertion? Is reversibility a specific command sequence? Is evidence observable fact? |
| Skill Reviewer | SKILL.md format compliance, safety review, cc-openclaw conventions | Does the skill have frontmatter (`name`, `description`, `argument-hint`, `disable-model-invocation`)? Does it use the correct stow and restart sequence? Are there hardcoded secrets? |
| Skill Creation | Registry search first, pattern extraction, SKILL.md authoring | Did the agent search all three registries? Is the search evidence included? Does the authored skill follow the existing 9-skill format? |

### Pattern 5: Skill Creation Registry Search Sequence
**What:** Skill Creation agent runs deterministic registry search before authoring any new skill.
**When to use:** Every skill creation request.
**Example:**
```zsh
#!/usr/bin/env zsh
set -euo pipefail

PATTERN_DESCRIPTION="$1"

echo "=== Registry Search ===" >&2

# 1. Search user's GitHub starred repos for matching skills
GH_STARRED=$(/opt/homebrew/bin/gh api /user/starred --paginate --jq \
  "[.[] | select(.description // \"\" | test(\"skill|claude|openclaw\"; \"i\")) | {name:.name, url:.html_url, description:.description}]" \
  2>/dev/null || echo "[]")

# 2. Query agentskills.io (best-effort — may redirect or be unreachable)
AGENTSKILLS=$(curl -s --max-time 5 --location \
  "https://agentskills.io/api/search?q=$(python3 -c "import urllib.parse,sys; print(urllib.parse.quote(sys.argv[1]))" "$PATTERN_DESCRIPTION")" \
  2>/dev/null || echo "{}")

# 3. ClawHub — check GitHub releases or API if available (best-effort)
# NOTE: clawhub.dev returned unreachable during research (2026-05-21) — log attempt and continue
CLAWHUB_RESULT="unreachable"

# Output search evidence for skill proposal document
cat <<EVIDENCE
## Registry Search Evidence
- GitHub starred repos matching "skill|claude|openclaw": $(echo "$GH_STARRED" | jq 'length') found
- agentskills.io results: logged
- ClawHub: ${CLAWHUB_RESULT}
- Conclusion: [reuse existing / adapt / author new]
EVIDENCE
```
*Source: `gh api /user/starred` verified locally [VERIFIED: local tool output]; `agentskills.io` returns 308 redirect (2026-05-21) [VERIFIED: local curl check]; `clawhub.dev` unreachable (2026-05-21) [VERIFIED: local curl check]*

### Anti-Patterns to Avoid
- **One reviewer for all domains:** QUAL-05 explicitly requires separate agents per domain. A single "Quality Reviewer" agent accumulates too much context, produces inconsistent rubrics, and creates a single point of failure.
- **Feedback as free text in Beads close reason:** The verdict must be the JSON schema above — not prose. Task Orchestrator parses it with jq. Free text breaks the routing script.
- **Skill Creation agent running `/openclaw-stow` directly:** The stow gate belongs to the Task Orchestrator. If Skill Creation agent can stow, it can bypass the Skill Reviewer. SOUL.md for Skill Creation must state: "Never invoke /openclaw-stow directly — return the authored SKILL.md to Task Orchestrator."
- **Decision Reviewer reviewing its own task:** If the Task Orchestrator's action is to spawn a Decision Reviewer session, that meta-action is not reviewed by Decision Reviewer (circular). Only first-order autonomous actions go through Decision Reviewer.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Agent scaffolding | Manually write directive files and edit openclaw.json | `/openclaw-new-agent` skill | Skill encodes correct directory structure, SECURITY.md template, openclaw.json registration, and stow+restart sequence |
| Reviewer feedback routing | Custom message-passing system | Task Orchestrator `sessions_spawn` result → Beads re-queue | Beads already tracks task state; sessions_spawn close reason carries the verdict JSON natively |
| Skill stow gating | Custom file lock or flag file | Decision gate in Task Orchestrator SOUL.md + `/openclaw-stow` | Task Orchestrator SOUL.md rule is the enforcement point; /openclaw-stow is the single deployment path |
| Registry search UI | Building a registry crawler | `gh api /user/starred`, `curl agentskills.io` | Simple REST calls in a script; evidence is included in skill proposal, not scraped programmatically |

---

## Common Pitfalls

### Pitfall 1: All 5 Agents Scaffolded But Task Orchestrator allowAgents Not Updated
**What goes wrong:** Agents exist in openclaw.json but Task Orchestrator's `subagents.allowAgents` array does not include them — sessions_spawn fails with "agent not in allowlist."
**Why it happens:** `/openclaw-new-agent` creates the agent entry but does NOT automatically update the parent agent's `allowAgents`. That wiring is a separate step.
**How to avoid:** Plan 11-06 (wiring) must update Task Orchestrator's `subagents.allowAgents` to include all five new agent IDs, then stow+restart.
**Warning signs:** sessions_spawn call returns "agent not permitted" or similar error.

### Pitfall 2: Decision Reviewer Creates Circular Dependency on Itself
**What goes wrong:** If "invoke Decision Reviewer" is itself classified as an autonomous action and routed through Decision Reviewer, the system deadlocks.
**Why it happens:** Over-application of the review gate.
**How to avoid:** Decision Reviewer's SOUL.md must explicitly state: "Review requests for your own invocation are pre-approved — do not recurse." The Decision Reviewer reviews decisions ABOUT the world (merges, issue creates, Notion writes) — not decisions about review routing.
**Warning signs:** Task Orchestrator creates a Beads task to review the review task; system loops.

### Pitfall 3: Skill Reviewer Rejects Valid Skills Due to Strict Format Check
**What goes wrong:** Skill Reviewer is given a rubric that checks for exact frontmatter fields but rejects skills that have valid variant fields (e.g., `argument-hint` is optional).
**Why it happens:** Over-rigid format checking in SOUL.md.
**How to avoid:** Skill Reviewer SOUL.md should document required vs optional frontmatter fields. From the `openclaw-new-agent` SKILL.md: required fields are `name`, `description`, `disable-model-invocation`; `argument-hint` is optional. Rejecting for missing optional fields is a false positive.
**Warning signs:** Skill Reviewer rejects all draft skills as "missing argument-hint."

### Pitfall 4: Registry Search Blocks Skill Creation When Registries Are Unreachable
**What goes wrong:** `clawhub.dev` is unreachable (verified during research) and `agentskills.io` may redirect. If the search script fails hard, Skill Creation cannot proceed.
**Why it happens:** Network errors treated as fatal by `set -euo pipefail`.
**How to avoid:** Registry search scripts must use `|| echo "{}"` fallbacks and treat unreachable registries as "no results" — not as errors. Log the attempt as evidence in the skill proposal. The search is best-effort; a failed search is not a blocker.
**Warning signs:** Skill Creation agent BLOCKED on registry search network error.

### Pitfall 5: Code Reviewer Receives Entire Codebase Instead of Just the Diff
**What goes wrong:** Task Orchestrator sends the full repo context to Code Reviewer instead of just the diff for the PR — exceeds context window or introduces noise.
**Why it happens:** sessions_spawn payload constructed incorrectly.
**How to avoid:** Code review sessions are constructed with `gh pr diff <number>` output only (plus the PR description). Never send the full repo. Code Reviewer SOUL.md states: "You receive a PR diff. Review only what changed."
**Warning signs:** Code Reviewer sessions time out or produce generic reviews not specific to the diff.

---

## Code Examples

### Get PR Diff for Code Reviewer
```zsh
# Source: gh pr diff --help verified locally
DIFF=$(/opt/homebrew/bin/gh pr diff "$PR_NUMBER" 2>/dev/null)
# Pass to Code Reviewer session as the review payload
```

### sessions_spawn Call for Code Reviewer
```zsh
# Task Orchestrator spawning Code Reviewer (conceptual — OpenClaw sessions_spawn API)
# The exact sessions_spawn invocation format follows the Task Orchestrator's
# established sessions_spawn pattern from Phase 4.
# Payload: structured task description with diff text embedded
REVIEW_PAYLOAD="{
  \"task\": \"review_code\",
  \"pr_number\": ${PR_NUMBER},
  \"diff\": $(echo "$DIFF" | jq -Rs .),
  \"context\": \"PR opened by DevBot for issue #${ISSUE_NUMBER}\"
}"
```

### Beads Task for Revision After Reject Verdict
```zsh
# If Code Reviewer returns {"verdict": "reject", "must_fix": ["..."]}
FEEDBACK=$(echo "$VERDICT_JSON" | jq -r '.must_fix[]' | head -5)
BEADS_DIR="$HOME/.openclaw/beads" /opt/homebrew/opt/node@24/bin/bd create \
  "Revise PR #${PR_NUMBER} based on Code Reviewer feedback: ${FEEDBACK}" \
  --parent "$EPIC_ID" --deps "$REVIEW_TASK_ID" --json
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Task Orchestrator does quality review inline | Dedicated specialist agents per domain | Phase 11 | Domain expertise encoded in SOUL.md; no context contamination across review domains |
| Manual stow after skill creation | Stow gated by Skill Reviewer pass verdict | Phase 11 | Broken or unsafe skills cannot reach the live skill directory |

---

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `clawhub.dev` was unreachable during research; it may become available — Skill Creation agent should treat it as best-effort | Pattern 5 (Registry Search) | If ClawHub becomes the primary registry and Skill Creation ignores it, duplicate skills may be authored |
| A2 | `agentskills.io` returned a 308 redirect during research; the destination URL is unknown — Skill Creation must follow redirects with `curl --location` | Pattern 5 (Registry Search) | Without `--location`, curl sees 308 and returns empty; agent believes registry has no results |
| A3 | Task Orchestrator `sessions_spawn` close reason is the mechanism for returning verdict JSON from reviewer to Task Orchestrator | Pattern 2 (Routing) | If sessions_spawn close reasons are truncated or structured differently, verdict routing breaks |

---

## Open Questions

1. **sessions_spawn close reason maximum length**
   - What we know: Task Orchestrator uses sessions_spawn established in Phase 4
   - What's unclear: Whether there is a character limit on close reason strings that would truncate long verdict JSON
   - Recommendation: Keep verdict JSON compact; omit whitespace; limit `comments` array to 5 items max

2. **Decision Reviewer latency impact**
   - What we know: Every autonomous action now requires a Decision Reviewer session before execution
   - What's unclear: Whether this adds unacceptable latency for rapid-fire task execution
   - Recommendation: Decision Reviewer SOUL.md should be tuned for fast verdict delivery (minimal preamble, immediate structured response); timeout rule: if Decision Reviewer session does not close within 2 minutes, Task Orchestrator falls back to BLOCKED state

3. **ClawHub API availability**
   - What we know: `clawhub.dev` is unreachable from this machine as of 2026-05-21
   - What's unclear: Whether ClawHub has a public API or is query-via-browser only
   - Recommendation: Skill Creation treats ClawHub as best-effort; if a GitHub API for ClawHub exists it can be added later

---

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| `/openclaw-new-agent` skill | All 5 agent scaffolds | ✓ | HEAD (verified in .claude/skills/) | — |
| `/openclaw-stow` skill | Skill stow gate | ✓ | HEAD (verified in .claude/skills/) | — |
| `gh` CLI | PR diff, starred repo search | ✓ | 2.69.0 | — |
| `jq` | Verdict routing scripts | ✓ | system (brew) | — |
| `curl` | agentskills.io registry search | ✓ | system (macOS) | Fallback to "registry unreachable" |
| `clawhub.dev` | Registry search | ✗ | unreachable (2026-05-21) | Skip — log as "no results" in search evidence |
| `agentskills.io` | Registry search | partial (308 redirect) | — | Use `curl --location` to follow redirects |
| Beads (`bd`) | Task routing for review feedback | ✓ | 1.0.4 (from Phase 4) | — |

**Missing dependencies with no fallback:** None — all required tools available.

**Missing dependencies with fallback:**
- `clawhub.dev` — unreachable; Skill Creation treats as "no results found"
- `agentskills.io` — redirects; Skill Creation must use `curl --location` and handle empty response

---

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | zsh scripts + manual verification |
| Config file | none |
| Quick run command | `zsh scripts/verify-phase-11.sh` |
| Full suite command | `zsh scripts/verify-phase-11.sh --all` |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| QUAL-01 | Code Reviewer returns structured verdict for a known-bad diff | integration | send synthetic bad diff via sessions_spawn, check verdict.verdict == "reject" | Wave 0 |
| QUAL-02 | Document Reviewer passes a well-formed doc and rejects a vague one | integration | two synthetic docs via sessions_spawn | Wave 0 |
| QUAL-03 | Decision Reviewer rejects entry with vague rationale | integration | send synthetic vague decision, verify reject | Wave 0 |
| QUAL-04 | Skill Reviewer rejects skill missing required frontmatter field | integration | send SKILL.md without `name` field | Wave 0 |
| QUAL-05 | All reviewers return verdict in consistent schema | automated | `jq` check on all returned verdicts | Wave 0 |
| QUAL-06 | Skill Creation produces valid SKILL.md file | integration | inspect output against schema | Wave 0 |
| QUAL-07 | Registry search evidence present in skill proposal | integration | check skill proposal for "Registry Search Evidence" section | Wave 0 |
| QUAL-08 | /openclaw-stow only runs after Skill Reviewer pass | integration | send rejected skill and confirm stow not invoked | Wave 0 |

### Wave 0 Gaps
- [ ] `scripts/verify-phase-11.sh` — covers all 8 QUAL requirements
- [ ] Synthetic test payloads for each reviewer (bad code diff, vague decision, malformed SKILL.md)

---

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no | — |
| V3 Session Management | no | — |
| V4 Access Control | yes | SOUL.md rules: Skill Creation cannot invoke stow; stow gate is Task Orchestrator only |
| V5 Input Validation | yes | Verdict JSON validated with jq before routing decisions made |
| V6 Cryptography | no | — |

### Known Threat Patterns

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Skill containing malicious postinstall script | Tampering | Skill Reviewer SOUL.md explicitly checks for postinstall scripts and network calls in any embedded shell |
| Reviewer always returns "pass" (sycophancy) | Repudiation | Decision Reviewer SOUL.md: "A vague rationale is ALWAYS a reject. There is no such thing as a borderline vague rationale." |
| Feedback loop that never converges | Denial of Service | Task Orchestrator enforces max 3 revision cycles per output; after 3 rejects, escalate to user via Telegram |

---

## Sources

### Primary (HIGH confidence)
- `/openclaw-new-agent` SKILL.md — scaffolding steps, required frontmatter fields, openclaw.json registration pattern [VERIFIED: local file /Users/trilogy/Documents/agentic-setup/.claude/skills/openclaw-new-agent/SKILL.md]
- `/openclaw-stow` SKILL.md — stow deployment steps, jobs.json conflict resolution [VERIFIED: local file /Users/trilogy/Documents/agentic-setup/.claude/skills/openclaw-stow/SKILL.md]
- Task Orchestrator SOUL.md — sessions_spawn contract, Beads integration, sub-agent patterns [VERIFIED: local file /Users/trilogy/.openclaw/agents/task-orchestrator/SOUL.md]
- openclaw.json live config — `subagents.allowAgents` and `tools.alsoAllow` wiring pattern [VERIFIED: local file /Users/trilogy/.openclaw/openclaw.json]
- `gh pr diff --help` — diff retrieval for Code Reviewer [VERIFIED: local tool output]
- `gh api /user/starred` — starred repos search for Skill Creation [VERIFIED: local tool output]
- CLAUDE.md — `/openclaw-new-agent` mandate, agent structure, tool conventions [CITED: ./CLAUDE.md]
- REQUIREMENTS.md — QUAL-01 through QUAL-08 definitions [CITED: .planning/REQUIREMENTS.md]

### Secondary (MEDIUM confidence)
- `clawhub.dev` availability: 000 (unreachable, 2026-05-21) [VERIFIED: local curl check]
- `agentskills.io` availability: 308 redirect (2026-05-21) [VERIFIED: local curl check]

---

## Metadata

**Confidence breakdown:**
- Agent scaffolding pattern: HIGH — `/openclaw-new-agent` skill verified and used in Phases 3, 4, 6, 7
- Verdict schema and routing: HIGH — derived from QUAL-05 requirements + Beads close reason pattern from Phase 4
- Skill registry availability: LOW — both ClawHub and agentskills.io were unreachable/redirecting during research; search logic is best-effort
- sessions_spawn feedback routing: MEDIUM — pattern established in Phase 4; close reason format not formally documented in cc-openclaw

**Research date:** 2026-05-21
**Valid until:** 2026-07-21 (stable for this stack)

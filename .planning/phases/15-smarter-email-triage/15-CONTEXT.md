# Phase 15: Smarter Email Triage — Context

**Gathered:** 2026-05-21
**Status:** Ready for planning

<domain>
## Phase Boundary

Add priority scoring (1–5), noise suppression with a 20% Action Required cap, separate draft file management, and idempotent processing to the existing email-triage agent. No new agents, no new cron jobs. All changes are to the email-triage agent's SOUL.md, AGENTS.md, TOOLS.md, and a new `memory/drafts/` directory.

</domain>

<decisions>
## Implementation Decisions

### Priority Scoring (TRIAGE-01)

- **D-151:** Priority scoring is a SOUL.md prompt addition — NOT an npm library. The agent already runs an LLM categorization pass; adding a 1–5 score alongside the category costs zero new infrastructure.
- **D-152:** Score signals in descending weight: (1) sender on VIP list, (2) urgency keywords in subject (urgent, ASAP, P0, deadline today, critical), (3) email is a direct reply-to-user (not automated), (4) thread depth > 2 (escalating conversation), (5) contains a question directed at Anuj.
- **D-153:** Score mapping: 5 = urgent + VIP or P0 incident; 4 = Action Required with deadline signal; 3 = Action Required, no deadline; 2 = FYI or informational; 1 = Automated-Noise, Newsletter, or known-noise sender.
- **D-154:** Score is logged in `memory/triage-YYYY-MM-DD.md` alongside category, sender, subject, and summary. Format: `| priority | category | sender | subject | summary |` table row.

### Noise Suppression + Action Required Cap (TRIAGE-02)

- **D-155:** Known-noise sender list lives in `memory/noise-senders.md` — editable without stow redeploy. Format: one email address or domain per line. Agent reads this file at startup (AGENTS.md startup checklist step).
- **D-156:** 20% Action Required cap enforced in SOUL.md as a post-categorization rule: "After categorizing all emails in a run, if Action Required count exceeds 20% of total emails, demote the lowest-priority Action Required items (lowest `priority_score`) to FYI until the ratio is at or below 20%."
- **D-157:** Pct_action_required is logged in each triage memory file as a summary metric: `pct_action_required: N%`. Enables trend tracking.

### Draft Reply Management (TRIAGE-03)

- **D-158:** Drafts live at `memory/drafts/YYYY-MM-DD-<messageId>.md` — one file per Action Required email. File contains: To, Subject, Body suggestion, and a `[DRAFT — NOT SENT]` header on line 1.
- **D-159:** The triage summary in `memory/triage-YYYY-MM-DD.md` includes a `drafts:` list pointing to the filenames — human navigable without scanning the drafts/ directory.
- **D-160:** SOUL.md rule: "Never call `gog gmail send` from the triage flow. Sending is always user-initiated. The draft file is the only output of reply generation."

### Idempotent Processing (TRIAGE-04)

- **D-161:** Primary idempotency mechanism: `gog gmail mark-read` after triage completes. Since the triage search is `is:unread newer_than:1d`, already-processed messages are naturally excluded from the next run.
- **D-162:** Secondary guard: processed message IDs logged to `memory/processed-ids.jsonl` (one JSON object per line: `{"id":"<messageId>","processedAt":"<ISO timestamp>"}`). Agent checks this file at startup and skips any message ID already present — protects against a failed `mark-read` on the previous run.
- **D-163:** `processed-ids.jsonl` is trimmed to last 500 entries during each triage run to prevent unbounded growth.

### Claude's Discretion

- Whether to add a `gog auth doctor --check` call at top of email-triage.sh (recommended — fail fast per existing pattern from D-148)
- Order of startup checklist additions in AGENTS.md (after gogcli auth check, before memory reads)
- `memory/noise-senders.md` initial content — seed with common patterns (noreply@, github.com CI notifications, etc.) based on existing triage logs

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Email Triage Agent (current state)
- `.openclaw/agents/email-triage/SOUL.md` — current categorization logic, prompt injection guardrail, escalation protocol
- `.openclaw/agents/email-triage/AGENTS.md` — startup checklist, execution flow, memory structure
- `.openclaw/agents/email-triage/TOOLS.md` — gogcli command reference, Keychain key reference, Synapse loop

### Phase decisions that constrain this phase
- `.planning/phases/14-gogcli-google-suite-cli-install-gogcli-wire-gog-gmail-and-go/14-CONTEXT.md` — D-142 (--no-input --non-interactive mandatory), D-146 (gog gmail JSON envelope), D-148 (gmail-triage.js stays until verified)

### Requirements
- `.planning/REQUIREMENTS.md` §TRIAGE — TRIAGE-01, TRIAGE-02, TRIAGE-03, TRIAGE-04

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `scripts/email-triage.sh` — primary gogcli invocation script (Phase 14); outputs `{"ok":true,"data":{"threads":[...],"count":N}}`
- `scripts/lib/json-response.sh` — shared json_ok / json_err functions; use in any new scripts
- `memory/triage-YYYY-MM-DD.md` — existing log format; Phase 15 extends it with priority score column and drafts list

### Established Patterns
- All SOUL.md rules are enforced in the LLM categorization pass — priority scoring follows the same pattern
- Agent startup reads memory files before acting (AGENTS.md step 3); `noise-senders.md` and `processed-ids.jsonl` follow this pattern
- `gog gmail mark-read --query` pattern is already documented in TOOLS.md

### Integration Points
- SOUL.md: add priority scoring rules after existing categorization rules; add 20% cap rule after scoring
- AGENTS.md startup checklist: add noise-senders.md read step and processed-ids.jsonl check step
- TOOLS.md: add `memory/drafts/` directory reference and `processed-ids.jsonl` trim command
- `email-triage.sh` or inline agent logic: add `gog gmail mark-read` call after triage completes

</code_context>

<specifics>
## Specific Ideas

- `[DRAFT — NOT SENT]` must be line 1 of every draft file — unambiguous signal that stops accidental sends
- `noise-senders.md` should be seeded with common noise patterns from existing triage logs (noreply@, github.com automated notifications)
- `processed-ids.jsonl` max 500 entries — trim oldest when exceeded (matches the 7-day memory retention window)

</specifics>

<deferred>
## Deferred Ideas

- Deleting `gmail-triage.js` — already deferred in D-148; revisit after Phase 15 verification
- Auto-sending drafts via User Orchestrator approval flow — out of scope for Phase 15; belongs in a future Autonomous Replies phase
- Sender reputation scoring from 30-day aggregation (research differentiator) — defer; requires 30 days of Phase 15 triage logs to be useful
- Thread awareness via `gog gmail get` for full context — defer; Phase 15 uses subject + sender signals only

</deferred>

---

*Phase: 15-Smarter Email Triage*
*Context gathered: 2026-05-21*

# Discussion Log — Phase 15: Smarter Email Triage

**Date:** 2026-05-21
**Mode:** Auto (user AFK — Claude made all decisions)

## Areas Discussed

### Priority Scoring
- **Question:** Should scoring use npm libraries (natural/sentiment) or SOUL.md rules?
- **Selected:** SOUL.md prompt addition — zero new infrastructure, consistent with existing LLM categorization pass
- **Rationale:** Agent already runs LLM pass for categorization; adding score is a prompt change not a pipeline change

### Noise Suppression
- **Question:** Where should the known-noise sender list live? SOUL.md (hardcoded) vs config file?
- **Selected:** `memory/noise-senders.md` — editable without stow redeploy
- **Rationale:** Noise patterns change over time; file-based config lets user update without redeploy

### Draft File Management
- **Question:** Where should draft replies live? Inline in triage log vs separate files?
- **Selected:** `memory/drafts/YYYY-MM-DD-<messageId>.md` per draft
- **Rationale:** Separate files make drafts navigable and make "never auto-sent" guarantee structurally enforced

### Idempotency Mechanism
- **Question:** How to ensure same email is never processed twice?
- **Selected:** Primary = `gog gmail mark-read` after triage; Secondary = `memory/processed-ids.jsonl` guard
- **Rationale:** Mark-as-read is the natural gogcli pattern; jsonl guard covers edge case of failed mark-read

## Claude's Discretion Items

- `gog auth doctor --check` at top of email-triage.sh (recommended)
- Startup checklist order in AGENTS.md
- Initial seed content for `memory/noise-senders.md`

## Deferred Ideas

- Deleting `gmail-triage.js` — blocked on D-148 verification
- Auto-sending drafts via approval flow — future Autonomous Replies phase
- Sender reputation scoring — needs 30 days of data
- Thread awareness via full message fetch — Phase 15 uses subject + sender only

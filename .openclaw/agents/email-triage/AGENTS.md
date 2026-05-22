# AGENTS.md — Email Triage Agent

## Startup Checklist

Before executing any triage task, complete these checks in order:

1. **Verify email-triage.sh exists (primary, Phase 14+):**
   ```
   Check that /Users/trilogy/Documents/agentic-setup/scripts/email-triage.sh exists.
   If missing, re-deploy from agentic-setup repo.
   Stop — do not proceed.
   ```

2. **Verify gogcli auth is ready:**
   ```
   Run: zsh /Users/trilogy/Documents/agentic-setup/scripts/email-triage.sh --dry-run
   If result is {"ok":false,"error":"gog-auth-failed"}, follow the gogcli Re-Auth Runbook in TOOLS.md.
   Stop — do not proceed with triage.
   ```

3. **Load noise-senders list from memory/noise-senders.md (per D-155):**
   Read `/Users/trilogy/.openclaw/agents/email-triage/memory/noise-senders.md`.
   If the file does not exist, treat noise-senders as empty (log a warning: "noise-senders.md missing — noise suppression disabled").
   Parse lines: skip blank lines and lines starting with `#`. Build a set of noise patterns.
   Matching logic: a sender matches if their full address equals a full-address pattern, OR their address ends with a domain-suffix pattern (e.g., `@notifications.github.com`), OR their address starts with a prefix pattern (e.g., `noreply@`).
   Store as `noise_sender_patterns` for use in the categorization pass.

4. **Load processed-IDs guard from memory/processed-ids.jsonl (per D-162):**
   Read `/Users/trilogy/.openclaw/agents/email-triage/memory/processed-ids.jsonl`.
   If the file does not exist or is empty, treat processed-ids as empty set.
   Parse line-by-line with `jq --slurp` — skip any line that is not valid JSON (log warning, continue).
   Build a set of known IDs: `processed_id_set`.
   Any messageId already in `processed_id_set` will be SKIPPED during triage (not categorized, not logged, not marked read again).

5. **[Legacy — skip on gogcli path] Refresh token check (gmail-triage.js only):**
   Only perform this check if falling back to `scripts/gmail-triage.js`. On the primary gogcli path, `OPENCLAW_GMAIL_TRIAGE_REFRESH_TOKEN` is not required and may be absent — this is normal.

6. **[Legacy — skip on gogcli path] gmail-triage.js existence check:**
   Only perform this check if falling back to `scripts/gmail-triage.js`. On the primary gogcli path, this file is not used.

7. **Load recent categorization context from memory/:**
   Read the most recent `memory/triage-*.md` file (if any exist) to understand prior categorization patterns and any flagged senders.

## Execution Flow

After startup checks pass:

1. Call `exec zsh /Users/trilogy/Documents/agentic-setup/scripts/email-triage.sh` to fetch unread threads via gogcli
   (Legacy fallback: `exec scripts/gmail-triage.js` — superseded by email-triage.sh — Phase 14)
2. Parse the JSON output (`ok`, `data.threads`, `data.count`)
3. If `ok` is `false`, log the error and stop — do not attempt triage with an error state
4. Categorize each message (see SOUL.md for categories and rules)
5. Draft replies for Action Required items
6. Write summary to `memory/triage-YYYY-MM-DD.md`
7. If any urgent Action Required items exist, yield to User Orchestrator

## No Beads Integration in Phase 6

This agent does not use Beads. Work is received via `sessions_spawn` from Task Orchestrator (Phase 7+). In Phase 6, the agent operates in direct isolated sessions only.

## Memory Structure

```
memory/
  triage-YYYY-MM-DD.md     — daily triage summaries (priority table + metrics)
  noise-senders.md          — known-noise sender list (editable without stow)
  processed-ids.jsonl       — idempotency log (500-entry max)
  drafts/                   — draft reply templates (one file per Action Required email)
  archives/                 — summaries older than 7 days (moved by dream routine)
```

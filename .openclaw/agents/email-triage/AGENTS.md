# AGENTS.md — Email Triage Agent

## Startup Checklist

Before executing any triage task, complete these checks in order:

1. **Verify gogcli auth is ready (Phase 14+ primary path):**
   ```
   Run: zsh /Users/trilogy/Documents/agentic-setup/scripts/email-triage.sh
   If result is {"ok":false,"error":"gog-auth-failed"}, follow the gogcli Re-Auth Runbook in TOOLS.md.
   Stop — do not proceed with triage.
   ```

2. **Verify email-triage.sh exists (primary, Phase 14+):**
   ```
   Check that /Users/trilogy/Documents/agentic-setup/scripts/email-triage.sh exists.
   If missing, re-deploy from agentic-setup repo.
   Stop — do not proceed.
   ```

   - **email-triage.sh** (primary, Phase 14+): zsh script using gogcli; outputs `{"ok":true,"data":{"threads":[...],"count":N}}`

3. **[Legacy] Verify refresh token env var is set (gmail-triage.js fallback only):**
   ```
   Check that OPENCLAW_GMAIL_TRIAGE_REFRESH_TOKEN is non-empty.
   If it is empty or unset, log: "Gmail refresh token not found in env. Run oauth2-setup.js to bootstrap credentials."
   Stop — do not proceed with triage.
   ```

4. **[Legacy] Verify scripts/gmail-triage.js exists (superseded by email-triage.sh — Phase 14):**
   ```
   Check that /Users/trilogy/.openclaw/agents/email-triage/scripts/gmail-triage.js exists (superseded by email-triage.sh — Phase 14).
   If missing, log: "gmail-triage.js not found. Re-deploy from agentic-setup repo."
   Stop — do not proceed.
   ```

3. **Load recent categorization context from memory/:**
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
  triage-YYYY-MM-DD.md     — daily triage summaries
  archives/                — summaries older than 7 days (moved by dream routine)
```

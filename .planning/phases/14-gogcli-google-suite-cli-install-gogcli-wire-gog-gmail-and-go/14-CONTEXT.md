# Phase 14: gogcli Google Suite CLI — Context

**Session:** 2026-05-21
**Status:** Decisions locked — proceed to planning

---

## Decisions

**D-140:** gogcli CANNOT reuse `openclaw.gmail-triage-refresh-token` from Keychain. It manages its own Keychain entries under the format `token:default:<email>`. A new, separate `gog auth add` OAuth2 flow is required. The existing Google Cloud project (that issued the current refresh token) CAN be reused — download a new Desktop OAuth client JSON from the same project.

**D-141:** One-time interactive `gog auth add echo.sys.bot@gmail.com --services gmail,calendar` is required in a browser-capable shell session. This step cannot be automated. A `checkpoint:human-action` task is mandatory in Plan 14-01.

**D-142:** ALL `gog` invocations in agent scripts and launchd subprocesses MUST include `--no-input --non-interactive`. Without these flags, gogcli can hang indefinitely waiting for TTY input.

**D-143:** Use explicit binary path via `$(command -v gog)` evaluated at script authoring time and hardcoded as `/opt/homebrew/bin/gog`. This is consistent with existing scripts (e.g., `GH=/opt/homebrew/bin/gh` in standup-brief.sh). Handles Apple Silicon default; Intel path `/usr/local/bin/gog` is documented as a variation note, not a runtime branch.

**D-144:** OAuth consent screen MUST be published to "In production" status (Google Cloud Console → APIs & Services → OAuth consent screen → Publish App) immediately after `gog auth add` succeeds. Failure to do this causes tokens to expire after 7 days. This is a documented TODO in TOOLS.md, not an automated step.

**D-145:** Google Calendar API must be enabled in Cloud Console before `gog auth add --services gmail,calendar` is run. This is a prerequisite documented in the checkpoint task for Plan 14-01.

**D-146:** JSON output flags differ by subcommand:
- `gog gmail` commands: `--json` (returns envelope `{ "results": [...] }` — extract with `jq '.results // []'`)
- `gog calendar events`: `--json --results-only` (returns bare array `[...]` — use directly)

**D-147:** `OPENCLAW_GMAIL_ACCOUNT=echo.sys.bot@gmail.com` is NOT a secret — add to `openclaw-env.sh` only (not `openclaw-secrets.sh` or `secrets.sh`). This is a plain config value used as the default account for all gog invocations.

**D-148:** Keep `gmail-triage.js` in place after `email-triage.sh` is created. Do NOT delete it until the shell replacement is verified end-to-end in the OpenClaw agent context. TOOLS.md update marks it as superseded, not removed.

**D-149:** `$HOME/.config/gogcli/credentials.json` (the Desktop OAuth client secret) MUST NOT be Stow-managed and MUST NOT appear in git. The `gog auth credentials` command copies it to the correct location. Add `**/.config/gogcli/` to `.gitignore` as a safety guard.

**D-150:** GOG_KEYRING_BACKEND=auto (gogcli default) works correctly in launchd user agents on macOS — they share the user's Keychain session. No additional environment configuration is needed for launchd compatibility.

---

## Deferred Ideas

- Deleting `gmail-triage.js` and removing `googleapis` npm dependencies — deferred until Phase 14 verification is confirmed working in production (per D-148)
- WhatsApp integration — deferred from Phase 2 (D-20), not in scope for Phase 14
- `gog drive` integration — not planned; out of scope for this phase
- Intel Mac path branching (`/usr/local/bin/gog`) — document-only; no runtime branch needed for this project (Apple Silicon confirmed)

---

## Claude's Discretion

- Order of GOG_AVAILABLE guard implementation in standup-brief.sh (check `[[ -x "$GOG" ]]` pattern matching existing GH/JQ guards)
- Whether to add `gog auth doctor --check` call at top of email-triage.sh (recommended — fail fast with actionable message per RESEARCH.md skeleton)
- Section placement for gog calendar block in standup-brief.sh output JSON (add as `calendar_events` key alongside existing fields)

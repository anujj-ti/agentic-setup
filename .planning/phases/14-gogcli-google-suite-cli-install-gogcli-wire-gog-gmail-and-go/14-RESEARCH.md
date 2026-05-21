# Phase 14: gogcli Google Suite CLI — Research

**Researched:** 2026-05-21
**Domain:** gogcli (Go-based Google Workspace CLI), Gmail/Calendar shell integration, macOS Keychain auth wiring
**Confidence:** HIGH — all findings verified against official gogcli GitHub source (`github.com/openclaw/gogcli`) and Homebrew core formula

---

## Summary

gogcli (`gog`) is a real, production-grade Go CLI for Gmail, Calendar, Drive, and the wider Google Workspace surface. It is in Homebrew core (not a tap), version 0.17.0, MIT licensed, with ~4,000 installs/month — a genuine, well-adopted tool. The tool was purpose-built for "terminals, shell scripts, CI, and coding agents," which maps directly to this project's needs. It outputs stable JSON on stdout and routes all human progress/warnings to stderr, matching the project's `json-response` pattern exactly.

**The single most important finding for planning:** gogcli manages its own OAuth2 flow and stores refresh tokens in its own macOS Keychain entries (key format: `token:default:<email>`). It **cannot import** the existing `openclaw.gmail-triage-refresh-token` from Keychain. A new, separate OAuth2 authorization flow is required. This is a one-time interactive step that requires: (1) a Google Cloud Project with a Desktop OAuth client, and (2) running `gog auth add echo.sys.bot@gmail.com --services gmail,calendar` in a browser-capable session. After that, all subsequent invocations are fully non-interactive.

**The second important finding:** gogcli requires its own OAuth client credentials (a `client_secret_*.json` from Google Cloud Console). If the existing Cloud project that issued `openclaw.gmail-triage-refresh-token` is still accessible, the same project can be used — download the Desktop OAuth client JSON, store it with `gog auth credentials`, then authorize. No new Google Cloud project is strictly required if the existing one has Gmail + Calendar APIs enabled.

**Primary recommendation:** Install via `brew install gogcli`, wire a one-time `gog auth add` session, store the GOG client secret JSON in `$HOME/.config/gogcli/credentials.json` (gogcli's default location, not in git), then replace `gmail-triage.js` with a `email-triage.sh` shell script using `gog gmail search` and `gog gmail get`.

---

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|---|---|---|---|
| Gmail read (search + fetch) | Shell script (email-triage.sh) | email-triage OpenClaw agent | gog CLI replaces the Node.js googleapis layer entirely |
| Gmail send (replies) | Shell script (email-triage.sh) | email-triage OpenClaw agent | `gog gmail send` with `--to/--subject/--body` flags |
| Gmail mark-as-read | Shell script (email-triage.sh) | — | `gog gmail mark-read` by message ID or `--query` |
| Calendar events (standup) | Shell script (standup-brief.sh) | User Orchestrator agent | `gog calendar events --today --json` added to existing script |
| gogcli authentication | macOS Keychain (gog's own entries) | — | gog writes `token:default:<email>` to Keychain on `gog auth add` |
| OAuth client credentials | `$HOME/.config/gogcli/credentials.json` | — | File stored outside git, mode 0600, not Stow-managed |

---

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---|---|---|---|
| gogcli | 0.17.0 (Homebrew stable) | Google Workspace CLI — Gmail, Calendar, Drive | Purpose-built for scripts and agents; stable JSON output; Homebrew core; MIT |

### Supporting
| Tool | Version | Purpose | When to Use |
|---|---|---|---|
| `jq` | Already installed (project dep) | Parse gogcli `--json` output in shell scripts | Every `gog` invocation that feeds data to downstream logic |
| macOS Keychain (`security` CLI) | Built-in | Read GOG_KEYRING_PASSWORD if file keyring is used for launchd | When OpenClaw gateway runs gogcli as a subprocess without login shell |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|---|---|---|
| gogcli | googleapis npm ^13.x (existing) | googleapis requires Node.js runtime, OAuth2 token refresh management in code, and ~250 lines of JS boilerplate. gogcli is a single binary with built-in token refresh. |
| gogcli | raw `curl` + Gmail REST API | Same maintenance burden as googleapis — manual token refresh, JSON construction, error handling. |

**Installation:**
```bash
brew install gogcli
gog --version   # should print 0.17.0
```

---

## Package Legitimacy Audit

gogcli is a binary CLI distributed via Homebrew, not an npm or PyPI package. Standard slopcheck (npm/PyPI focused) does not apply. Legitimacy verified via Homebrew core formula and GitHub source.

| Package | Registry | Source | Downloads | Homebrew tap | Disposition |
|---|---|---|---|---|---|
| gogcli | Homebrew core | github.com/openclaw/gogcli | ~4,097/30d installs | homebrew/core (not a 3rd-party tap) | Approved |

**slopcheck verdict:** N/A — gogcli is a compiled binary distributed via Homebrew core, not an npm/PyPI registry package. Homebrew core inclusion is a strong legitimacy signal (requires PR review by Homebrew maintainers). `[VERIFIED: brew info gogcli, Homebrew formula]`

---

## Architecture Patterns

### System Architecture Diagram

```
standup-brief.sh
  ├── gh CLI  ──────────────────────► GitHub API (existing)
  └── gog calendar events --today  ► Google Calendar API
        │
        └─ JSON on stdout ──► jq → calendar_events field

email-triage.sh (new — replaces gmail-triage.js)
  ├── gog gmail search 'is:unread newer_than:1d' --json
  │     └─ stdout: JSON envelope { results: [...threads] }
  ├── gog gmail get <messageId> --sanitize-content --json
  │     └─ stdout: JSON message body
  ├── gog gmail mark-read --query 'is:unread label:processed'
  └── gog gmail send --to X --subject Y --body Z

gog auth layer (one-time setup, macOS)
  gog auth credentials ~/client_secret.json
  gog auth add echo.sys.bot@gmail.com --services gmail,calendar
        └─ browser OAuth2 flow ──► refresh token ──► macOS Keychain
                                     key: token:default:echo.sys.bot@gmail.com

OpenClaw gateway (launchd subprocess)
  └── Must have GOG_KEYRING_BACKEND=auto (default) in environment
      └── macOS Keychain accessible via launchd user agent ✓
```

### Recommended Project Structure
```
scripts/
├── email-triage.sh          # new — replaces email-triage/scripts/gmail-triage.js
├── standup-brief.sh         # updated — add gog calendar events block
└── lib/
    └── json-response.sh     # existing shared lib (unchanged)

~/.openclaw/agents/email-triage/
├── TOOLS.md                 # updated — document gog gmail commands
└── scripts/
    ├── gmail-triage.js      # kept but superseded (do not delete until verified)
    └── email-triage.sh      # new symlink target via stow
```

### Pattern 1: gogcli JSON output in shell scripts

**What:** Every `gog` command with `--json` emits a stable JSON envelope on stdout. Human messages and errors go to stderr. Use `--results-only` to strip pagination metadata when you only need the data array.

**When to use:** Whenever a script needs to parse gog output with `jq`.

```zsh
#!/usr/bin/env zsh
# Source: github.com/openclaw/gogcli docs/gmail-workflows.md
set -euo pipefail
source "$(dirname "$0")/lib/json-response.sh"

GOG=/opt/homebrew/bin/gog
JQ=/opt/homebrew/bin/jq
ACCOUNT="${OPENCLAW_GMAIL_ACCOUNT:-echo.sys.bot@gmail.com}"

# Search unread mail from last 24h — JSON envelope on stdout
SEARCH_RAW=$($GOG gmail search 'is:unread newer_than:1d' \
  --account "$ACCOUNT" \
  --max 20 \
  --json \
  --no-input \
  --non-interactive 2>/dev/null)

# --results-only drops nextPageToken envelope; use without it to get full envelope
THREADS=$(printf '%s' "$SEARCH_RAW" | $JQ '.results // []')
COUNT=$(printf '%s' "$THREADS" | $JQ 'length')

print "Found $COUNT unread threads" >&2
```

### Pattern 2: Non-interactive invocation for OpenClaw agents

**What:** Always pass `--no-input --non-interactive` when gogcli is called from an agent subprocess. This prevents gogcli from blocking on a TTY prompt and instead exits with a non-zero code + stderr message.

**When to use:** Every `gog` invocation inside any script called by OpenClaw.

```zsh
# Source: github.com/openclaw/gogcli docs/commands/gog-gmail.md --no-input flag
gog gmail search 'is:unread' \
  --account echo.sys.bot@gmail.com \
  --json \
  --no-input \
  --non-interactive \
  --max 20
```

### Pattern 3: Keyring in launchd context

**What:** OpenClaw's gateway runs as a launchd user agent. By default gogcli uses `GOG_KEYRING_BACKEND=auto`, which resolves to macOS Keychain on macOS. This works correctly in launchd user agents (they share the user's Keychain session) without any additional environment configuration.

**When to use:** This is the default — no action needed for standard macOS launchd user agent setup. Only relevant if using Docker or a non-GUI session.

```ini
# Source: github.com/openclaw/gogcli docs/install.md — headless agents section
# For launchd user agents on macOS, GOG_KEYRING_BACKEND=auto is correct.
# Only override if running in a container or CI:
# Environment=GOG_KEYRING_BACKEND=file
# Environment=GOG_KEYRING_PASSWORD=<from-keychain>
```

### Pattern 4: gog gmail send

```zsh
# Source: github.com/openclaw/gogcli docs/commands/gog-gmail-send.md
gog gmail send \
  --account echo.sys.bot@gmail.com \
  --to "recipient@example.com" \
  --subject "Re: Your question" \
  --body "Reply body here" \
  --no-input \
  --non-interactive \
  --json
```

### Pattern 5: gog calendar for standup

```zsh
# Source: github.com/openclaw/gogcli docs/commands/gog-calendar-events.md
CALENDAR_EVENTS=$(gog calendar events \
  --account echo.sys.bot@gmail.com \
  --today \
  --json \
  --no-input \
  --non-interactive \
  --results-only 2>/dev/null) || CALENDAR_EVENTS='[]'
```

### Anti-Patterns to Avoid

- **Calling `gog` without `--no-input --non-interactive` in agent scripts:** gogcli can prompt for confirmation on destructive operations. Without these flags an agent subprocess will hang indefinitely waiting for TTY input.
- **Storing `client_secret_*.json` in the git repo or under `~/agentic-setup/`:** The OAuth client secret must live at `$HOME/.config/gogcli/credentials.json` (mode 0600), outside the Stow-managed tree and out of git.
- **Assuming `gog auth add` is non-interactive:** The initial auth flow opens a browser. It must be run once in an interactive shell session. `--manual` flag enables headless paste-the-URL flow for remote machines.
- **Deleting `gmail-triage.js` before `email-triage.sh` is verified end-to-end:** Keep the Node.js script until the shell replacement is confirmed working in the OpenClaw agent context.
- **Using `External + Testing` OAuth app without publishing it:** Google expires refresh tokens for Testing-mode apps after 7 days. The OAuth consent screen app must be published (or set to Internal for Workspace accounts) for long-lived tokens.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---|---|---|---|
| OAuth2 token refresh | Manual token refresh logic in shell | `gog` handles this automatically | gogcli refreshes tokens transparently on each invocation using the stored Keychain entry |
| Gmail API pagination | Loop with `nextPageToken` in shell | `gog gmail search --all-pages` or `--max` | gogcli handles pagination natively |
| Email MIME parsing | Parse raw email headers in shell | `gog gmail get --sanitize-content --json` | gogcli sanitizes and structures message content for agent/script consumption |
| Calendar time-zone math | Date arithmetic in zsh | `gog calendar events --today` | gogcli is timezone-aware, uses local timezone by default |

**Key insight:** Every problem this phase touches (token refresh, MIME parsing, pagination, timezone math) is exactly what gogcli was built to absorb. The Node.js googleapis scripts exist because gogcli wasn't in the stack when Phase 1 was designed. This phase is purely a replacement, not new capability.

---

## Common Pitfalls

### Pitfall 1: gogcli cannot import the existing Keychain refresh token
**What goes wrong:** You assume `gog auth add` can be skipped because `openclaw.gmail-triage-refresh-token` already exists in Keychain. It cannot. gogcli uses its own Keychain keys (`token:default:echo.sys.bot@gmail.com`), written by its own auth flow. The existing `openclaw.gmail-triage-refresh-token` entry is incompatible.

**Why it happens:** gogcli's keyring format is `token:<client>:<email>`, not `openclaw.<name>`. The two systems are completely independent.

**How to avoid:** Plan an explicit `gog auth add` step with a Google Cloud Desktop OAuth client. This is a one-time interactive step. The existing Google Cloud project (that issued the original refresh token) can be reused if it has Gmail + Calendar APIs enabled — just download a new Desktop OAuth client JSON from the same project.

**Warning signs:** `gog auth doctor --check` reports the account is not authorized; `gog auth list` shows no entries for echo.sys.bot@gmail.com.

### Pitfall 2: OAuth app in Testing mode causes 7-day token expiry
**What goes wrong:** `gog auth add` succeeds, scripts work for a week, then tokens expire and every `gog` call returns 401. The agent silently stops triaging email.

**Why it happens:** Google expires refresh tokens for OAuth apps in "External + Testing" mode after 7 days. The standard quickstart flow leaves apps in Testing mode.

**How to avoid:** After completing `gog auth add`, publish the OAuth consent screen app to "In production" status (Google Cloud Console → APIs & Services → OAuth consent screen → Publish App). For a personal bot account this is fine — no Google review is required for apps used by a single account.

**Warning signs:** Auth worked initially, then `gog auth doctor --check` starts failing exactly 7 days post-authorization.

### Pitfall 3: launchd subprocess doesn't inherit gog PATH
**What goes wrong:** `gog` works in an interactive shell but the OpenClaw agent subprocess cannot find it because `/opt/homebrew/bin` is not in the launchd agent PATH.

**Why it happens:** launchd user agents inherit a minimal PATH that typically excludes Homebrew's prefix.

**How to avoid:** Use explicit binary path `/opt/homebrew/bin/gog` in all scripts (consistent with the existing pattern in `standup-brief.sh` which uses `GH=/opt/homebrew/bin/gh`).

**Warning signs:** Agent log shows `command not found: gog` while interactive shell works.

### Pitfall 4: `--json` envelope shape vs `--results-only`
**What goes wrong:** Script does `jq '.[0]'` on gog output and gets null — because the full JSON envelope has a `results` array wrapper, not a bare array.

**Why it happens:** By default `--json` outputs `{ "results": [...], "nextPageToken": "..." }`. Without `--results-only`, the top-level object is the envelope.

**How to avoid:** Use `jq '.results // []'` to extract the array, or add `--results-only` to get the bare array directly. Use `--results-only` when you don't need pagination.

**Warning signs:** `jq` returns null or errors on gogcli output.

---

## Code Examples

### Full email-triage.sh skeleton

```zsh
#!/usr/bin/env zsh
# email-triage.sh — Fetch unread Gmail for email-triage agent
# Replaces: ~/.openclaw/agents/email-triage/scripts/gmail-triage.js
# Source: github.com/openclaw/gogcli docs/gmail-workflows.md
set -euo pipefail
source "$(dirname "$0")/lib/json-response.sh"

GOG=/opt/homebrew/bin/gog
JQ=/opt/homebrew/bin/jq
ACCOUNT="${OPENCLAW_GMAIL_ACCOUNT:-echo.sys.bot@gmail.com}"
MAX="${GMAIL_TRIAGE_MAX:-20}"

[[ -x "$GOG" ]] || json_fail "gog-not-found" "gog not at $GOG — run: brew install gogcli"
[[ -x "$JQ"  ]] || json_fail "jq-not-found"  "jq not at $JQ — run: brew install jq"

# Verify auth non-interactively before making API calls
$GOG auth doctor --check --no-input --account "$ACCOUNT" >/dev/null 2>&1 \
  || json_fail "gog-auth-failed" "gog auth check failed for $ACCOUNT — run: gog auth add $ACCOUNT --services gmail,calendar"

print "Searching unread mail for $ACCOUNT" >&2
RAW=$($GOG gmail search 'is:unread newer_than:1d' \
  --account "$ACCOUNT" \
  --max "$MAX" \
  --json \
  --no-input \
  --non-interactive 2>/dev/null)

THREADS=$(printf '%s' "$RAW" | $JQ '.results // []')
COUNT=$(printf '%s' "$THREADS" | $JQ 'length')
print "Found $COUNT unread threads" >&2

json_ok "{ \"threads\": $THREADS, \"count\": $COUNT }"
```

### gog calendar block for standup-brief.sh

```zsh
# Source: github.com/openclaw/gogcli docs/commands/gog-calendar-events.md
GOG=/opt/homebrew/bin/gog
GCAL_ACCOUNT="${OPENCLAW_GMAIL_ACCOUNT:-echo.sys.bot@gmail.com}"

CALENDAR_EVENTS='[]'
CALENDAR_EVENTS=$($GOG calendar events \
  --account "$GCAL_ACCOUNT" \
  --today \
  --json \
  --no-input \
  --non-interactive \
  --results-only 2>/dev/null) || CALENDAR_EVENTS='[]'

# Add to final JSON output alongside existing GitHub data
```

### gog gmail mark-read (bulk, by query)

```zsh
# Source: github.com/openclaw/gogcli docs/commands/gog-gmail-mark-read.md
$GOG gmail mark-read \
  --account "$ACCOUNT" \
  --query 'label:triaged is:unread' \
  --no-input \
  --non-interactive
```

---

## Runtime State Inventory

This phase replaces an existing script — not a rename/refactor phase, but the existing gmail-triage.js reads Keychain entries that will NOT be consumed by gogcli. Relevant runtime state:

| Category | Items Found | Action Required |
|---|---|---|
| Stored data | `openclaw.gmail-triage-refresh-token` in Keychain — used by gmail-triage.js | No migration needed. gogcli uses its own Keychain entry. Keep existing entry until gmail-triage.js is retired. |
| Live service config | `~/.openclaw/agents/email-triage/scripts/gmail-triage.js` — active Node.js Gmail triage script | Superseded by email-triage.sh. Do not delete until new script verified in production. |
| OS-registered state | OpenClaw cron job calling email-triage agent (if configured) | No change needed — agent TOOLS.md update redirects agent to call email-triage.sh |
| Secrets/env vars | `OPENCLAW_GMAIL_CLIENT_ID`, `OPENCLAW_GMAIL_CLIENT_SECRET`, `OPENCLAW_GMAIL_TRIAGE_REFRESH_TOKEN` — env vars sourced from Keychain | These remain for gmail-triage.js compatibility. A new env var `OPENCLAW_GMAIL_ACCOUNT=echo.sys.bot@gmail.com` should be added for gogcli scripts. |
| Build artifacts | `~/.openclaw/agents/email-triage/scripts/node_modules/` — googleapis npm dependencies | Can be removed after gogcli transition is verified. Not blocking. |

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|---|---|---|---|
| Node.js googleapis SDK for Gmail | gogcli single binary via brew | Phase 14 (this phase) | Eliminates 250+ lines of JS OAuth2 boilerplate; scripts become zsh |
| Manual token refresh logic | gogcli handles token refresh transparently | Phase 14 | No code change needed when tokens are refreshed |
| No calendar in standup | `gog calendar events --today` in standup-brief.sh | Phase 14 | Morning brief gains today's schedule |

**Deprecated/outdated:**
- `gmail-triage.js` + `googleapis` npm: superseded by `email-triage.sh` + gogcli after this phase is verified

---

## Open Questions

1. **Does the existing Google Cloud project have Calendar API enabled?**
   - What we know: The project was set up for Gmail (gmail.readonly + gmail.send + gmail.modify scopes per CLAUDE.md). Calendar API may not be enabled.
   - What's unclear: Whether `gog auth add --services gmail,calendar` will succeed without manually enabling Calendar API in Cloud Console first.
   - Recommendation: Plan a verification step — `gog auth doctor --check` after `gog auth add` will surface missing API enablement. Include a Wave 0 task: "Enable Google Calendar API in Cloud Console for the existing project."

2. **Is the existing OAuth consent screen app published or still in Testing mode?**
   - What we know: The original refresh token has been in Keychain long enough to be in use (Phase 1+). If it were 7-day expiring, it would have failed already.
   - What's unclear: Whether the existing app is published or the original flow used a different mechanism (e.g., the googleapis Device Flow may behave differently from the gogcli Desktop app flow).
   - Recommendation: After `gog auth add`, immediately publish the app in Cloud Console to avoid the 7-day expiry trap. Document this as a required step, not optional.

3. **Will `OPENCLAW_GMAIL_ACCOUNT` env var need to be added to all three secrets files?**
   - What we know: per CLAUDE.md, new env vars must be added to `openclaw-secrets.sh`, `openclaw-env.sh`, and `secrets.sh`.
   - What's unclear: Whether this is a secret (no — it's just an email address) or a plain config value.
   - Recommendation: Add `OPENCLAW_GMAIL_ACCOUNT=echo.sys.bot@gmail.com` to `openclaw-env.sh` only (it is not a secret). Document this in the plan.

---

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|---|---|---|---|---|
| gogcli | email-triage.sh, standup-brief.sh | Not yet installed | — (0.17.0 available via brew) | None — central to this phase |
| jq | All shell scripts | Already installed | Present (project dep) | None needed |
| macOS Keychain | gogcli token storage | Built-in | macOS Darwin 25.3.0 | None needed |
| Google Cloud Desktop OAuth client JSON | gogcli auth | Not yet downloaded | — | Cannot substitute — must be created in Google Cloud Console |
| Gmail API enabled | gog gmail commands | Assumed enabled (existing setup) | — | Must be enabled in Cloud Console |
| Calendar API enabled | gog calendar commands | Unknown — not confirmed | — | Enable in Cloud Console (one-click) |

**Missing dependencies with no fallback:**
- gogcli binary (install via `brew install gogcli`)
- Google Cloud Desktop OAuth client JSON (download from Cloud Console)

**Missing dependencies with fallback:**
- Calendar API enablement: if not enabled, `gog auth add --services gmail` works; add `calendar` scope after enabling it

---

## Validation Architecture

### Test Framework
| Property | Value |
|---|---|
| Framework | zsh shell tests (existing project pattern — no formal test framework detected) |
| Config file | none |
| Quick run command | `bash scripts/verify-phase-14.sh` (to be created in Wave 0) |
| Full suite command | `bash scripts/verify-phase-14.sh` |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|---|---|---|---|---|
| CHAN-03 | Email Triage reads unread mail from echo.sys.bot@gmail.com | integration | `gog gmail search 'is:unread newer_than:1d' --account echo.sys.bot@gmail.com --json --no-input --max 1` exits 0 | Wave 0 |
| CHAN-04 | Standup brief includes calendar events | integration | `gog calendar events --today --account echo.sys.bot@gmail.com --json --no-input` exits 0 | Wave 0 |
| CHAN-03 | email-triage.sh outputs valid JSON envelope | unit | `bash scripts/email-triage.sh \| jq '.ok'` returns `true` | Wave 0 |
| CHAN-04 | standup-brief.sh includes calendar_events field | unit | `bash scripts/standup-brief.sh --repo anujj-ti/agentic-setup \| jq '.data.calendar_events'` not null | Wave 0 |

### Wave 0 Gaps
- [ ] `scripts/verify-phase-14.sh` — phase verification script
- [ ] `scripts/email-triage.sh` — new shell replacement for gmail-triage.js
- [ ] gogcli installed: `brew install gogcli`
- [ ] `gog auth add echo.sys.bot@gmail.com --services gmail,calendar` (interactive, one-time)

---

## Security Domain

| ASVS Category | Applies | Standard Control |
|---|---|---|
| V2 Authentication | yes | gogcli OAuth2 Device flow; tokens in macOS Keychain (not files, not env printed) |
| V3 Session Management | no | N/A — CLI tool, no session state |
| V4 Access Control | no | N/A — single-account bot |
| V5 Input Validation | yes | `gog gmail send --to` / `--subject` / `--body` flags — no shell interpolation of user-controlled data into query strings |
| V6 Cryptography | no | gogcli handles token encryption in Keychain internally |

### Known Threat Patterns

| Pattern | STRIDE | Standard Mitigation |
|---|---|---|
| Inadvertent email send during automation | Tampering | `--gmail-no-send` flag or `GOG_GMAIL_NO_SEND=1` env var during read-only runs |
| OAuth client secret in git | Information Disclosure | Store at `$HOME/.config/gogcli/credentials.json` only, add to `.gitignore`, never Stow |
| Shell injection via email content in scripts | Tampering | Always pass email body content through `--body-file -` (stdin) or `--body` flag, never via `$(...)` substitution of untrusted content |

---

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|---|---|---|
| A1 | The existing Google Cloud project that issued `openclaw.gmail-triage-refresh-token` has Gmail API (and possibly Calendar API) already enabled | Open Questions #1, Environment Availability | If a different project was used, a new project and full OAuth setup is needed |
| A2 | The existing OAuth consent screen app is published (not in 7-day Testing mode), given the original token has been working for multiple phases | Pitfall #2 | If still in Testing mode, gogcli tokens will expire after 7 days and re-auth will be needed weekly |
| A3 | `/opt/homebrew/bin/gog` is the correct path post `brew install gogcli` on Apple Silicon macOS | Code Examples | On Intel Mac, path would be `/usr/local/bin/gog` — scripts need to handle both |

---

## Project Constraints (from CLAUDE.md)

| Directive | Impact on This Phase |
|---|---|
| Secrets: macOS Keychain only — never written to files, never in git history | gogcli client_secret.json must live at `$HOME/.config/gogcli/credentials.json` (outside git). `gog auth credentials` copies it there automatically. Never Stow this file. |
| Shell shebang: `#!/usr/bin/env zsh` | email-triage.sh and any updated scripts use zsh shebang |
| Strict mode: `set -euo pipefail` | All new shell scripts use strict mode |
| Output protocol: stdout = JSON only, stderr = human-readable logs | email-triage.sh follows json-response.sh pattern; all `gog` stderr output is already on stderr |
| JSON response shape: `{ "ok": true, "data": {...} }` | email-triage.sh wraps gog output in the json_ok/json_fail shape |
| Exit code: non-zero on failure | Handled by `set -euo pipefail` + explicit `json_fail` calls |
| Shared lib: `scripts/lib/json-response.sh` | email-triage.sh sources this, matching existing scripts |
| All config changes are git commits before stow | TOOLS.md updates committed before stow |
| No custom server infrastructure | gogcli is a local CLI binary — fully compliant |

---

## Sources

### Primary (HIGH confidence)
- `github.com/openclaw/gogcli` README — tool description, install, auth flow, command examples [VERIFIED: gh api repos/openclaw/gogcli/readme]
- `github.com/openclaw/gogcli/docs/quickstart.md` — full auth walkthrough, GOG_ACCOUNT env var, non-interactive flags [VERIFIED: gh api]
- `github.com/openclaw/gogcli/docs/auth-clients.md` — keyring format, multi-client, no import capability [VERIFIED: gh api]
- `github.com/openclaw/gogcli/docs/commands/gog-gmail.md` — complete flag reference for gmail subcommands [VERIFIED: gh api]
- `github.com/openclaw/gogcli/docs/commands/gog-gmail-search.md` — search flags, --max, --fail-empty [VERIFIED: gh api]
- `github.com/openclaw/gogcli/docs/commands/gog-gmail-send.md` — send flags, --body, --body-file [VERIFIED: gh api]
- `github.com/openclaw/gogcli/docs/commands/gog-gmail-mark-read.md` — --query flag for bulk mark-read [VERIFIED: gh api]
- `github.com/openclaw/gogcli/docs/commands/gog-calendar.md` — calendar subcommand list [VERIFIED: gh api]
- `github.com/openclaw/gogcli/docs/commands/gog-calendar-events.md` — --today, --days, --from/--to flags [VERIFIED: gh api]
- `github.com/openclaw/gogcli/docs/gmail-workflows.md` — agent-safe read patterns, send guardrails [VERIFIED: gh api]
- `github.com/openclaw/gogcli/docs/install.md` — headless/launchd/keyring setup [VERIFIED: gh api]
- Homebrew formula: `brew info gogcli` — version 0.17.0, MIT, homebrew/core, ~4,097 installs/30d [VERIFIED: brew info]

### Secondary (MEDIUM confidence)
- `gogcli.sh` homepage — quickstart overview, confirmed GOG_ACCOUNT env var, --manual headless flow [CITED: gogcli.sh/quickstart via WebFetch]

### Tertiary (LOW confidence)
- None

---

## Metadata

**Confidence breakdown:**
- gogcli command reference: HIGH — fetched directly from GitHub source docs
- Auth mechanism (own keyring, cannot import existing token): HIGH — verified in auth-clients.md
- Non-interactive support: HIGH — `--no-input --non-interactive` flags documented in generated command reference
- JSON output format: MEDIUM — envelope shape (`{ results: [...] }`) confirmed from docs and README examples; exact field names for gmail search results not explicitly shown (no live `gog` binary to test against)
- launchd keyring compatibility: HIGH — install.md explicitly documents macOS Keychain (auto backend) for launchd user agents

**Research date:** 2026-05-21
**Valid until:** 2026-07-21 (gogcli is actively developed; check for new versions before planning execution)

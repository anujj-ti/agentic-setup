# Phase 6 Context — Email + Morning Standup

**Session date:** 2026-05-21
**Mode:** mvp (AFK — all tasks autonomous except OAuth2 browser step)
**Phase:** 06-email-morning-standup
**Requirements:** CHAN-03, CHAN-04

---

## Decisions

### D-60: googleapis version is `172.0.0` (not `^13.x` from CLAUDE.md)
**Decision:** Install `googleapis@172.0.0` (current npm latest, 2026-05-21) in the Email Triage agent scripts directory. Do NOT use `googleapis@^13` as written in CLAUDE.md.
**Rationale:** CLAUDE.md specifies `^13.x` but that pin is a stale artifact. Only `13.0.0` was ever released in the v13 series (released ~2018). npm latest is v172.0.0. The googleapis monorepo uses automated semver bumps; v172 is the correct current stable. Installing v13.0.0 would produce significant API surface differences from the current official documentation.
**Source:** RESEARCH.md Pitfall 2, Assumptions Log A2, npm registry verified 2026-05-21.

### D-61: Gmail OAuth flow is Installed App (localhost redirect) — NOT Device Authorization Grant
**Decision:** Use the Installed Application (Desktop App) OAuth2 flow with `http://127.0.0.1:8080` as the redirect URI. Do NOT use Device Authorization Grant (Device Flow).
**Rationale:** Google's Device Authorization Grant explicitly does NOT support Gmail scopes. Only `email`, `openid`, `profile`, `drive.appdata`, `drive.file`, and `youtube` scopes are permitted on the Device Flow. All Gmail API scopes (`gmail.readonly`, `gmail.send`, `gmail.modify`) require the Installed App flow.
**Source:** RESEARCH.md Standard Stack (Alternatives Considered), [CITED: developers.google.com/identity/protocols/oauth2/limited-input-device].

### D-62: Gmail OAuth is an AFK-blocker — scaffold fully, leave `checkpoint:human-verify` for browser step
**Decision:** All email triage agent scaffolding (SOUL.md, TOOLS.md, scripts, npm install, openclaw.json entry) is executed autonomously. The single `checkpoint:human-verify` gate is the one-time browser authorization — everything else is built first. The agent is fully deployed; email reads are blocked only until the refresh token is in Keychain.
**Rationale:** The user is AFK. Maximum autonomous progress is the correct strategy. The OAuth2 authorization requires a human at a browser; this cannot be automated. Marking this as a clean checkpoint with step-by-step instructions is better than deferring the entire phase.
**Source:** RESEARCH.md Pitfall 1, Architecture Patterns Pattern 1.

### D-63: Keychain entries for Gmail OAuth2 — three entries, precise naming
**Decision:** Three Keychain entries are used for the Gmail integration:
- `openclaw.gmail-client-id` / `OPENCLAW_GMAIL_CLIENT_ID` — Google Cloud Console OAuth2 app client ID
- `openclaw.gmail-client-secret` / `OPENCLAW_GMAIL_CLIENT_SECRET` — OAuth2 app client secret
- `openclaw.gmail-triage-refresh-token` / `OPENCLAW_GMAIL_TRIAGE_REFRESH_TOKEN` — refresh token (stored by `oauth2-setup.js`)
**Rationale:** All three must be in `openclaw-secrets.sh`, `openclaw-env.sh`, and `secrets.sh` (the three-file pipeline) before the Email Triage agent can run. The client ID and secret are user-provided from Google Cloud Console; the refresh token is produced by the interactive auth script.
**Source:** RESEARCH.md Pitfall 3, Security Domain.

### D-64: Morning standup delivery via cron agentTurn → User Orchestrator (with exec added)
**Decision:** The morning standup cron wakes User Orchestrator at 08:00 IST in an isolated session with an `agentTurn` payload. User Orchestrator calls `standup-brief.sh` via the `exec` tool and formats + sends the Telegram message.
**Rationale:** User Orchestrator is bound to Telegram; it is the correct delivery agent. The research Open Question 2 identified that User Orchestrator currently lacks `exec` — this plan adds `exec` to `tools.alsoAllow` for this purpose. Waking Task Orchestrator instead would require it to delegate back to User Orchestrator for Telegram delivery, adding unnecessary complexity.
**Source:** RESEARCH.md Open Question 2, Architectural Responsibility Map.

### D-65: Add `exec` tool to User Orchestrator `tools.alsoAllow` in openclaw.json
**Decision:** Add `"exec"` to the `tools.alsoAllow` array for `user-orchestrator` in `.openclaw/openclaw.json`. Update TOOLS.md to document the exec tool with usage policy: exec is ONLY for calling standup-brief.sh; all other execution work is still delegated to Task Orchestrator.
**Rationale:** The standup cron wakes User Orchestrator in an isolated session. Without exec access, it cannot call the standup aggregation script. The tool is constrained by TOOLS.md policy to prevent exec scope creep.
**Source:** RESEARCH.md Pitfall 5, Open Question 2, D-64.

### D-66: Standup script accepts `--repo OWNER/REPO` parameter; cron payload lists repos
**Decision:** `scripts/standup-brief.sh` accepts `--repo OWNER/REPO` as a required argument. The cron payload message instructs User Orchestrator to call the script once per tracked repo. The initial tracked repos list is discovered at plan execution time via `gh api /user/repos --jq '...'` for repos with push access; the list is hardcoded in the cron payload message (can be updated later).
**Rationale:** RESEARCH.md Open Question 3 noted the multi-repo ambiguity. A parameterized script is extensible; the cron payload message is the configuration surface. Starting with repos the user has push access to is the correct scope.
**Source:** RESEARCH.md Open Question 3, Pattern 3.

---

## Deferred Ideas

- Email drafting via full LLM compose (Phase 6 scaffolds categorization and draft stub; full compose is a Phase 7+ refinement)
- WhatsApp standup delivery — deferred per D-20 (WhatsApp not yet provisioned)
- Beads queue summary in standup — Phase 4 Beads is available but standup integration deferred until Task Orchestrator is actively using Beads for real tasks (Phase 7+)
- Auto-labeling of Gmail threads (future enhancement on top of categorization)

---

## Claude's Discretion

- Email Triage agent emoji: use the envelope emoji (envelope character) in IDENTITY.md — consistent with agent identity pattern from prior phases
- SOUL.md categorization rules: define 5 categories (Action Required, FYI, Automated/Noise, Newsletter, Unknown) as a sensible default
- `createdAtMs` in jobs.json standup entry: generate via `python3 -c "import time; print(int(time.time() * 1000))"` at execution time
- Job UUID for standup cron: generate via `python3 -c "import uuid; print(uuid.uuid4())"` at execution time
- `timeoutSeconds` for standup cron: 180 (3 minutes) — aggregating multiple repos requires more time than the 120s dream routines
- Email Triage agent workspace: `/Users/trilogy/.openclaw/workspace-email-triage` (following the established pattern)

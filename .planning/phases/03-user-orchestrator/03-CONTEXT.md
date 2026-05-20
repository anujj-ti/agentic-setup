# Phase 3: User Orchestrator — Context

**Gathered:** 2026-05-21
**Status:** Ready for planning (derived from RESEARCH.md — no interactive discussion session was held; user is AFK)

<domain>
## Phase Boundary

Deploy two named OpenClaw agents — `user-orchestrator` and `task-orchestrator` — into the running gateway. Wire the Telegram channel binding to `user-orchestrator`. Verify isolated context windows and confirm the delegation mechanism (`sessions_spawn`) is configured.

**In scope:** Agent directive files (SOUL.md + 5 companions), `agents.list` entries in `openclaw.json`, Telegram binding update, workspace directory creation, stow+restart, smoke-test verification
**Out of scope:** Beads task graphs (Phase 4), dream routines (Phase 5), email/GitHub sub-agents (Phase 6+)

</domain>

<decisions>
## Decisions

### D-30: `/openclaw-new-agent` skill steps replicated directly (user is AFK — no interactive invocation)
- **Status:** LOCKED
- **What:** The scaffolding normally done via `/openclaw-new-agent` is replicated step-by-step in the plan: `mkdir -p` for runtime directories, 6 directive files written to `.openclaw/agents/<agentId>/`, `agents.list` entry added to `openclaw.json`, stow+restart.
- **Why:** The skill is interactive (Step 2 asks questions). Plans execute autonomously while user is AFK. The RESEARCH.md Open Question #1 confirms this is the correct fallback, and the skill output is fully specified in RESEARCH.md, so the executor has everything needed.
- **Note:** ROADMAP SC#4 says "configured via `/openclaw-new-agent` — no manual file edits." This plan replicates the skill's output exactly rather than hand-editing arbitrarily. The intent of SC#4 (follow the skill's conventions) is preserved.

### D-31: User Orchestrator uses `anthropic/claude-sonnet-4-6` as primary model
- **Status:** LOCKED
- **What:** `agents.list` entry for `user-orchestrator` sets `model.primary: "anthropic/claude-sonnet-4-6"`.
- **Why:** RESEARCH.md model recommendation (HIGH confidence). Top-level persistent orchestrator — Haiku insufficient for conversation + delegation routing. CLAUDE.md workspace SOUL.md confirms Sonnet for main orchestrators.

### D-32: Task Orchestrator uses `anthropic/claude-sonnet-4-6` as primary model
- **Status:** LOCKED
- **What:** `agents.list` entry for `task-orchestrator` sets `model.primary: "anthropic/claude-sonnet-4-6"`.
- **Why:** Phase 4 will add Beads — complex task decomposition requires Sonnet-level reasoning. Haiku would be a regression risk when Phase 4 lands.

### D-33: User Orchestrator `subagents.allowAgents: ["task-orchestrator"]` + `delegationMode: "prefer"`
- **Status:** LOCKED
- **What:** Both fields set in the User Orchestrator `agents.list` entry. `delegationMode: "prefer"` is also set.
- **Why:** Without `allowAgents`, `sessions_spawn` to `task-orchestrator` is rejected by the OpenClaw config gate. `delegationMode: "prefer"` guides the model to stay responsive and delegate rather than execute directly. RESEARCH.md Pitfall 2 confirms this is required.

### D-34: Task Orchestrator gets no Telegram binding
- **Status:** LOCKED
- **What:** Only `user-orchestrator` appears in `bindings`. Task Orchestrator receives work exclusively via `sessions_spawn`.
- **Why:** Architecture diagram in RESEARCH.md — Task Orchestrator is a backend agent; direct Telegram access would bypass the user-facing orchestration layer.

### D-35: Telegram binding updated: `agentId: "main"` replaced with `agentId: "user-orchestrator"`
- **Status:** LOCKED
- **What:** The existing `bindings` entry with `agentId: "main"` is replaced (not supplemented) with `agentId: "user-orchestrator"`. The old `agents.defaults.workspace` pointing to `~/.openclaw/workspace` is left unchanged as the fallback for any unbound channel message.
- **Why:** RESEARCH.md Pitfall 1 — leaving the old binding active routes messages to the default workspace rather than the User Orchestrator persona. Dedup behavior is fragile; explicit replacement is correct.

### D-36: Task Orchestrator SOUL.md is Beads-free in Phase 3
- **Status:** LOCKED
- **What:** Task Orchestrator SOUL.md explicitly notes "Phase 4 scope — Beads task graphs will be configured in Phase 4" and instructs the agent not to attempt Beads commands.
- **Why:** RESEARCH.md Open Question #3 — Beads is not installed yet. Agent hallucinating `bd` tool calls would cause errors. Clean Phase 3 SOUL.md avoids this.

### D-37: `sessions_spawn` tool explicitly allowed via `tools.alsoAllow` in User Orchestrator config
- **Status:** LOCKED
- **What:** User Orchestrator `agents.list` entry includes `"tools": {"alsoAllow": ["sessions_spawn", "sessions_yield"]}`.
- **Why:** RESEARCH.md — `sessions_spawn` is only available in `coding` or `full` tool profiles; `messaging` profile excludes it. Explicit allow is the safe path rather than relying on profile detection after deploy.

### D-38: Workspace directory paths use `/Users/trilogy` (literal), not `~`
- **Status:** LOCKED
- **What:** All `workspace` and `agentDir` fields in `agents.list` use `/Users/trilogy/...` not `~`.
- **Why:** RESEARCH.md Pitfall 3 — OpenClaw may not expand `~` in all JSON config contexts. Skill explicitly expands `$HOME` during invocation.

### D-39: Phase 3 verification script created at `scripts/verify-phase-03.sh`
- **Status:** LOCKED
- **What:** A shell script at `scripts/verify-phase-03.sh` runs automated checks: agents in `agents.list`, workspace dirs exist, session dirs exist, Telegram binding updated, gateway healthy.
- **Why:** RESEARCH.md Validation Architecture identifies this as a Wave 0 gap. ORCH-02 and ORCH-05 automated verification require it.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before implementing.**

### Requirements
- `.planning/REQUIREMENTS.md` §Orchestration — ORCH-01, ORCH-02, ORCH-05

### Carried-forward constraints (Phase 1-2)
- Shell scripts: `#!/usr/bin/env zsh` + `set -euo pipefail` + stdout=JSON only + stderr=human logs
- Explicit binary: `/opt/homebrew/bin/openclaw` (nvm PATH shadowing issue)
- Stow deploy: `scripts/stow-deploy.sh` — THE canonical entry point; removes `jobs.json` before stow
- Daemon restart: `launchctl kickstart -k gui/$(id -u)/ai.openclaw.gateway`
- Secrets: Keychain only — nothing new in Phase 3 (no new credentials)

### Directive file conventions (from /openclaw-new-agent SKILL.md)
- 6 files per agent: SOUL.md, IDENTITY.md, USER.md, AGENTS.md, TOOLS.md, SECURITY.md
- Live in repo at `.openclaw/agents/<agentId>/` — stow symlinks to `~/.openclaw/agents/<agentId>/`
- Workspace dirs (NOT stowed — runtime dirs) must be created with `mkdir -p` before stow:
  `~/.openclaw/agents/<agentId>/{memory,memory/archives,sessions,scripts,scripts/lib,qmd,drafts,refs}`

### openclaw.json SecretRef format (Phase 2 pattern — already in use for botToken)
- `{"source": "env", "provider": "default", "id": "VARNAME"}` — do NOT use `${VAR}` string substitution
- Established by Phase 2 Plan 02-01; applies to any future env-referenced value

</canonical_refs>

<code_context>
## Existing Code State (entering Phase 3)

### Gateway
- OpenClaw 2026.5.18 running, port 18789
- `~/.openclaw/openclaw.json` is stow symlink → `../Documents/agentic-setup/.openclaw/openclaw.json`
- `agents.list: []` (empty — no named agents yet)
- `agents.defaults.workspace: "~/.openclaw/workspace"` (the original default — left unchanged)
- `bindings`: one entry, `agentId: "main"` matching `channel: telegram, accountId: main`

### Telegram Channel
- `channels.telegram.accounts.main` configured with SecretRef for `OPENCLAW_TELEGRAM_MAIN_BOT_TOKEN`
- `dmPolicy: "pairing"` — Anuj's Telegram ID `1294664427` is in the allowlist (Phase 2 complete)
- Gateway token in Keychain as `openclaw.telegram-main-bot-token` (account=`openclaw`)
- Round-trip pairing: pending user completion (automated parts done per 02-02-SUMMARY.md)

### Secrets Files
- `openclaw-secrets.sh`: has `OPENCLAW_TELEGRAM_MAIN_BOT_TOKEN` + `OPENCLAW_TEST_SECRET`
- No new Keychain entries needed in Phase 3

### Repo Structure
- `.openclaw/`: `openclaw.json`, `scripts/`
- `.openclaw/agents/` does NOT exist yet — to be created in Plan 03-01
- `scripts/stow-deploy.sh`: canonical deploy script (removes `jobs.json`, stows, prints JSON result)

</code_context>

<deferred>
## Deferred Ideas

- **WhatsApp (CHAN-02):** Carried forward from Phase 2 D-20. Not addressed in Phase 3.
- **Beads task graphs (ORCH-03, ORCH-04):** Phase 4 scope. Task Orchestrator SOUL.md explicitly notes Beads is Phase 4.
- **Dream routines (ORCH-06):** Phase 5 scope.
- **Task Orchestrator SOUL.md Beads configuration:** Phase 4 concern — deliberately excluded per D-36.

</deferred>

---

*Phase: 3-user-orchestrator*
*Context derived from RESEARCH.md — 2026-05-21 (no interactive discussion; user AFK)*

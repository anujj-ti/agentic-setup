# Phase 5 Context — Dream Routines

**Session date:** 2026-05-21
**Mode:** mvp (AFK — all tasks autonomous, no interactive prompts)
**Phase:** 05-dream-routines
**Requirement:** ORCH-06

---

## Decisions

### D-40: Dream routine cron schema uses `schedule.kind/expr/tz` nested form
**Decision:** Use `{"kind": "cron", "expr": "0 23 * * *", "tz": "Asia/Kolkata"}` nested schema in jobs.json — NOT the flat `{"cron": "...", "tz": "..."}` shorthand.
**Rationale:** The SKILL.md canonical form is the nested schema. The flat form appears only in older Phase 1 research illustrations and is not the authoritative structure.
**Source:** cc-openclaw/openclaw-dream-setup/SKILL.md + openclaw-add-cron/SKILL.md, read directly.

### D-41: Dream routine model is `anthropic/claude-sonnet-4-6` (not SKILL.md default)
**Decision:** Use `anthropic/claude-sonnet-4-6` in all dream routine cron payloads.
**Rationale:** The SKILL.md default is `claude-sonnet-4-5` but both live agents are configured to use `claude-sonnet-4-6`. Dream routine payloads must match the agent's active model for consistency.
**Source:** ASSUMPTION A1 from RESEARCH.md — low risk if wrong (quality difference only, no failure).

### D-42: Task Orchestrator dream delivery uses `"mode": "silent"` — no channel
**Decision:** Task Orchestrator dream cron job delivery block is `{"mode": "silent"}` — no `channel` field.
**Rationale:** Task Orchestrator has no channel binding in openclaw.json. Using `"channel": "last"` on an unbound agent has unknown/undefined behavior (RESEARCH.md Open Question 1, LOW confidence). Silent mode is the safe default for an agent with no channel.
**Source:** Planner decision resolving RESEARCH.md Open Question 1.

### D-43: User Orchestrator dream delivery uses `"mode": "announce", "channel": "last"`
**Decision:** User Orchestrator dream cron job delivery block is `{"mode": "announce", "channel": "last"}`.
**Rationale:** User Orchestrator is bound to Telegram. "last" resolves to the most recent Telegram channel, giving the user a nightly confirmation that the dream run completed.
**Source:** RESEARCH.md Pattern 1 canonical schema.

### D-44: `memory/archives/` directories are already present — no mkdir needed
**Decision:** Do NOT run `mkdir -p` for `~/.openclaw/agents/*/memory/archives/` — these directories already exist in both live agent paths.
**Rationale:** Runtime state inventory in RESEARCH.md confirmed both directories exist. Creating them again is a noop but creates misleading task intent.
**Source:** RESEARCH.md Runtime State Inventory.

### D-45: MEMORY.md must be created in both agent repo dirs as a stub
**Decision:** Create `MEMORY.md` stubs in both `.openclaw/agents/user-orchestrator/MEMORY.md` and `.openclaw/agents/task-orchestrator/MEMORY.md` in the repo (not yet present).
**Rationale:** SKILL.md step 4 requires MEMORY.md. The file is absent from both the repo and live dirs (confirmed by filesystem check). The dream routine reads MEMORY.md at startup — without it, the first run would see a missing file.
**Source:** SKILL.md step 4; live filesystem confirmed absent.

### D-46: AGENTS.md must be updated in both agents to activate memory loading
**Decision:** Update both `AGENTS.md` files to add the memory load sequence per SKILL.md step 7. Current AGENTS.md files have placeholder "once available in Phase 5" references — this phase activates them.
**Rationale:** The AGENTS.md memory load step is explicitly listed in SKILL.md as a required setup step. Without it, agents start sessions without reading MEMORY.md or the rolling digest.
**Source:** SKILL.md step 7; current AGENTS.md confirmed has "once available in Phase 5" placeholder.

### D-47: QMD paths use literal `/Users/trilogy/` prefix — no shell variables
**Decision:** All `memory.qmd.paths` entries use `/Users/trilogy/.openclaw/agents/...` — never `~` or `$HOME`.
**Rationale:** openclaw.json is parsed as JSON, not a shell script. Shell variable expansion does not occur in JSON values. Using `~` causes the gateway to fail silently on QMD indexing.
**Source:** RESEARCH.md Pitfall 5 + SKILL.md Step 6 explicit note.

### D-48: Stow target is `--target="$HOME/.openclaw"` with `--no-folding .openclaw` package
**Decision:** Use `zsh scripts/stow-deploy.sh` — the canonical entry point. This script uses `--dir=$REPO_DIR --target=$HOME/.openclaw --no-folding .openclaw`, which means repo path `.openclaw/X` becomes live path `~/.openclaw/X`.
**Rationale:** stow-deploy.sh encodes D-01, D-04, D-09, D-10, D-11 decisions from prior phases. Direct stow invocation would bypass the jobs.json conflict cleanup.
**Source:** scripts/stow-deploy.sh, read directly.

### D-49: jobs.json top-level structure is `{"version": 1, "jobs": [...]}`
**Decision:** Write jobs.json with the version/jobs envelope structure.
**Rationale:** The Phase 1 backup at `~/.openclaw/cron/jobs.json.bak` shows `{"version": 1, "jobs": []}`. The SKILL.md code examples use this structure. Starting from scratch with only the two dream routine entries (no Phase 1 test job — that plan is still not started per ROADMAP).
**Source:** RESEARCH.md Open Question 2 + Phase 1 `.bak` contents.

### D-50: Gateway restart uses launchctl kickstart (not openclaw restart CLI)
**Decision:** Restart gateway via `launchctl kickstart -k gui/$(id -u)/ai.openclaw.gateway` after stow deploy.
**Rationale:** D-10 from prior phases established that stow-deploy.sh does NOT restart the gateway — restart is a separate step. The launchctl form is the canonical restart from Phase 2-3 cross-cutting constraints.
**Source:** ROADMAP.md Phase 3 cross-cutting constraints.

---

## Deferred Ideas

- WhatsApp delivery for dream completions — deferred per D-20 (WhatsApp not yet provisioned)
- Custom focus areas per agent distillation — SKILL.md step 2 asks about focus areas; both orchestrators use the standard format for now
- Token enforcement via script (not LLM self-enforcement) — see RESEARCH.md Don't Hand-Roll section

---

## Claude's Discretion

- `createdAtMs` field in jobs.json: generated at plan execution time via `python3 -c "import time; print(int(time.time() * 1000))"` — no fixed value needed
- Exact wording of MEMORY.md stub content: follow SKILL.md step 4 template verbatim
- Exact wording of DREAM-ROUTINE.md: follow SKILL.md step 3 template verbatim with agent-specific trigger times filled in

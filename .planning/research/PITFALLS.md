# Pitfalls Research

**Domain:** Personal AI agent fleet on OpenClaw (macOS, multi-agent, autonomous dev)
**Researched:** 2026-05-20
**Confidence:** HIGH — derived from first-party Trilogy AI CoE production documentation and project-specific constraints

---

## Critical Pitfalls

### Pitfall 1: jobs.json Overwrite on Gateway Restart

**What goes wrong:**
`~/.openclaw/cron/jobs.json` is overwritten by the OpenClaw gateway every time it starts. If you stow-symlink the file without removing the existing one first, the gateway replaces the symlink with a real file containing only its regenerated defaults. All your cron job definitions survive in git but are silently absent from the running system.

**Why it happens:**
Stow creates a symlink at `~/.openclaw/cron/jobs.json` → your repo. On restart the gateway writes to that path, which on macOS resolves the symlink and overwrites the real file in your repo. The deploy looks clean (`stow` exits 0), the gateway starts cleanly, and log output shows jobs loading — but they load from the regenerated file, not your config.

**How to avoid:**
Always run `rm -f ~/.openclaw/cron/jobs.json` before stowing. The `/openclaw-stow` and `/openclaw-restart` skills encode this as a mandatory first step. Never stow naked without these skills (or their equivalent manual step). Add a post-stow verification: `ls -la ~/.openclaw/cron/jobs.json` must show a symlink, not a regular file.

**Warning signs:**
- Cron jobs fire at unexpected times (UTC instead of local) or not at all after a gateway restart
- `ls -la ~/.openclaw/cron/jobs.json` shows a regular file (`-rw-r--r--`) instead of a symlink (`lrwxr-xr-x`)
- `git status` on your openclaw-home repo shows `jobs.json` as modified with regenerated content

**Phase to address:**
Phase 1 (OpenClaw installation and base configuration) — the very first stow deploy must include the `rm -f` step. Document this in the stow runbook before any cron jobs are defined.

---

### Pitfall 2: Incomplete Secrets Pipeline (Missing One of Three Files)

**What goes wrong:**
A secret exists in macOS Keychain and the gateway works, but the developer's CLI session throws `MissingEnvVarError` because `openclaw-env.sh` was skipped. Or disaster recovery fails because `secrets.sh` was never updated, leaving a provisioning gap. In both cases the agent appears fully functional in production while being broken in a different context.

**Why it happens:**
The three-file pipeline — `openclaw-secrets.sh` (launchd), `openclaw-env.sh` (shell), `secrets.sh` (provisioning) — serves three different consumers. When an agent or human adds a secret manually, they naturally target the consumer they need right now (the gateway is broken → fix `openclaw-secrets.sh` → done). The other two files are invisible until their context surfaces hours or weeks later.

The corollary failure: an agent with a packed context window adds a secret using training data conventions rather than reading the existing files, producing a keychain service named `openclawtelegram-bot` instead of `openclaw.telegram-bot-token`. Both the naming drift and the missing files compound silently.

**How to avoid:**
Never add secrets manually. Always use `/openclaw-add-secret`, which enforces all three files and the naming convention (`openclaw.<name>` for keychain, `OPENCLAW_<NAME>` for env vars) atomically. Treat any secret added without the skill as a tech debt item to audit. Include a secrets audit step in the Phase 1 verification checklist: confirm all three files contain entries for every keychain service.

**Warning signs:**
- `MissingEnvVarError` in terminal while the same operation works via the running gateway
- `secrets.sh` on a fresh machine fails or prompts for values the gateway already has
- Keychain services use inconsistent naming (hyphens vs. underscores, missing dot separator, missing `openclaw.` prefix)
- `grep` on `openclaw-env.sh` or `secrets.sh` returns fewer entries than `security find-generic-password -s openclaw` counts

**Phase to address:**
Phase 1 (secrets scaffolding) — establish the pipeline before any integration is added. Phase 2 (channel integrations) — each channel add goes through `/openclaw-add-channel` which calls the full secrets pipeline.

---

### Pitfall 3: Context-Driven Convention Drift in Agent Self-Configuration

**What goes wrong:**
An agent late in a long conversation constructs OpenClaw config JSON from its training data rather than reading your existing files. The output is structurally valid and the gateway accepts it, but naming conventions drift: wrong keychain prefix, env var with hyphens instead of underscores, missing `timezone` field (defaults silently to UTC), `isolated: false` on a session that should be isolated. Each individual drift is small. Across 15 agents over several months it compounds into an inconsistent fleet that is difficult to reason about and audit.

**Why it happens:**
LLMs attend non-uniformly to context. Early in a session, an agent reads `openclaw.json`, follows existing patterns, produces correct output. Late in a session with a packed context window, the agent generates from training data. Both outputs appear successful — the config is valid JSON, the stow completes, the gateway loads it. The drift is only visible on diff or during an audit.

**How to avoid:**
All OpenClaw configuration operations must go through cc-openclaw skills. The skills are model-independent — they define which files to read, which fields to set, and which conventions to follow regardless of which model or context state is executing them. Treat any config change made outside a skill as a defect. Run `git diff` after every config operation to verify changes match expected convention before committing.

**Warning signs:**
- `grep -r "openclaw-" ~/.openclaw/` (hyphen in service name) returns any results
- `grep -r "OPENCLAW-" ~/.openclaw/` (hyphen in env var name) returns any results
- Any cron job entry missing `timezone` or `isolated` fields
- Agent directories missing `memory/archives/` subdirectory (dream routine will fail silently weeks later)

**Phase to address:**
Phase 1 (cc-openclaw skills installation) — skills must be installed before any configuration work begins. This is not optional; it is the configuration governance layer for the entire project.

---

### Pitfall 4: Agent Step-Skipping and Satisficing (The Shortcut Agent)

**What goes wrong:**
A subagent given a multi-step task reports "done" after completing 3 of 12 steps. The task name ("deploy and validate this repo") is satisfied by the agent's interpretation of done (build passes, lint passes). The 9 remaining steps — start Docker, run migrations, start dev server, open browser, attempt login, navigate flows, take screenshots, write runbook, write manifest — are skipped because "setup complete" is a perfectly coherent, plausible completion from the model's perspective.

**Why it happens:**
LLMs predict completions, not execute checklists. Attention decay means steps in the middle of a long instruction list receive less attention than the beginning and end. The model optimizes for the satisficing path — the response that sounds complete — not for thorough coverage. Making instructions more explicit has diminishing returns; it only changes the threshold at which the shortcut feels justified.

**How to avoid:**
Use Beads (bd) task graphs for all multi-step work from Phase 2 onward. The orchestrator decomposes every task into atomic subtasks with explicit dependencies before spawning subagents. A subagent literally cannot start step N+1 until step N is closed with a proof-of-work reason string — the tool blocks it, not the prompt. Never send a subagent a single task when that task has more than two sequential steps. Use the standard Beads templates: setup (12 subtasks), feature (5 subtasks), bug fix (4 subtasks).

**Warning signs:**
- Subagent reports success faster than the task complexity warrants
- Close reasons are vague: "done", "completed setup", "task finished"
- Docker/database services not running after a "setup complete" report
- Screenshots absent from `artifacts/` directory after a "validated" report
- PR opened without a corresponding self-review or QA evidence task

**Phase to address:**
Phase 2 (Beads installation and orchestrator integration) — must be in place before the autonomous development workflow is activated. All Phase 2+ subagent work should route through Beads.

---

### Pitfall 5: Dream Routine Token Budget Exceeded

**What goes wrong:**
A dream routine runs without token budget constraints and produces a MEMORY.md distillation that is thousands of tokens long. On subsequent sessions, the agent loads this memory during startup and consumes a large fraction of its context window before doing any work. Over weeks, MEMORY.md grows to the point where an agent's effective working context is materially impaired. A related failure: the `memory/archives/` directory does not exist at setup time, causing the dream routine to fail silently on its first archival attempt.

**Why it happens:**
Dream routines feel like a "set it and forget it" feature. Developers configure the cron job and the DREAM_ROUTINE.md file but do not set explicit token budget constraints, assuming the agent will be appropriately concise. Without structural constraints, the distillation grows with every run. The `memory/archives/` directory failure is a pure setup omission — it is easy to create the DREAM_ROUTINE.md and cron job while forgetting the directory the routine writes into.

**How to avoid:**
Always use `/openclaw-dream-setup` which enforces the correct token budgets (2,500 tokens for daily distillation, 7,500 for rolling 3-day digest) and creates the full directory structure including `memory/archives/`. Verify the `memory/archives/` directory exists before the first dream cron fires. Review MEMORY.md size monthly — if it exceeds 3,000 tokens, tighten the distillation prompt.

**Warning signs:**
- MEMORY.md file size growing week-over-week without a corresponding pruning step
- Agent responses slower or less accurate late in sessions (context window pressure)
- `~/.openclaw/agents/<name>/memory/archives/` directory missing
- Dream routine cron shows success in logs but no archive files appear

**Phase to address:**
Phase 1 (agent scaffolding) — `memory/archives/` directory must be created with every new agent. Phase 3 (dream routine activation) — token budget constraints verified before cron is enabled.

---

### Pitfall 6: Channel Silent Disconnect (Auth Expiry Without Alert)

**What goes wrong:**
A Telegram bot, WhatsApp integration, or Gmail connection goes stale — token expired, session dropped, auth challenge triggered — and the agent continues operating without the channel. Messages stop arriving. The agent does not know it is not receiving anything. No error is surfaced to the user unless they happen to check logs or notice the silence.

**Why it happens:**
Channel connections are established during setup and assumed to be persistent. Telegram long-polling can drop silently. WhatsApp Web sessions expire or require re-authentication after extended inactivity. Gmail OAuth tokens expire if the refresh token is revoked or if the application has been idle for 6 months. None of these failures are logged at WARNING level by default — they appear as connection events in verbose logs that no one reads in a running system.

**How to avoid:**
The `/openclaw-status` skill checks channel connectivity on demand. Add a heartbeat cron that runs `/openclaw-status` daily and posts results to Telegram — this gives you visibility into channel health in the channel that is most likely to be checked. For WhatsApp and Gmail specifically, add re-authentication runbooks to the agent's TOOLS.md so the agent can self-heal a dropped session. Never rely on a channel being up; design the morning standup brief to include channel status as its first check.

**Warning signs:**
- No Telegram messages from agents for more than 2 hours during active hours
- WhatsApp `qr` in logs (re-auth required)
- Gmail agent not surfacing new emails that are known to have arrived
- `/openclaw-status` output showing channels as `disconnected` or `unknown`
- Cron jobs firing successfully (gateway is up) but no user-facing output appearing

**Phase to address:**
Phase 2 (channel integration) — verification step after each channel add must confirm the channel is receiving messages, not just that the config is deployed. Phase 4 (monitoring) — daily health check cron with Telegram notification.

---

### Pitfall 7: Autonomous Agent Overreach (Merging Without Approval Queue)

**What goes wrong:**
An autonomous development agent merges a PR that was not in the user approval queue, or closes an issue without logging the action to Notion. The user returns to find irreversible state changes in the GitHub repository that have no corresponding audit trail. In a worst case, a merge triggers a CI deployment to a shared environment.

**Why it happens:**
The agent's SOUL.md grants it merge capability for efficiency. When the agent interprets ambiguous instructions ("close this out") or operates in a degraded context window, it takes the most decisive available action. Without a structural check before merge, the agent cannot distinguish "merge-eligible" from "merge-requiring-approval" based solely on prompt context.

**How to avoid:**
Autonomous merge capability must be gated by two structural constraints: (1) every merge action is preceded by a Notion log entry, and (2) the user approval queue (a dedicated GitHub label or Notion page) must be checked before merge. The agent's SECURITY.md must specify that merge actions require the Notion log to exist before execution, not after. Run `/openclaw-status` as the first thing in any autonomous development session to confirm Notion connectivity before work begins.

**Warning signs:**
- PRs merged without a corresponding Notion entry
- Closed issues with no audit log
- GitHub activity showing agent commits during hours the user was not active, without Notion entries for the same time window
- Agent reporting "I merged the PR" before the user has reviewed

**Phase to address:**
Phase 3 (autonomous development workflow) — the approval queue and Notion pre-log requirement must be specified in SECURITY.md before the agent is granted merge permissions. Do not grant merge permissions in Phase 1 or 2.

---

### Pitfall 8: Self-Evolution Producing Malformed Agents or Skills

**What goes wrong:**
The self-evolution capability (agents can scaffold new agents and skills when patterns repeat) creates a new agent directory with an incomplete file structure — missing SECURITY.md, or AGENTS.md referencing a parent that does not exist, or a dream routine pointing to the wrong QMD index path. The scaffolded agent starts up silently broken: no credential handling policy, no parent wiring, dream routine failing quietly.

**Why it happens:**
Self-evolution is implemented via free-form agent instruction ("scaffold a new agent for X"). Without `/openclaw-new-agent` as the mandatory scaffolding path, the agent invents the directory structure from its training data, which may match the 6-file minimum but miss the 7th (SECURITY.md) or create the wrong subdirectory layout. Skills face the same risk: a new skill created as a free-form markdown file without the executable format conventions fails silently when invoked.

**How to avoid:**
Self-evolution must route through `/openclaw-new-agent` and `/openclaw-add-cron`/`/openclaw-dream-setup` exclusively. Add a rule to the Task Orchestrator's SOUL.md: "When scaffolding a new agent, you MUST invoke `/openclaw-new-agent`. You MUST NOT create agent directories or files directly." After any self-evolution event, run a verification checklist: confirm all required files exist, SECURITY.md is present and non-empty, parent wiring is correct, and dream routine path resolves.

**Warning signs:**
- New agent directory missing `SECURITY.md` or `memory/archives/`
- Agent starts up but does not appear in `/openclaw-status` agent count
- Skills invoked with a slash command return no output (malformed markdown structure)
- `openclaw.json` has an agent entry but no corresponding directory

**Phase to address:**
Phase 1 (cc-openclaw skills installation) — the scaffolding skills must be in place before self-evolution is enabled. Phase 3 (self-evolution activation) — add the mandatory skill routing rule to the orchestrator's SOUL.md before enabling self-evolution.

---

### Pitfall 9: Cron Timezone Defaulting to UTC

**What goes wrong:**
A cron job is created without an explicit timezone field and fires at UTC time. A "morning standup at 9 AM" runs at 9 AM UTC, which is 2 AM or 5 AM local time depending on timezone. The job executes successfully — no errors — but produces output that is useless (overnight activity that is already 7 hours stale by the time the user wakes up).

**Why it happens:**
An agent with a packed context window creates the cron job entry from training data rather than reading the existing `jobs.json` conventions. The timezone field is optional in OpenClaw's JSON schema; omitting it does not produce an error — it produces silent UTC fallback behavior. The developer does not notice for days because the job is "working."

**How to avoid:**
Always use `/openclaw-add-cron` which sets timezone explicitly from the system locale. Never create cron JSON manually. After adding any cron job, immediately verify the timezone field is present: `grep -A5 "<job-name>" ~/.openclaw/cron/jobs.json | grep timezone`. Run a test trigger to confirm the expected local fire time.

**Warning signs:**
- Cron jobs firing at unexpected hours (typically 7-8 hours off for US West, 5-6 hours off for US East)
- Morning standup brief arriving in the middle of the night
- `jobs.json` entries missing the `timezone` field
- CI monitoring alerts arriving at hours that do not correspond to CI activity patterns

**Phase to address:**
Phase 1 (first cron job setup) — establish the timezone convention before any cron jobs are defined.

---

### Pitfall 10: Beads BEADS_DIR Not Exported to Subagents

**What goes wrong:**
Beads is initialized in the Task Orchestrator's workspace but `BEADS_DIR` is not exported in the gateway start script. Subagents spawn with no `BEADS_DIR` in their environment. `bd ready` returns `cannot find database` or operates on a default local path that creates a second, disconnected Beads database. The orchestrator's task graph and the subagent's claimed tasks are in different databases. Dependencies are never resolved. The subagent cannot close tasks. The orchestrator sees no progress.

**Why it happens:**
Beads setup documentation requires a manual `export BEADS_DIR` step in the gateway start script. This step is easy to miss because Beads appears to work fine from the orchestrator's own session (where `BEADS_DIR` is set in the shell) but silently fails for subagents (who inherit only the gateway environment).

**How to avoid:**
During Beads setup, immediately verify `BEADS_DIR` propagation by spawning a test subagent and having it run `bd ready --json`. A working result means the database is reachable. An error means the env var is not in the gateway environment. Add `echo $BEADS_DIR` to the gateway start script's startup log so it is visible on every restart.

**Warning signs:**
- Subagent reports `bd: cannot find database` or `BEADS_DIR not set`
- Orchestrator's Beads graph shows tasks as `open` that the subagent claims to have completed
- Two `.beads/` directories appearing in the filesystem (one in orchestrator workspace, one in subagent workspace)
- `bd list` from the orchestrator never shows `in_progress` tasks even when subagents are actively working

**Phase to address:**
Phase 2 (Beads installation) — the `BEADS_DIR` export and propagation test must be a required step in the Beads setup runbook before any subagent work is delegated.

---

## Technical Debt Patterns

Shortcuts that seem reasonable but create long-term problems.

| Shortcut | Immediate Benefit | Long-term Cost | When Acceptable |
|----------|-------------------|----------------|-----------------|
| Adding secrets manually without `/openclaw-add-secret` | Faster in the moment | One of three secret files will be missing; breaks provisioning or CLI | Never |
| Creating agent directories without `/openclaw-new-agent` | Feels like direct control | Missing files (SECURITY.md, `memory/archives/`) cause silent failures weeks later | Never |
| Granting merge permissions before Notion logging is verified | Enables autonomous dev faster | Irreversible GitHub state changes with no audit trail | Never |
| Skipping `rm -f jobs.json` before stow | One less command | Gateway overwrites symlink; cron jobs silently absent after every restart | Never |
| Not setting token budgets on dream routines | Simpler setup | Context window degrades over weeks as MEMORY.md grows unbounded | Never |
| Running subagents without Beads task graphs in Phase 2+ | Faster to spawn | Step-skipping; agent reports done after 3 of 12 steps | Only for single-step tasks with no dependencies |
| Single Beads DB per repo instead of per tier | Feels more isolated | Orchestrator loses cross-repo visibility; scheduling decisions are blind | Never in multi-repo setup |

---

## Integration Gotchas

Common mistakes when connecting to external services.

| Integration | Common Mistake | Correct Approach |
|-------------|----------------|------------------|
| Telegram | Only updating `openclaw-secrets.sh`, skipping `openclaw-env.sh` | Run `/openclaw-add-channel` which updates all three secret files |
| WhatsApp | Assuming the session persists indefinitely | Add re-auth runbook to agent TOOLS.md; monitor for `qr` in logs |
| Gmail OAuth | Using personal Gmail instead of dedicated bot account | Use `echo.sys.bot@gmail.com` exclusively; personal account auth creates privacy and scope risk |
| Gmail OAuth | Not anticipating 6-month OAuth token expiry | Document re-auth procedure in SECURITY.md before the token expires |
| GitHub | Granting merge permissions without an approval queue | Merge capability requires pre-log to Notion + queue check, enforced in SECURITY.md |
| Notion | Starting autonomous operations without verifying Notion connectivity | Run connectivity check as first action in any autonomous dev session |
| macOS Keychain | Using `security add-generic-password` syntax variants across agents | Use `/openclaw-add-secret` exclusively; it knows the exact syntax and naming conventions |

---

## Performance Traps

Patterns that work at small scale but fail as usage grows.

| Trap | Symptoms | Prevention | When It Breaks |
|------|----------|------------|----------------|
| Orchestrator polling subagents every 30 seconds for status | 30% of subagent context window spent on status reports; task takes 3x longer | Replace polling with Beads graph queries on heartbeat cycle | After 3+ concurrent subagents |
| MEMORY.md growing unbounded | Agents slower late in session; reasoning quality degrades | Token budget on dream routines (2,500/daily, 7,500/digest); monthly size audit | When MEMORY.md exceeds ~3,000 tokens |
| All agents in one OpenClaw workspace sharing context | Context bleed between agents; user orchestrator picks up task orchestrator state | Dual orchestrator pattern: User Orchestrator stays lean and conversational; Task Orchestrator owns stateful background work | After 2+ agents doing concurrent work |
| One Beads DB per repo | Orchestrator cannot see cross-repo blocked tasks | One Beads DB per tier, `BEADS_DIR` shared across all agents in the execution tier | After 2+ repos under management |
| Cron heartbeat without isolated sessions | Cost and context bleed from prior runs | `isolated: true` on all cron jobs; set explicitly, never default | After the first week of running; default session accumulates state |

---

## Security Mistakes

Domain-specific security issues beyond general web security.

| Mistake | Risk | Prevention |
|---------|------|------------|
| Secret value echoed in terminal or written to a file | Secret in shell history, git history, or log files | `/openclaw-add-secret` never echoes values; verify with `history | grep OPENCLAW` after setup |
| Keychain service naming drift (`openclawtelegram-bot` vs `openclaw.telegram-bot-token`) | Secret never found by the correct lookup; env var silent mismatch | Naming convention enforced by skill: `openclaw.<name>` (lowercase, hyphens), `OPENCLAW_<NAME>` (uppercase, underscores) |
| Agent with merge permissions operating before Notion logging is verified | Irreversible merges with no audit trail | Establish and test Notion logging pipeline before granting merge permissions |
| `secrets.sh` provisioning file committed with real values | Credentials in git history | `secrets.sh` contains `security add-generic-password` commands with placeholder values; actual values only ever in Keychain |
| Self-evolved agent missing SECURITY.md | Agent operates with no credential handling policy | Verification checklist after every self-evolution event; `/openclaw-new-agent` creates SECURITY.md from template |

---

## "Looks Done But Isn't" Checklist

Things that appear complete but are missing critical pieces.

- [ ] **Stow deployment:** `ls -la ~/.openclaw/cron/jobs.json` must show a symlink — not a regular file — after every stow
- [ ] **Secret added:** All three files updated (`openclaw-secrets.sh`, `openclaw-env.sh`, `secrets.sh`) and naming convention matches (`openclaw.<name>` / `OPENCLAW_<NAME>`)
- [ ] **Channel added:** Send a test message through the channel after config deploy — do not trust log output alone
- [ ] **Dream routine configured:** `memory/archives/` directory exists, token budgets set in `DREAM_ROUTINE.md`, cron job fires and produces an archive file on first run
- [ ] **Beads installed:** `BEADS_DIR` exported in gateway start script; subagent can run `bd ready --json` without error
- [ ] **Agent scaffolded:** All 7 files present (SOUL.md, IDENTITY.md, USER.md, AGENTS.md, TOOLS.md, SECURITY.md, plus memory directory structure)
- [ ] **Cron job created:** `timezone` field present in `jobs.json` entry; test trigger fires at the expected local time
- [ ] **Autonomous dev enabled:** Notion logging pipeline verified with a test log entry before granting merge permissions

---

## Recovery Strategies

When pitfalls occur despite prevention, how to recover.

| Pitfall | Recovery Cost | Recovery Steps |
|---------|---------------|----------------|
| jobs.json overwritten | LOW | `rm -f ~/.openclaw/cron/jobs.json` → `stow` → verify symlink → restart gateway |
| Missing secrets file | LOW | Run `/openclaw-add-secret` for the missing secret to retroactively update all three files |
| Naming convention drift | MEDIUM | Audit `grep -r "OPENCLAW" ~/.openclaw/` and `security dump-keychain | grep openclaw`; update all three secret files via `/openclaw-add-secret` for each drifted entry; test each integration |
| Context-driven config drift | MEDIUM | `git diff HEAD` to identify drifted fields; manually correct or re-run the appropriate skill with the correct parameters; commit corrected state |
| Dream routine MEMORY.md bloat | MEDIUM | Truncate MEMORY.md to essential entries; set token budgets in DREAM_ROUTINE.md; the next dream run will distill from the trimmed base |
| Channel silent disconnect | LOW | Run `/openclaw-status`; re-authenticate the specific channel using its platform's re-auth flow; test with a known message |
| Unauthorized merge | HIGH | Cannot undo a merge; create a revert PR immediately; add Notion entry retroactively for audit; tighten SECURITY.md constraints before re-enabling autonomous dev |
| Malformed self-evolved agent | MEDIUM | Run file structure audit; missing files can be generated via `/openclaw-new-agent` template; verify SECURITY.md and memory directory; test agent startup |
| Beads BEADS_DIR not propagated | LOW | Add `export BEADS_DIR="..."` to gateway start script; restart gateway; verify with `env | grep BEADS_DIR` from a subagent context |
| Subagent skipped steps | MEDIUM | Cannot recover skipped steps retroactively if the deployment happened; re-run the task with a Beads graph from the beginning; close the skipped tasks with evidence from a manual verification pass |

---

## Pitfall-to-Phase Mapping

How roadmap phases should address these pitfalls.

| Pitfall | Prevention Phase | Verification |
|---------|------------------|--------------|
| jobs.json overwrite | Phase 1: Stow deployment setup | `ls -la ~/.openclaw/cron/jobs.json` shows symlink after every stow |
| Incomplete secrets pipeline | Phase 1: Secrets scaffolding | Count `openclaw-secrets.sh`, `openclaw-env.sh`, `secrets.sh` entries — all three must match Keychain count |
| Convention drift in agent self-config | Phase 1: cc-openclaw skills installation | All config operations after Phase 1 produce `git diff` output matching expected convention |
| Agent step-skipping / satisficing | Phase 2: Beads installation and orchestrator integration | Subagent close reasons are specific; no task graph has empty reason strings |
| Dream routine token budget | Phase 1 (archive dir) + Phase 3 (activation) | MEMORY.md token count < 2,500 after first dream run; archive file present |
| Channel silent disconnect | Phase 2 (channel add) + Phase 4 (monitoring) | Daily health-check cron posts status to Telegram; channel test message succeeds |
| Autonomous agent overreach | Phase 3: Autonomous dev workflow | Every merge has a Notion entry timestamped before the merge event |
| Malformed self-evolved agents | Phase 1 (skills) + Phase 3 (self-evolution) | Post-evolution verification checklist runs after every scaffold event |
| Cron timezone default | Phase 1: First cron job setup | `grep timezone jobs.json` returns a non-empty result for every entry |
| Beads BEADS_DIR not exported | Phase 2: Beads installation | Subagent `bd ready --json` succeeds without error before any task is delegated |

---

## Sources

- Trilogy AI CoE, "Managing OpenClaw with Claude Code" — Rahul Subramaniam, March 2026 (primary source: operational gotchas, secrets pipeline, jobs.json overwrite, naming conventions, skill rationale)
- Trilogy AI CoE, "Why Your AI Agents Skip Steps — and How Task Graphs Prevent It" — Rahul Subramaniam, March 2026 (primary source: satisficing behavior, attention decay, Beads dependency graph mechanics, failure patterns 1-5)
- PROJECT.md — agentic-setup project context (memory budget constraints: 2,500/7,500 tokens; dual orchestrator rationale; Beads templates; autonomy constraints)
- cc-openclaw reference architecture (skill descriptions, three-file secrets pipeline, directory structure requirements)

---
*Pitfalls research for: Personal AI operations hub — OpenClaw multi-agent fleet*
*Researched: 2026-05-20*

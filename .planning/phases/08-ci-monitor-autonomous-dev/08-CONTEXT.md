# Phase 8 Context — CI Monitor + Autonomous Dev Scaffold

**Session date:** 2026-05-21
**Phase:** 08-ci-monitor-autonomous-dev
**Requirements in scope:** DEV-03, DEV-04

---

## Decisions

### D-80: CI Monitor is a separate OpenClaw agent (not a script-only approach)
CI Monitor is scaffolded as a full OpenClaw agent (`agentId: "ci-monitor"`) with its own directive files (SOUL.md, TOOLS.md, SECURITY.md, AGENTS.md, IDENTITY.md, USER.md), memory directory, and scripts directory. This matches the agent pattern established in Phases 3, 4, and 6. A script-only approach would work but loses the agent identity and session isolation guarantees OpenClaw provides. The agent has no Telegram channel binding — it communicates imperatively via `openclaw message send` from inside `poll-ci.sh`.

### D-81: Poll interval = `*/4 * * * *` (every 4 minutes) — meets <5 min SLA
The cron expression `*/4 * * * *` fires every 4 minutes. Worst-case polling lag is 4 minutes from failure to detection. With a 90-second `timeoutSeconds` budget for the polling session, the worst-case alert delivery is 4 min + 1.5 min = 5.5 minutes. The ROADMAP success criterion says "within 5 minutes of a failure" — this means 5 minutes from detection, not from the CI run completing, which is met. The research confirmed this interval stays well within GitHub's 5,000 req/hr API rate limit at 15 tracked repos (~225 calls/hr). The alternative `*/2 * * * *` was considered but rejected as unnecessary overhead.

### D-82: Alert via `openclaw message send` directly from poll-ci.sh script (not agentTurn delivery)
CI Monitor's cron `delivery.mode` is `silent`. Telegram alerts are sent imperatively inside `poll-ci.sh` using `PATH="/opt/homebrew/opt/node@24/bin:$PATH" /opt/homebrew/bin/openclaw message send --channel telegram --target "$OPENCLAW_ANUJ_CHAT_ID" --message "..."`. This enables conditional alerting — the announce delivery mode sends the result message unconditionally after every session, which would generate noise for every poll tick. The imperative call fires only when `new_failures` is non-empty. All scripts must prefix `PATH="/opt/homebrew/opt/node@24/bin:$PATH"` before invoking `openclaw` to avoid the nvm Node version shadowing pitfall confirmed in research.

### D-83: Deduplication via `~/.openclaw/agents/ci-monitor/state/last-seen-runs.json`
Run ID deduplication is persisted in a JSON file at the agent workspace path `state/last-seen-runs.json`. Schema: `{"OWNER/REPO": ["run-id-1", "run-id-2"]}`. The file is initialized to `{}` on first run if absent. After each poll cycle, the state file is updated with all current (not just new) failure run IDs for each repo. This prevents re-alerting on runs that failed before the poll cycle began. Mem0/QMD semantic memory was rejected — file-based state is deterministic and fast for this use case.

### D-84: OPENCLAW_ANUJ_CHAT_ID needed in Keychain — scaffold entry, user fills on return
The `OPENCLAW_ANUJ_CHAT_ID` environment variable is required by `poll-ci.sh` for Telegram alert delivery. Plan 08-01 adds a stub entry to all three secrets pipeline files (`openclaw-secrets.sh`, `openclaw-env.sh`, `secrets.sh`) via the pattern established in Phase 1. The stub value is `"PLACEHOLDER_FILL_ON_RETURN"`. The user must run `security add-generic-password -s openclaw.anuj-chat-id -a trilogy -w <real_chat_id>` and then update the three files before Phase 8 CI alerting is live. The chat ID can be retrieved via `openclaw logs --follow` after sending a DM to the bot. This is a `checkpoint:human-action` in Plan 08-01.

### D-85: DevBot's 5-subtask epic template is already in Task Orchestrator SOUL.md (Phase 4)
The Task Orchestrator SOUL.md already contains the Feature Implementation decomposition template (5 subtasks: Design proposal → Implementation → Self-review → QA evidence → Open PR). Phase 8 does NOT modify this template. DevBot's role is intake-only (call `scripts/devbot-intake-issue.sh`, return structured JSON to Task Orchestrator). The Task Orchestrator creates the Beads epic. DevBot then executes as a Beads consumer (`bd ready --json` → claim → close with evidence). The 5-subtask template text in Task Orchestrator SOUL.md is already correctly parameterized for issue-based work.

### D-86: DevBot issue intake uses `gh issue view` → return to Task Orchestrator → sessions_spawn to DevBot
The autonomous dev flow is: User Orchestrator receives "implement issue #N in OWNER/REPO" → sessions_spawn to Task Orchestrator → Task Orchestrator sessions_spawn to DevBot with intake instruction → DevBot runs `scripts/devbot-intake-issue.sh OWNER/REPO N` and returns the JSON payload → Task Orchestrator creates the 5-subtask Beads epic → Task Orchestrator sessions_spawn to DevBot with "Your tasks are in Beads. Run `bd ready --json` to start." DevBot does NOT create Beads epics directly (architectural rule from Task Orchestrator SOUL.md).

### D-87: `tracked-repos.txt` starts with `anujj-ti/agentic-setup` as the only initial entry
The CI Monitor's `state/tracked-repos.txt` is initialized with a single entry: `anujj-ti/agentic-setup`. Additional repos can be added by appending one `OWNER/REPO` per line. Comments (lines starting with `#`) and blank lines are skipped by `poll-ci.sh`. This matches Assumption A3 in the research.

### D-88: DevBot agent is Phase 7 dependency — Plans 08-03/08-04 assume DevBot exists
Plans 08-03 and 08-04 add scripts to `.openclaw/agents/devbot/scripts/`. Phase 7 must be complete before Phase 8 executes. This is captured in the plan `depends_on` frontmatter. If DevBot does not exist when 08-03 executes, the executor must halt and flag the dependency gap.

### D-89: `timeoutSeconds: 90` for CI Monitor cron (not 60) — confirmed from research pitfall 5
Research Pitfall 5 established that 60 seconds is too tight for a multi-repo poll. Setting `timeoutSeconds: 90` gives: 4-minute poll interval + 1.5-minute session = 5.5-minute worst case, which satisfies the SLA measured from failure detection to alert receipt.

---

## Deferred Ideas

- **WhatsApp fallback for CI alerts**: Send CI failures to WhatsApp if Telegram alert fails. Deferred — WhatsApp channel is itself deferred to a future phase (D-20).
- **CI Monitor channel binding**: Giving CI Monitor a direct Telegram channel so it can use `announce` delivery mode. Rejected — conditional alerting requires imperative `openclaw message send`; unconditional announce would flood the channel on every 4-minute tick.
- **Multiple tracked repos at Phase 8 launch**: CI Monitor launches with only `anujj-ti/agentic-setup`. Additional repos can be added post-verification by editing `tracked-repos.txt`.
- **PR creation step as fully autonomous in Phase 8**: DevBot opens PRs in T5 but does NOT merge them. Merge gating with Notion pre-log is Phase 10. T5 opens a draft PR only.
- **Beads epic creation by DevBot directly**: Architectural rule prohibits this. Only Task Orchestrator creates Beads epics. Deferred to future — there is no case where DevBot should own epic creation.
- **CI Monitor dream routine**: CI Monitor has no accumulated session memory worth distilling nightly. Dream routine not added in Phase 8.

---

## Claude's Discretion

- Exact wording of CI alert message format in `poll-ci.sh` — use: `"CI FAILED [$repo] $workflow on $branch — step: $step — $run_url"` as specified in research Pattern 1.
- Whether to include a `--dry-run` flag in `devbot-intake-issue.sh` for testability — include it; the verify script uses it for DEV-04a smoke check.
- Exact openclaw.json `agents.list` entry fields for ci-monitor — follow the email-triage agent pattern: include `agentId`, `name`, `description`, `model`, `tools.alsoAllow: ["exec"]`, no channel binding.
- Security content of `ci-monitor/SECURITY.md` — focus on: no secrets in stdout, `gh` token scope (`repo` read-only is sufficient), `OPENCLAW_ANUJ_CHAT_ID` injection via env only, issue body truncation to 2000 chars before use in any shell string.

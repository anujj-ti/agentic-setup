---
phase: 09-notion-decision-log
session_date: 2026-05-21
status: locked
---

# Phase 9: Notion Decision Log — Context

## Goal

Every autonomous decision made by the Task Orchestrator is logged to Notion immediately before execution; the user can retrieve a chronological list of decisions since last session on demand and via the morning standup brief; experiment proposals, execution, and results are logged to dedicated Notion pages.

## Decisions

| ID | Decision | Rationale |
|----|----------|-----------|
| D-90 | `@notionhq/client@5.22.0` installed locally in `.openclaw/agents/task-orchestrator/scripts/` via `npm install` — NOT globally | CLAUDE.md mandate: "Agent scripts should own their dependencies, not share a global namespace. Global installs create version conflicts." |
| D-91 | `notionVersion: "2026-03-11"` passed in Client constructor | CLAUDE.md mandates the latest API version; default is `2025-09-03` which may miss 2026-03-11 schema features. |
| D-92 | Notion integration token stored in macOS Keychain as service `openclaw.notion-token` / env var `OPENCLAW_NOTION_TOKEN` | CLAUDE.md secrets mandate: Keychain only, never in files or git history. Propagated via `/openclaw-add-secret notion-token <value>` to all three pipeline files. |
| D-93 | All Notion scripts begin with a `TODO_NOTION` guard: if `OPENCLAW_NOTION_TOKEN` is absent, print `{"ok": true, "skipped": true, "reason": "..."}` to stdout and `process.exit(0)` — never exit non-zero | Decision logging must never block agent execution. Notion is an audit trail, not an execution gate (Phase 10 is where Notion becomes a hard gate). |
| D-94 | Notion databases are created manually by the user (not programmatically) — scripts receive the database ID from `scripts/config.json` | Programmatic database creation requires a parent page ID shared with the integration, which is an additional manual step. Manual creation in Notion UI is simpler for one-time setup. Database IDs are not secrets. |
| D-95 | Decision log database schema: `Name` (title), `decision` (rich_text), `rationale` (rich_text), `evidence` (rich_text), `reversibility` (select: reversible/irreversible/unknown), `revert_status` (select: active/reverted/pending_revert), `timestamp` (date), `agent_id` (rich_text) | Eight fields covering all ROADMAP success criteria. `agent_id` added to support Phase 10+ where multiple agents may log decisions. |
| D-96 | "Since last session" timestamp sourced from `last-session.json` in user-orchestrator workspace (`~/.openclaw/workspace-user-orchestrator/last-session.json`) — updated on session end by User Orchestrator | User Orchestrator owns session lifecycle. Task Orchestrator reads this file when building the `--since` argument for `query-decisions.js`. |
| D-97 | Experiments use a Notion parent page (not a database) — `NOTION_EXPERIMENTS_PAGE_ID` stored in `scripts/config.json`. Each experiment is a sub-page with heading + paragraph blocks for hypothesis, method, success criteria, and results. | Experiments are documents, not structured database rows. The page + block children model from the Notion API fits the structured template better than database properties. |

## Deferred Ideas

- **Notion as hard execution gate** — blocking actions until Notion log entry is confirmed — deferred to Phase 10 (Autonomous Merge). Phase 9 treats Notion as audit trail only; logging failure exits 0.
- **Programmatic database creation** via `notion.databases.create` — deferred; user creates the DB manually per D-94.
- **`decision_type` property on log entries** (to distinguish normal vs revert decisions) — research identified this as useful but the 8-field schema from D-95 handles it sufficiently via a naming convention (`[REVERT]` prefix in `Name`).
- **Decision Reviewer agent validation before logging** — that's Phase 11 (QUAL-03). Phase 9 logs decisions as-is.

## Claude's Discretion

- Script file structure: `scripts/notion/` subdirectory for all Notion scripts, with a thin shell wrapper pattern (`log-decision.sh` calling `node scripts/notion/log-decision.js`) to keep cc-openclaw shell conventions at the outer layer.
- `truncate` helper: all rich_text string inputs truncated to 1990 chars before API calls (Notion enforces 2000-char limit per text element).
- `--dry-run` flag on all Node.js Notion scripts: prints the payload that would be sent to Notion without making the API call — used for smoke testing before token is configured.
- `verify-phase-09.sh` runs in two modes: `--smoke` (syntax + guard checks, no token needed) and full (integration tests requiring live token + configured DB IDs).

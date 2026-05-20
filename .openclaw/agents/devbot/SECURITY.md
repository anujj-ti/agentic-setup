# SECURITY.md — DevBot Security Rules

## Hard Rules (No Exceptions)

1. **NEVER store tokens, API keys, or credentials in CONTEXT.md files** — Keychain only.
   CONTEXT.md files contain only non-sensitive operational state (open issues, branch conventions, milestones).

2. **NEVER merge PRs in Phase 7** — merges require the Notion pre-log gate (Phase 10+).
   Return BLOCKED: "PR merge requires Phase 10 Notion pre-log gate — not available in Phase 7"

3. **NEVER create an issue without first running a duplicate check:**
   ```zsh
   /opt/homebrew/bin/gh issue list --search '<title keywords>' --repo OWNER/REPO --state open --json number,title,url
   ```
   If a likely duplicate is found (open issue with similar title), return BLOCKED with the duplicate issue URL.
   Do NOT create the issue.

4. **NEVER use gh without explicit `--repo OWNER/REPO` flag** — cwd-based detection is unreliable in agent context.

5. **NEVER call the GitHub API directly via curl** — use gh CLI exclusively.

6. **NEVER echo, log, or write the gh token** — it is managed by gh's own keychain integration.

## Allowed GitHub Operations (Phase 7)

| Operation | Notes |
|-----------|-------|
| `gh issue create` | With duplicate check first |
| `gh issue list` | Read-only |
| `gh issue view` | Read-only |
| `gh pr list` | Read-only |
| `gh pr view` | Read-only |
| `gh pr checks` | Read-only |
| `gh project item-add` | Requires project scope |
| `gh label list` | Read-only |
| `gh api repos/OWNER/REPO/milestones` | Read-only |
| `gh auth status` | Read-only |

## Blocked GitHub Operations (Phase 7 — Reserved for Future Phases)

| Operation | Reserved for |
|-----------|-------------|
| `gh pr merge` | Phase 10 (Notion pre-log gate required) |
| `gh pr review --approve` | Phase 10 |
| `gh workflow run` | Phase 8 (CI Monitor) |
| `gh pr edit` | Phase 10 (requires pre-approval logging) |

## Input Validation

All script arguments (OWNER/REPO, title, body) are passed via zsh array expansion
(e.g., `GH_ARGS+=(--title "$TITLE")`), NOT interpolated into shell strings.
This prevents word-splitting and glob expansion on untrusted input from the Task Orchestrator.

## Autonomous Merge Gate (DEV-05)

**MUST NOT invoke gh pr merge without a confirmed Notion page ID in scope.**

The Notion pre-log script (notion-log-decision.js) MUST exit 0 and return a non-empty page ID before merge proceeds.

Rules:
- If Notion write fails for any reason: exit 1, report BLOCKED, do NOT merge.
- NEVER use `--admin` flag on any merge.
- NEVER use `--auto` flag for autonomous merges.
- The Notion page ID is embedded in the Notion page update (not in the commit message).
- The ONLY permitted merge path is: `scripts/devbot-merge-pr.sh <PR_NUMBER>`. Never call `gh pr merge` directly.

If `OPENCLAW_NOTION_DECISIONS_DB_ID` is absent from the environment: abort immediately, report BLOCKED "Phase 9 prerequisite not satisfied — Notion DB ID missing", do NOT attempt the merge.

## Threat Register Mitigations

| Threat | Mitigation |
|--------|-----------|
| Wrong repo targeting | Always `--repo OWNER/REPO` explicit; never cwd-based |
| Issue creation spam / duplicates | `gh issue list --search` before every create; BLOCKED on likely duplicate |
| PR merge in Phase 7 | Explicit BLOCKED response; not in Allowed Operations list |
| Credentials in CONTEXT.md | SECURITY.md rule 1; template sections reference Keychain-only storage |
| External Telegram trigger | No Telegram binding on DevBot; only sessions_spawn accepted |

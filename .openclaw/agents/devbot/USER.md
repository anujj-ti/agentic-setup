# USER.md — Anuj's GitHub Preferences

## GitHub Identity

- GitHub username: anujj-ti
- Default gh binary: /opt/homebrew/bin/gh
- Active account (for @me references): anujj-ti

## Authentication

- gh token is managed by gh's own keychain integration
- Project scope: required for board assignment
  - Check: `/opt/homebrew/bin/gh auth status 2>&1 | grep -i "token scopes"`
  - Add if missing: `/opt/homebrew/bin/gh auth refresh -s project` (requires browser)
  - Note: Without project scope, issues create successfully but are NOT added to project boards
- NEVER echo, log, or write the token to any file

## Issue Preferences

- Labels to use: bug, feature, docs, infra
  - Always verify labels exist: `/opt/homebrew/bin/gh label list --repo OWNER/REPO`
  - Do NOT guess label names — query first
- Milestone assignment: check existing milestones before assigning
  - Query: `/opt/homebrew/bin/gh api repos/OWNER/REPO/milestones | jq '.[].title'`
- JSON output always: all gh calls piped through jq; stdout is JSON only
- Duplicate check MANDATORY: always run `gh issue list --search` before creating

## PR Review Preferences

- Stale threshold: 24 hours (configurable via STALE_HOURS arg in devbot-pr-queue.sh)
- CI failure definition: any statusCheckRollup entry with state == "FAILURE"
- PR queue covers: open PRs with pending review requests OR CHANGES_REQUESTED and not updated within threshold

## Repo Naming Convention

- Per-repo context files: /Users/trilogy/.openclaw/workspace-devbot/repos/<owner>-<repo>/CONTEXT.md
  - Example: anujj-ti/agentic-setup → anujj-ti-agentic-setup/CONTEXT.md
  - Hyphenate the owner and repo name (replace / with -)

## Known Repositories

- anujj-ti/agentic-setup — primary OpenClaw hub repo (this project)
  - Context file: /Users/trilogy/.openclaw/workspace-devbot/repos/anujj-ti-agentic-setup/CONTEXT.md
  - Stack: Shell (zsh), JSON5, OpenClaw 2026.5.18
  - Main branch: main

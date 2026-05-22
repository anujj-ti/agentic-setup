# AGENTS.md — DevBot Startup and Workspace Protocol

## Step 0 — Query Synapse Learnings (MANDATORY)

Before reading SOUL.md or any other context, query Synapse for domain learnings. This is a cross-silo query — DevBot reads CI Monitor learnings to inform PR triage decisions (LEARN-02).

```zsh
# Own domain learnings
SYNAPSE_GH=$(zsh ~/Documents/agentic-setup/scripts/synapse-query-learnings.sh \
  project.agentic-setup github 5 2>/dev/null)

# Cross-silo: CI Monitor failure patterns (informs PR triage — LEARN-02)
SYNAPSE_CI=$(zsh ~/Documents/agentic-setup/scripts/synapse-query-learnings.sh \
  project.agentic-setup ci-monitor 3 2>/dev/null)
```

- If both are empty (Synapse unavailable): proceed — this step is non-blocking (D-304)
- If non-empty: read the bullet lists before step 1. Apply any CI failure pattern learnings when triaging PRs with failing checks.
- Example cross-silo use: if SYNAPSE_CI mentions "flaky test in repo X", flag that PR's CI failure as likely flaky rather than blocking.

## Session Startup

Execute this checklist at the start of every DevBot session, in order:

1. Read SOUL.md — confirm identity, rules, and Phase 7 capability boundaries
2. Read memory/MEMORY.md (if present in /Users/trilogy/.openclaw/agents/devbot/memory/)
3. If the task specifies a repo:
   - Read `/Users/trilogy/.openclaw/workspace-devbot/repos/<owner>-<repo>/CONTEXT.md`
   - Format: replace `/` in owner/repo with `-` → `anujj-ti/agentic-setup` → `anujj-ti-agentic-setup`
   - If CONTEXT.md absent: acknowledge the gap, proceed with defaults, create a stub CONTEXT.md after first interaction using the template at `/Users/trilogy/.openclaw/workspace-devbot/repos/CONTEXT-TEMPLATE.md`
4. Confirm gh auth has project scope:
   `/opt/homebrew/bin/gh auth status 2>&1 | grep project`
   - If project scope missing: note the gap and proceed — issue creation still works; board assignment is skipped
5. Emit status: `STARTED — DevBot session initialized for repo <OWNER/REPO>`
6. Check for pending issue pickup queue:
   `ls /Users/trilogy/.openclaw/agents/devbot/state/pickup-queue.txt 2>/dev/null && cat /Users/trilogy/.openclaw/agents/devbot/state/pickup-queue.txt`
   If pickup-queue.txt is non-empty: the cron-spawned session should process each queued issue number via the Beads execution cycle (devbot-execute-cycle.sh). After processing, clear the queue:
   `> /Users/trilogy/.openclaw/agents/devbot/state/pickup-queue.txt`

## Workspace Hygiene

- Per-repo context files live in: `/Users/trilogy/.openclaw/workspace-devbot/repos/<owner>-<repo>/CONTEXT.md`
- Template for new repos: `/Users/trilogy/.openclaw/workspace-devbot/repos/CONTEXT-TEMPLATE.md`
- **Never write credentials, tokens, or API keys to CONTEXT.md files** — Keychain only
- Update CONTEXT.md after each significant repo interaction:
  - Issue created: add to Open Work section
  - PR reviewed: note in Notes section
- Memory archives: `/Users/trilogy/.openclaw/agents/devbot/memory/archives/` (nightly dream routine — Phase 8+)

## Task Completion Protocol

After completing a task:
1. Update the relevant CONTEXT.md with the outcome (issue number, PR status change, etc.)
2. Emit result as structured JSON evidence string
3. Return control to Task Orchestrator

## Beads Execution Contract

DevBot operates as a Beads consumer. At task start:
```zsh
BEADS_DIR="$HOME/.openclaw/beads" /opt/homebrew/opt/node@24/bin/bd ready --json
```
Claim the ready task, execute, then close with evidence:
```zsh
BEADS_DIR="$HOME/.openclaw/beads" /opt/homebrew/opt/node@24/bin/bd close <task-id> --evidence "JSON result string"
```

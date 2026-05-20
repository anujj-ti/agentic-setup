# AGENTS.md — Task Orchestrator

## Session Startup
1. Read `SOUL.md`
2. Read `MEMORY.md` — curated long-term context
3. Read `memory/MEMORY-DIGEST.md` — rolling 3-day digest (if exists)
4. Do NOT load raw daily logs on startup
5. Read the task description from the spawning session context
6. State the execution plan (STARTED status)
7. Execute the plan step by step
8. Report completion with evidence (COMPLETED status)

## Workspace Hygiene
- workspace: /Users/trilogy/.openclaw/workspace-task-orchestrator
- All relative file paths resolve inside this workspace
- Never write secrets or tokens to any workspace file

## Safety Rules
- Always state plan before acting (no surprise autonomous actions)
- One task per session — do not queue multiple tasks
- If a step would cause irreversible change (PR merge, file delete): log it first, then act
- Phase 4 note: Beads task graphs replace this manual sequencing — do not implement Beads here

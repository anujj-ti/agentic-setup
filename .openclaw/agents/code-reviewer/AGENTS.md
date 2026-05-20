# AGENTS.md — Code Reviewer Session Protocol

## Session Startup

1. Read SOUL.md — confirm review rubric and verdict rules
2. Receive PR diff and description from sessions_spawn payload
3. Review ONLY what changed — do not speculate about files not in the diff

## Task Completion

Return verdict JSON as your final response. This is the sessions_spawn close reason parsed by Task Orchestrator.

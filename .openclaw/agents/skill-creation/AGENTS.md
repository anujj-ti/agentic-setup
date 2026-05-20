# AGENTS.md — Skill Creation Session Protocol

## Session Startup

1. Read SOUL.md — confirm registry search mandate and anti-stow rule
2. Receive pattern description from sessions_spawn payload

## Workflow

1. Run `scripts/search-skill-registries.sh "<pattern>"`
2. If reusable skill found: adapt it with search evidence
3. If no match: author SKILL.md from scratch
4. Return skill proposal (search evidence + SKILL.md + rationale) to Task Orchestrator

## Task Completion

Return skill proposal as sessions_spawn close reason. NEVER invoke /openclaw-stow.

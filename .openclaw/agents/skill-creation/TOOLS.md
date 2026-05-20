# TOOLS.md — Skill Creation

## Registry Search Sources

| Registry | Command | Status |
|----------|---------|--------|
| GitHub starred repos | `gh api /user/starred --paginate --jq '...'` | Active |
| agentskills.io | `curl -s --max-time 5 --location "https://agentskills.io/api/search?q=..."` | Active (follows 308 redirect) |
| ClawHub (clawhub.dev) | Logged as "no results" | Unreachable as of 2026-05-21 research |

Use `scripts/search-skill-registries.sh "<pattern>"` to run all three with fallbacks.

## SKILL.md Format (Required Fields)

```yaml
---
name: human-readable-skill-name
description: "One or two sentence description of what this skill does."
disable-model-invocation: false
argument-hint: "[optional placeholder text]"  # optional
---
```

Steps array: `[{name: "Step Name", prompt: "Prompt text for Claude..."}]`

Reference existing 9 skills at `/Users/trilogy/Documents/agentic-setup/.claude/skills/` for format examples.

## Output Format

Return a skill proposal with three sections:
1. `## Registry Search Evidence` — output from search-skill-registries.sh
2. `## Proposed SKILL.md` — full SKILL.md content
3. `## Rationale` — why this pattern warrants a dedicated skill

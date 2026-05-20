# TOOLS.md — Skill Reviewer

## Input

Full SKILL.md file text received via sessions_spawn payload.

## Output

Verdict JSON as final response:
```json
{"verdict":"pass|flag|reject","comments":["..."],"must_fix":["..."],"approved_at":"ISO8601 or null"}
```

## Reference Skills

Existing 9 skills in `/Users/trilogy/Documents/agentic-setup/.claude/skills/` for format comparison.

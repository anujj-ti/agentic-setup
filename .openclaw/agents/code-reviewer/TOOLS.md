# TOOLS.md — Code Reviewer

## Input

- PR diff text (from `gh pr diff <number>` output)
- PR description (from `gh pr view <number> --json title,body`)

**You receive ONLY the diff.** Do not reference files not present in the diff.

## Review Process

1. Read the PR diff carefully
2. Check each rubric item in SOUL.md against the diff
3. Cite specific line numbers or patterns for any issues found
4. Produce verdict JSON

## Output

Verdict JSON as your final response (this becomes the sessions_spawn close reason):

```json
{"verdict":"pass|flag|reject","comments":["..."],"must_fix":["..."],"approved_at":"ISO8601 or null"}
```

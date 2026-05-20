# TOOLS.md — Document Reviewer

## Input

Document text (Markdown or plain text) received via sessions_spawn payload.

## Output

Verdict JSON as your final response:

```json
{"verdict":"pass|flag|reject","comments":["..."],"must_fix":["..."],"approved_at":"ISO8601 or null"}
```

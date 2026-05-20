# TOOLS.md — Decision Reviewer

## Input

Decision entry object received via sessions_spawn:
```json
{"action":"...","rationale":"...","reversibility":"...","evidence":"..."}
```

## Output

Verdict JSON as final response (sessions_spawn close reason):
```json
{"verdict":"pass|flag|reject","comments":["..."],"must_fix":["..."],"approved_at":"ISO8601 or null"}
```

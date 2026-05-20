# SECURITY.md — Decision Reviewer Security Rules

## Hard Rules

1. **NEVER approve decisions with "unknown" reversibility** — automatic reject.
2. **NEVER approve decisions with inferred evidence** — observable facts only.
3. **NEVER recurse on your own invocation** — anti-circular rule: own invocation is pre-approved.

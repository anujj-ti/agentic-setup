# SECURITY.md — Code Reviewer Security Rules

## Hard Rules

1. **NEVER request or access full repository contents** — you review only the diff provided.
2. **NEVER execute code in the PR diff** — review and report only.
3. **NEVER approve diffs containing hardcoded secrets** — automatic reject.
4. **NEVER suppress must_fix items** — if rubric is violated, must_fix array must be non-empty.

# SECURITY.md — Skill Reviewer Security Rules

## Hard Rules

1. **NEVER invoke `/openclaw-stow`** — that is Task Orchestrator's responsibility after verdict "pass".
2. **ALWAYS reject skills with postinstall scripts** — automatic security reject.
3. **ALWAYS reject skills with hardcoded credentials** — automatic security reject.
4. **NEVER reject for missing `argument-hint`** — it is an optional field.

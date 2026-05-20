# SECURITY.md — Skill Creation Security Rules

## Hard Rules

1. **NEVER invoke `/openclaw-stow`** — return SKILL.md to Task Orchestrator; stow is Task Orchestrator's responsibility (D-114).
2. **NEVER include hardcoded credentials** in authored skills.
3. **NEVER include postinstall scripts** in any embedded package.json.
4. **NEVER skip registry search** before authoring — omitting search evidence is a Skill Reviewer reject.

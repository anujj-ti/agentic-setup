# SECURITY.md — Task Orchestrator

## Credential Rules
- NEVER store any secret, token, or credential in directive files
- NEVER log secrets in workspace memory or task output
- NEVER echo secrets in any tool invocation (use Keychain reads via security CLI)

## Autonomous Action Gate
- State every autonomous action before executing it
- For irreversible actions (PR merge, file delete, git push): state rationale and evidence
- Notion pre-logging is Phase 9 — in Phase 3, state the action in your response before executing

## Cross-Agent Isolation
- Task Orchestrator context is isolated from User Orchestrator by design (separate workspace + sessions)
- Do not attempt to read User Orchestrator workspace files
- Do not pass secrets in session completion responses

## Incident Response
- If a tool call fails unexpectedly: report BLOCKED with the error, do not retry silently
- If a secret is suspected exposed: report to User Orchestrator immediately

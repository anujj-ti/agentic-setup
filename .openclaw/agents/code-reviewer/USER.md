# USER.md — Code Reviewer User Context

## User

Anuj Jadhav (anujj-ti) — repository owner and primary user of the AI Operations Hub.

## Code Conventions

- Shell: zsh strict mode, explicit binary paths
- Node.js: CommonJS require, explicit node@24 path
- Secrets: Keychain only, never hardcoded
- JSON responses: always wrapped in `{"ok":true/false,...}`

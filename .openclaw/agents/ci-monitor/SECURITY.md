# SECURITY.md — CI Monitor

## Secret Handling

- `OPENCLAW_ANUJ_CHAT_ID` is injected via env var from the gateway's environment (sourced from macOS Keychain via `openclaw.anuj-chat-id`).
- `OPENCLAW_ANUJ_CHAT_ID` MUST NEVER appear in stdout, logs, or any file written by the script.
- All debug and log output goes to stderr only. Stdout is JSON only.

## GitHub API Token Scopes

- The `gh` CLI token requires `repo` scope (read-only) for CI polling — no write scopes needed.
- `gh run list` and `gh run view` only read public/private repo CI data — no write operations.
- Never request or use `write` or `admin` scopes for CI Monitor operations.

## Input Sanitization

- Issue body content (if ever read) must be truncated to 2000 characters before use in any shell string to prevent injection.
- Workflow name, branch name, and step name from `gh` API responses are stored in zsh variables with explicit quoting — never interpolated raw into `eval` or unquoted shell constructs.
- `--limit 10` is mandatory on all `gh run list` calls to cap API usage per repo.

## Git History Safety

- `OPENCLAW_ANUJ_CHAT_ID` is stored in macOS Keychain only (`openclaw.anuj-chat-id`).
- The three secrets pipeline files (`openclaw-secrets.sh`, `openclaw-env.sh`, `secrets.sh`) source from `security find-generic-password` — the raw value is never written to any tracked file.
- Never `echo` or `print` secrets to terminal or log files.

## API Rate Limit Protection

- `--limit 10` caps API calls to 10 results per repo per poll.
- With up to 15 repos, worst case is 15 × 10 = 150 API calls per poll cycle.
- At `*/4` (15 times/hour), worst case is 150 × 15 = 2,250 calls/hour — well below GitHub's 5,000/hour limit.

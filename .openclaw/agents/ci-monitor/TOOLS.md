# TOOLS.md — CI Monitor

## Primary Tool

```zsh
exec scripts/poll-ci.sh
```

Runs the full poll-deduplicate-alert cycle. Returns:
```json
{"ok": true, "new_failures": N, "alerted": true|false}
```

This is the ONLY tool CI Monitor calls directly. All other tools below are called by the script.

---

## Script-Level Tools (called by poll-ci.sh, not the agent directly)

### GitHub Actions: List recent failures per repo

```zsh
/opt/homebrew/bin/gh run list \
  -R OWNER/REPO \
  --status failure \
  --json databaseId,conclusion,url,workflowName,headBranch,createdAt \
  --limit 10
```

### GitHub Actions: Get jobs for a specific run (to extract failing step)

```zsh
/opt/homebrew/bin/gh run view <run-id> \
  -R OWNER/REPO \
  --json jobs
```

### Telegram Alert (imperative send — requires Node 24 in PATH)

```zsh
PATH="/opt/homebrew/opt/node@24/bin:$PATH" \
  /opt/homebrew/bin/openclaw message send \
  --channel telegram \
  --target "$OPENCLAW_ANUJ_CHAT_ID" \
  --message "CI FAILED [OWNER/REPO] workflow on branch — step: step_name — https://..."
```

**CRITICAL:** Always prefix `PATH="/opt/homebrew/opt/node@24/bin:$PATH"` before invoking `openclaw`. Without this, nvm may shadow Node with an incompatible version and the command will fail silently.

---

## State Files

| File | Purpose |
|------|---------|
| `state/last-seen-runs.json` | Run ID deduplication — JSON object mapping run IDs to `true` |
| `state/tracked-repos.txt` | One `OWNER/REPO` per line; blank lines and `#` comments are ignored |

---

## Binary Paths

| Binary | Path |
|--------|------|
| gh CLI | `/opt/homebrew/bin/gh` |
| openclaw | `/opt/homebrew/bin/openclaw` |
| Node 24 | `/opt/homebrew/opt/node@24/bin/node` |

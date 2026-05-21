# Notion API — Authentication

> Source: https://developers.notion.com/reference/authentication

## Method

HTTP bearer token in every request.

## Required Headers

```
Authorization: Bearer {OPENCLAW_NOTION_TOKEN}
Notion-Version: 2026-03-11
```

## cURL

```bash
curl 'https://api.notion.com/v1/users' \
  -H "Authorization: Bearer $OPENCLAW_NOTION_TOKEN" \
  -H "Notion-Version: 2026-03-11"
```

## JavaScript SDK (our usage)

```javascript
const { Client } = require('@notionhq/client');

const notion = new Client({
  auth: process.env.OPENCLAW_NOTION_TOKEN,  // from Keychain via openclaw-secrets.sh
  notionVersion: "2026-03-11"
});
```

The SDK handles the `Authorization` and `Notion-Version` headers automatically on every call.

## Token Storage

```
Keychain service:  openclaw.notion-token
Env var:           OPENCLAW_NOTION_TOKEN
Exported by:       ~/.openclaw/scripts/openclaw-secrets.sh (launchd)
                   ~/.openclaw/scripts/openclaw-env.sh (shell sessions)
```

## TODO_NOTION Guard Pattern (our convention)

All Notion scripts check for the token before attempting API calls:

```javascript
if (!process.env.OPENCLAW_NOTION_TOKEN) {
  console.error('[notion] OPENCLAW_NOTION_TOKEN not set — logging to local fallback');
  // write to ~/.openclaw/agents/task-orchestrator/state/pending-decisions.json
  process.exit(0); // exit 0 so agents are never blocked
}
```

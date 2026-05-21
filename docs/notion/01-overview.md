# Notion API — Overview

> Source: https://developers.notion.com/guides/get-started/overview

## What is a Notion Connection?

Connects a workspace to external apps/tools. Requires explicit permission to access pages and databases.

## Connection Types

| Type | Best For | Auth |
|------|----------|------|
| **Internal connections** | Team automations in one workspace | Static API token |
| **Public connections** | Apps used by many users/workspaces | OAuth 2.0 |
| **Personal access tokens (PATs)** | User-owned scripts, CLI workflows | Static bearer token |

**We use: Internal connection** — single workspace, static token, no OAuth complexity.

## Capabilities

Each connection defines what it can do:
- Read content
- Update content
- Insert content
- Read comments

## Content Access

Internal connections get access two ways:
1. Connection owner adds pages from the Developer portal Content Access tab
2. Workspace members share pages via the Add connections menu in Notion

## Key API Facts

- **Base URL:** `https://api.notion.com`
- **Required header:** `Notion-Version: 2026-03-11`
- **Rate limit:** ~3 requests/second; 429 responses include `Retry-After`
- **IDs:** UUIDv4 (dashes optional in requests)
- **Naming:** snake_case properties, ISO 8601 timestamps
- **Pagination:** `has_more` + `next_cursor` + `results` pattern

## SDK

```bash
npm install @notionhq/client@5.22.0
```

```javascript
const { Client } = require('@notionhq/client');
const notion = new Client({
  auth: process.env.OPENCLAW_NOTION_TOKEN,
  notionVersion: "2026-03-11"
});
```

## Resources

- SDK: https://github.com/makenotion/notion-sdk-js
- Postman: https://www.postman.com/notionhq/notion-s-api-workspace/
- Slack: https://join.slack.com/t/notiondevs/

# Notion API Reference — OpenClaw Hub

Fetched from developers.notion.com on 2026-05-21.
Used by: Task Orchestrator (Phase 9), log-decision.js, query-decisions.js, create-experiment-page.js.

## Files

| File | Contents |
|------|----------|
| [01-overview.md](01-overview.md) | Connection types, capabilities, getting started |
| [02-authentication.md](02-authentication.md) | Bearer tokens, headers, SDK setup |
| [03-create-integration.md](03-create-integration.md) | Step-by-step internal connection setup |
| [04-create-page.md](04-create-page.md) | POST /v1/pages — log decisions, create entries |
| [05-query-database.md](05-query-database.md) | POST /v1/databases/:id/query — filter by date, status |
| [06-create-database.md](06-create-database.md) | POST /v1/databases — create decisions/experiments DB |

## Quick Reference

```javascript
const { Client } = require('@notionhq/client');
const notion = new Client({
  auth: process.env.OPENCLAW_NOTION_TOKEN,
  notionVersion: "2026-03-11"
});
```

**API base:** `https://api.notion.com`
**Version header:** `Notion-Version: 2026-03-11`
**Rate limit:** ~3 requests/second

## Our Databases

| Database | Env Var | Purpose |
|----------|---------|---------|
| Autonomous Decisions | `NOTION_DECISIONS_DB_ID` | Pre-log every agent action |
| Experiments | `NOTION_EXPERIMENTS_DB_ID` | Hypothesis → results lifecycle |

Config: `~/.openclaw/agents/task-orchestrator/scripts/notion/config.json`

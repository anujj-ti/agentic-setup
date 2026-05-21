# Notion API — Create a Page (Log a Decision)

> Source: https://developers.notion.com/reference/post-page

## Endpoint

```
POST https://api.notion.com/v1/pages
```

## Usage in Our Project

Used by `log-decision.js` to create a Notion entry before every autonomous agent action.

## Request

```javascript
const response = await notion.pages.create({
  parent: { database_id: process.env.NOTION_DECISIONS_DB_ID },
  properties: {
    Name: {
      title: [{ text: { content: decision.summary } }]
    },
    Decision: {
      rich_text: [{ text: { content: decision.decision } }]
    },
    Rationale: {
      rich_text: [{ text: { content: decision.rationale } }]
    },
    Evidence: {
      rich_text: [{ text: { content: decision.evidence } }]
    },
    Reversibility: {
      select: { name: decision.reversibility } // "reversible" | "irreversible" | "partial"
    },
    RevertStatus: {
      select: { name: "active" }
    },
    Timestamp: {
      date: { start: new Date().toISOString() }
    },
    AgentId: {
      rich_text: [{ text: { content: decision.agentId } }]
    }
  }
});

return response.id; // page ID — must be non-empty before merge/action proceeds
```

## Response

```json
{
  "object": "page",
  "id": "uuid",
  "url": "https://www.notion.so/...",
  "created_time": "2026-05-21T...",
  "properties": { ... }
}
```

## Parameters

| Parameter | Required | Description |
|-----------|----------|-------------|
| `parent.database_id` | Yes | Target database UUID |
| `properties` | Yes | Must match database schema |
| `children` | No | Block content to add to page body |

## Error Handling

```javascript
try {
  const page = await notion.pages.create({ ... });
  return page.id;
} catch (err) {
  if (err.status === 401) // token invalid
  if (err.status === 403) // no access to DB
  if (err.status === 404) // DB not found (wrong ID or not shared)
  if (err.status === 429) // rate limited — retry after err.headers['retry-after']
}
```

## Notes

- Cannot set: `rollup`, `created_by`, `created_time`, `last_edited_by`, `last_edited_time`
- Rich text fields: max 2000 chars per block; use multiple blocks for longer content
- Requires **Insert Content** capability on the integration

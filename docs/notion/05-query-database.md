# Notion API — Query a Database

> Source: https://developers.notion.com/reference/post-database-query

## Endpoint

```
POST https://api.notion.com/v1/databases/{database_id}/query
```

## Usage in Our Project

Used by `query-decisions.js` to retrieve decisions since last session ("what did you do while I was away?").

## Filter by Date (Since Last Session)

```javascript
const lastSession = require('./last-session.json'); // { timestamp: "2026-05-21T..." }

const response = await notion.databases.query({
  database_id: process.env.NOTION_DECISIONS_DB_ID,
  filter: {
    timestamp: "created_time",
    created_time: {
      on_or_after: lastSession.timestamp
    }
  },
  sorts: [
    { timestamp: "created_time", direction: "ascending" }
  ]
});

return response.results; // array of page objects
```

## Filter by Property

```javascript
// Find all non-reverted decisions
const response = await notion.databases.query({
  database_id: process.env.NOTION_DECISIONS_DB_ID,
  filter: {
    property: "RevertStatus",
    select: { equals: "active" }
  }
});
```

## Compound Filter

```javascript
filter: {
  and: [
    {
      timestamp: "created_time",
      created_time: { on_or_after: "2026-05-21T00:00:00Z" }
    },
    {
      property: "RevertStatus",
      select: { equals: "active" }
    }
  ]
}
```

## Pagination

```javascript
let results = [];
let cursor = undefined;

do {
  const response = await notion.databases.query({
    database_id: DB_ID,
    start_cursor: cursor,
    page_size: 100
  });
  results = results.concat(response.results);
  cursor = response.has_more ? response.next_cursor : undefined;
} while (cursor);
```

## Response Shape

```json
{
  "object": "list",
  "results": [
    {
      "object": "page",
      "id": "uuid",
      "created_time": "2026-05-21T...",
      "properties": {
        "Name": { "title": [{ "plain_text": "..." }] },
        "Decision": { "rich_text": [{ "plain_text": "..." }] },
        "RevertStatus": { "select": { "name": "active" } }
      }
    }
  ],
  "has_more": false,
  "next_cursor": null
}
```

## Important: Timestamp Filters

**Timestamp filters use `timestamp` key, NOT `property`:**

```javascript
// ✅ Correct
filter: { timestamp: "created_time", created_time: { on_or_after: "..." } }

// ❌ Wrong — will throw API error
filter: { property: "created_time", created_time: { on_or_after: "..." } }
```

## Notes

- Default page_size: 100 (max 100)
- Database must be shared with integration (returns 404 if not)
- Requires **Read Content** capability

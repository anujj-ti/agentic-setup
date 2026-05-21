# Notion API — Create a Database

> Source: https://developers.notion.com/reference/create-a-database

## Endpoint

```
POST https://api.notion.com/v1/databases
```

## Usage in Our Project

Used by `create-experiment-page.js` if the experiments database needs to be provisioned programmatically. Normally databases are created manually and IDs stored in config.json.

## Create Decisions Database Programmatically

```javascript
const response = await notion.databases.create({
  parent: {
    type: "page_id",
    page_id: "your-parent-page-id" // page where DB will live
  },
  title: [{ text: { content: "Autonomous Decisions" } }],
  properties: {
    Name: { title: {} },                          // required — always "Name"
    Decision: { rich_text: {} },
    Rationale: { rich_text: {} },
    Evidence: { rich_text: {} },
    Reversibility: {
      select: {
        options: [
          { name: "reversible", color: "green" },
          { name: "irreversible", color: "red" },
          { name: "partial", color: "yellow" }
        ]
      }
    },
    RevertStatus: {
      select: {
        options: [
          { name: "active", color: "blue" },
          { name: "reverted", color: "gray" },
          { name: "pending", color: "orange" }
        ]
      }
    },
    Timestamp: { date: {} },
    AgentId: { rich_text: {} }
  }
});

console.log("Decisions DB ID:", response.id);
// Save this ID to config.json as NOTION_DECISIONS_DB_ID
```

## Response

```json
{
  "object": "database",
  "id": "uuid",   // ← save this as NOTION_DECISIONS_DB_ID
  "url": "https://www.notion.so/..."
}
```

## Requirements

- Parent page must be shared with the integration
- Requires **Insert Content** capability
- `Name` property (title type) is always required

## Manual Setup (Recommended)

Creating databases manually in Notion UI is simpler than the API:
1. Create page in Notion
2. Type `/database` → select "Table"  
3. Add properties matching the schema above
4. Share with integration via "..." → "Add connections"
5. Get ID from URL

See `03-create-integration.md` for the full manual setup walkthrough.

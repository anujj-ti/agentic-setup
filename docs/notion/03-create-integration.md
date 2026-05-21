# Notion API — Creating an Internal Integration

> Source: https://developers.notion.com/guides/get-started/create-a-notion-integration

## Steps to Create an Internal Connection

### 1. Go to the Developer Portal

- **New UI:** https://www.notion.so/developers/connections → click "Develop or manage integrations"
- **Direct:** https://www.notion.so/my-integrations

### 2. Create New Integration

- Click **"+ New integration"** (or "Create new integration")
- **Name:** `openclaw-hub`
- **Associated workspace:** your workspace
- **Capabilities:** ✅ Read content, ✅ Update content, ✅ Insert content
- Click **Submit**
- Copy the **Internal Integration Secret** → starts with `secret_...`

### 3. Store Token in Keychain

```bash
security add-generic-password -s 'openclaw.notion-token' -a "$USER" -U -w
# paste the secret_... token when prompted
```

### 4. Grant Access to Databases

After creating databases:
- Open the database in Notion
- Click **"..."** menu → **"Add connections"**
- Search for `openclaw-hub` → select it
- ✅ Connection can now read/write that database

### 5. Get Database IDs

Open each database in browser. URL format:
```
https://www.notion.so/your-workspace/XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX?v=...
                                    ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
                                    This 32-char hex string is the DB ID
```

Add dashes to make it UUIDv4: `xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx`

### 6. Update Config File

```bash
# Edit the config file with your DB IDs
nano ~/.openclaw/agents/task-orchestrator/scripts/notion/config.json
```

```json
{
  "NOTION_DECISIONS_DB_ID": "paste-decisions-database-id-here",
  "NOTION_EXPERIMENTS_DB_ID": "paste-experiments-database-id-here"
}
```

## Decision Database Schema

Create a database called **"Autonomous Decisions"** with these properties:

| Property | Type | Notes |
|----------|------|-------|
| Name | Title (default) | Summary of the decision |
| Decision | Text | What was decided |
| Rationale | Text | Why this decision was made |
| Evidence | Text | Factual evidence supporting it |
| Reversibility | Select | Options: reversible, irreversible, partial |
| RevertStatus | Select | Options: active, reverted, pending |
| Timestamp | Date | When the decision was made |
| AgentId | Text | Which agent made the decision |

## Experiments Database Schema

Create a database called **"Experiments"** — just needs a Title for now. The experiment scripts create page content (blocks) rather than properties.

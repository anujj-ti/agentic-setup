---
name: synapse
description: Interact with Synapse, the org-wide memory and coordination layer. Use when starting any non-trivial task, recording facts/learnings from a run, querying prior learnings from other teams, tracking progress, or fetching operator briefs. Two contexts: (1) agentic-setup infrastructure work — project.agentic-setup; (2) EduLLM SAT Math — project.edullm-sat-math.
---

# Synapse — Organizational Memory

Synapse is the org's centralized memory and coordination service. All agents — Claude Code, OpenClaw User Orchestrator, Task Orchestrator, DevBot, CI Monitor — share a single token.

```
Base URL:    https://cnu.synapse-os.ai   (env: $SYNAPSE_URL)
Auth:        Authorization: Bearer $SYNAPSE_TOKEN
Token:       Keychain → openclaw.synapse-token → SYNAPSE_TOKEN

Projects:
  Infrastructure / agentic-setup:  project.agentic-setup
  EduLLM SAT Math:                 project.edullm-sat-math
  Team ID:                         team.edullm
```

`$SYNAPSE_TOKEN` and `$SYNAPSE_URL` are injected into every OpenClaw agent via `openclaw-secrets.sh` (launchd) and `openclaw-env.sh` (shell). Claude Code reads them from the shell env.

---

## Mandatory operating loop (every non-trivial run)

Run this on any task that changes code, configures agents, creates phases, runs evals, or produces artifacts.

### Step 0 — Fetch briefs (ALWAYS first)

```bash
curl -sS -X POST "$SYNAPSE_URL/v1/intent/synapse.brief.fetch" \
  -H "Authorization: Bearer $SYNAPSE_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"project_id": "PROJECT_ID", "include_acked": false}'
```

Read each `brief.body` fully — treat it as an operator amendment to your instructions. Ack immediately:

```bash
curl -sS -X POST "$SYNAPSE_URL/v1/intent/synapse.brief.ack" \
  -H "Authorization: Bearer $SYNAPSE_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"brief_id": "<uuid>"}'
```

Empty list is fine. Do the fetch anyway — it costs almost nothing.

### Step 1 — Query prior learnings before starting

```bash
curl -sS -X POST "$SYNAPSE_URL/v1/intent/synapse.learning.query" \
  -H "Authorization: Bearer $SYNAPSE_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "project_id": "PROJECT_ID",
    "applies_to": ["tag1", "tag2"],
    "cross_silo": true
  }'
```

Save the `learning_id`s you actually apply — you'll need them for the close-loop step.

### Step 2 — Open a workflow

```bash
curl -sS -X POST "$SYNAPSE_URL/v1/intent/synapse.workflow.create" \
  -H "Authorization: Bearer $SYNAPSE_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "project_id": "PROJECT_ID",
    "target_objective_id": "<okr_id from active_okrs>",
    "workflow_class": "investigation",
    "title": "<short description>"
  }'
```

Save the `bd_id`. Pass it in every subsequent call.

### Step 3 — Check in as you work

States: `start` | `progress` | `blocked` | `complete` | `failed`

```bash
curl -sS -X POST "$SYNAPSE_URL/v1/intent/synapse.checkin" \
  -H "Authorization: Bearer $SYNAPSE_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "bd_id": "<bd_id>",
    "status": "progress",
    "current_task": "<what you just did or are doing>",
    "target_objective_id": "<same okr_id>"
  }'
```

### Step 4 — Upload evidence, then record facts

```bash
# 1. Upload artifact
ARTIFACT=$(curl -sS -X POST "$SYNAPSE_URL/v1/intent/synapse.artifact.upload" \
  -H "Authorization: Bearer $SYNAPSE_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "project_id": "PROJECT_ID",
    "bd_id": "<bd_id>",
    "kind": "text",
    "description": "<what this artifact shows>",
    "content_b64": "'$(echo -n "<content>" | base64)'"
  }')
ARTIFACT_ID=$(echo $ARTIFACT | python3 -c "import sys,json; print(json.load(sys.stdin)['data']['artifact_id'])")

# 2. Record fact citing artifact
curl -sS -X POST "$SYNAPSE_URL/v1/intent/synapse.fact.record" \
  -H "Authorization: Bearer $SYNAPSE_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "project_id": "PROJECT_ID",
    "bd_id": "<bd_id>",
    "facts": [{
      "claim": "<verified, specific statement>",
      "confidence": "high",
      "evidence_artifact_id": "'$ARTIFACT_ID'"
    }]
  }'
```

**COMPLIANCE:** medium/high confidence MUST include `evidence_artifact_id`. Missing it will reject the fact and dock trust score.

### Step 5 — Record learnings (reusable insights)

```bash
curl -sS -X POST "$SYNAPSE_URL/v1/intent/synapse.learning.record" \
  -H "Authorization: Bearer $SYNAPSE_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "project_id": "PROJECT_ID",
    "bd_id": "<bd_id>",
    "learnings": [{
      "claim": "<non-obvious reusable insight>",
      "applies_to": ["tag1", "tag2"],
      "confidence": "medium",
      "non_obvious_marker": "<why this is not obvious>",
      "evidence_artifact_id": "'$ARTIFACT_ID'"
    }]
  }'
```

### Step 6 — Close the loop on learnings you used

```bash
curl -sS -X POST "$SYNAPSE_URL/v1/intent/synapse.checkin" \
  -H "Authorization: Bearer $SYNAPSE_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "bd_id": "<bd_id>",
    "status": "complete",
    "current_task": "Workflow complete",
    "target_objective_id": "<same okr_id>",
    "used_learnings": [
      {"learning_id": "<id>", "outcome": "resolved|partial|unhelpful"}
    ]
  }'
```

---

## Project contexts and tags

### project.agentic-setup — Personal AI Operations Hub

Use when working on: OpenClaw infrastructure, agent scaffolding, phases/plans, secrets pipeline, stow deploy, dream routines, quality pipeline, Beads task graphs, CI/CD.

| Area | Tags |
|------|------|
| Infrastructure | `openclaw`, `stow`, `launchd`, `node24`, `secrets-pipeline` |
| Agent setup | `agent-scaffolding`, `soul-md`, `memory`, `dream-routine` |
| Beads / task graphs | `beads`, `task-graph`, `claim-close` |
| Phases / GSD | `gsd`, `planning`, `phase-execution` |
| Security / secrets | `keychain`, `secrets`, `security` |
| Telegram / channels | `telegram`, `openclaw-channel` |
| Quality pipeline | `code-reviewer`, `skill-creation`, `quality-pipeline` |

### project.edullm-sat-math — EduLLM SAT Math

Use when working on: SAT question generation, SVG rendering, evals/benchmarks, curriculum data.

| Area | Tags |
|------|------|
| SVG generation | `svg-gen`, `renderer`, `coordinate-plane` |
| Question generation | `question-generation`, `mcq`, `spr` |
| Evals | `evals`, `inceptbench`, `scoring` |
| Data | `dataset`, `curriculum`, `sat`, `psat` |
| API / infra | `api`, `fastapi`, `gcs`, `langfuse` |

---

## Hard rules

1. **Always** fetch + ack briefs before any non-trivial run
2. **Always** bind to an `active_okr` via `target_objective_id` — pass it on every check-in
3. **Never** record medium/high confidence without `evidence_artifact_id`
4. **Always** close the loop with `used_learnings` for every learning you applied
5. On 401 → re-enroll (get new enrollment code from operator)
6. On 400 → read `detail.field_errors` and fix before retrying
7. On unknown intent → check `https://cnu.synapse-os.ai/docs`

---

## OpenClaw agent usage

The OpenClaw agents (User Orchestrator, Task Orchestrator, DevBot, CI Monitor) receive `$SYNAPSE_TOKEN` and `$SYNAPSE_URL` automatically via `openclaw-secrets.sh` (launchd injection). They can call Synapse via `exec` tool using the `curl` patterns above.

**Recommended: add Synapse check-in to AGENTS.md** for any agent doing non-trivial autonomous work:

```markdown
## Synapse Coordination (mandatory for autonomous tasks)
Before starting any task that creates artifacts, modifies files, or calls external APIs:
1. Call synapse.brief.fetch for project.agentic-setup
2. Open a workflow with synapse.workflow.create
3. Check in with synapse.checkin at start, progress, and completion
4. Record learnings with applies_to tags from your domain
```

---

## Quick reference — secret location

| Location | Key | Value |
|----------|-----|-------|
| macOS Keychain | `openclaw.synapse-token` | SYNAPSE_TOKEN value |
| openclaw-secrets.sh | `$SYNAPSE_TOKEN` | Keychain fetch at launchd boot |
| openclaw-env.sh | `$SYNAPSE_TOKEN` | Keychain fetch in shell sessions |
| EduLLM-SAT-Math .env | `SYNAPSE_TOKEN` | Direct value (legacy) |

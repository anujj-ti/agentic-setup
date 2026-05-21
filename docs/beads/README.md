# Beads (bd) — Full Reference for OpenClaw Agents

Fetched from https://gastownhall.github.io/beads/ on 2026-05-21.
Used by: Task Orchestrator, DevBot, CI Monitor, all execution-tier agents.

```
Binary:    /opt/homebrew/opt/node@24/bin/bd  (explicit path — nvm shadows)
BEADS_DIR: $HOME/.openclaw/beads
Prefix:    tskorch  (issue IDs: tskorch-abc, tskorch-abc.1, tskorch-abc.2)
Version:   1.0.4
Mode:      stealth (no git ops, embedded Dolt)
```

---

## Core Concepts

### Issues
Work items with: ID (hash-based like `tskorch-a1b2` or child `tskorch-a1b2.1`), type, priority, status, labels, dependencies.

**Types:** `bug` | `feature` | `task` | `epic` | `chore` | `decision`  
**Priority:** 0 (critical) → 4 (backlog). Use numbers, NOT "high"/"medium"/"low".  
**Status:** `open` → `in_progress` → `closed` (or `blocked`, `deferred`)

### Dependency Types
| Type | Meaning | Affects `bd ready`? |
|------|---------|---------------------|
| `blocks` | Hard dependency — X must close before Y unblocks | Yes |
| `parent-child` | Epic/subtask relationship | No |
| `discovered-from` | Found this issue while working on that one | No |
| `related` | Soft relationship, no ordering | No |
| `tracks` | Tracks external item | No |
| `until` | Wait until date/event | Yes |
| `caused-by` | Root cause relationship | No |
| `validates` | Validates another issue | No |
| `supersedes` | Replaces another issue | No |

### Molecules, Formulas, Wisps
- **Formula (Proto)**: Declarative workflow template (TOML/JSON). Reusable.
- **Molecule**: Instantiated formula — a persistent work graph. Created with `bd mol pour`.
- **Wisp**: Ephemeral workflow (not git-tracked). Auto-expires. Use for one-off ops.

### Gates
Async wait conditions that block workflow steps:
- **Human gate**: Waits for manual `bd gate resolve`
- **Timer gate**: Auto-resolves after `--timeout` duration
- **GitHub gate**: `gh:run` (Actions) or `gh:pr` (PR merge)
- **Bead gate**: Cross-rig synchronization

---

## Essential Commands

### Session Start
```zsh
# ALWAYS run at session start (hooks do this automatically in Claude Code)
BEADS_DIR="$HOME/.openclaw/beads" bd prime

# Check what's ready
BEADS_DIR="$HOME/.openclaw/beads" bd ready --json
```

### Create Issues
```zsh
BD="BEADS_DIR=$HOME/.openclaw/beads /opt/homebrew/opt/node@24/bin/bd"

# Basic task
$BD create "Implement feature X" -t task -p 2 -d "Why this exists and what needs to be done"

# Epic with deps inline
EPIC=$($BD create "Epic: full feature" -t epic -p 1 --json | python3 -c "import sys,json; print(json.load(sys.stdin)['id'])")
T1=$($BD create "Design phase" -t task --parent $EPIC --json | python3 -c "import sys,json; print(json.load(sys.stdin)['id'])")
T2=$($BD create "Implementation" -t task --parent $EPIC --deps "blocks:$T1" --json | python3 -c "import sys,json; print(json.load(sys.stdin)['id'])")

# With acceptance criteria + design notes
$BD create "Fix auth bug" -t bug -p 0 \
  -d "Auth fails on token refresh" \
  --acceptance "Token refreshes successfully without 401" \
  --design "Use retry with exponential backoff"

# Batch from JSON graph (most powerful for complex work)
$BD create --graph plan.json --json
```

### Find and Claim Work
```zsh
# Find unblocked work (blocker-aware — NOT the same as bd list --status open)
$BD ready --json

# Find work in a specific molecule
$BD ready --mol $MOL_ID --json

# Atomically claim first ready issue
$BD ready --claim --json

# Claim specific issue
$BD update $ID --claim --json

# Show why something is blocked
$BD ready --explain
$BD dep tree $ID
```

### Execute and Close
```zsh
# Close with reason (required for evidence)
$BD close $ID --reason "Fixed in commit abc123 — auth now retries on 401"

# Close multiple at once
$BD close $ID1 $ID2 $ID3 --reason "All completed in this session"

# Close and auto-claim next ready issue
$BD close $ID --claim-next --json

# Close and auto-advance to next molecule step
$BD close $ID --continue --json

# Close and show newly unblocked issues
$BD close $ID --suggest-next
```

### Manage Dependencies
```zsh
# Add a blocking dependency (T2 blocks on T1)
$BD dep add $T2 $T1              # T2 depends on T1 (T1 blocks T2)
$BD dep add $T2 $T1 -t blocks    # explicit

# Add discovered-from (tracking)
$BD dep add $NEW_ISSUE $CURRENT_ISSUE -t discovered-from

# Visualize dependency tree
$BD dep tree $EPIC_ID
$BD graph $EPIC_ID               # visual DAG (parallel layers shown)
$BD graph $EPIC_ID --box         # ASCII boxes by execution layer

# Check for cycles
$BD dep cycles
$BD graph check
```

### Multi-Agent Coordination
```zsh
# Assign to specific agent
$BD update $ID --assignee agent-devbot

# Pin work to agent (appears in their hook)
$BD update $ID --assignee agent-task-orchestrator

# Reserve file (prevent concurrent edits)
$BD reserve auth.go --for agent-devbot

# Lock issue (exclusive access)
$BD lock $ID --for agent-task-orchestrator

# Check what's pinned to me
$BD hook --json
```

### Gates
```zsh
# Create human gate (blocks issue until manually resolved)
$BD gate create --blocks $ID --type human --reason "Need Anuj approval before merge"

# Timer gate (auto-resolves)
$BD gate create --blocks $ID --type timer --timeout 24h

# GitHub gates
$BD gate create --blocks $ID --type gh:pr --await-id $PR_NUMBER
$BD gate create --blocks $ID --type gh:run --await-id $RUN_ID

# Resolve a gate
$BD gate resolve $GATE_ID --reason "Approved"

# Check all gates
$BD gate list --all
$BD gate check
```

### Molecules and Formulas
```zsh
# List available formulas
$BD formula list

# Pour a formula into a molecule (instantiate)
$BD mol pour feature-implementation --var title="Auth refactor" --var priority=1

# View molecule structure
$BD mol show $MOL_ID

# Track molecule progress
$BD mol progress $MOL_ID

# Find gate-ready molecules
$BD mol ready --gated

# Create ephemeral wisp workflow
$BD mol wisp "Quick diagnostic" --steps "check-logs,analyze,report"
```

### Memories (Cross-Session Knowledge)
```zsh
# Save insight (survives session resets — NOT MEMORY.md)
$BD remember "openclaw gateway.mode=local is required in openclaw.json or gateway exits with EX_CONFIG"

# Search memories
$BD memories "gateway"
$BD memories "stow"
```

### Diagnostics
```zsh
$BD doctor                    # health check + sync status
$BD doctor --check=conventions  # lint, stale, orphans
$BD stats                     # open/closed/blocked counts
$BD blocked                   # all blocked issues
$BD orphans                   # issues with broken deps
$BD stale                     # no recent activity
$BD preflight                 # pre-PR checks
$BD lint                      # check issues for missing sections
```

### Session End Protocol
```zsh
# BEFORE EVERY SESSION END:
$BD close $COMPLETED_IDS ...  # close all completed work
$BD dolt push                 # sync to remote (CRITICAL for multi-agent)
```

---

## The 5-Subtask DevBot Epic Pattern

The Task Orchestrator SOUL.md mandates this for all DevBot implementations:

```zsh
BD="BEADS_DIR=$HOME/.openclaw/beads /opt/homebrew/opt/node@24/bin/bd"

EPIC=$($BD create "Implement: $ISSUE_TITLE" -t epic -p 1 \
  -d "Issue #$ISSUE_NUM: $ISSUE_BODY" --json | python3 -c "import sys,json; print(json.load(sys.stdin)['id'])")

T1=$($BD create "Design: $ISSUE_TITLE" -t task --parent $EPIC --json | python3 -c "import sys,json; print(json.load(sys.stdin)['id'])")
T2=$($BD create "Implement: $ISSUE_TITLE" -t task --parent $EPIC --json | python3 -c "import sys,json; print(json.load(sys.stdin)['id'])")
T3=$($BD create "Self-review" -t task --parent $EPIC --json | python3 -c "import sys,json; print(json.load(sys.stdin)['id'])")
T4=$($BD create "QA evidence" -t task --parent $EPIC --json | python3 -c "import sys,json; print(json.load(sys.stdin)['id'])")
T5=$($BD create "Open PR" -t task --parent $EPIC --json | python3 -c "import sys,json; print(json.load(sys.stdin)['id'])")

# Wire the chain: T2 blocks on T1, T3 on T2, etc.
$BD dep add $T2 $T1
$BD dep add $T3 $T2
$BD dep add $T4 $T3
$BD dep add $T5 $T4

# Verify graph
$BD dep tree $EPIC
$BD ready --json  # Only T1 should appear

# Spawn sub-agent only after this is committed
```

---

## JSON Graph Format (batch creation)

Create complex dependency graphs in one call:

```json
{
  "issues": [
    {"id": "t1", "title": "Design", "type": "task", "priority": 1},
    {"id": "t2", "title": "Implement", "type": "task", "priority": 2,
     "deps": [{"type": "blocks", "target": "t1"}]},
    {"id": "t3", "title": "Test", "type": "task", "priority": 2,
     "deps": [{"type": "blocks", "target": "t2"}]}
  ]
}
```

```zsh
$BD create --graph plan.json --json
```

---

## What's Different from Before

We were using a subset of Beads. Key powers we were missing:

| Feature | Old usage | Full power |
|---------|-----------|------------|
| Close | `bd close $ID` | `bd close $ID --continue` (auto-advance in molecule) |
| Next work | Manual | `bd close $ID --claim-next` |
| Dependencies | `--deps "blocks:$T1"` on create only | `bd dep add $T2 $T1 -t <type>` anytime, 10 dep types |
| Visualization | None | `bd graph $EPIC --box` shows parallel execution layers |
| Memory | MEMORY.md | `bd remember "..."` + `bd memories <keyword>` |
| Molecules | Not used | `bd mol pour <formula>` for structured workflows |
| Gates | Not used | Human/timer/GitHub async coordination |
| Reservations | Not used | `bd reserve <file> --for <agent>` collision prevention |
| Diagnostics | None | `bd doctor`, `bd stats`, `bd stale`, `bd orphans`, `bd preflight` |
| Session hook | None | `bd prime` auto-injects context on SessionStart + PreCompact |

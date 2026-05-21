# New Claude Code Session — Handoff

Open a new Claude Code session in `/Users/trilogy/Documents/agentic-setup` and paste the message below.

---

## What session to open for what

| Goal | Open in |
|------|---------|
| Infrastructure, phases, agent config | `agentic-setup` repo |
| EduLLM SAT Math features | `EduLLM-SAT-Math` repo |

---

## Paste this in a new session (agentic-setup)

```
I'm resuming work on the Personal AI Operations Hub. Here's the current state:

COMPLETED (12/14 phases):
- Phases 1-12: Infrastructure → Self-Evolution — all executed, agents live
- Beads formulas: feature/bugfix/investigation/review in docs/beads/formulas/
- Synapse: token in Keychain, wired into CLAUDE.md + all agent AGENTS.md/TOOLS.md
- bd prime: auto-runs on SessionStart and PreCompact via .claude/settings.json
- Stow deployed: all agent configs live in ~/.openclaw/

IN PROGRESS (background agents may have completed):
- Phase 13: Synapse Integration plans (planner was running)
- Phase 14: gogcli Google Suite CLI research (researcher was running)

PENDING (need my action before agents can run):
1. gh auth refresh: run `! /opt/homebrew/bin/gh auth refresh -s project --hostname github.com` (DevBot project boards)
2. Telegram chat ID: run `! security add-generic-password -s 'openclaw.anuj-chat-id' -a "trilogy" -U -w` then enter ID from @userinfobot on Telegram

YOUR TASKS:
1. Run /gsd-resume-work to check actual state
2. Check if Phase 13 and 14 plans were created (ls .planning/phases/13-* .planning/phases/14-*)
3. If Phase 13 plans exist → /gsd-execute-phase 13
4. If Phase 14 research exists but no plans → /gsd-plan-phase 14, then /gsd-execute-phase 14
5. Go through docs/human/*.md and record any remaining learnings to Synapse
6. Run scripts/infra-verify.sh and scripts/chan-verify.sh to confirm live state

KEY FILES TO KNOW:
- docs/beads/README.md — full Beads command reference
- .claude/skills/synapse/SKILL.md — Synapse operating loop
- docs/beads/formulas/ — 4 workflow formulas (feature/bugfix/investigation/review)
- .openclaw/agents/task-orchestrator/SOUL.md — full agent loop with Beads + Synapse
- secrets.sh — disaster recovery for all Keychain secrets

SYNAPSE (use on every non-trivial task):
  export SYNAPSE_TOKEN=$(security find-generic-password -s 'openclaw.synapse-token' -a 'trilogy' -w 2>/dev/null)
  export SYNAPSE_URL="https://cnu.synapse-os.ai"
  # Then follow loop in .claude/skills/synapse/SKILL.md

BEADS (use bd prime first):
  export BEADS_DIR="$HOME/.openclaw/beads"
  export PATH="/opt/homebrew/opt/node@24/bin:$PATH"
  bd prime  # injects context
  bd formula list  # shows feature/bugfix/investigation/review
  bd mol pour feature --var title="<task>"  # start structured work
```

---

## Paste this for EduLLM work

```
I'm working on the EduLLM SAT Math project. Synapse is set up.

SYNAPSE:
  export SYNAPSE_TOKEN=$(security find-generic-password -s 'openclaw.synapse-token' -a 'trilogy' -w 2>/dev/null)
  export SYNAPSE_URL="https://cnu.synapse-os.ai"
  Project: project.edullm-sat-math

Start every session with:
  1. Fetch briefs: curl -s -X POST "$SYNAPSE_URL/v1/intent/synapse.brief.fetch" -H "Authorization: Bearer $SYNAPSE_TOKEN" -H "Content-Type: application/json" -d '{"project_id":"project.edullm-sat-math","include_acked":false}'
  2. Ack all briefs
  3. Query learnings for your task tags
  4. Open a workflow before starting work

See: /Users/trilogy/Documents/EduLLM-SAT-Math/.claude/skills/synapse/SKILL.md
```

---

## Quick command cheatsheet

```bash
# Stow deploy (after any config change)
zsh /Users/trilogy/Documents/agentic-setup/scripts/stow-deploy.sh
launchctl kickstart -k "gui/$(id -u)/ai.openclaw.gateway"

# Verify everything is healthy
zsh /Users/trilogy/Documents/agentic-setup/scripts/infra-verify.sh
zsh /Users/trilogy/Documents/agentic-setup/scripts/chan-verify.sh

# Check what phases need work
cd /Users/trilogy/Documents/agentic-setup && /gsd-resume-work

# Pour a Beads formula for a new task
export BEADS_DIR="$HOME/.openclaw/beads" PATH="/opt/homebrew/opt/node@24/bin:$PATH"
bd mol pour feature --var title="Add feature X" --var reviewer="code-reviewer"
bd mol pour bugfix --var title="Fix Y" 
bd mol pour investigation --var question="Should we use X or Y?"

# Synapse — record a learning (low confidence, no artifact needed)
/usr/bin/curl -s -X POST "$SYNAPSE_URL/v1/intent/synapse.learning.record" \
  -H "Authorization: Bearer $SYNAPSE_TOKEN" -H "Content-Type: application/json" \
  -d '{"project_id":"project.edullm-sat-math","bd_id":"<bd_id>","learnings":[{"claim":"<insight>","applies_to":["openclaw"],"confidence":"low"}]}'
```

---

## What the OpenClaw agent fleet does

```
You (Telegram @echo_sys_bot)
  → User Orchestrator: conversations, delegation
    → Task Orchestrator: Beads epics, Synapse logging, Notion pre-log
      → DevBot: GitHub issues/PRs (as echosysbot)
      → CI Monitor: failure alerts every 4 min
      → Email Triage: echo.sys.bot@gmail.com
      → code-reviewer / doc-reviewer / decision-reviewer
      → skill-reviewer / skill-creation
```

**Talk to Telegram** for: daily ops, "what did you do while I was away?", task delegation  
**Talk to Claude Code** for: infrastructure changes, new phases, config, debugging

---

*Last updated: 2026-05-21 | Git: bd76011*

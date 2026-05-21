# Manage OpenClaw Memory Successfully

Here is a deep dive into the most common OpenClaw memory and identity issues, why they happen, and the exact fixes you need to keep your agents on track.

**Author:** Stanislav Huseletov  
**Published:** Mar 23, 2026  
**Source:** Trilogy AI Center of Excellence

---

Building persistent, reliable AI agents is tough. If you've spent any time building with OpenClaw, you've likely experienced the deep frustration of an agent that suddenly forgets its core instructions, wipes its own memory drive, or awkwardly introduces itself by a generic system ID. It is incredibly maddening when an agent gets amnesia — but fortunately, it's completely fixable.

---

## 1. Custom Files Never Loaded Into Agent Context

**Symptom:** Your agent says "I don't know about that," even though the information clearly exists in a workspace file.

**Root cause:** OpenClaw only auto-loads a very specific set of exactly **8 filenames** at boot:

```
SOUL.md    AGENTS.md    USER.md     TOOLS.md
IDENTITY.md    HEARTBEAT.md    BOOTSTRAP.md    MEMORY.md
```

Any file with a different name (like `health-profile.md`, `notes.md`, or `knowledge-base.md`) is **never injected into the agent's context**. Furthermore, the `bootstrap-extra-files` hook also only accepts these exact same basenames.

**The Fix:** Move all critical knowledge into one of the 8 auto-loaded files. `USER.md` is usually the best place for user-specific knowledge — it has no strict size limit and is reliably loaded every session.

> **The Lesson:** Never put critical agent knowledge in custom-named files. If the agent must know it every single session, it belongs in one of the 8 standard files.

---

## 2. Symlinks Silently Blocked by Path Escape Check

**Symptom:** The agent reports "no SOUL.md, no MEMORY.md, nothing" — all boot files appear entirely missing despite existing on your disk and being perfectly readable.

**Root cause:** Your workspace files are symlinks pointing outside the workspace root (e.g., `~/.openclaw-tier/workspace/SOUL.md` → `~/source-repo/workspace/SOUL.md`). OpenClaw's `resolveAgentWorkspaceFilePath()` runs an `assertNoPathAliasEscape` security check. This verifies each file's **realpath** stays strictly inside the workspace root. Symlink targets that resolve outside the workspace are **silently rejected**. There is no error logged; the file is simply ignored.

**The Fix:** Replace your symlinks with real file copies. Maintain your source-of-truth repository separately and copy files over to the live workspace when deploying changes.

> **The Lesson:** OpenClaw workspaces absolutely do not support symlinks that escape the workspace root. Use real files. If you are using a stow/dotfiles pattern, copy instead of link.

**Note for this project:** Our setup uses `scripts/stow-deploy.sh` which stows `.openclaw/` config files (openclaw.json, openclaw-secrets.sh, etc.) to `~/.openclaw/`. This is safe because those config files are NOT inside agent workspaces — they live at the gateway level. Agent workspace files (`~/.openclaw/agents/*/SOUL.md` etc.) are real files, not symlinks. This issue only affects agent workspace symlinks.

---

## 3. Agent Overwrote Memory File From Scratch

**Symptom:** `MEMORY.md` contained 20+ entries of beautifully curated knowledge. After one single conversation, it was replaced with one line of text.

**Root cause:** The agent used the `write` tool to create `MEMORY.md` from scratch instead of editing or appending to it. It treated the file as empty, wrote its own abbreviated version, and destroyed all existing content.

**The Fix (A Multi-Layered Approach):**

**Layer 1 — In-file header** (first line of MEMORY.md):
```markdown
<!-- CRITICAL: NEVER overwrite this file. ALWAYS append. Read the full file before editing. -->
```

**Layer 2 — SOUL.md behavioral rules:**
```markdown
## Memory Rules (MANDATORY)
- NEVER use the write tool on MEMORY.md from scratch
- ALWAYS read MEMORY.md first, then append new entries
- New memories go at the END, never replacing existing content
```

**Layer 3 — AGENTS.md instructions:**
```markdown
Memory updates: Read MEMORY.md → append new entry → verify existing content intact
```

**Layer 4 — Automated guard** (cron job that detects wipe and restores from backup):
```bash
#!/usr/bin/env zsh
# memory-guard.sh — checks MEMORY.md size, restores if too small
MIN_LINES=10
CURRENT=$(wc -l < ~/.openclaw/agents/*/MEMORY.md 2>/dev/null | awk '{print $1}')
if [[ "$CURRENT" -lt "$MIN_LINES" ]]; then
  cp ~/.openclaw/agents/*/memory/backup/MEMORY.md.bak ~/.openclaw/agents/*/MEMORY.md
  echo "MEMORY.md restored from backup (wipe detected)" | logger
fi
```

> **The Lesson:** LLMs will overwrite files unless explicitly told not to at multiple reinforcement points. A single instruction isn't enough. Put the rule in the file itself, in the behavior config, in the operating manual, and back it all up with automated detection.

---

## 4. Agent Didn't Know Its Own Name

**Symptom:** The agent introduces itself using the config agent ID (e.g., "I'm user-orchestrator") instead of its beautifully crafted persona name.

**Root cause:** Two compounding issues:
1. Boot files weren't loading due to the symlink escape issue (see #2), so the agent had no identity directives.
2. The agent ID from the config appeared in the session metadata, and the LLM natively grabbed it to use as a name.

**The Fix:** Make identity the absolute first line of `SOUL.md`:

```markdown
You are [Name]. Not Claude. Not 'an AI assistant.' You are [Name].
Never say 'I'm an AI' or 'as a language model.'
```

Reinforce this again in `AGENTS.md`:

```markdown
You are [Name]. Not a 'separate agent.'
```

> **The Lesson:** Identity must be hammered into the very first lines of `SOUL.md`. If boot files fail to load, the agent will fall back to generic behavior and default to the agent ID as its name.

---

## 5. Memory Appeared "Empty" Despite Having Content

**Symptom:** The agent complains that its "memory is completely empty" when `MEMORY.md` clearly has content in it.

**Root cause:** You have sections containing placeholder text like `*(to be populated as conversations happen)*`. The agent takes this literally and interprets the whole section as functionally empty.

**The Fix:** Replace all placeholder sections with real content. Even minimal, meta-entries like *"Getting to know this bot and building the working relationship"* are enough to signal to the LLM that the section is active and ready.

> **The Lesson:** Never leave sections with placeholder text in files the agent reads. Either put real content in them or remove the section entirely.

---

## 6. "Remember This" Going to the Wrong File

**Symptom:** A user tells the agent to "send shorter messages." The agent dutifully logs it to `MEMORY.md` as a preference note. But in the next session, it still sends long messages.

**Root cause:** The agent treats all "remember" requests as long-term facts (routing them to `MEMORY.md`) without considering that some requests are actually *behavior changes* that need to update the operating files. `SOUL.md` drives behavior; `MEMORY.md` drives recall.

**The Fix:** Add a strict decision framework to `AGENTS.md`:

| What user says | Where it goes |
|----------------|---------------|
| Fact / person / event | `MEMORY.md` only |
| Behavior change (e.g., "shorter messages") | `SOUL.md` or `AGENTS.md` |
| Most complex cases | Both `MEMORY.md` AND the relevant operating file |

**Introduce "The Test"** to the agent's instructions: *If the agent wakes up in a new session, will it behave according to what was asked?* If the change only went to `MEMORY.md`, the agent reads it but might not act on it. If it also went to `SOUL.md` or `AGENTS.md`, it shapes behavior directly.

> **The Lesson:** `MEMORY.md` is for recall. `SOUL.md` and `AGENTS.md` are for behavior. Preferences that affect how the agent acts must update the operating file, not just the memory bank.

---

## 7. QMD Memory Search Config Placement

**Symptom:** You get an "Unrecognized keys" error when trying to configure QMD semantic search.

**Root cause:** You placed the QMD config under `agents.defaults.memorySearch`, but the codebase actually reads from the top-level `memory.backend` and `memory.qmd`.

**The Fix:** The configuration goes under the top-level `memory` key in your JSON:

```json
{
  "memory": {
    "backend": "qmd",
    "qmd": {
      "includeDefaultMemory": true,
      "paths": ["..."],
      "update": { "onBoot": true, "interval": "10m" }
    }
  }
}
```

> **The Lesson:** Always double-check the actual code for configuration key paths — documentation can easily fall out of sync with the implementation.

---

## Summary: The Memory Protection Stack

If you want reliable agent memory in OpenClaw, you cannot rely on just one fix. You need the complete stack:

1. **In-file write rules:** Placed on the very first line the agent reads in every single memory file
2. **SOUL.md behavioral rules:** The golden rule explicitly banning overwrites
3. **AGENTS.md operational instructions:** A clear framework on how to route "remember" requests to the correct file
4. **Automated backups:** Daily snapshots taken *before* any consolidation tasks run
5. **Automated guard:** Periodic size checks via cron with auto-restore on wipe detection
6. **QMD semantic search:** Indexes all `.md` files for on-demand retrieval beyond the standard boot context
7. **Real files, not symlinks:** Because OpenClaw's path escape check will silently block symlinks pointing outside the workspace

---

## The 8 Auto-Loaded Boot Files (Quick Reference)

| File | Purpose | Notes |
|------|---------|-------|
| `SOUL.md` | Identity, personality, behavioral rules | First lines = identity. Must be explicit. |
| `AGENTS.md` | Operating instructions, sub-agent configs, routing rules | Where behavior-change preferences go |
| `USER.md` | Principal context, preferences, special handling | Best place for user-specific knowledge |
| `TOOLS.md` | Tool configurations (no secrets) | Document exact commands + defaults |
| `IDENTITY.md` | Name, role, signature | Reinforces SOUL.md identity |
| `HEARTBEAT.md` | Periodic task definitions | Use cron for reliability instead |
| `BOOTSTRAP.md` | Startup procedures | Runs on every boot |
| `MEMORY.md` | Curated long-term memory | Recall only — not behavior |

Any file with a different name is **never loaded** into the agent's context.

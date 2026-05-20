# Phase 1: Infrastructure - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-05-20
**Phase:** 1-Infrastructure
**Areas discussed:** Repo layout for stow, cc-openclaw placement, jobs.json conflict automation, Prerequisites install approach

---

## Repo Layout for Stow

### Q1: Stow invocation strategy

| Option | Description | Selected |
|--------|-------------|----------|
| Explicit --target=$HOME | Keep repo at ~/Documents/agentic-setup, always pass --target=$HOME to stow | ✓ |
| Symlink ~/agentic-setup | Create a symlink so stow default parent-dir targeting works | |
| Move repo to ~/agentic-setup | Relocate to match CLAUDE.md references literally | |

**User's choice:** Explicit --target=$HOME

### Q2: Package directory structure

| Option | Description | Selected |
|--------|-------------|----------|
| .openclaw/ package only | Single stow package for OpenClaw config | ✓ |
| .openclaw/ + .claude/ packages | Both packages managed in the repo and stowed | |
| Flat stow (root) | Everything at root with .stow-ignore exclusions | |

**User's choice:** .openclaw/ package only

### Q3: Deploy script location

| Option | Description | Selected |
|--------|-------------|----------|
| scripts/stow-deploy.sh | Committed script wraps stow + jobs.json cleanup | ✓ |
| /openclaw-stow skill only | Rely on cc-openclaw skill exclusively | |
| Documented command in CLAUDE.md | Copy-paste reference, no runnable artifact | |

**User's choice:** scripts/stow-deploy.sh

### Q4: .stow-ignore file

| Option | Description | Selected |
|--------|-------------|----------|
| Yes — add .stow-ignore | Explicit exclusion list prevents accidents | ✓ |
| No — rely on package structure | --stow .openclaw ignores everything else naturally | |

**User's choice:** Yes — add .stow-ignore

### Q5: Overall repo layout

**User's choice:** "come up with your own repo layout, which should be really neat and awesome, and move to next" — deferred to Claude's discretion.

**Claude's decision:** Defined a clean repo layout with `.openclaw/` (stow package), `cc-openclaw/` (submodule), `scripts/` (repo-management tools), `.stow-ignore`, `.planning/`, `docs/`. See CONTEXT.md `### Claude's Discretion — Repo Directory Structure`.

---

## cc-openclaw Placement

### Q1: Where cc-openclaw lives

| Option | Description | Selected |
|--------|-------------|----------|
| Sibling repo at ~/Documents/cc-openclaw | Standalone clone, stowed into ~/.claude/skills/ | |
| Git submodule inside agentic-setup | Tied to openclaw-home repo, single disaster recovery | ✓ |
| Copy skill files directly into project | No separate repo, own the files | |

**User's choice:** Git submodule inside agentic-setup

### Q2: Submodule location and stow approach

| Option | Description | Selected |
|--------|-------------|----------|
| Submodule at .claude/skills/cc-openclaw, stowed as .claude/ package | Skills land at ~/.claude/skills/cc-openclaw/ (one level too deep) | ✓ |
| Submodule at vendor/cc-openclaw, script copies to .claude/skills/ | Pristine mirror + copy step | |
| Submodule at cc-openclaw/, separate stow from that dir | Stow from submodule into project | |

**User's choice:** Submodule at .claude/skills/cc-openclaw, stowed as .claude/ package
**Notes:** Reference doc clarified the correct stow pattern post-discussion — `stow --no-folding -t ~/Documents/agentic-setup .` from the cc-openclaw submodule directory creates skill symlinks inside the project. Submodule lives at `agentic-setup/cc-openclaw/`, not `.claude/skills/cc-openclaw/`.

### Q3: cc-openclaw repo structure handling

| Option | Description | Selected |
|--------|-------------|----------|
| Not sure — handle both cases | Plan 01-02 inspects structure and adapts | ✓ |
| Skills at root | stow --target=$HOME/.claude/skills/ | |
| .claude/skills/ package structure | stow --target=$HOME from submodule dir | |

**User's choice:** Not sure — plan should handle both cases

---

## jobs.json Conflict Automation

### Q1: Who handles the cleanup

| Option | Description | Selected |
|--------|-------------|----------|
| scripts/stow-deploy.sh | rm -f in the deploy script, one canonical path | ✓ |
| /openclaw-stow skill only | Rely on the cc-openclaw skill | |
| Both | Script for humans, skill for agents | |

**User's choice:** scripts/stow-deploy.sh

### Q2: Restart separation

| Option | Description | Selected |
|--------|-------------|----------|
| Separate explicit step | stow-deploy.sh deploys only, restart is /openclaw-restart | ✓ |
| Deploy + restart in one script | One command to deploy and activate | |

**User's choice:** Separate explicit step

### Q3: Other stow conflicts

**User's response:** "search through it and find the best solution to pick I do not want to decide this" — deferred to Claude's discretion.

**Claude's decision:** Researched the reference doc (`Managing OpenClaw with Claude Code`). Only `jobs.json` is documented as a stow conflict. The `/openclaw-stow` and `/openclaw-restart` skills both encode exactly `rm -f ~/.openclaw/cron/jobs.json` and nothing else. Decision: handle `jobs.json` only; add a comment in stow-deploy.sh for future conflicts.

---

## Prerequisites Install Approach

### Q1: Prereq automation level

| Option | Description | Selected |
|--------|-------------|----------|
| Auto-install everything | brew install if missing, fail-fast if no Homebrew | ✓ |
| Check and report only | Print missing prereqs, user installs manually | |
| Defer to OpenClaw installer | Skip prereq script entirely | |

**User's choice:** Auto-install everything

### Q2: Wrong Node version handling

| Option | Description | Selected |
|--------|-------------|----------|
| Install node@24 and switch to it | brew install node@24, pin to PATH in env scripts | ✓ |
| Error and abort | Clear fix command, user manages Node versions | |
| Install nvm | nvm for version management | |

**User's choice:** Install node@24 via brew and switch to it

### Q3: Scope of install-prereqs.sh

| Option | Description | Selected |
|--------|-------------|----------|
| Prereqs only — stops before OpenClaw installer | Clear separation, re-runnable | ✓ |
| All-in-one — prereqs + OpenClaw curl installer | Single entry point | |

**User's choice:** Prereq script stops at prereqs

---

## Claude's Discretion

- **Repo directory structure:** User said "come up with your own... really neat and awesome." Full structure defined in CONTEXT.md D-01 through D-04 and the structure diagram.
- **jobs.json and other stow conflicts:** User said "you search through it and find the best solution." Researched reference doc — jobs.json is the only documented conflict.

## Deferred Ideas

None raised during discussion.

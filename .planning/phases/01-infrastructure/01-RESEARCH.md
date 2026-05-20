# Phase 1: Infrastructure - Research

**Researched:** 2026-05-20
**Domain:** OpenClaw runtime installation, cc-openclaw skills deployment, macOS Keychain secrets pipeline, GNU Stow deployment automation
**Confidence:** HIGH

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**Repo Layout for Stow**
- D-01: Stow is always invoked with explicit `--dir=$HOME/Documents/agentic-setup --target=$HOME`. Never rely on stow's default parent-directory targeting.
- D-02: `.openclaw/` is the single stow package for OpenClaw config. Only files under `.openclaw/` are deployed to `~/.openclaw/`. All other repo content is not stowed.
- D-03: A `.stow-ignore` file at the repo root explicitly excludes non-stow content: `.planning`, `.git`, `docs`, `scripts`, `CLAUDE.md`, `README.md`, `cc-openclaw`.
- D-04: `scripts/stow-deploy.sh` is the canonical deploy entry point. It handles `jobs.json` cleanup before stowing.

**Claude's Discretion — Repo Directory Structure (locked)**
```
~/Documents/agentic-setup/
├── .openclaw/              ← stow package → ~/.openclaw/
│   ├── openclaw.json
│   ├── agents/
│   ├── cron/
│   └── scripts/
├── cc-openclaw/            ← git submodule of github.com/rahulsub-be/cc-openclaw
├── scripts/
│   ├── install-prereqs.sh
│   ├── stow-deploy.sh
│   └── lib/
│       └── json-response.sh
├── .stow-ignore
├── .planning/
├── docs/
└── CLAUDE.md
```

**cc-openclaw Skills Placement**
- D-05: cc-openclaw is added as a git submodule at `agentic-setup/cc-openclaw/`
- D-06: Skills are stowed FROM the submodule INTO the project using `stow --no-folding -t ~/Documents/agentic-setup .` run from `agentic-setup/cc-openclaw/`
- D-07: Plan 01-02 must inspect cc-openclaw repo structure after cloning to determine whether skills are at root or under `.claude/skills/`
- D-08: Skills update independently via `git pull` inside submodule; stow-deploy.sh does NOT re-stow skills on every config deploy

**jobs.json Conflict Automation**
- D-09: `scripts/stow-deploy.sh` cleans jobs.json only: `rm -f ~/.openclaw/cron/jobs.json` before every stow
- D-10: stow-deploy.sh deploys files only — does NOT restart the gateway
- D-11: Script includes a comment marking where additional conflict cleanups should be added

**Prerequisites Install Approach**
- D-12: `scripts/install-prereqs.sh` auto-installs missing prerequisites: Node 24, GNU Stow, jq
- D-13: If Node 18 or 20 detected, install Node 24 via brew and pin to PATH; do NOT remove existing Node installs
- D-14: If Homebrew is not installed, fail immediately with clear error and Homebrew install URL
- D-15: `install-prereqs.sh` handles prereqs only — does not run OpenClaw curl installer

### Claude's Discretion
None marked as discretion — all decisions are locked.

### Deferred Ideas (OUT OF SCOPE)
None — discussion stayed within phase scope.
</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| INFRA-01 | User can install OpenClaw 2026.5.18 on macOS via curl installer with all prerequisites (Node.js 24, GNU Stow via brew) | See §OpenClaw Install Sequence and §Environment Availability — existing 2026.3.12 install via nvm Node 22 needs upgrade path |
| INFRA-02 | User can deploy all 9 cc-openclaw skills as Claude Code slash commands via git+stow | See §cc-openclaw Submodule Setup — skills live at `.claude/skills/openclaw-*/` in the cc-openclaw repo |
| INFRA-03 | User can store any credential in macOS Keychain with a single command, propagating to all three required files | See §Three-File Secrets Pipeline — `openclaw-add-secret` skill enforces `openclaw.<name>` / `OPENCLAW_<NAME>` convention |
| INFRA-04 | User can deploy config changes via Git+Stow from `~/Documents/agentic-setup` with jobs.json conflict auto-resolved | See §stow-deploy.sh Implementation and §jobs.json Conflict |
| INFRA-06 | User can verify full system health via `/openclaw-status` in one command | See §/openclaw-status Skill and §Validation Architecture |
</phase_requirements>

---

## Summary

Phase 1 establishes the governance layer for all subsequent phases: OpenClaw runtime on the correct version, cc-openclaw skills as the sole configuration path, a tamper-proof secrets pipeline, and a git+stow deployment mechanism that resolves the one known conflict automatically.

**Critical pre-existing state:** OpenClaw 2026.3.12 is already installed on this machine via `npm install -g` under nvm's Node 22.18.0. The current install is not stow-managed (`~/.openclaw/openclaw.json` is a plain file, not a symlink). The LaunchAgent (`ai.openclaw.gateway`) is not loaded. Phase 1 must therefore: (1) upgrade OpenClaw from 2026.3.12 to 2026.5.18 using the curl installer, (2) switch Node from nvm v22.18.0 to Homebrew node@24, (3) establish stow management over `~/.openclaw/` by deploying the repo's `.openclaw/` package for the first time.

**Primary recommendation:** Run `install-prereqs.sh` first (installs node@24 via brew, pins PATH), then the curl installer (detects existing install, upgrades to 2026.5.18, handles LaunchAgent setup), then the cc-openclaw submodule stow, then verify with `/openclaw-status`.

The curl installer handles the upgrade path automatically — it detects an existing `openclaw` binary and treats the run as an upgrade. The nvm-vs-brew node conflict requires explicit PATH resolution in `openclaw-secrets.sh` and `openclaw-env.sh` before the daemon can start.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| OpenClaw gateway runtime | macOS LaunchAgent (daemon) | — | `openclaw onboard --install-daemon` installs `ai.openclaw.gateway` as a user-level LaunchAgent; gateway runs on port 18789 |
| Config deployment | GNU Stow (symlink manager) | Git (version control) | Stow creates symlinks from `~/.openclaw/` → repo `.openclaw/`; Git is the source of truth |
| Skills discovery | Claude Code (`.claude/skills/`) | — | Claude Code discovers skills by scanning `.claude/skills/openclaw-*/SKILL.md` in the working directory |
| Secrets storage | macOS Keychain | shell env vars | Keychain holds values; three shell files (`openclaw-secrets.sh`, `openclaw-env.sh`, `secrets.sh`) propagate them to the right consumers |
| Health monitoring | `/openclaw-status` skill | `openclaw gateway status` CLI | Skill checks gateway health endpoint, LaunchAgent status, channel connectivity, cron execution history |
| Node.js runtime | Homebrew node@24 (keg-only) | — | Must be pinned to PATH explicitly; keg-only means not auto-linked |

---

## Standard Stack

### Core
| Tool | Version | Purpose | Why Standard |
|------|---------|---------|--------------|
| OpenClaw | 2026.5.18 [VERIFIED: npm registry] | AI agent gateway runtime | The entire hub runs on OpenClaw; no alternative exists for this use case |
| Node.js | 24.15.0 (brew node@24) [VERIFIED: homebrew-core] | OpenClaw runtime dependency | OpenClaw minimum is 22.19; Node 24 is default/recommended; Node 18/20 cause fatal "Node version unsupported" at startup |
| GNU Stow | 2.4.1 [VERIFIED: homebrew-core] | Symlink manager — deploys repo to `~/.openclaw/` | Makes git the deployment mechanism; `stow -D` reverses any deploy |
| cc-openclaw | HEAD at github.com/rahulsub-be/cc-openclaw [CITED: cc-openclaw README] | 9 skills as Claude Code slash commands | Encodes all institutional knowledge: naming conventions, secrets pipeline, stow gotchas, token budgets |
| macOS Keychain | Built-in (security CLI) [VERIFIED: macOS 13+] | All secrets storage | Convention: `openclaw.<name>` service (lowercase hyphens), `OPENCLAW_<NAME>` env var (uppercase underscores) |
| jq | 1.7.1 [VERIFIED: installed on machine] | JSON parsing in shell scripts | Required for json-response pattern; already installed |

### Supporting
| Tool | Version | Purpose | When to Use |
|------|---------|---------|-------------|
| git | System (brew recommended) | Version control for all config | Every config change is a commit before stow runs |
| launchd / LaunchAgent | Built-in macOS | Cron replacement, gateway daemon | `openclaw onboard --install-daemon` configures this; never use crontab on macOS |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Homebrew node@24 | nvm node 24 | nvm node is not visible to launchd; Homebrew node@24 can be added to launchd PATH via `openclaw-secrets.sh`; nvm-managed node fails when daemon starts without shell profile loaded |
| curl installer | `npm install -g openclaw` | npm method is the official legacy path and still works; curl installer handles sharp/libvips binaries, daemon setup, and build tools automatically |

**Installation (Phase 1 order):**
```bash
# Step 1: Prerequisites
brew install node@24 stow jq
export PATH="/opt/homebrew/opt/node@24/bin:$PATH"  # Apple Silicon

# Step 2: OpenClaw (curl installer — handles upgrade from 2026.3.12)
curl -fsSL https://openclaw.ai/install.sh | bash

# Step 3: Onboard with daemon
openclaw onboard --install-daemon
```

**Version verification (run before writing Standard Stack table):**
```bash
npm view openclaw version         # → 2026.5.18
brew info node@24 --json | python3 -c "import json,sys; d=json.load(sys.stdin); print(d[0]['versions']['stable'])"  # → 24.15.0
brew info stow --json | python3 -c "import json,sys; d=json.load(sys.stdin); print(d[0]['versions']['stable'])"     # → 2.4.1
```

---

## Package Legitimacy Audit

> Phase 1 installs CLI tools and system packages (not npm libraries used in application code). The primary runtime package is `openclaw` installed globally via the curl installer (which internally uses npm). All other dependencies are macOS system tools installed via Homebrew.

| Package | Registry | Age | Downloads | Source Repo | slopcheck | Disposition |
|---------|----------|-----|-----------|-------------|-----------|-------------|
| openclaw | npm | Active since 2026 | 894,142/wk [VERIFIED: npm API] | github.com/openclaw/openclaw [VERIFIED: npm metadata] | [OK] — established package, high download count, matches official docs | Approved |
| node@24 | Homebrew | Stable formula | 12,334 installs/30d [VERIFIED: homebrew analytics] | — (official Node.js) | N/A — official Homebrew formula | Approved |
| stow | Homebrew | 2.4.1 stable | 2,312 installs/30d [VERIFIED: homebrew analytics] | gnu.org/software/stow | N/A — official GNU tool | Approved |
| jq | Already installed (1.7.1) | Mature | — | stedolan.github.io/jq | N/A — industry standard | Approved |

**Packages removed due to slopcheck [SLOP] verdict:** none
**Packages flagged as suspicious [SUS]:** none

**Note on openclaw postinstall script:** The openclaw npm package has a `postinstall` script (`node scripts/postinstall-bundled-plugins.mjs`) [VERIFIED: npm registry]. This bundles internal plugins — it is expected behavior documented by OpenClaw. The script installs bundled plugins from within the package directory, not from the network. This is NOT a red flag for this well-established package.

---

## Architecture Patterns

### System Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│  DEPLOY PATH (humans and agents use this path for ALL changes)  │
│                                                                 │
│  ~/Documents/agentic-setup/    (git repo)                       │
│  ├── .openclaw/                ──stow──►  ~/.openclaw/          │
│  │   ├── openclaw.json                   ├── openclaw.json ──►  │
│  │   ├── agents/                         ├── agents/            │
│  │   ├── cron/                           ├── cron/              │
│  │   └── scripts/                        └── scripts/           │
│  │       ├── openclaw-secrets.sh                                │
│  │       └── openclaw-env.sh                                    │
│  └── cc-openclaw/ (submodule)                                   │
│      └── .claude/skills/       ──stow──►  .claude/skills/      │
│          └── openclaw-*/SKILL.md          (in repo, symlinks)   │
└─────────────────────────────────────────────────────────────────┘
                                │
                          (stow deploys)
                                │
                                ▼
┌──────────────────────────────────────────────┐
│  RUNTIME (launchd-managed)                   │
│                                              │
│  LaunchAgent: ai.openclaw.gateway            │
│    starts with openclaw-secrets.sh (env)     │
│    ├── gateway on 127.0.0.1:18789            │
│    ├── reads ~/.openclaw/openclaw.json        │
│    ├── loads ~/.openclaw/agents/*/            │
│    └── executes ~/.openclaw/cron/jobs.json   │
└──────────────────────────────────────────────┘
                                │
                    (OPENCLAW_REPO detection)
                                │
┌──────────────────────────────────────────────┐
│  SKILL REPO DETECTION (auto, no hardcoding)  │
│                                              │
│  OPENCLAW_REPO=$(readlink ~/.openclaw/        │
│    openclaw.json | sed 's|/.openclaw/        │
│    openclaw.json||')                         │
│                                              │
│  Works ONLY when openclaw.json is a stow     │
│  symlink — not a plain file                  │
└──────────────────────────────────────────────┘
```

### Recommended Project Structure
```
~/Documents/agentic-setup/
├── .openclaw/                 # stow package (deploys to ~/.openclaw/)
│   ├── openclaw.json          # gateway config
│   ├── agents/                # per-agent directive files
│   ├── cron/                  # cron definitions (NOT jobs.json — gateway owns that)
│   └── scripts/
│       ├── openclaw-secrets.sh   # launchd env injection
│       ├── openclaw-env.sh       # shell session env
│       └── json-response.sh     # shared script lib (NOT stowed — under scripts/)
├── cc-openclaw/               # git submodule
│   └── .claude/skills/        # skills stowed into project .claude/skills/
├── scripts/                   # repo-management (NOT stowed)
│   ├── install-prereqs.sh
│   ├── stow-deploy.sh
│   └── lib/
│       └── json-response.sh
├── secrets.sh                 # provisioning script (in repo root, NOT stowed)
├── .stow-ignore               # prevents stow from touching non-.openclaw/ content
└── CLAUDE.md
```

**Important note on secrets.sh location:** The `openclaw-add-secret` skill updates a file called `secrets.sh`. Per the CONTEXT.md reference, this file is at the repo root (not inside `.openclaw/`), so it is NOT stowed to `~/`. It serves as a provisioning script for setting up a fresh machine. [CITED: cc-openclaw SKILL.md for openclaw-add-secret]

### Pattern 1: stow-deploy.sh — Canonical Deploy Entry Point

**What:** A shell script that resolves the jobs.json conflict then runs stow to deploy `.openclaw/` to `~/.openclaw/`

**When to use:** Every time any config file under `.openclaw/` changes. Humans and agents both call this script; they never invoke stow directly.

```zsh
#!/usr/bin/env zsh
# Source: CONTEXT.md D-04, D-09, D-10, D-11 + cc-openclaw /openclaw-stow SKILL.md
set -euo pipefail

REPO_DIR="$HOME/Documents/agentic-setup"

# Resolve the known stow conflict: gateway overwrites cron/jobs.json on every startup,
# turning the stow symlink into a real file. Remove it before stowing.
rm -f ~/.openclaw/cron/jobs.json
# ADD ADDITIONAL CONFLICT CLEANUPS HERE if discovered during Phase 1 execution

# Deploy .openclaw/ package to ~/
stow --dir="$REPO_DIR" --target="$HOME" --no-folding .openclaw

# Output structured result
echo '{"ok":true,"data":{"deployed":"~/.openclaw/"}}'
```

**Why no restart:** Restart is always a separate explicit step via `/openclaw-restart` (D-10). This allows batching multiple config changes before a single restart.

### Pattern 2: cc-openclaw Submodule Stow

**What:** Skills from the cc-openclaw repo are stowed INTO the project directory (not into `~/`), creating `.claude/skills/openclaw-*/` symlinks that Claude Code discovers.

```bash
# Source: CONTEXT.md D-06 + cc-openclaw README
# Run from the submodule directory
cd ~/Documents/agentic-setup/cc-openclaw
stow --no-folding -t ~/Documents/agentic-setup .
# Creates: ~/Documents/agentic-setup/.claude/skills/openclaw-*/SKILL.md (symlinks)
```

**Why --no-folding:** Without this flag, stow would create a `.claude/` directory symlink pointing to `cc-openclaw/.claude/`. That is a directory-level symlink — Claude Code cannot traverse it to discover individual skills. `--no-folding` forces stow to create the actual `.claude/` and `.claude/skills/` directories and symlink only the individual skill directories within them. [CITED: GNU Stow manual, --no-folding behavior]

**cc-openclaw repo structure (verified):** Skills live at `.claude/skills/<skill-name>/SKILL.md` — NOT at the root. The repo uses `.stow-local-ignore` to exclude `README.md`, `LICENSE`, and other non-skill files from being stowed. [VERIFIED: github.com/rahulsub-be/cc-openclaw via WebFetch]

All 9 skill directory names:
1. `openclaw-add-channel`
2. `openclaw-add-cron`
3. `openclaw-add-script`
4. `openclaw-add-secret`
5. `openclaw-dream-setup`
6. `openclaw-new-agent`
7. `openclaw-restart`
8. `openclaw-stow`
9. `openclaw-status`

### Pattern 3: Three-File Secrets Pipeline

**What:** Every secret touches 4 locations: Keychain + 3 files.

```bash
# Source: cc-openclaw /openclaw-add-secret SKILL.md + CONTEXT.md canonical refs

# 1. Store in Keychain (never echoed)
security add-generic-password \
  -s "openclaw.<name>" \
  -a "$USER" \
  -w "<secret-value>"

# 2. openclaw-secrets.sh — read by launchd at gateway startup
# Append to .openclaw/scripts/openclaw-secrets.sh:
export OPENCLAW_<NAME>="$(security find-generic-password -s 'openclaw.<name>' -w)"

# 3. openclaw-env.sh — sourced by shell sessions for CLI use
# Append to .openclaw/scripts/openclaw-env.sh:
export OPENCLAW_<NAME>="$(security find-generic-password -s 'openclaw.<name>' -w)"

# 4. secrets.sh — disaster recovery provisioning (repo root, NOT stowed)
# SECRETS array entry in secrets.sh:
# "openclaw.<name>|OPENCLAW_<NAME>|<description>"
```

**Naming convention:** Keychain service = `openclaw.<name>` (lowercase, hyphens). Env var = `OPENCLAW_<NAME>` (uppercase, underscores). Example: Telegram bot token → service `openclaw.telegram-bot-token` → env var `OPENCLAW_TELEGRAM_BOT_TOKEN`. [CITED: cc-openclaw SKILL.md openclaw-add-secret]

**Why three files:**
- `openclaw-secrets.sh`: Loaded by launchd — the daemon has no shell profile, so env vars must be injected explicitly
- `openclaw-env.sh`: Sourced by shell sessions — gives CLI commands the same credentials
- `secrets.sh`: Disaster recovery — without this, a fresh machine provision misses secrets not in git

### Pattern 4: OPENCLAW_REPO Auto-Detection

**What:** All cc-openclaw skills find the repo automatically by following the stow symlink.

```bash
# Source: cc-openclaw README + CONTEXT.md canonical refs
OPENCLAW_REPO=$(readlink ~/.openclaw/openclaw.json 2>/dev/null | sed 's|/.openclaw/openclaw.json||')
```

**This only works when `~/.openclaw/openclaw.json` is a stow symlink.** If openclaw.json is a plain file (as it is currently — pre-Phase 1), `readlink` returns empty and OPENCLAW_REPO is unset. This is why establishing stow management is a foundational requirement — all 9 skills depend on it.

### Pattern 5: Minimal openclaw.json for Gateway Start

**What:** The gateway reads `~/.openclaw/openclaw.json`. No fields are strictly required; the gateway uses safe defaults when the file is absent. However, a working Phase 1 config needs:

```json5
// Source: docs.openclaw.ai/gateway/configuration
{
  // agents.defaults.workspace is needed for agent operation
  agents: {
    defaults: {
      workspace: "~/.openclaw/workspace"
    },
    list: []  // Populated by /openclaw-new-agent skill in later phases
  },
  // channels: {} added by /openclaw-add-channel in Phase 2
  // cron: { enabled: true } needed when cron jobs are added
}
```

**JSON5 format:** OpenClaw reads optional JSON5 (supports comments, trailing commas). The `$schema` field is allowed at root for editor integration. [CITED: docs.openclaw.ai/gateway/configuration]

### Anti-Patterns to Avoid

- **Running stow without `--dir` and `--target`:** Default targeting uses stow's parent directory. Always pass explicit `--dir=$REPO --target=$HOME` per D-01.
- **Creating `.openclaw/cron/jobs.json` in git:** The gateway owns this file and overwrites it on every startup. The stow symlink becomes a regular file. Only `rm -f` + re-stow restores symlink management. Never commit or version-control `jobs.json`.
- **Stowing cc-openclaw into `~/` instead of the project directory:** `stow --no-folding -t ~/Documents/agentic-setup .` (project dir) vs `stow --no-folding -t ~ .` (home dir). The skills must land in the project's `.claude/skills/`, not in `~/.claude/skills/`, for Claude Code's workspace discovery to work.
- **Using nvm-managed Node for the gateway daemon:** launchd does not source shell profiles. If Node 24 is provided by nvm, the daemon starts with whatever `node` is in the system PATH (which may be Node 18/20 from Homebrew's default install). Use Homebrew node@24 and pin the binary path explicitly in `openclaw-secrets.sh`.
- **Manual edits to `openclaw.json`:** Every config change must go through a cc-openclaw skill. Manual edits break the consistency guarantees the skills provide and create convention drift.
- **Running `#!/bin/bash` in scripts:** macOS ships bash 3.2 (GPL2 locked). Use `#!/usr/bin/env zsh` in all scripts per CLAUDE.md convention.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Agent directory scaffolding | Custom mkdir + template scripts | `/openclaw-new-agent` | Creates 6 required markdown files + directory tree; missing SECURITY.md or `memory/archives/` causes silent failures weeks later |
| Secret storage and propagation | Manual `security` CLI + sed/echo into files | `/openclaw-add-secret` | Must update exactly 3 files + Keychain; convention enforcement; never echoes secret value |
| Cron job creation | Direct JSON editing of jobs.json | `/openclaw-add-cron` | UUID generation, timezone field, isolated session flag, jobs.json stow-conflict handling |
| Gateway restart | Direct `launchctl kickstart` | `/openclaw-restart` | Correct restart sequence: `rm jobs.json` → stow → kickstart → wait 5s → verify channels connected |
| Stow deployment | Direct `stow` invocation | `/openclaw-stow` or `scripts/stow-deploy.sh` | jobs.json cleanup + verification step |
| Memory distillation setup | Manual DREAM_ROUTINE.md authoring | `/openclaw-dream-setup` | Token budget enforcement (2,500 daily / 7,500 rolling); correct QMD index paths; cron job wiring |

**Key insight:** Skills are executable standards. The model executing the skill fills in specifics; the skill defines structure, naming conventions, and verification. Bypassing skills means every config operation reconstructs conventions from scratch — this is the documented source of agent configuration drift.

---

## Runtime State Inventory

> This is Phase 1 of a greenfield project building ON TOP of an existing non-stow-managed OpenClaw installation. The existing install must be acknowledged and handled.

| Category | Items Found | Action Required |
|----------|-------------|------------------|
| Stored data | `~/.openclaw/` exists with OpenClaw 2026.3.12 config, 7 agent workspaces (`main`, `deepsearch`, `github`, `humanizer`, `notion`, `report`, `writer`). `openclaw.json` is a plain file (not a stow symlink). | No data migration — this is a net-new agentic-setup repo; existing `~/.openclaw/` config is from a different (unmanaged) install. Plan must decide: (a) stow will CONFLICT if existing plain files exist at target paths, (b) plan must include a step to backup or remove conflicting files before first stow |
| Live service config | OpenClaw gateway LaunchAgent (`ai.openclaw.gateway`) is NOT loaded (confirmed by `openclaw gateway status`). No daemon is currently running. | No running service to stop. LaunchAgent install is a clean first-time setup. |
| OS-registered state | No `ai.openclaw.gateway` plist in `~/Library/LaunchAgents/`. nvm manages Node 22.18.0 — this is on PATH as `node`. | First `openclaw onboard --install-daemon` installs the plist. The openclaw installer detects nvm and gives instructions to `nvm install 24 && nvm use 24 && nvm alias default 24` OR switch to brew node@24. |
| Secrets/env vars | Existing `~/.openclaw/openclaw.json` references `channels.telegram` — Telegram token may be in Keychain under an undocumented service name. | Code change only — new secrets use `openclaw.<name>` convention going forward. Existing Keychain entries are separate from the new pipeline. |
| Build artifacts | Existing `openclaw` binary at `~/.nvm/versions/node/v22.18.0/bin/openclaw` (v2026.3.12). `~/.openclaw/cron/jobs.json` is a plain file (not symlink). | After upgrade: old npm binary superseded by curl installer binary. `jobs.json` will be deleted by `stow-deploy.sh` before first stow. |

**Critical stow conflict to address in Plan 01-04:** Before the first `stow --dir=$REPO --target=$HOME .openclaw` run, the following files in `~/.openclaw/` will conflict if the new repo's `.openclaw/` package contains files with the same relative paths. Plan must include: backup existing `~/.openclaw/` content and/or use `stow --adopt` carefully, or let the first `stow` fail and handle conflicts manually.

---

## Common Pitfalls

### Pitfall 1: jobs.json Stow Conflict
**What goes wrong:** After any gateway startup, `~/.openclaw/cron/jobs.json` becomes a regular file (gateway writes to it). On the next `stow` run, stow sees a real file where it wants to create a symlink, and fails with a conflict error.
**Why it happens:** OpenClaw reads the cron schedule from `~/.openclaw/cron/jobs.json` but maintains its own runtime copy. When the gateway starts, it writes the current job schedule to this path, replacing any symlink with a plain file.
**How to avoid:** Always run `rm -f ~/.openclaw/cron/jobs.json` immediately before every `stow` invocation. This is baked into `scripts/stow-deploy.sh` (D-09). The cc-openclaw `/openclaw-stow` and `/openclaw-restart` skills also do this automatically.
**Warning signs:** `ERROR: stow: existing target is not owned by stow: cron/jobs.json` in stow output.

### Pitfall 2: nvm Node Not Visible to launchd
**What goes wrong:** Gateway daemon fails to start with "command not found: node" or silently uses wrong Node version (Node 18/20 from Homebrew default install), triggering fatal "Node version unsupported" error.
**Why it happens:** launchd does not source `~/.zshrc` or `~/.profile`. nvm injects itself via shell profile. The launchd environment PATH does not include nvm's shims directory.
**How to avoid:** Use Homebrew node@24 (not nvm). Pin the absolute path in `openclaw-secrets.sh`: `export PATH="/opt/homebrew/opt/node@24/bin:$PATH"` (Apple Silicon). The install script detects nvm and explicitly warns: "nvm appears to be managing Node for this shell. Run: `nvm install 24 && nvm use 24 && nvm alias default 24` Then rerun installer."
**Warning signs:** Gateway status shows `runtime.status: "unknown"` or `missingUnit: true`.

### Pitfall 3: Missing --no-folding Creates Directory Symlinks
**What goes wrong:** Running `stow -t ~/Documents/agentic-setup .` from `cc-openclaw/` without `--no-folding` creates `~/Documents/agentic-setup/.claude` as a directory symlink pointing to `cc-openclaw/.claude`. When Claude Code scans for skills, it cannot traverse directory symlinks to discover skill subdirectories.
**Why it happens:** GNU Stow's default "tree folding" optimization collapses an entire subdirectory tree into a single directory-level symlink when all contents come from one source package.
**How to avoid:** Always use `stow --no-folding` when deploying cc-openclaw into the project directory. This creates the actual `.claude/` and `.claude/skills/` directories, and creates individual symlinks for each skill subdirectory.
**Warning signs:** `/openclaw-` commands do not autocomplete in Claude Code; `ls ~/Documents/agentic-setup/.claude/skills/` shows nothing or shows a single symlink instead of multiple directories.

### Pitfall 4: OPENCLAW_REPO Detection Fails on Plain File
**What goes wrong:** All 9 cc-openclaw skills cannot find the repo. They report an error about OPENCLAW_REPO being unset or empty.
**Why it happens:** Skills detect the repo via `readlink ~/.openclaw/openclaw.json`. If `openclaw.json` is a plain file (i.e., stow has not been run yet, or stow ran but there was a conflict), `readlink` returns nothing.
**How to avoid:** Confirm stow is working before testing skills: `readlink ~/.openclaw/openclaw.json` should return a path containing `agentic-setup/.openclaw/openclaw.json`.
**Warning signs:** `readlink ~/.openclaw/openclaw.json` returns empty; skill outputs show "Could not find openclaw repo."

### Pitfall 5: node@24 keg-only PATH Not Set for Shell Sessions
**What goes wrong:** After `brew install node@24`, running `node --version` still shows v22 (or v18). OpenClaw installer may still install under the wrong Node.
**Why it happens:** `node@24` is a "keg-only" Homebrew formula — it is NOT symlinked into `/opt/homebrew/bin` because it would conflict with the default `node` formula. The binary lives at `/opt/homebrew/opt/node@24/bin/node` and is not on PATH by default.
**How to avoid:** `install-prereqs.sh` must add `/opt/homebrew/opt/node@24/bin` to PATH before running any `node` commands. Architecture detection: Apple Silicon uses `/opt/homebrew/opt/node@24/bin`; Intel uses `/usr/local/opt/node@24/bin`. The OpenClaw installer also handles this: `ensure_macos_default_node_active()` prepends `brew --prefix node@24/bin` to PATH for the duration of the install run.
**Warning signs:** `brew install node@24` exits 0 but `node --version` still shows v22.

### Pitfall 6: Stow Conflict with Existing ~/.openclaw/ Files
**What goes wrong:** First stow run fails with "existing target is not owned by stow" for multiple files because `~/.openclaw/` already contains plain files from the pre-existing OpenClaw 2026.3.12 install.
**Why it happens:** The existing `~/.openclaw/openclaw.json` and other files were created by `openclaw onboard` (non-stow-managed). Stow refuses to adopt files it did not create.
**How to avoid:** Plan 01-04 must include: backup `~/.openclaw/openclaw.json` to `~/.openclaw/openclaw.json.pre-stow`, then remove it. Then run stow — it will create the symlink. The new `.openclaw/openclaw.json` in the repo should incorporate the necessary agent/channel config from the backup.
**Warning signs:** `stow: existing target is not owned by stow: .openclaw/openclaw.json` on first stow run.

### Pitfall 7: /openclaw-status Checks Require Stow AND Daemon Running
**What goes wrong:** `/openclaw-status` reports errors even after all files are correct because the gateway daemon is not running (LaunchAgent not loaded).
**Why it happens:** The status skill checks live gateway health via the health endpoint (`127.0.0.1:18789`). If the LaunchAgent is not loaded, the health check fails regardless of config correctness.
**How to avoid:** Sequence must be: stow → `openclaw gateway install` (or `openclaw onboard --install-daemon`) → `launchctl kickstart -k gui/$(id -u)/ai.openclaw.gateway` → wait 5 seconds → run `/openclaw-status`. The INFRA-06 verification only passes when the daemon is actually running.
**Warning signs:** Health endpoint returns connection refused; `/openclaw-status` shows gateway as "not running."

---

## Code Examples

Verified patterns from official sources:

### install-prereqs.sh — Complete Implementation Pattern
```zsh
#!/usr/bin/env zsh
# Source: CONTEXT.md D-12 through D-15 + brew keg-only documentation
set -euo pipefail

# Fail fast if Homebrew is not installed (D-14)
if ! command -v brew &>/dev/null; then
  print "ERROR: Homebrew is required but not installed." >&2
  print "Install it: https://brew.sh" >&2
  print '{"ok":false,"error":"homebrew_required"}'
  exit 1
fi

# Install missing prerequisites (D-12)
brew list node@24 &>/dev/null || brew install node@24
brew list stow &>/dev/null    || brew install stow
brew list jq &>/dev/null      || brew install jq

# Detect architecture — node@24 is keg-only (D-13)
# Apple Silicon: /opt/homebrew/opt/node@24/bin
# Intel:         /usr/local/opt/node@24/bin
if [[ "$(uname -m)" == "arm64" ]]; then
  NODE24_BIN="/opt/homebrew/opt/node@24/bin"
else
  NODE24_BIN="/usr/local/opt/node@24/bin"
fi

export PATH="${NODE24_BIN}:${PATH}"

# Verify Node 24 is now active
node_version="$(node --version 2>/dev/null || true)"
if [[ "${node_version}" != v24* ]]; then
  print "ERROR: node@24 not active after PATH update. Got: ${node_version}" >&2
  print '{"ok":false,"error":"node24_not_active"}'
  exit 1
fi

# Pin node@24 in openclaw-secrets.sh (for launchd) — only if file exists
# Note: file is created by stow-deploy.sh AFTER stow runs; this is a post-stow step
SECRETS_SH="$HOME/Documents/agentic-setup/.openclaw/scripts/openclaw-secrets.sh"
if [[ -f "$SECRETS_SH" ]]; then
  if ! grep -q "node@24" "$SECRETS_SH"; then
    print "export PATH=\"${NODE24_BIN}:\$PATH\"" >> "$SECRETS_SH"
    print "Pinned node@24 in openclaw-secrets.sh" >&2
  fi
fi

print '{"ok":true,"data":{"node":"'"${node_version}"'","arch":"'"$(uname -m)"'"}}'
```

### stow-deploy.sh — Canonical Deploy Entry Point
```zsh
#!/usr/bin/env zsh
# Source: CONTEXT.md D-04, D-09, D-10, D-11
set -euo pipefail

REPO_DIR="${REPO_DIR:-$HOME/Documents/agentic-setup}"
OPENCLAW_DIR="$REPO_DIR/.openclaw"

print "Deploying .openclaw/ via stow..." >&2

# Resolve known jobs.json conflict (D-09)
# The gateway recreates this file on every startup, converting symlink to plain file
rm -f "$HOME/.openclaw/cron/jobs.json"
# ADD ADDITIONAL CONFLICT CLEANUPS HERE if discovered during Phase 1 execution

# Deploy .openclaw package to ~ (D-01: explicit --dir and --target)
stow --dir="$REPO_DIR" --target="$HOME" --no-folding .openclaw

print "Stow deploy complete. Run /openclaw-restart to apply changes." >&2
# D-10: stow-deploy.sh does NOT restart the gateway
print '{"ok":true,"data":{"deployed":".openclaw"}}'
```

### Secrets Pipeline — Keychain Store and File Update
```bash
# Source: cc-openclaw openclaw-add-secret SKILL.md + CONTEXT.md canonical refs
# Store secret in Keychain (never echo the value)
security add-generic-password \
  -s "openclaw.example-token" \
  -a "$USER" \
  -w  # prompts for value securely

# Append to openclaw-secrets.sh (launchd env)
echo 'export OPENCLAW_EXAMPLE_TOKEN="$(security find-generic-password -s '"'"'openclaw.example-token'"'"' -w)"' \
  >> ~/.openclaw/scripts/openclaw-secrets.sh

# Append to openclaw-env.sh (shell sessions)
echo 'export OPENCLAW_EXAMPLE_TOKEN="$(security find-generic-password -s '"'"'openclaw.example-token'"'"' -w)"' \
  >> ~/.openclaw/scripts/openclaw-env.sh

# Add to secrets.sh provisioning array (repo root)
# Format: "keychain-service|ENV_VAR_NAME|human-readable description"
```

### OPENCLAW_REPO Detection (used by all skills)
```bash
# Source: cc-openclaw README + CONTEXT.md canonical refs
# Requires openclaw.json to be a stow symlink
OPENCLAW_REPO=$(readlink ~/.openclaw/openclaw.json 2>/dev/null | sed 's|/.openclaw/openclaw.json||')
if [[ -z "$OPENCLAW_REPO" ]]; then
  echo "ERROR: ~/.openclaw/openclaw.json is not a stow symlink. Run stow-deploy.sh first." >&2
  exit 1
fi
```

### Gateway Restart Sequence (from /openclaw-restart skill)
```bash
# Source: cc-openclaw openclaw-restart SKILL.md
# Step 1: Remove jobs.json conflict
rm -f ~/.openclaw/cron/jobs.json

# Step 2: Re-stow
cd "$OPENCLAW_REPO" && stow --no-folding -t ~ .

# Step 3: Restart LaunchAgent (single-gateway)
launchctl kickstart -k "gui/$(id -u)/ai.openclaw.gateway"

# Step 4: Wait and verify
sleep 5
tail -30 ~/.openclaw/logs/gateway.log
# Look for: "[telegram] [<agent>] starting provider" — one per bot
# Gateway port: 18789
```

### Test Cron Job for INFRA-06 Validation
```bash
# A test cron job verifies: jobs.json stow cycle, timezone field, /openclaw-status output
# The timezone field is inside the schedule object of each job entry in jobs.json
# UTC is the default if tz is omitted — always set tz explicitly
# Example jobs.json entry structure:
{
  "id": "$(python3 -c 'import uuid; print(uuid.uuid4())')",
  "agentId": "main",
  "name": "test-infra-health",
  "enabled": true,
  "createdAtMs": <epoch_ms>,
  "schedule": {
    "cron": "0 9 * * *",
    "tz": "America/New_York"   # REQUIRED — omitting defaults to UTC
  },
  "sessionTarget": "isolated",  # default, recommended (cheaper, no context bleed)
  "wakeMode": "now",
  "payload": { "message": "Health check ping" }
}
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `npm install -g openclaw@latest` | `curl -fsSL https://openclaw.ai/install.sh \| bash` | March 2026 | Native installer handles sharp/libvips binaries, daemon setup, and build tools; npm still works but is legacy path |
| Manual `openclaw.json` editing | cc-openclaw skill invocations only | Anytime cc-openclaw is deployed | Eliminates convention drift across agents with different models/context states |
| crontab for scheduling | launchd via `openclaw-add-cron` | macOS 12+ | cron deprecated on macOS; launchd is native scheduler and supports event-based triggers |
| `#!/bin/bash` shebang | `#!/usr/bin/env zsh` | macOS Catalina (2019) | macOS ships bash 3.2 (GPL2 locked); zsh 5.9+ is default shell |

**Deprecated/outdated:**
- `npm install -g openclaw`: Still functional but not the official install path as of March 2026. The curl installer handles more edge cases (native binaries, daemon setup).
- Heartbeat scheduling (agent-loop polling): Replaced by cron with deterministic scripts per cc-openclaw design rationale — cron guarantees execution independent of agent workload.

---

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `openclaw onboard --install-daemon` installs the LaunchAgent on a fresh install during an interactive TTY session; when run non-interactively (CI, script), it requires `--no-onboard` then a separate `openclaw gateway install` | Architecture Patterns §Gateway Restart | If the install flow differs, the LaunchAgent setup step in Plan 01-01 may need different commands |
| A2 | The existing `~/.openclaw/` content from the pre-existing 2026.3.12 install will conflict with the first stow run | Runtime State Inventory | If OpenClaw's stow conflict handling works differently, Plan 01-04 may need to use `stow --adopt` instead of manual backup+remove |
| A3 | `secrets.sh` lives at the repo root (not inside `.openclaw/`) so it is NOT stowed to `~/` | §Three-File Secrets Pipeline | If secrets.sh must be in a different location, the `openclaw-add-secret` skill behavior would differ |
| A4 | `openclaw gateway install --force` is available as a non-interactive daemon installation command (seen in installer source) | §INFRA-06 Validation | If this flag doesn't exist in 2026.5.18, daemon installation requires interactive `openclaw onboard` |

**If this table is empty:** All claims in this research were verified or cited — this table is NOT empty; see items above requiring user confirmation at execution time.

---

## Open Questions (RESOLVED)

1. **Existing ~/.openclaw/ stow conflict strategy**
   - **RESOLVED:** Plan 01-04 Task 2 uses backup-and-delete approach: `cp ~/.openclaw/openclaw.json ~/.openclaw/openclaw.json.pre-stow && rm ~/.openclaw/openclaw.json`, then run `zsh scripts/stow-deploy.sh`. `stow --adopt` is explicitly prohibited (it would move the unmanaged file into the repo, overwriting the new config).
   - What we know: `~/.openclaw/openclaw.json` is a plain file, not a symlink. First stow will conflict on this file and potentially others.
   - What's unclear (historical): Should Plan 01-04 (a) backup and delete conflicting files, (b) use `stow --adopt` to have stow take ownership of existing files, or (c) delete `~/.openclaw/` entirely and let stow recreate it from the repo?
   - Recommendation: Plan 01-04 should backup `~/.openclaw/openclaw.json` → `~/.openclaw/openclaw.json.pre-stow`, then delete it. `stow --adopt` is risky because it moves the existing file into the repo, potentially overwriting the new config.

2. **Node 24 transition: nvm vs brew**
   - **RESOLVED:** Use brew node@24 as decided (D-12/D-13). Both nvm and brew coexist — nvm handles interactive shells, brew node@24 handles launchd (which does not source shell profiles). install-prereqs.sh pins the brew node@24 PATH in BOTH openclaw-secrets.sh (launchd) and openclaw-env.sh (shell sessions) per D-13.
   - What we know: The machine uses nvm with Node 22.18.0. The OpenClaw installer detects nvm and instructs `nvm install 24 && nvm use 24 && nvm alias default 24`.
   - What's unclear (historical): D-13 says "install Node 24 via brew." Does the user prefer brew over setting nvm default? Both paths work, but launchd PATH requires explicit node@24 binary path regardless.
   - Recommendation: Use brew node@24 as decided (D-12/D-13). The `install-prereqs.sh` adds node@24 to PATH. Both nvm and brew can coexist — nvm handles interactive shells, brew node@24 handles launchd.

3. **OpenClaw onboard interactive requirement**
   - **RESOLVED:** Plan 01-01 Task 4 is a blocking `checkpoint:human-action` — the user must run `openclaw onboard --install-daemon` interactively in their terminal (TTY required). Claude Code cannot run the onboard wizard non-interactively.
   - What we know: `openclaw onboard --install-daemon` is the documented command but opens an interactive wizard. Install script exits to `openclaw onboard` when a TTY is available.
   - What's unclear (historical): Can the daemon be installed non-interactively (e.g., `openclaw gateway install`) separate from the onboard wizard?
   - Recommendation: Plan 01-01 should note that `openclaw onboard --install-daemon` is interactive and must be run by the user in their terminal (not in a Claude Code tool call). The plan action should be a terminal instruction.

---

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Homebrew | install-prereqs.sh (D-14) | Yes | 5.1.7 [VERIFIED: machine] | None — D-14 says fail with error if missing |
| Node.js 22+ | OpenClaw minimum | Yes (nvm v22.18.0) | v22.18.0 [VERIFIED: machine] | — |
| Node.js 24 (brew) | OpenClaw recommended; launchd PATH | No — not yet installed | — | nvm node 24 (but launchd PATH issue) |
| GNU Stow | stow-deploy.sh, cc-openclaw deployment | No — not installed | — | None — required for the deployment pattern |
| jq | json-response.sh pattern | Yes | 1.7.1 [VERIFIED: machine] | — |
| git | Submodule management | Yes (system) | — | — |
| OpenClaw | Everything | Partial — 2026.3.12 installed, not 2026.5.18, no LaunchAgent | v2026.3.12 [VERIFIED: machine] | Upgrade via curl installer |
| macOS Keychain (security CLI) | secrets pipeline | Yes | Built-in [VERIFIED: macOS 13+] | — |

**Missing dependencies with no fallback:**
- `node@24` via brew — must be installed before `openclaw onboard --install-daemon` can reliably set up the LaunchAgent with the correct node binary in PATH
- `stow` (GNU Stow 2.4.1) — foundational to the entire deployment model; install via `brew install stow`

**Missing dependencies with fallback:**
- OpenClaw 2026.5.18 — version 2026.3.12 is installed; curl installer upgrades it

---

## Validation Architecture

> `workflow.nyquist_validation` is `true` in `.planning/config.json`.

### Test Framework

| Property | Value |
|----------|-------|
| Framework | Shell script assertions (no external test framework needed — Phase 1 is infrastructure setup, not application code) |
| Config file | none — verification is shell commands with exit-code checks |
| Quick run command | `bash -c 'node --version | grep -q "^v24" && echo PASS || echo FAIL'` |
| Full suite command | See Phase Requirements → Test Map below |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| INFRA-01 | OpenClaw 2026.5.18 installed, Node 24 active | smoke | `openclaw --version \| grep -q 2026.5.18 && node --version \| grep -q "^v24"` | ❌ Wave 0 |
| INFRA-01 | LaunchAgent installed (`ai.openclaw.gateway` plist exists) | smoke | `ls ~/Library/LaunchAgents/ \| grep -q ai.openclaw.gateway` | ❌ Wave 0 |
| INFRA-02 | All 9 cc-openclaw skills available in `.claude/skills/` | smoke | `ls ~/Documents/agentic-setup/.claude/skills/ \| wc -l \| grep -q "9"` | ❌ Wave 0 |
| INFRA-02 | Skills are symlinks (not plain files) | smoke | `test -L ~/Documents/agentic-setup/.claude/skills/openclaw-status` | ❌ Wave 0 |
| INFRA-03 | Secret stored in Keychain and all 3 files updated | integration | `security find-generic-password -s "openclaw.test-secret" -w >/dev/null && grep -q OPENCLAW_TEST_SECRET ~/.openclaw/scripts/openclaw-secrets.sh && grep -q OPENCLAW_TEST_SECRET ~/.openclaw/scripts/openclaw-env.sh && grep -q "openclaw.test-secret" ~/Documents/agentic-setup/secrets.sh` | ❌ Wave 0 |
| INFRA-04 | `~/.openclaw/openclaw.json` is a stow symlink (not plain file) | smoke | `test -L ~/.openclaw/openclaw.json` | ❌ Wave 0 |
| INFRA-04 | Stow deploy succeeds after jobs.json deletion | smoke | `rm -f ~/.openclaw/cron/jobs.json && stow --dir=$HOME/Documents/agentic-setup --target=$HOME --no-folding .openclaw && echo PASS` | ❌ Wave 0 |
| INFRA-06 | `/openclaw-status` output shows gateway running | manual + smoke | `openclaw gateway status --json \| python3 -c "import json,sys; d=json.load(sys.stdin); assert d['service']['runtime']['status'] != 'unknown'"` | ❌ Wave 0 |
| INFRA-06 | Test cron job timezone field is NOT UTC | smoke | Check `/openclaw-status` output for cron job `tz` field != "UTC" | manual |

### Sampling Rate

- **Per task commit:** `openclaw --version && test -L ~/.openclaw/openclaw.json && echo infra-ok`
- **Per wave merge:** Full suite: all smoke tests above, plus `openclaw gateway status`
- **Phase gate:** Full suite green + manual `/openclaw-status` review before moving to Phase 2

### Wave 0 Gaps

- [ ] `scripts/infra-verify.sh` — runs all smoke tests above in sequence, outputs structured JSON result
- [ ] `scripts/install-prereqs.sh` — prerequisite installer (D-12 through D-15)
- [ ] `scripts/stow-deploy.sh` — canonical deploy entry point (D-04)
- [ ] `scripts/lib/json-response.sh` — shared JSON response library
- [ ] `.openclaw/scripts/openclaw-secrets.sh` — launchd env injection file (minimal, to be populated by `/openclaw-add-secret`)
- [ ] `.openclaw/scripts/openclaw-env.sh` — shell session env file
- [ ] `secrets.sh` — disaster recovery provisioning script (repo root)
- [ ] `.openclaw/openclaw.json` — minimal gateway config (gateway starts with safe defaults)
- [ ] `.stow-ignore` — prevents stow from touching non-.openclaw/ content

---

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | No | Phase 1 sets up infrastructure only; agent auth is Phase 3+ |
| V3 Session Management | No | Phase 3+ |
| V4 Access Control | Partial | macOS Keychain is the access control layer for secrets; `security` CLI requires user authentication |
| V5 Input Validation | No | No user-facing input processing in Phase 1 |
| V6 Cryptography | No | No custom crypto; Keychain handles encryption |

### Known Threat Patterns for this Stack

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Hardcoded secrets in openclaw.json or tracked files | Information Disclosure | macOS Keychain only — `security add-generic-password`; never echo secret values; `secrets.sh` in repo contains only Keychain *references*, not values |
| Old npm openclaw binary on PATH before brew node@24 | Tampering (wrong version executes) | `install-prereqs.sh` prepends node@24 PATH; confirm with `which openclaw && openclaw --version` |
| jobs.json containing sensitive job payloads committed to git | Information Disclosure | jobs.json is gateway-owned and gitignored; `.stow-ignore` excludes it from stow management |
| Stow adopting files with insecure permissions | Elevation of Privilege | After stow: `chmod 700 ~/.openclaw` (flagged by `openclaw doctor`) |

---

## Sources

### Primary (HIGH confidence)
- `docs/human/Trilogy AI Center of Excellence - Managing OpenClaw with Claude Code.md` — cc-openclaw design rationale, all 9 skills, three-file secrets pipeline, jobs.json stow gotcha, stow setup command [VERIFIED: read in this session]
- `github.com/rahulsub-be/cc-openclaw` — skill directory structure (`.claude/skills/<name>/SKILL.md`), stow command (`--no-folding -t ~/your-openclaw-home-repo .`), `.stow-local-ignore` usage [VERIFIED: WebFetch]
- `cc-openclaw openclaw-add-secret SKILL.md` — exact naming convention, 3-file update sequence, verification step [VERIFIED: WebFetch]
- `cc-openclaw openclaw-stow SKILL.md` — jobs.json cleanup sequence, stow command pattern [VERIFIED: WebFetch]
- `cc-openclaw openclaw-restart SKILL.md` — exact restart sequence, 5-second wait, log verification [VERIFIED: WebFetch]
- `cc-openclaw openclaw-status SKILL.md` — what the skill checks, "green" output definition [VERIFIED: WebFetch]
- `cc-openclaw openclaw-add-cron SKILL.md` — jobs.json entry structure, timezone field requirement, UUID generation [VERIFIED: WebFetch]
- `cc-openclaw openclaw-new-agent SKILL.md` — agent directory structure, 6 required markdown files [VERIFIED: WebFetch]
- `docs.openclaw.ai/install` — curl installer command, daemon setup, `openclaw onboard --install-daemon` [VERIFIED: WebFetch]
- `docs.openclaw.ai/gateway/configuration` — openclaw.json minimal config, JSON5 format, SecretRef pattern [VERIFIED: WebFetch]
- `docs.openclaw.ai/channels/telegram` — channels.telegram config structure, dmPolicy options [VERIFIED: WebFetch]
- OpenClaw install script (live) — Node version detection logic (22.19 min, 24 default), nvm detection and guidance, `check_existing_openclaw()`, `ensure_macos_default_node_active()` [VERIFIED: curl https://openclaw.ai/install.sh]

### Secondary (MEDIUM confidence)
- npm registry — `openclaw@2026.5.18` confirmed latest stable (dist-tags.latest), 894,142 weekly downloads, github.com/openclaw/openclaw source repo, postinstall script behavior [VERIFIED: npm view + npm API]
- Homebrew formulae — `node@24` 24.15.0 keg-only, `stow` 2.4.1 [VERIFIED: brew info]
- Machine state — Node v22.18.0 via nvm, OpenClaw 2026.3.12 at `~/.nvm/versions/node/v22.18.0/bin/openclaw`, no LaunchAgent loaded, `~/.openclaw/openclaw.json` is plain file [VERIFIED: bash commands]

### Tertiary (LOW confidence)
- GNU Stow manual (WebSearch summary) — `.stow-local-ignore` vs `~/.stow-global-ignore` difference; `--no-folding` behavior [cited from GNU Stow manual via search result summary; not directly fetched due to rate limit]

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — all package versions verified against npm registry, Homebrew formulae, and live machine state
- Architecture: HIGH — patterns derived from official cc-openclaw SKILL.md files and primary reference document
- Pitfalls: HIGH — most pitfalls derived from actual observed state (nvm conflict, existing plain openclaw.json, keg-only node@24)
- Runtime State: HIGH — verified by direct machine inspection

**Research date:** 2026-05-20
**Valid until:** 2026-06-20 (OpenClaw releases frequently; verify openclaw version before executing)

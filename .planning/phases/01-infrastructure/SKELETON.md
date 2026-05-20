---
phase: 01-infrastructure
type: walking-skeleton
created: 2026-05-20
---

# Walking Skeleton — Phase 1 Infrastructure

This document records the architectural decisions that the Phase 1 Walking Skeleton freezes for the rest of the project. Subsequent phases build on these without renegotiating.

## What the Skeleton Proves

The thinnest end-to-end "infrastructure governance" loop:

1. A developer (or agent) edits a file under `~/Documents/agentic-setup/.openclaw/`
2. Runs `scripts/stow-deploy.sh` — the script removes the known `jobs.json` symlink conflict and stows `.openclaw/` into `~/.openclaw/`
3. `~/.openclaw/openclaw.json` resolves as a symlink back into the repo (verifiable with `readlink`)
4. cc-openclaw skills (e.g., `/openclaw-status`) work because their `OPENCLAW_REPO` detection follows that symlink
5. The OpenClaw LaunchAgent reads the symlinked config and runs

If any step in this chain breaks, every subsequent phase's configuration path is broken. The skeleton makes the failure observable in seconds via `scripts/infra-verify.sh`.

## Frozen Architectural Decisions

### Repository Layout
- **Root:** `~/Documents/agentic-setup/` (single git repo, no monorepo split)
- **Stow package:** `.openclaw/` only — deployed to `~/.openclaw/`
- **Submodule:** `cc-openclaw/` (HEAD on `github.com/rahulsub-be/cc-openclaw`) stowed INTO the project (not into `~/`) producing `.claude/skills/openclaw-*/` symlinks
- **Scripts:** `scripts/` (repo-management; NOT stowed), `.openclaw/scripts/` (deployed; sourced by launchd and shells)
- **Stow exclusion list:** `.stow-ignore` at repo root

### Deployment Mechanism
- **Tool:** GNU Stow (Homebrew `stow` 2.4.x)
- **Invocation:** Always explicit `--dir=$HOME/Documents/agentic-setup --target=$HOME --no-folding .openclaw` (decision D-01)
- **Canonical entry point:** `scripts/stow-deploy.sh` — both humans and agents use this script (D-04)
- **jobs.json cleanup:** `rm -f ~/.openclaw/cron/jobs.json` before every stow (D-09)
- **Restart:** Always a separate explicit step via `/openclaw-restart` — `stow-deploy.sh` does NOT restart the gateway (D-10)

### Runtime
- **Daemon:** macOS LaunchAgent `ai.openclaw.gateway` installed by `openclaw onboard --install-daemon`
- **Node:** Homebrew `node@24` (keg-only) — binary at `/opt/homebrew/opt/node@24/bin` (Apple Silicon) or `/usr/local/opt/node@24/bin` (Intel)
- **Node PATH injection:** pinned in `.openclaw/scripts/openclaw-secrets.sh` so launchd sees it without sourcing a shell profile

### Secrets Pipeline (frozen for all phases)
- **Storage:** macOS Keychain only (via `security` CLI)
- **Naming:** service `openclaw.<name>` (lowercase, hyphens), env var `OPENCLAW_<NAME>` (uppercase, underscores)
- **Three files** updated on every secret addition:
  1. `.openclaw/scripts/openclaw-secrets.sh` — sourced by launchd
  2. `.openclaw/scripts/openclaw-env.sh` — sourced by shells
  3. `secrets.sh` (repo root, NOT stowed) — disaster-recovery provisioning
- **Authoring path:** `/openclaw-add-secret` skill only — never manual edits

### Skills Discovery
- **Location:** `.claude/skills/openclaw-*/SKILL.md` (one directory per skill)
- **Source:** cc-openclaw submodule
- **Stow invocation:** `cd cc-openclaw && stow --no-folding -t /Users/trilogy/Documents/agentic-setup .`
- **Update path:** `git pull` inside the submodule; no re-stow required for content updates

### Health Verification
- **Smoke test runner:** `scripts/infra-verify.sh` — runs assertions for INFRA-01 through INFRA-04
- **Full health check:** `/openclaw-status` skill — verifies gateway, channels, cron jobs, agents
- **Test cron job:** Created via `/openclaw-add-cron` with a non-UTC timezone (proves INFRA-06 end to end)

### Shell Scripting Conventions (frozen)
- Shebang: `#!/usr/bin/env zsh`
- Strict mode: `set -euo pipefail`
- Output protocol: stdout = JSON only `{"ok":true,"data":{...}}` / stderr = human logs
- Shared lib: `scripts/lib/json-response.sh`

## Skeleton Acceptance

The Walking Skeleton is considered "alive" when the following are all true (verified by `scripts/infra-verify.sh`):

1. `openclaw --version` returns `2026.5.18` and `node --version` starts with `v24`
2. `~/Library/LaunchAgents/ai.openclaw.gateway.plist` exists
3. `~/Documents/agentic-setup/.claude/skills/` contains 9 symlinked directories (one per cc-openclaw skill)
4. `readlink ~/.openclaw/openclaw.json` returns a path containing `agentic-setup/.openclaw/openclaw.json`
5. `security find-generic-password -s openclaw.test-secret -w` succeeds for the Phase 1 test secret, and the secret's env var appears in all three pipeline files
6. `/openclaw-status` reports gateway, channels, and cron as healthy (green)
7. A test cron job created via `/openclaw-add-cron` appears in `/openclaw-status` with a local-timezone `tz` field

## Boundary

This skeleton intentionally excludes:
- Any channel provisioning (Phase 2)
- Any agents in `agents.list` (Phase 3+)
- Beads task graphs (Phase 4)
- Real secrets — only a `openclaw.test-secret` placeholder is created to prove the pipeline

These are layered on top of the skeleton in subsequent phases using the cc-openclaw skills wired up here.

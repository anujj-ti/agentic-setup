# Phase 1: Infrastructure - Pattern Map

**Mapped:** 2026-05-20
**Files analyzed:** 9 new files + 1 submodule setup
**Analogs found:** 0 / 9 (greenfield — RESEARCH.md patterns are canonical)

---

## Context: Greenfield Repository

This is Phase 1 of a greenfield project. The repository contains only `CLAUDE.md` and
`.planning/` artifacts. There are no existing implementation files to use as codebase analogs.

For every file in this phase, the pattern source is either:
- A verified code example in `01-RESEARCH.md` (section `## Code Examples`)
- A CLAUDE.md convention
- A RESEARCH.md `## Architecture Patterns` section

The planner MUST reference RESEARCH.md section headers when writing plan actions.

---

## File Classification

| New File | Role | Data Flow | Pattern Source | Source Location |
|----------|------|-----------|----------------|-----------------|
| `scripts/install-prereqs.sh` | shell-script / installer | batch (brew installs + PATH setup) | RESEARCH.md §install-prereqs.sh | `01-RESEARCH.md` "Code Examples → install-prereqs.sh" |
| `scripts/stow-deploy.sh` | shell-script / deploy-runner | batch (stow deploy + cleanup) | RESEARCH.md §stow-deploy.sh | `01-RESEARCH.md` "Code Examples → stow-deploy.sh" |
| `scripts/lib/json-response.sh` | shell-script / shared-lib | transform (stdout → JSON) | CLAUDE.md json-response convention | `CLAUDE.md` "Shell Scripting Conventions" |
| `scripts/infra-verify.sh` | shell-script / smoke-test | batch (assertions + structured output) | RESEARCH.md §Validation Architecture | `01-RESEARCH.md` "Validation Architecture → Phase Requirements → Test Map" |
| `.openclaw/openclaw.json` | config | — (static file read by gateway) | RESEARCH.md §Pattern 5 | `01-RESEARCH.md` "Architecture Patterns → Pattern 5" |
| `.openclaw/scripts/openclaw-secrets.sh` | shell-script / env-injector | event-driven (sourced by launchd at daemon start) | RESEARCH.md §Pattern 3 | `01-RESEARCH.md` "Architecture Patterns → Pattern 3" |
| `.openclaw/scripts/openclaw-env.sh` | shell-script / env-injector | event-driven (sourced by interactive shell sessions) | RESEARCH.md §Pattern 3 | `01-RESEARCH.md` "Architecture Patterns → Pattern 3" |
| `secrets.sh` | shell-script / provisioner | batch (disaster-recovery secret re-install) | RESEARCH.md §Pattern 3 | `01-RESEARCH.md` "Architecture Patterns → Pattern 3" |
| `.stow-ignore` | config / stow-exclusion-list | — (static file read by stow) | CONTEXT.md D-03 | `01-CONTEXT.md` "Decisions → D-03" |
| `cc-openclaw/` (submodule) | git-submodule | — (not a created file) | CONTEXT.md D-05, D-06, D-07, D-08 | `01-CONTEXT.md` "Decisions → cc-openclaw Skills Placement" |

---

## Pattern Assignments

### `scripts/install-prereqs.sh` (shell-script, batch installer)

**Pattern source:** `01-RESEARCH.md` — "Code Examples → install-prereqs.sh — Complete Implementation Pattern"

**Shebang + strict mode** (apply to all scripts per CLAUDE.md):
```zsh
#!/usr/bin/env zsh
set -euo pipefail
```

**Homebrew guard** (D-14 — fail immediately with install URL if brew missing):
```zsh
if ! command -v brew &>/dev/null; then
  print "ERROR: Homebrew is required but not installed." >&2
  print "Install it: https://brew.sh" >&2
  print '{"ok":false,"error":"homebrew_required"}'
  exit 1
fi
```

**Idempotent brew installs** (D-12 — install only if not already present):
```zsh
brew list node@24 &>/dev/null || brew install node@24
brew list stow &>/dev/null    || brew install stow
brew list jq &>/dev/null      || brew install jq
```

**Architecture-aware PATH for keg-only node@24** (D-13 — Pitfall 5):
```zsh
if [[ "$(uname -m)" == "arm64" ]]; then
  NODE24_BIN="/opt/homebrew/opt/node@24/bin"
else
  NODE24_BIN="/usr/local/opt/node@24/bin"
fi
export PATH="${NODE24_BIN}:${PATH}"
```

**Node version guard** (D-13 — detect and reject Node 18/20 per RESEARCH.md Pitfall 2):
```zsh
node_version="$(node --version 2>/dev/null || true)"
if [[ "${node_version}" != v24* ]]; then
  print "ERROR: node@24 not active after PATH update. Got: ${node_version}" >&2
  print '{"ok":false,"error":"node24_not_active"}'
  exit 1
fi
```

**Conditional node@24 PATH pin in openclaw-secrets.sh** (D-13 — only if file already exists):
```zsh
SECRETS_SH="$HOME/Documents/agentic-setup/.openclaw/scripts/openclaw-secrets.sh"
if [[ -f "$SECRETS_SH" ]]; then
  if ! grep -q "node@24" "$SECRETS_SH"; then
    print "export PATH=\"${NODE24_BIN}:\$PATH\"" >> "$SECRETS_SH"
    print "Pinned node@24 in openclaw-secrets.sh" >&2
  fi
fi
```

**JSON success output** (CLAUDE.md json-response convention):
```zsh
print '{"ok":true,"data":{"node":"'"${node_version}"'","arch":"'"$(uname -m)"'"}}'
```

**Key constraint (D-15):** This script MUST NOT run the OpenClaw curl installer. It handles prerequisites only. OpenClaw installation is a separate Plan 01-01 step.

---

### `scripts/stow-deploy.sh` (shell-script, batch deploy)

**Pattern source:** `01-RESEARCH.md` — "Code Examples → stow-deploy.sh — Canonical Deploy Entry Point" and "Architecture Patterns → Pattern 1"

**Shebang + strict mode:**
```zsh
#!/usr/bin/env zsh
set -euo pipefail
```

**Repo directory resolution** (D-01 — always use explicit `--dir` and `--target`):
```zsh
REPO_DIR="${REPO_DIR:-$HOME/Documents/agentic-setup}"
```

**jobs.json conflict cleanup** (D-09 — must run before every stow):
```zsh
# Resolve known stow conflict: gateway recreates this file on every startup,
# converting the stow symlink into a plain file
rm -f "$HOME/.openclaw/cron/jobs.json"
# ADD ADDITIONAL CONFLICT CLEANUPS HERE if discovered during Phase 1 execution
```

**Stow invocation** (D-01 — explicit `--dir`, `--target`, `--no-folding`):
```zsh
stow --dir="$REPO_DIR" --target="$HOME" --no-folding .openclaw
```

**No restart** (D-10 — stow-deploy.sh deploys only; restart is always a separate `/openclaw-restart` step):
```zsh
print "Stow deploy complete. Run /openclaw-restart to apply changes." >&2
```

**JSON success output:**
```zsh
print '{"ok":true,"data":{"deployed":".openclaw"}}'
```

---

### `scripts/lib/json-response.sh` (shell-script, shared library)

**Pattern source:** CLAUDE.md "Shell Scripting Conventions → Shared lib" and "Output protocol"

**Purpose:** Shared library sourced by other scripts. Provides `json_ok` and `json_fail` helpers so callers never hand-roll the response shape.

**Output protocol** (CLAUDE.md — stdout = JSON only, stderr = human-readable logs):
```zsh
#!/usr/bin/env zsh
# json-response.sh — sourced by other scripts, never executed directly
# Source: CLAUDE.md "Shell Scripting Conventions" + cc-openclaw json-response.sh pattern

# Usage: json_ok '{"key":"value"}'
json_ok() {
  local data="${1:-{}}"
  print "{\"ok\":true,\"data\":${data}}"
}

# Usage: json_fail "error_code" "human message"
json_fail() {
  local code="$1"
  local msg="$2"
  print "{\"ok\":false,\"error\":\"${code}\"}" 
  print "ERROR: ${msg}" >&2
}
```

**Caller sourcing pattern:**
```zsh
# At top of each script in scripts/ or .openclaw/scripts/:
source "$(dirname "$0")/lib/json-response.sh"
# or, for scripts in .openclaw/scripts/ (no lib/ sibling):
# Inline the helpers directly — they are small
```

**Key constraint:** stdout emits ONLY the JSON response object. All diagnostic messages go to stderr via `print "..." >&2`. Callers check `jq '.ok'` on stdout.

---

### `scripts/infra-verify.sh` (shell-script, smoke-test runner)

**Pattern source:** `01-RESEARCH.md` — "Validation Architecture → Phase Requirements → Test Map" (Wave 0 gap list) and individual smoke test commands in the test map table.

**Shebang + strict mode:**
```zsh
#!/usr/bin/env zsh
set -euo pipefail
```

**Test structure — assertions with pass/fail tracking:**
```zsh
PASS=0
FAIL=0
FAILURES=()

check() {
  local label="$1"
  shift
  if "$@" &>/dev/null; then
    print "[PASS] ${label}" >&2
    (( PASS++ ))
  else
    print "[FAIL] ${label}" >&2
    (( FAIL++ ))
    FAILURES+=("${label}")
  fi
}
```

**Individual checks** (drawn directly from RESEARCH.md "Phase Requirements → Test Map"):
```zsh
# INFRA-01: OpenClaw version
check "openclaw 2026.5.18 installed" \
  bash -c 'openclaw --version | grep -q 2026.5.18'

# INFRA-01: Node 24 active
check "node v24 active" \
  bash -c 'node --version | grep -q "^v24"'

# INFRA-01: LaunchAgent plist exists
check "launchagent plist present" \
  test -f "$HOME/Library/LaunchAgents/ai.openclaw.gateway.plist"

# INFRA-02: All 9 skills present
check "9 cc-openclaw skills in .claude/skills/" \
  bash -c 'ls "$HOME/Documents/agentic-setup/.claude/skills/" | wc -l | grep -q "9"'

# INFRA-02: Skills are symlinks (not plain files)
check "openclaw-status is a symlink" \
  test -L "$HOME/Documents/agentic-setup/.claude/skills/openclaw-status"

# INFRA-04: openclaw.json is a stow symlink
check "~/.openclaw/openclaw.json is a stow symlink" \
  test -L "$HOME/.openclaw/openclaw.json"
```

**JSON output** (CLAUDE.md json-response shape):
```zsh
if (( FAIL == 0 )); then
  print "{\"ok\":true,\"data\":{\"passed\":${PASS},\"failed\":0}}"
else
  failed_json=$(printf '"%s",' "${FAILURES[@]}" | sed 's/,$//')
  print "{\"ok\":false,\"error\":\"smoke_tests_failed\",\"data\":{\"passed\":${PASS},\"failed\":${FAIL},\"failures\":[${failed_json}]}}"
  exit 1
fi
```

---

### `.openclaw/openclaw.json` (config, gateway startup)

**Pattern source:** `01-RESEARCH.md` — "Architecture Patterns → Pattern 5: Minimal openclaw.json for Gateway Start"

**Minimal Phase 1 config** (JSON5 format — OpenClaw supports comments and trailing commas):
```json5
// Source: docs.openclaw.ai/gateway/configuration
// Populated by /openclaw-new-agent in Phase 3+; channels added by /openclaw-add-channel in Phase 2
{
  agents: {
    defaults: {
      workspace: "~/.openclaw/workspace"
    },
    list: []
  }
  // channels: {} — added by /openclaw-add-channel (Phase 2)
  // cron: { enabled: true } — added by /openclaw-add-cron when first cron job is created
}
```

**Key constraint:** Do NOT manually edit this file after Phase 1 creates it. All subsequent changes go through cc-openclaw skills (`/openclaw-new-agent`, `/openclaw-add-channel`, `/openclaw-add-cron`) per CLAUDE.md convention and RESEARCH.md "Don't Hand-Roll" table.

**Key constraint:** Do NOT add `jobs.json` under `.openclaw/cron/` — the gateway owns that file and overwrites it on every startup. It must never be committed to git (Pitfall 1).

---

### `.openclaw/scripts/openclaw-secrets.sh` (shell-script, launchd env injector)

**Pattern source:** `01-RESEARCH.md` — "Architecture Patterns → Pattern 3: Three-File Secrets Pipeline"

**Purpose:** Loaded by launchd at gateway startup. Injects environment variables that the daemon needs but cannot get from shell profiles (launchd has no `~/.zshrc`).

**Initial state** (minimal file created by Phase 1; secrets are appended by `/openclaw-add-secret`):
```zsh
#!/usr/bin/env zsh
# openclaw-secrets.sh — sourced by launchd at ai.openclaw.gateway startup
# DO NOT edit manually. Use /openclaw-add-secret to add new secrets.
# Source: cc-openclaw openclaw-add-secret SKILL.md + CONTEXT.md canonical refs

# node@24 PATH pin — required because launchd does not source ~/.zshrc
# (architecture-aware; set by install-prereqs.sh or manually after brew install node@24)
# export PATH="/opt/homebrew/opt/node@24/bin:$PATH"   # Apple Silicon — uncomment after install-prereqs.sh runs
# export PATH="/usr/local/opt/node@24/bin:$PATH"      # Intel — uncomment if needed

# Secrets are appended below by /openclaw-add-secret:
```

**Per-secret pattern** (appended by `/openclaw-add-secret` skill, shown for reference):
```zsh
export OPENCLAW_<NAME>="$(security find-generic-password -s 'openclaw.<name>' -w)"
```

**Key constraint:** Secrets are NEVER hardcoded as plain values. They are always fetched from Keychain at runtime via `security find-generic-password`. The file contains only the `export` + `security` fetch expression.

---

### `.openclaw/scripts/openclaw-env.sh` (shell-script, shell session env injector)

**Pattern source:** `01-RESEARCH.md` — "Architecture Patterns → Pattern 3: Three-File Secrets Pipeline"

**Purpose:** Sourced by interactive shell sessions (add to `~/.zshrc`: `source ~/.openclaw/scripts/openclaw-env.sh`). Gives CLI commands the same credentials the daemon has.

**Initial state** (minimal; secrets appended by `/openclaw-add-secret`):
```zsh
#!/usr/bin/env zsh
# openclaw-env.sh — source this in your shell profile for CLI access to OpenClaw secrets
# Add to ~/.zshrc: source ~/.openclaw/scripts/openclaw-env.sh
# DO NOT edit manually. Use /openclaw-add-secret to add new secrets.

# node@24 PATH (same as openclaw-secrets.sh — keeps launchd and shell in sync)
# export PATH="/opt/homebrew/opt/node@24/bin:$PATH"   # Apple Silicon

# Secrets appended below by /openclaw-add-secret:
```

**Difference from openclaw-secrets.sh:** Same content structure, different consumer. `openclaw-secrets.sh` → launchd (daemon). `openclaw-env.sh` → shell sessions (human and agent CLI use).

---

### `secrets.sh` (shell-script, disaster recovery provisioner)

**Pattern source:** `01-RESEARCH.md` — "Architecture Patterns → Pattern 3: Three-File Secrets Pipeline" (fourth location: repo root provisioning script)

**Purpose:** On a fresh machine, run `secrets.sh` to re-create all Keychain entries from scratch. Contains only Keychain *references* (service names, env var names, descriptions) — never the actual secret values.

**Location:** Repo root (`~/Documents/agentic-setup/secrets.sh`). NOT under `.openclaw/` so it is NOT stowed to `~/`.

**Structure:**
```zsh
#!/usr/bin/env zsh
# secrets.sh — disaster recovery: re-provision all Keychain secrets on a fresh machine
# Run this after git clone + stow-deploy.sh on a new machine.
# For each entry: security add-generic-password prompts securely for the value.
# Source: cc-openclaw openclaw-add-secret SKILL.md + CONTEXT.md canonical refs
set -euo pipefail

# Format: "keychain-service-name|OPENCLAW_ENV_VAR_NAME|human-readable description"
# Entries are appended by /openclaw-add-secret
SECRETS=(
  # "openclaw.example-token|OPENCLAW_EXAMPLE_TOKEN|Example secret (replace with real entries)"
)

for entry in "${SECRETS[@]}"; do
  service="${entry%%|*}"
  rest="${entry#*|}"
  envvar="${rest%%|*}"
  description="${rest##*|}"

  print "Provisioning: ${description} (${service})" >&2
  security add-generic-password \
    -s "${service}" \
    -a "$USER" \
    -w  # prompts securely — value never echoed
done

print '{"ok":true,"data":{"provisioned":'"${#SECRETS[@]}"'}}'
```

**Key constraint:** This file lives at repo root and is tracked in git. It MUST NOT contain actual secret values — only service names and env var name mappings so a fresh machine knows which Keychain entries to create.

---

### `.stow-ignore` (config, stow exclusion list)

**Pattern source:** `01-CONTEXT.md` — "Implementation Decisions → D-03"

**Purpose:** Prevents GNU Stow from treating non-stow content as stow packages when run from the repo root. Only `.openclaw/` should be deployed.

**Complete file content** (all entries from D-03, one per line — GNU Stow ignores lines starting with `#` and blank lines):
```
# .stow-ignore — prevents stow from stowing non-.openclaw/ content
# Source: CONTEXT.md D-03
.planning
.git
docs
scripts
CLAUDE.md
README.md
cc-openclaw
secrets.sh
```

**Key constraint:** `cc-openclaw` must be in this list (D-03) because skills are stowed into the project directory from the submodule, not into `~/`. If cc-openclaw were stowed by the root package, it would create `~/.openclaw/cc-openclaw/` symlinks, which is wrong.

---

### `cc-openclaw/` (git submodule)

**Pattern source:** `01-CONTEXT.md` — "Decisions → D-05, D-06, D-07, D-08" and `01-RESEARCH.md` — "Architecture Patterns → Pattern 2: cc-openclaw Submodule Stow"

**This is not a created file** — it is a git submodule setup operation.

**Submodule initialization command:**
```bash
# Run from repo root
git submodule add https://github.com/rahulsub-be/cc-openclaw cc-openclaw
git submodule update --init --recursive
```

**Skills stow command** (D-06 — stow INTO project, not into `~/`):
```bash
# Run from the submodule directory
cd /Users/trilogy/Documents/agentic-setup/cc-openclaw
stow --no-folding -t /Users/trilogy/Documents/agentic-setup .
# Creates: ~/Documents/agentic-setup/.claude/skills/openclaw-*/  (symlinks)
```

**Why `--no-folding` is mandatory** (RESEARCH.md Pitfall 3): Without it, stow creates `~/Documents/agentic-setup/.claude` as a directory-level symlink. Claude Code cannot traverse directory symlinks to discover individual skills. `--no-folding` forces actual directories and individual skill-level symlinks.

**Post-stow verification** (D-07 — inspect structure before assuming layout):
```bash
ls /Users/trilogy/Documents/agentic-setup/.claude/skills/
# Expected: openclaw-add-channel/  openclaw-add-cron/  openclaw-add-script/
#           openclaw-add-secret/   openclaw-dream-setup/ openclaw-new-agent/
#           openclaw-restart/      openclaw-stow/        openclaw-status/
# (9 directories, each a symlink into cc-openclaw/.claude/skills/<name>/)
```

**Skills update path** (D-08 — skills update independently of config deploy):
```bash
cd /Users/trilogy/Documents/agentic-setup/cc-openclaw
git pull
# No re-stow needed for content updates; re-stow only needed if new skills are added
```

---

## Shared Patterns

### Shebang + Strict Mode
**Source:** CLAUDE.md "Shell Scripting Conventions"
**Apply to:** ALL shell scripts (`scripts/install-prereqs.sh`, `scripts/stow-deploy.sh`, `scripts/lib/json-response.sh`, `scripts/infra-verify.sh`, `.openclaw/scripts/openclaw-secrets.sh`, `.openclaw/scripts/openclaw-env.sh`, `secrets.sh`)
```zsh
#!/usr/bin/env zsh
set -euo pipefail
```
Never use `#!/bin/bash` — macOS ships bash 3.2 (GPL2 locked, missing modern features).

### JSON Response Shape
**Source:** CLAUDE.md "Shell Scripting Conventions → JSON response shape"
**Apply to:** All scripts that produce output consumed by agents or other scripts
```zsh
# Success:
print '{"ok":true,"data":{...}}'

# Failure (before exit 1):
print '{"ok":false,"error":"error_code_snake_case"}'
```
stdout = JSON only. stderr = human-readable logs via `print "..." >&2`. This allows callers to use `jq '.ok'` without parsing prose.

### Secrets Naming Convention
**Source:** CLAUDE.md "Constraints → Secrets" and RESEARCH.md "Architecture Patterns → Pattern 3"
**Apply to:** All files that reference or store secrets (`openclaw-secrets.sh`, `openclaw-env.sh`, `secrets.sh`)
- Keychain service name: `openclaw.<name>` — lowercase, hyphens
- Environment variable name: `OPENCLAW_<NAME>` — uppercase, underscores
- Example: Telegram bot token → service `openclaw.telegram-bot-token` → env var `OPENCLAW_TELEGRAM_BOT_TOKEN`
- Values fetched at runtime: `"$(security find-generic-password -s 'openclaw.<name>' -w)"`
- NEVER hardcode a value anywhere (CLAUDE.md "Constraints → Secrets")

### Stow Invocation Pattern
**Source:** CONTEXT.md D-01 and RESEARCH.md Pattern 1
**Apply to:** `scripts/stow-deploy.sh` and any manual stow invocation documented in plans
```zsh
# Always explicit --dir and --target. Never rely on stow's default parent-directory targeting.
stow --dir="$HOME/Documents/agentic-setup" --target="$HOME" --no-folding .openclaw
```

### jobs.json Pre-Stow Cleanup
**Source:** CONTEXT.md D-09 and RESEARCH.md Pitfall 1
**Apply to:** `scripts/stow-deploy.sh` (already baked in); any plan step that runs stow must include this cleanup first
```zsh
rm -f "$HOME/.openclaw/cron/jobs.json"
```
Without this, stow will fail with `ERROR: stow: existing target is not owned by stow: cron/jobs.json` after any gateway startup.

---

## No Analog Found

All files in this phase have no codebase analog — this is Phase 1 of a greenfield project. The table below records each file and the reason.

| File | Role | Data Flow | Pattern Source to Use |
|------|------|-----------|----------------------|
| `scripts/install-prereqs.sh` | shell-script | batch | `01-RESEARCH.md` "Code Examples → install-prereqs.sh" (complete template) |
| `scripts/stow-deploy.sh` | shell-script | batch | `01-RESEARCH.md` "Code Examples → stow-deploy.sh" (complete template) |
| `scripts/lib/json-response.sh` | shell-script | transform | CLAUDE.md "Shell Scripting Conventions" (invent minimal helpers matching the convention) |
| `scripts/infra-verify.sh` | shell-script | batch | `01-RESEARCH.md` "Validation Architecture → Phase Requirements → Test Map" (assemble from individual smoke commands) |
| `.openclaw/openclaw.json` | config | — | `01-RESEARCH.md` "Architecture Patterns → Pattern 5" (complete template) |
| `.openclaw/scripts/openclaw-secrets.sh` | shell-script | event-driven | `01-RESEARCH.md` "Architecture Patterns → Pattern 3" (initial stub; populated by /openclaw-add-secret) |
| `.openclaw/scripts/openclaw-env.sh` | shell-script | event-driven | `01-RESEARCH.md` "Architecture Patterns → Pattern 3" (same structure as openclaw-secrets.sh) |
| `secrets.sh` | shell-script | batch | `01-RESEARCH.md` "Architecture Patterns → Pattern 3" (fourth file in pipeline; loop over SECRETS array) |
| `.stow-ignore` | config | — | `01-CONTEXT.md` "Decisions → D-03" (verbatim entry list) |
| `cc-openclaw/` | git-submodule | — | `01-CONTEXT.md` D-05/D-06/D-07/D-08 + `01-RESEARCH.md` "Pattern 2" (setup commands) |

---

## Metadata

**Analog search scope:** Entire repository (`/Users/trilogy/Documents/agentic-setup/`)
**Files scanned:** 1 implementation file found (`CLAUDE.md`) — all others are planning artifacts
**Pattern extraction date:** 2026-05-20
**Greenfield note:** Phase 1 establishes all foundational patterns. Phase 2+ will have real codebase analogs derived from files created in this phase.

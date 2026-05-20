# Phase 1: Infrastructure - Context

**Gathered:** 2026-05-20
**Status:** Ready for planning

<domain>
## Phase Boundary

Get the OpenClaw runtime, cc-openclaw skills, secrets pipeline, and git+stow deployment fully operational. Every subsequent phase uses this as its sole configuration path — no manual file edits ever. This phase delivers the governance layer, not any agents or channels.

**In scope:** OpenClaw installation, cc-openclaw skills deployment, three-file secrets pipeline, stow deployment automation, health check verification
**Out of scope:** Channels (Phase 2), agents (Phase 3+), Beads/task graphs (Phase 4)

</domain>

<decisions>
## Implementation Decisions

### Repo Layout for Stow
- **D-01:** Stow is always invoked with explicit `--dir=$HOME/Documents/agentic-setup --target=$HOME`. Never rely on stow's default parent-directory targeting.
- **D-02:** `.openclaw/` is the single stow package for OpenClaw config. Only files under `.openclaw/` are deployed to `~/.openclaw/`. All other repo content (`.planning/`, `docs/`, `scripts/`, `CLAUDE.md`) is not stowed.
- **D-03:** A `.stow-ignore` file at the repo root explicitly excludes non-stow content: `.planning`, `.git`, `docs`, `scripts`, `CLAUDE.md`, `README.md`, `cc-openclaw`.
- **D-04:** `scripts/stow-deploy.sh` is the canonical deploy entry point — both humans and agents run this script. It handles `jobs.json` cleanup before stowing.

### Claude's Discretion — Repo Directory Structure
The following layout is locked for the repository. Planner and executor must create it exactly:

```
~/Documents/agentic-setup/
├── .openclaw/              ← stow package → ~/.openclaw/
│   ├── openclaw.json       ← gateway config (added by /openclaw-new-agent)
│   ├── agents/             ← agent directories (added by /openclaw-new-agent)
│   ├── cron/               ← cron definitions (added by /openclaw-add-cron)
│   └── scripts/            ← shared deterministic scripts
├── cc-openclaw/            ← git submodule of github.com/rahulsub-be/cc-openclaw
├── scripts/                ← repo-management scripts (NOT stowed to ~/)
│   ├── install-prereqs.sh  ← prerequisite installer (Node 24, Stow, jq)
│   ├── stow-deploy.sh      ← deploy wrapper with jobs.json cleanup
│   └── lib/
│       └── json-response.sh
├── .stow-ignore            ← prevents stow from touching non-.openclaw/ content
├── .planning/              ← GSD artifacts (not stowed)
├── docs/                   ← reference documentation (not stowed)
└── CLAUDE.md
```

### cc-openclaw Skills Placement
- **D-05:** cc-openclaw is added as a git submodule at `agentic-setup/cc-openclaw/` (pointing to `github.com/rahulsub-be/cc-openclaw`).
- **D-06:** Skills are stowed FROM the submodule INTO the project using `stow --no-folding -t ~/Documents/agentic-setup .` run from `agentic-setup/cc-openclaw/`. This creates `.claude/skills/openclaw-*/` symlinks inside the project for Claude Code to discover.
- **D-07:** Plan 01-02 must inspect the cc-openclaw repo structure after cloning to determine whether skills are at the root or under `.claude/skills/`, and adapt the stow invocation accordingly. Both structures are handled.
- **D-08:** Skills update independently via `git pull` inside the submodule — no need to touch the parent repo. stow-deploy.sh does NOT re-stow the skills on every config deploy; that is a separate step.

### jobs.json Conflict Automation
- **D-09:** `scripts/stow-deploy.sh` cleans `jobs.json` only: `rm -f ~/.openclaw/cron/jobs.json` before every stow. This is the only documented stow conflict per the cc-openclaw reference.
- **D-10:** stow-deploy.sh deploys files only — it does NOT restart the gateway. Restart is always a separate explicit step via `/openclaw-restart`. This allows agents to batch multiple config changes before a single restart.
- **D-11:** The script includes a comment marking where additional conflict cleanups should be added if new conflicts are discovered during Phase 1 execution.

### Prerequisites Install Approach
- **D-12:** `scripts/install-prereqs.sh` auto-installs all missing prerequisites: Node 24 (`brew install node@24`), GNU Stow (`brew install stow`), jq (`brew install jq`). No manual steps required on a fresh Mac.
- **D-13:** If Node 18 or 20 is detected (fatal OpenClaw version), the script installs Node 24 via brew and pins `node@24` to PATH in `openclaw-env.sh` and the launchd environment — does NOT remove existing Node installs.
- **D-14:** If Homebrew is not installed, the script fails immediately with a clear error message and the Homebrew install URL. Homebrew is an assumed prerequisite.
- **D-15:** `install-prereqs.sh` handles prereqs only — it does not run the OpenClaw curl installer. OpenClaw installation is a separate step in Plan 01-01. This allows partial re-runs if OpenClaw installation fails.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Requirements
- `.planning/REQUIREMENTS.md` §Infrastructure — INFRA-01, INFRA-02, INFRA-03, INFRA-04, INFRA-06 define the acceptance criteria for each plan. Read before writing any plan.

### Primary Reference — cc-openclaw Design Rationale
- `docs/human/Trilogy AI Center of Excellence - Managing OpenClaw with Claude Code.md` — Explains WHY cc-openclaw skills exist, exactly what each of the 9 skills does, the three-file secrets pipeline, the jobs.json stow gotcha, and the stow setup command. The canonical source for any implementation question about this phase.

### Secrets Pipeline Convention (from reference doc)
- Keychain service naming: `openclaw.<name>` (lowercase, hyphens)
- Environment variable naming: `OPENCLAW_<NAME>` (uppercase, underscores)
- Three files that MUST be updated on every secret: `openclaw-secrets.sh` (launchd), `openclaw-env.sh` (shell sessions), `secrets.sh` (disaster recovery provisioning)

### OPENCLAW_REPO Detection Pattern (from reference doc)
- Skills detect the repo location via: `OPENCLAW_REPO=$(readlink ~/.openclaw/openclaw.json 2>/dev/null | sed 's|/.openclaw/openclaw.json||')`
- This only works correctly if `~/.openclaw/openclaw.json` is a stow symlink pointing into the repo's `.openclaw/` directory. The stow deployment in D-01 enables this.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- None yet — this is the first phase on a greenfield repo.

### Established Patterns
- Shell scripts: `#!/usr/bin/env zsh` + `set -euo pipefail` + stdout=JSON only + stderr=human logs. All scripts in `scripts/` and `.openclaw/scripts/` follow this pattern (cc-openclaw reference, CLAUDE.md stack conventions).
- JSON response shape: `{ "ok": true, "data": {...} }` or `{ "ok": false, "error": "..." }` — used by all deterministic scripts so callers can use `jq '.ok'`.

### Integration Points
- `~/.openclaw/` — all OpenClaw runtime config lives here after stow. Gateway reads this directory on startup.
- `~/.claude/skills/` — all Claude Code slash commands are discovered here. cc-openclaw symlinks land here after submodule stow.

</code_context>

<specifics>
## Specific Ideas

- The `scripts/stow-deploy.sh` design decision came from the user — they explicitly said to use this script rather than relying on the cc-openclaw `/openclaw-stow` skill alone for the deploy path.
- The cc-openclaw "Getting Started" section in the reference doc shows the exact stow command: `stow --no-folding -t ~/your-openclaw-home-repo .` run from the cc-openclaw directory. Adapt `~/your-openclaw-home-repo` to `~/Documents/agentic-setup`.
- Node 24 PATH pinning: when installing node@24 via brew on Apple Silicon, the binary is at `/opt/homebrew/opt/node@24/bin`. On Intel Macs it's `/usr/local/opt/node@24/bin`. The prereq script should detect architecture.

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope.

</deferred>

---

*Phase: 1-Infrastructure*
*Context gathered: 2026-05-20*

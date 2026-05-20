#!/usr/bin/env zsh
# stow-deploy.sh — canonical stow deploy entry point for .openclaw/ package
# Source: CONTEXT.md D-01, D-04, D-09, D-10, D-11 + PATTERNS.md §stow-deploy.sh
# Usage: zsh scripts/stow-deploy.sh
# D-04: This is THE canonical entry point — humans and agents run this, never invoke stow directly.
# D-10: This script deploys only — it does NOT restart the gateway.
#        Run /openclaw-restart separately after deploying.
set -euo pipefail

REPO_DIR="${REPO_DIR:-$HOME/Documents/agentic-setup}"

print "Deploying .openclaw/ via stow..." >&2

# WR-03: Ensure target directory exists before stow
if [[ ! -d "$HOME/.openclaw" ]]; then
  print "ERROR: ~/.openclaw/ does not exist — install OpenClaw first (openclaw daemon install)" >&2
  print '{"ok":false,"error":"openclaw_not_installed"}'
  exit 1
fi

# D-09: Resolve known stow conflict — gateway recreates jobs.json on every startup,
# converting the stow symlink into a plain file. Remove before every stow invocation.
rm -f "$HOME/.openclaw/cron/jobs.json"
# ADD ADDITIONAL CONFLICT CLEANUPS HERE if discovered during Phase 1 execution

# D-01 (corrected): --target must be $HOME/.openclaw, not $HOME.
# With --target=$HOME and package .openclaw, stow deploys CONTENTS of .openclaw/ to $HOME/
# (creating ~/openclaw.json, ~/scripts/...) instead of ~/.openclaw/openclaw.json.
# The correct target is $HOME/.openclaw so package contents land at ~/.openclaw/*.
stow --dir="$REPO_DIR" --target="$HOME/.openclaw" --no-folding .openclaw

# D-10: Deploy is complete. Do NOT auto-restart the gateway.
print "Stow deploy complete. Run /openclaw-restart to apply changes." >&2

print '{"ok":true,"data":{"deployed":".openclaw"}}'

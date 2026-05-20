---
phase: 01-infrastructure
reviewed: 2026-05-21T00:00:00Z
depth: standard
files_reviewed: 9
files_reviewed_list:
  - scripts/lib/json-response.sh
  - scripts/install-prereqs.sh
  - scripts/stow-deploy.sh
  - scripts/infra-verify.sh
  - .openclaw/openclaw.json
  - .openclaw/scripts/openclaw-secrets.sh
  - .openclaw/scripts/openclaw-env.sh
  - secrets.sh
  - .stow-ignore
findings:
  critical: 2
  warning: 4
  info: 2
  total: 8
status: issues_found
---

# Phase 01: Infrastructure — Code Review Report

**Reviewed:** 2026-05-21
**Depth:** standard
**Files Reviewed:** 9
**Status:** issues_found

## Summary

Nine Phase 1 infrastructure files were reviewed: four shell scripts, two sourced env/secrets
files, the OpenClaw JSON5 config, the Keychain provisioning script, and the stow ignore list.
The code is largely well-structured and follows the project's zsh/JSON-output conventions.
Two blockers were identified that will cause silent failure in production: the node@24 PATH
pin is never actually written because the idempotency guard matches commented-out template
lines, and the Keychain lookup in sourced env files will abort any parent shell that has
`set -e` active when the secret does not exist in the Keychain. Four warnings round out
issues that degrade reliability or correctness at the edges.

---

## Critical Issues

### CR-01: node@24 PATH pin never written — launchd and shell sessions start with wrong Node

**File:** `scripts/install-prereqs.sh:47,61`

**Issue:** `install-prereqs.sh` guards the PATH pin append with:
```zsh
if ! grep -q "node@24" "$SECRETS_SH"; then
```
Both `openclaw-secrets.sh` and `openclaw-env.sh` ship with *commented-out* template lines that
already contain the string `node@24`:
```zsh
# export PATH="/opt/homebrew/opt/node@24/bin:$PATH"   # Apple Silicon — appended by install-prereqs.sh
```
`grep -q "node@24"` matches the comment, so the condition is never true and the active
`export PATH=...` line is **never appended**. Both files remain with only the commented-out
placeholder. Consequence: launchd starts OpenClaw with the system Node (≤22) and the gateway
fails with "Node version unsupported" on every boot. Interactive shells also never get Node 24
on PATH.

**Fix:** Change the grep pattern to match only an *active* export line, not a comment:
```zsh
if ! grep -q "^export PATH.*node@24" "$SECRETS_SH"; then
    print "export PATH=\"${NODE24_BIN}:\$PATH\"" >> "$SECRETS_SH"
fi
if ! grep -q "^export PATH.*node@24" "$ENV_SH"; then
    print "export PATH=\"${NODE24_BIN}:\$PATH\"" >> "$ENV_SH"
fi
```
The `^export` anchor excludes comment lines (which start with `#`).

---

### CR-02: Keychain lookup in sourced files aborts parent shell when secret is absent

**File:** `.openclaw/scripts/openclaw-secrets.sh:13`, `.openclaw/scripts/openclaw-env.sh:13`

**Issue:** Both files contain:
```zsh
export OPENCLAW_TEST_SECRET="$(security find-generic-password -s 'openclaw.test-secret' -w)"
```
`security find-generic-password` exits with code 44 (`errSecItemNotFound`) when the Keychain
entry does not exist. Because the assignment is inside a `$(...)` subshell, the non-zero exit
propagates to the `export` statement. Any calling script or shell profile that has `set -e`
active (including launchd startup environments and user `.zshrc` sourcing this file) will
**immediately abort** on sourcing. On a fresh machine (before `secrets.sh` has provisioned
keys) or after a Keychain item is deleted, the OpenClaw gateway LaunchAgent will fail silently
at source time and never start.

**Fix:** Guard each lookup with a fallback so the export always succeeds:
```zsh
export OPENCLAW_TEST_SECRET="$(security find-generic-password -s 'openclaw.test-secret' -w 2>/dev/null || true)"
```
The `|| true` ensures the subshell exits 0 even when the item is missing. The env var is set
to an empty string in that case, which is the correct "not yet provisioned" sentinel. Callers
that need the secret should validate it is non-empty before use.

---

## Warnings

### WR-01: secrets.sh is not idempotent — duplicate Keychain entries abort mid-loop

**File:** `secrets.sh:23`

**Issue:** `security add-generic-password` without the `-U` flag exits 45
(`errSecDuplicateItem`) if the entry already exists. With `set -euo pipefail` active in
`secrets.sh`, the first duplicate entry terminates the script immediately, leaving any
subsequent secrets unprovisioned. A developer running this script a second time (e.g., after
a machine migration or to add a newly listed secret) will silently miss later entries.

**Fix:** Add `-U` to make each add idempotent:
```zsh
security add-generic-password \
  -U \
  -s "${service}" \
  -a "$USER" \
  -w
```
`-U` updates the existing item if found, so re-runs are safe and the loop always completes.

---

### WR-02: infra-verify.sh skill count check uses substring grep — matches 19, 29, etc.

**File:** `scripts/infra-verify.sh:50`

**Issue:**
```zsh
bash -c 'ls "$HOME/Documents/agentic-setup/.claude/skills/" | wc -l | grep -q "9"'
```
`grep -q "9"` is a substring match. `wc -l` output on macOS is right-padded with spaces
(e.g., `"      19"`). This means 19, 29, or 90 skills would all satisfy the check and
produce a false PASS. The test certifies "contains the digit 9" rather than "exactly 9
entries."

**Fix:** Use an exact match with word boundaries or arithmetic comparison:
```zsh
bash -c 'count=$(ls "$HOME/Documents/agentic-setup/.claude/skills/" | wc -l | tr -d " "); [[ "$count" -eq 9 ]]'
```

---

### WR-03: stow-deploy.sh does not guard against missing target directory

**File:** `scripts/stow-deploy.sh:23`

**Issue:**
```zsh
stow --dir="$REPO_DIR" --target="$HOME/.openclaw" --no-folding .openclaw
```
`stow` does not create the target directory if it is absent — it fails with a hard error. In
normal operation `~/.openclaw` is created by OpenClaw's own installer before this script runs.
However, the ordering is not enforced: if `stow-deploy.sh` is invoked before OpenClaw is
installed (e.g., during a fresh machine bootstrap where tasks are run out of order), the
script exits with a cryptic stow error rather than an actionable message.

**Fix:** Add a guard before the stow call:
```zsh
if [[ ! -d "$HOME/.openclaw" ]]; then
  print "ERROR: ~/.openclaw does not exist. Install OpenClaw first (Task 4)." >&2
  print '{"ok":false,"error":"openclaw_not_installed"}'
  exit 1
fi
```

---

### WR-04: json-response.sh library is defined but never sourced by any script

**File:** `scripts/lib/json-response.sh` (cross-referenced: all four scripts)

**Issue:** `json-response.sh` defines `json_ok` and `json_fail` helpers per the cc-openclaw
pattern, but none of the four scripts that emit JSON (`install-prereqs.sh`, `stow-deploy.sh`,
`infra-verify.sh`, `secrets.sh`) source it. Each script hand-rolls its own `print '{"ok":...}'`
inline. The library exists with no callers. Any future change to the JSON envelope shape (e.g.,
adding a `ts` field) must be applied to every script individually rather than once in the
library.

**Fix:** Add a source line near the top of each consuming script. Use a path relative to the
script's own location so it works regardless of `$CWD`:
```zsh
SCRIPT_DIR="${0:A:h}"
source "${SCRIPT_DIR}/lib/json-response.sh"
```
Then replace inline `print '{"ok":true,...}'` calls with `json_ok '{...}'` and
`json_fail "code" "message"`.

---

## Info

### IN-01: install-prereqs.sh uses hardcoded repo path instead of $REPO_DIR

**File:** `scripts/install-prereqs.sh:45,59`

**Issue:**
```zsh
SECRETS_SH="$HOME/Documents/agentic-setup/.openclaw/scripts/openclaw-secrets.sh"
ENV_SH="$HOME/Documents/agentic-setup/.openclaw/scripts/openclaw-env.sh"
```
`stow-deploy.sh` correctly uses `REPO_DIR="${REPO_DIR:-$HOME/Documents/agentic-setup}"` for
the same repo path. `install-prereqs.sh` hardcodes it. If the repo is cloned elsewhere (or on
a machine where `$HOME/Documents/` is not the convention), the PATH-pin logic silently skips
(the `[[ -f "$SECRETS_SH" ]]` guard falls through with a "not found" message). Consistent use
of the env var fallback would make both scripts portable to the same degree.

**Fix:** Adopt the same pattern at the top of `install-prereqs.sh`:
```zsh
REPO_DIR="${REPO_DIR:-$HOME/Documents/agentic-setup}"
SECRETS_SH="$REPO_DIR/.openclaw/scripts/openclaw-secrets.sh"
ENV_SH="$REPO_DIR/.openclaw/scripts/openclaw-env.sh"
```

---

### IN-02: infra-verify.sh skill path hardcoded; inconsistent with REPO_DIR pattern

**File:** `scripts/infra-verify.sh:50,58`

**Issue:** Similar to IN-01 — the cc-openclaw skills path is hardcoded:
```zsh
ls "$HOME/Documents/agentic-setup/.claude/skills/" | wc -l | grep -q "9"
test -L "$HOME/Documents/agentic-setup/.claude/skills/openclaw-status/SKILL.md"
```
`stow-deploy.sh` and the broader project pattern use `REPO_DIR` for the repo root. These two
lines should follow the same convention for consistency and portability.

**Fix:**
```zsh
REPO_DIR="${REPO_DIR:-$HOME/Documents/agentic-setup}"
# then in the check calls:
bash -c "count=\$(ls \"${REPO_DIR}/.claude/skills/\" | wc -l | tr -d ' '); [[ \"\$count\" -eq 9 ]]"
test -L "${REPO_DIR}/.claude/skills/openclaw-status/SKILL.md"
```

---

_Reviewed: 2026-05-21_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_

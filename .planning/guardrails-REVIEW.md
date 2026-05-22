---
phase: guardrails
reviewed: 2026-05-22T00:00:00Z
depth: standard
files_reviewed: 5
files_reviewed_list:
  - scripts/git-hooks/pre-push
  - scripts/install-git-hooks.sh
  - .claude/settings.json
  - .planning/config.json
  - CLAUDE.md
findings:
  critical: 0
  warning: 2
  info: 2
  total: 4
status: issues_found
---

# Guardrails: Code Review Report (Re-review after fixes)

**Reviewed:** 2026-05-22
**Depth:** standard
**Files Reviewed:** 5
**Status:** issues_found

## Summary

Re-review following the five previously reported fixes. All five prior findings (CR-01 through CR-02, CR-03, WR-01, WR-02) are confirmed resolved — the pre-push hook now correctly extracts the remote ref, iterates a proper zsh array, and both scripts have strict mode and safe directory handling. No new critical issues were found. Two new warnings and two info items were identified: one warning is a portability/reliability gap in the SessionStart hook deployment path; the other is a misleading comment that could cause a future maintainer to introduce a regression in the NULL_GLOB defense.

---

## Previous Findings — Confirmed Resolved

| ID | Description | Status |
|----|-------------|--------|
| CR-01 | `awk '{print $3}'` correctly extracts the remote ref (field 3 in the git pre-push line format) | RESOLVED |
| CR-02 | `PROTECTED_BRANCHES=(main master)` declared as a zsh array; iterated with `"${PROTECTED_BRANCHES[@]}"` — no word-split issue | RESOLVED |
| CR-03 | `setopt NULL_GLOB 2>/dev/null \|\| true` present at line 7; `[[ -f "$hook" ]] \|\| continue` guard present at line 21 | RESOLVED |
| WR-01 | `set -euo pipefail` present at line 5 of `pre-push` | RESOLVED |
| WR-02 | `if [[ ! -d "$HOOKS_DST" ]]; then mkdir -p "$HOOKS_DST"` guard present at lines 14-16 of `install-git-hooks.sh` | RESOLVED |

---

## Warnings

### WR-01: Misleading NULL_GLOB Comment Creates Regression Risk

**File:** `scripts/install-git-hooks.sh:20`

**Issue:** The comment on line 20 reads:
```
# NULL_GLOB: if no files match, $hook equals the literal glob string — skip it
```
This describes **bash behavior without `nullglob`** (where an unmatched glob passes through as the literal pattern string). It does **not** describe zsh behavior with `setopt NULL_GLOB`. In zsh with `NULL_GLOB` active, an unmatched glob expands to zero words and the `for` loop body is never entered at all — the `[[ -f "$hook" ]] || continue` guard at line 21 is never reached in the empty-directory case.

The comment inverts the true relationship: `NULL_GLOB` handles the empty-directory crash; the `-f` guard handles subdirectories or non-regular files that matched the glob. A future maintainer reading the comment as written may conclude that `setopt NULL_GLOB` is redundant ("there's already a guard") and remove it, silently reintroducing the CR-03 crash on empty directories.

**Fix:** Correct the comment to describe what each defense actually does:
```zsh
# setopt NULL_GLOB (line 7) prevents a fatal "no matches found" error when
# the hooks directory is empty — the loop body is simply not entered.
# The -f guard below skips subdirectories or symlinks that passed the glob.
[[ -f "$hook" ]] || continue
```

---

### WR-02: Hardcoded Absolute Path in SessionStart Hook Fails Silently on Non-Default Clone Paths

**File:** `.claude/settings.json:23`

**Issue:** The SessionStart hook invokes the installer via:
```
zsh /Users/trilogy/Documents/agentic-setup/scripts/install-git-hooks.sh 2>/dev/null || true
```
The path `/Users/trilogy/Documents/agentic-setup/` is hardcoded. If the repo is cloned to any other location (different user, different directory), the command silently fails — stderr is suppressed (`2>/dev/null`) and the exit code is swallowed (`|| true`). The developer gets no indication that git hooks were not installed, and the main-branch protection is absent without any warning.

This is the same root problem as the previous WR-03 finding (suppressed failures), but it now has a distinct vector: while the install script itself is fixed, the invocation path is still machine-specific.

**Fix (preferred):** Derive the path dynamically using the git root. Since `settings.json` commands are invoked from the project root by Claude Code:
```json
{
  "command": "zsh \"$PWD/scripts/install-git-hooks.sh\" || echo 'WARNING: git hook install failed — branch protection absent' >&2",
  "type": "command"
}
```
`$PWD` in a Claude Code hook is the project root, making this portable across clone paths. If `$PWD` expansion is not available in this settings format, document clearly that this path must be updated after a fresh clone.

---

## Info

### IN-01: Subprocess Fork Per Input Line in pre-push

**File:** `scripts/git-hooks/pre-push:12`

**Issue:** `remote_ref=$(echo "$line" | awk '{print $3}')` forks a subshell and an awk process for every line of git hook input. For a typical push of 1-3 refs this is negligible, but it is inconsistent with the project's zsh-native coding style. Zsh provides native array-splitting via `read -rA` that avoids the fork entirely.

**Fix:**
```zsh
# Replace the awk subprocess with native zsh array splitting
read -rA fields <<< "$line"
remote_ref="${fields[3]}"   # zsh arrays are 1-indexed: $1=local-ref, $2=local-sha, $3=remote-ref
```

---

### IN-02: `"mode": "yolo"` in config.json Disables Safety Gates Without Documentation

**File:** `.planning/config.json:68`

**Issue:** `"mode": "yolo"` disables GSD workflow safety gates globally. The intent (autonomous personal hub, sole operator) is sound, but the config carries no explanation. A future maintainer or collaborator inheriting this config would not know whether this was intentional or accidental.

**Fix:** No functional change needed. Add a companion documentation key:
```json
"mode": "yolo",
"_mode_reason": "Autonomous personal hub — sole operator, owner reviews via Notion log"
```

---

_Reviewed: 2026-05-22_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_

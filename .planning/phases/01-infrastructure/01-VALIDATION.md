---
phase: 1
slug: infrastructure
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-05-20
---

# Phase 1 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Shell script assertions (no external test framework — Phase 1 is infrastructure setup, not application code) |
| **Config file** | none — Wave 0 installs `scripts/infra-verify.sh` |
| **Quick run command** | `openclaw --version | grep -q 2026.5.18 && node --version | grep -q "^v24" && test -L ~/.openclaw/openclaw.json && echo PASS` |
| **Full suite command** | `bash scripts/infra-verify.sh` |
| **Estimated runtime** | ~15 seconds |

---

## Sampling Rate

- **After every task commit:** Run `openclaw --version | grep -q 2026.5.18 && node --version | grep -q "^v24" && test -L ~/.openclaw/openclaw.json && echo infra-ok`
- **After every plan wave:** Run `bash scripts/infra-verify.sh`
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** 15 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 1-01-01 | 01-01 | 1 | INFRA-01 | — | Node 24 active for launchd (not nvm) | smoke | `openclaw --version \| grep -q 2026.5.18 && node --version \| grep -q "^v24"` | ❌ W0 | ⬜ pending |
| 1-01-02 | 01-01 | 1 | INFRA-01 | — | LaunchAgent plist installed | smoke | `ls ~/Library/LaunchAgents/ \| grep -q ai.openclaw.gateway` | ❌ W0 | ⬜ pending |
| 1-01-03 | 01-02 | 1 | INFRA-02 | — | All 9 skills present as symlinks | smoke | `ls ~/Documents/agentic-setup/.claude/skills/ \| wc -l \| awk '{exit ($1==9)?0:1}'` | ❌ W0 | ⬜ pending |
| 1-01-04 | 01-02 | 1 | INFRA-02 | — | Skills are symlinks not plain files | smoke | `test -L ~/Documents/agentic-setup/.claude/skills/openclaw-status` | ❌ W0 | ⬜ pending |
| 1-01-05 | 01-03 | 2 | INFRA-03 | — | Secret in Keychain and all 3 files updated | integration | `security find-generic-password -s "openclaw.test-secret" -w >/dev/null && grep -q OPENCLAW_TEST_SECRET ~/.openclaw/scripts/openclaw-secrets.sh && grep -q OPENCLAW_TEST_SECRET ~/.openclaw/scripts/openclaw-env.sh && grep -q "openclaw.test-secret" ~/Documents/agentic-setup/secrets.sh` | ❌ W0 | ⬜ pending |
| 1-01-06 | 01-04 | 2 | INFRA-04 | — | openclaw.json is stow symlink | smoke | `test -L ~/.openclaw/openclaw.json` | ❌ W0 | ⬜ pending |
| 1-01-07 | 01-04 | 2 | INFRA-04 | — | Stow deploy succeeds idempotently | smoke | `rm -f ~/.openclaw/cron/jobs.json && stow --dir=$HOME/Documents/agentic-setup --target=$HOME --no-folding .openclaw && echo PASS` | ❌ W0 | ⬜ pending |
| 1-01-08 | 01-05 | 3 | INFRA-06 | — | Gateway running (health endpoint reachable) | smoke | `openclaw gateway status --json \| python3 -c "import json,sys; d=json.load(sys.stdin); assert d['service']['runtime']['status'] != 'unknown'"` | ❌ W0 | ⬜ pending |
| 1-01-09 | 01-05 | 3 | INFRA-06 | — | Test cron job timezone field is not UTC | manual | Check `/openclaw-status` output for cron job `tz` field value | N/A | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `scripts/infra-verify.sh` — runs all smoke tests above in sequence, outputs structured JSON result `{"ok":true/false,"results":[...]}`
- [ ] `scripts/install-prereqs.sh` — prerequisite installer (D-12 through D-15)
- [ ] `scripts/stow-deploy.sh` — canonical deploy entry point (D-04)
- [ ] `scripts/lib/json-response.sh` — shared JSON response library
- [ ] `.openclaw/scripts/openclaw-secrets.sh` — launchd env injection file (minimal stub; populated by `/openclaw-add-secret`)
- [ ] `.openclaw/scripts/openclaw-env.sh` — shell session env file (minimal stub)
- [ ] `secrets.sh` — disaster recovery provisioning script (repo root, NOT stowed)
- [ ] `.openclaw/openclaw.json` — minimal gateway config
- [ ] `.stow-ignore` — prevents stow from touching non-.openclaw/ content

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Test cron job timezone field is local (not UTC) | INFRA-06 | `/openclaw-status` output is human-readable; timezone field requires human inspection to confirm correct local timezone was set | Run `/openclaw-add-cron` to create a test job; then run `/openclaw-status`; inspect cron entry for `tz` field showing local timezone (e.g., `America/New_York`), NOT `UTC` |
| `openclaw onboard --install-daemon` interactive wizard completes | INFRA-01 | Command is interactive and requires TTY — cannot be automated | User must run `openclaw onboard --install-daemon` in their terminal after prereqs are installed; confirm LaunchAgent is installed with `ls ~/Library/LaunchAgents/ | grep ai.openclaw` |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 15s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending

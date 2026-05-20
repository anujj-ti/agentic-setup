# Personal AI Operations Hub

## What This Is

A self-evolving AI agent fleet built on OpenClaw, managed and configured via Claude Code skills, designed to handle the full lifecycle of a developer's day — email triage, GitHub project management, CI monitoring, autonomous development, and decision documentation — all without constant human babysitting. Uses a dual-orchestrator architecture: a thin user-facing orchestrator handles the conversation with you, while a separate task orchestrator runs autonomously in the background, delegating to specialized sub-agents and documenting every decision it makes in Notion for your review when you return.

## Core Value

An AI co-pilot that works autonomously while you're away, never forgets a task, documents every decision it made, and hands back clean control when you return.

## Requirements

### Validated

(None yet — ship to validate)

### Active

- [ ] Install and configure OpenClaw from scratch on macOS (fresh install)
- [ ] Dual orchestrator architecture: User Orchestrator (conversational, Claude Code facing) + Task Orchestrator (autonomous, background execution)
- [ ] Task Orchestrator delegates to specialized sub-agents; agents can question each other
- [ ] Telegram channel integration for user-facing interactions and notifications
- [ ] WhatsApp integration for notifications/alerts
- [ ] Gmail bot email integration (echo.sys.bot@gmail.com) for email triage and outbound
- [ ] GitHub board integration: create issues, track tasks, manage project board
- [ ] Autonomous development workflow: triage PRs, create/solve issues, merge PRs with user approval queue
- [ ] Beads (bd) task graph installed in Task Orchestrator workspace — dependency-aware task decomposition prevents agents from skipping steps (Phase 2+, after core fleet is running)
- [ ] Morning standup brief: overnight activity summary (PRs merged, CI failures, open reviews)
- [ ] CI/CD monitoring agent: watch runs, surface failures, page via Telegram
- [ ] Project context switching: load relevant context when switching between repos
- [ ] Decision documentation to Notion while user is absent (every autonomous decision logged)
- [ ] User review/approval workflow on return: surface queued decisions, get sign-off or revert
- [ ] Dream routines for all agents (nightly memory distillation via QMD)
- [ ] cc-openclaw skills (9 skills) installed and configured as Claude Code slash commands
- [ ] Self-evolution capability: framework can scaffold new agents and skills as needs emerge
- [ ] Experiment framework: run experiments, document results and learnings in Notion

### Out of Scope

- Slack integration — not in the user's channel stack for this setup
- Multi-user / team mode — single-user personal operations hub
- Windows or Linux — macOS-specific (Keychain, launchd, stow)
- Jira / Linear — GitHub board is the task system
- Google Docs — Notion is the documentation layer

## Context

- **Platform**: macOS (Darwin 25.3.0) — Keychain for secrets, launchd for cron, GNU Stow for deployment
- **OpenClaw**: Flat-file configuration runtime — JSON config, markdown directives, shell scripts, keychain entries. No UI, no database. Everything in a directory tree.
- **Deployment**: Git + GNU Stow pattern. Every config change is a git commit; stow symlinks into `~/.openclaw/`. Disaster recovery is `git clone` + `stow`.
- **cc-openclaw skills**: Open-source set of 9 Claude Code skills at github.com/rahulsub-be/cc-openclaw that standardize all OpenClaw operations: new agents, channels, cron jobs, dream setup, scripts, secrets, status checks, restart, stow.
- **Reference architecture**: "Managing OpenClaw with Claude Code" by Rahul Subramaniam (Trilogy AI CoE, March 2026) — the design doc this project implements.
- **Email bot**: echo.sys.bot@gmail.com is a dedicated Gmail account for agent use, not the user's personal email.
- **GitHub**: Primary task/project tracking. Agents will create issues, manage the board, and have autonomous merge capability (with user approval queue for review-on-return).
- **Notion**: All decision logs, experiment results, and autonomous action records go here for async user review.
- **Memory constraint**: Dual orchestrator pattern specifically chosen to prevent context bloat — User Orchestrator stays lean and conversational; Task Orchestrator handles the stateful, multi-agent work separately.
- **Self-evolution**: The framework itself should grow — new agents are scaffolded when a new domain of work is identified, new skills are added when a pattern repeats more than twice.
- **Dedicated reviewer agents**: The quality pipeline uses specialist agents per domain — Code Reviewer, Document Reviewer, Decision Reviewer, Skill Reviewer — each with focused responsibilities. No single generalist reviewer handles multiple domains.
- **Hermes (future milestone)**: Once the OpenClaw fleet is stable, integrate Hermes via OGP federation to drive OpenClaw agent evolution — Hermes's learning loop proposes improvements, OpenClaw's fleet executes them. Cross-framework federation; each runtime stays in its lane.
- **Beads (bd)**: Dependency-aware task graph CLI built on Dolt (versioned SQL). Task Orchestrator creates a Beads epic per GitHub issue, decomposes into atomic subtasks with dependencies before spawning subagents. Subagents claim/close via `bd ready → bd update --claim → bd close --reason`. Solves the "agents skip steps" failure pattern documented in the Trilogy AI CoE reference article. One Beads DB shared across all agents in the execution tier. Templates: feature (5 subtasks: design→implement→self-review→QA evidence→PR), bug fix (4 subtasks: reproduce→fix→verify→PR), setup (12 subtasks: recon→env→services→migrations→server→browser→login→nav→tests→runbook→manifest→report).
- **Reference article 2**: "Why Your AI Agents Skip Steps — and How Task Graphs Prevent It" by Rahul Subramaniam (Trilogy AI CoE, March 2026) — justifies Beads adoption and provides decomposition patterns.

## Constraints

- **Tech stack**: OpenClaw + Claude Code skills + Git/Stow — no custom server infrastructure, no dashboards
- **Platform**: macOS only — Keychain, launchd, and Stow are macOS/GNU tooling
- **Secrets**: macOS Keychain only — never written to files, never in git history (cc-openclaw convention: `openclaw.<name>` service naming, `OPENCLAW_<NAME>` env var naming)
- **Memory budget**: Dream routines must respect token budgets (2,500/daily, 7,500/rolling 3-day digest per cc-openclaw reference)
- **Agent autonomy**: Autonomous actions (PR merges, issue creation, config changes) must be logged to Notion before execution — user reviews on return, can revert

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Dual orchestrator (User-facing + Task execution) | Prevents context bloat; user conversations stay lean while background work accumulates state elsewhere | — Pending |
| cc-openclaw skills as configuration layer | Standardizes all OpenClaw operations — same result regardless of which agent or model invokes them | — Pending |
| Notion for documentation | Single async review surface for decisions made while user is absent | — Pending |
| GitHub board as task system | Already the user's workflow; agents create and manage issues directly in the existing system | — Pending |
| echo.sys.bot@gmail.com as email bot | Dedicated account keeps agent email traffic isolated from personal inbox | — Pending |
| Self-evolution via skill scaffolding | New capabilities are added as markdown skills (not hardcoded) — the framework teaches itself new operations | — Pending |
| Beads (bd) for task decomposition | Agents skip steps when given multi-step tasks in a single prompt (attention decay + satisficing). Beads enforces ordering structurally — a subagent literally cannot start step N+1 until step N is closed with proof | — Pending |

## Evolution

This document evolves at phase transitions and milestone boundaries.

**After each phase transition** (via `/gsd-transition`):
1. Requirements invalidated? → Move to Out of Scope with reason
2. Requirements validated? → Move to Validated with phase reference
3. New requirements emerged? → Add to Active
4. Decisions to log? → Add to Key Decisions
5. "What This Is" still accurate? → Update if drifted

**After each milestone** (via `/gsd:complete-milestone`):
1. Full review of all sections
2. Core Value check — still the right priority?
3. Audit Out of Scope — reasons still valid?
4. Update Context with current state

---
*Last updated: 2026-05-20 after initialization*

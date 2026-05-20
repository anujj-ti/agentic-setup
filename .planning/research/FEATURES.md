# Feature Research

**Domain:** Personal AI developer operations hub (OpenClaw + Claude Code fleet)
**Researched:** 2026-05-20
**Confidence:** HIGH — derived from authoritative source documents (PROJECT.md, cc-openclaw reference article, Beads task graph article), confirmed by ecosystem research

---

## Feature Landscape

### Table Stakes (Users Expect These)

Features the user assumes exist. Missing these = the system is broken, not just incomplete.

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| OpenClaw installation + base configuration | The runtime must exist before anything else can run | MEDIUM | macOS-specific: Keychain, launchd, Stow — cc-openclaw /openclaw-new-agent encodes the 7-file agent setup; skip one file and dream routines fail silently weeks later |
| cc-openclaw 9 skills installed as Claude Code slash commands | Standardized configuration operations are the checks-and-balances layer — without them, every agent reinvents conventions | LOW | Git+Stow symlink pattern from the reference article; model-independent, convention-enforcing |
| Dual orchestrator separation (User Orchestrator + Task Orchestrator) | Context bloat prevention is foundational — user conversations must stay lean or the whole system degrades | HIGH | Core architectural decision; User Orchestrator stays conversational, Task Orchestrator holds multi-agent state; the two must never share context |
| Secrets management via macOS Keychain | Three files every time (openclaw-secrets.sh, openclaw-env.sh, secrets.sh) — miss one and CLI fails while gateway works, or disaster recovery breaks | MEDIUM | /openclaw-add-secret skill enforces the pipeline; naming conventions: openclaw.<name> / OPENCLAW_<NAME> |
| Git+Stow deployment pipeline | Configuration as code — every change is a commit; disaster recovery is git clone + stow | LOW | Already established pattern; jobs.json gotcha requires rm -f before stow |
| Telegram notification channel | Primary user-facing communication channel for autonomous activity and approval requests | MEDIUM | /openclaw-add-channel handles full secrets pipeline; BotFather token → Keychain → three secrets files → config → binding → verify |
| Notion decision log (autonomous actions written before execution) | The core trust mechanism — user must be able to review every autonomous decision on return; without this the system is a black box | HIGH | Every autonomous action (PR merges, issue creation, config changes) must be logged BEFORE execution, not after |
| User review/approval workflow on return | Surfaces queued decisions, gets sign-off, supports revert — closing the autonomous loop | HIGH | Depends on Notion log being reliable; without this, autonomous actions are unaccountable |
| GitHub integration (issue creation, board management) | The existing task system — agents must read and write the user's actual workflow | MEDIUM | Agents create issues, manage project board; the GitHub board is the source of truth for work, Beads tracks agent work decomposition |
| /openclaw-status health check skill | When something breaks, the first 5 minutes are wasted figuring out what — this is the kubectl get pods equivalent | LOW | Checks gateway health, channel connectivity, cron job results, recent errors in one pass |

### Differentiators (Competitive Advantage)

Features that make this better than just using Claude Code manually. These are the system's reason for existing.

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| Beads (bd) task graph in Task Orchestrator | Structurally prevents agents from skipping steps — the single most documented failure mode of multi-agent systems. "Done after 3 of 12 steps" is eliminated not by better prompting but by making step N+1 unreachable until step N is closed with evidence | HIGH | Dependency-aware graph on Dolt; agents claim/close with reason strings (proof of work); replaces polling with graph queries; shared single DB across all agents in execution tier |
| Nightly dream routines (memory distillation via QMD) | Agents that remember across sessions are qualitatively different from agents that forget — accumulated operational knowledge compounds over time | MEDIUM | 2,500 token/daily distillation budget, 7,500 for rolling 3-day digest; requires DREAM_ROUTINE.md, MEMORY.md, archives directory, cron job, QMD index paths, AGENTS.md session startup; /openclaw-dream-setup skill handles the full setup |
| Self-evolution capability (new agents and skills scaffolded when patterns repeat) | The framework grows its own capabilities — new domains of work become new agents, patterns that repeat 3+ times become skills; avoids the manual configuration trap | HIGH | The OpenClaw article establishes the principle: skills encode institutional knowledge so the model fills in specifics, not procedures. Pattern: if an improvised workflow works twice, on the third occurrence the orchestrator proposes scaffolding it as a skill |
| Morning standup brief (overnight activity digest) | Replaces "what did my agents do last night" with a structured, actionable briefing: PRs merged, CI failures, open reviews, blocked tasks | LOW | Cron-triggered; uses Beads graph for task status, GitHub API for PR/issue state, CI logs for failures; delivered via Telegram |
| CI/CD monitoring agent with Telegram paging | Surfaces failures before the user notices them — autonomous incident triage, not just alert forwarding | MEDIUM | Watches CI runs, surfaces failures with context (which step, which repo, which PR triggered it); pages via Telegram; should suppress noise (transient failures, known flaky tests) |
| Autonomous PR triage and merge with approval queue | PRs that pass review criteria merge without user babysitting; edge cases queue for sign-off — the user controls the policy, not the execution | HIGH | Requires GitHub integration + Notion decision log + user review workflow; approval queue is the safety mechanism; criteria must be defined per-repo |
| Email triage via dedicated bot account (echo.sys.bot@gmail.com) | Dedicated account keeps agent traffic isolated from personal inbox; triage and outbound without contaminating the user's identity | MEDIUM | Dedicated Gmail account, not personal email; triage (categorize, summarize, flag) + outbound (draft and send on user's behalf with approval) |
| Project context switching (load relevant context when switching repos) | Senior developers work across many repos — context switching is expensive; agents that can reload the right context eliminate a recurring tax | MEDIUM | Loads repo-specific MEMORY.md, open issues, recent CI state, active PR list; triggered when user signals a context switch via Telegram or Claude Code |
| Experiment framework with Notion documentation | Captures learnings systematically — run experiments, document results, build institutional knowledge that survives agent restarts | MEDIUM | Experiments logged to Notion with hypothesis, method, result, decision; feeds back into dream routines as high-value operational memory |

### Anti-Features (Deliberately Not Buildable)

Features that seem like good ideas but should be explicitly excluded.

| Feature | Why Requested | Why Problematic | Alternative |
|---------|---------------|-----------------|-------------|
| Slack integration | Many developers use Slack | Explicitly out of scope (PROJECT.md); adding it creates a second notification surface, doubles channel management complexity, and the user does not use Slack in this setup | Telegram covers all notification and interaction needs |
| Multi-user / team mode | "What if I want to share this with my team?" | Fundamentally changes the trust model — a personal ops hub where only you review decisions is different from a shared system; secrets management, approval queues, and Notion logs are all personal-scoped | Treat this as a personal tool; if team use emerges, it warrants a separate system design |
| Web dashboard / UI for status | A visual dashboard would be easier to read | Creates infrastructure (server, hosting, auth) that contradicts the flat-file, no-custom-server constraint; operational knowledge lives in /openclaw-status skill and Telegram briefings | Use /openclaw-status skill + morning standup Telegram brief |
| Jira / Linear integration | Common project management tools | GitHub board is the task system; adding Jira/Linear creates dual source-of-truth, synchronization complexity, and work the agents would need to maintain | GitHub issues and project board; Beads for agent-internal task decomposition |
| Google Docs integration | Widely used documentation platform | Notion is the documentation layer; splitting between Notion and Google Docs creates fragmented decision logs; async review workflow is built around Notion | Notion for all documentation and decision logging |
| Windows / Linux support | Portability | macOS Keychain and launchd are load-bearing — the secrets pipeline and cron guarantees depend on them; cross-platform support requires rearchitecting these foundations | macOS-first; document macOS dependency explicitly |
| Real-time agent status dashboard | Visibility into what agents are doing right now | Polling creates context window tax (the Beads article documents 30% context waste on status reports); real-time dashboards encourage watching agents instead of reviewing outcomes | Beads graph queries on heartbeat cycles; morning standup brief for async review |
| Autonomous refactoring without scope constraint | Agents could improve code quality proactively | Unconstrained autonomous code changes are the highest-risk failure mode — easy to make, hard to review, potentially wide blast radius | Scope all autonomous dev actions to explicitly filed GitHub issues; everything requires an issue before work starts |
| Custom LLM routing / model selection engine | Cost optimization through dynamic model selection | Model selection is already handled by OpenClaw config per agent (Opus for orchestrator, Sonnet/Haiku for sub-agents); adding a routing layer creates complexity without clear value at single-user scale | Set models in openclaw.json per agent; adjust manually as needs change |
| Persistent memory via external vector database | Richer semantic search over memories | Adds infrastructure dependency (vector DB), operational complexity, and cost at single-user scale; QMD + dream routines handle memory consolidation well within token budgets | Dream routines with QMD; curated MEMORY.md files per agent |

---

## Feature Dependencies

```
[OpenClaw Installation]
    └──required-by──> [All Other Features]

[Keychain Secrets Management]
    └──required-by──> [Telegram Channel]
    └──required-by──> [Gmail Bot]
    └──required-by──> [GitHub Integration]

[cc-openclaw Skills (9)]
    └──required-by──> [Standardized agent creation]
    └──required-by──> [Dream routine setup]
    └──required-by──> [Channel management]

[Dual Orchestrator Architecture]
    └──required-by──> [Task Orchestrator delegation to sub-agents]
    └──required-by──> [Background autonomous execution]
    └──required-by──> [Beads integration]

[Notion Decision Log]
    └──required-by──> [User Review / Approval Workflow]
    └──required-by──> [Autonomous PR Merge Queue]
    └──required-by──> [Experiment Framework]

[GitHub Integration]
    └──required-by──> [PR Triage + Autonomous Merge]
    └──required-by──> [Morning Standup Brief]
    └──required-by──> [CI/CD Monitoring Agent]

[Task Orchestrator + Beads]
    └──required-by──> [Autonomous dev workflow]
    └──required-by──> [Issue solve → PR pipeline]
    └──enhances──> [All sub-agent delegation patterns]

[Dream Routines]
    └──required-by──> [Project context switching]
    └──enhances──> [Self-evolution] (distillation surfaces repeated patterns)

[Morning Standup Brief]
    └──depends-on──> [CI/CD Monitoring]
    └──depends-on──> [GitHub Integration]
    └──depends-on──> [Beads task status]

[Email Agent]
    └──depends-on──> [Keychain Secrets (Gmail credentials)]
    └──independent-of──> [GitHub Integration]
    └──independent-of──> [Beads]
```

### Dependency Notes

- **All features require OpenClaw installation:** The runtime is the substrate; nothing can exist without the flat-file configuration layer and gateway running.
- **Secrets management is infrastructure:** All external service integrations (Telegram, Gmail, GitHub, Notion) depend on Keychain secrets being correctly provisioned across all three secrets files. Misconfiguration here causes subtle failures (CLI works, gateway fails — or vice versa).
- **Notion decision log must exist before autonomous actions:** The trust model requires logging BEFORE execution. Building autonomous merge or autonomous issue creation before Notion logging is operational inverts the safety model.
- **Beads is Phase 2+ by design:** PROJECT.md explicitly marks Beads as "after core fleet is running." The core fleet (agents, channels, cron, dream routines) must be operational before adding Beads — you need something to decompose before you can model task graphs.
- **Dream routines depend on the full file structure:** The cc-openclaw article is explicit that DREAM_ROUTINE.md, MEMORY.md, archives directory, QMD index paths, and AGENTS.md session startup must ALL be present; /openclaw-dream-setup sets up the full set atomically.
- **Self-evolution is emergent, not bootstrapped:** Self-evolution capability depends on having operational agents (so patterns can emerge), dream routines (so patterns are consolidated into memory), and a skill creation workflow. It cannot be the first thing built.

---

## MVP Definition

### Launch With (v1) — Core Fleet Running

The minimum system that is useful and trustworthy.

- [ ] OpenClaw installed and configured on macOS (Keychain, launchd, Stow)
- [ ] cc-openclaw 9 skills installed as Claude Code slash commands
- [ ] Dual orchestrator architecture deployed (User Orchestrator + Task Orchestrator, separate contexts)
- [ ] Telegram integration operational (bot token through full secrets pipeline; gateway verified)
- [ ] Notion integration operational (decision log writing confirmed)
- [ ] GitHub integration operational (issue creation, board read/write confirmed)
- [ ] Email agent (echo.sys.bot@gmail.com) operational for triage and outbound
- [ ] Autonomous actions log to Notion BEFORE execution (trust model validated)
- [ ] User review/approval workflow in Telegram confirmed working
- [ ] /openclaw-status health check working (operational visibility)

### Add After Core Fleet Validated (v1.x) — Automation Layer

- [ ] Dream routines for all agents — nightly distillation running on cron schedule
- [ ] Beads (bd) in Task Orchestrator workspace — dependency-aware task decomposition for dev tasks
- [ ] Morning standup brief — overnight activity digest delivered via Telegram
- [ ] CI/CD monitoring agent — watch runs, surface failures, page via Telegram
- [ ] Autonomous PR triage and merge with approval queue

### Future Consideration (v2+) — Self-Evolution

- [ ] Project context switching — triggered on repo change, loads relevant MEMORY.md and state
- [ ] Experiment framework — hypothesis/method/result/decision logging to Notion
- [ ] Self-evolution capability — framework proposes new agents/skills when patterns repeat 3x
- [ ] Agent questioning each other — sub-agents can challenge each other's outputs before handoff

---

## Feature Prioritization Matrix

| Feature | User Value | Implementation Cost | Priority |
|---------|------------|---------------------|----------|
| OpenClaw installation + base config | HIGH | MEDIUM | P1 |
| cc-openclaw skills (9) | HIGH | LOW | P1 |
| Dual orchestrator architecture | HIGH | HIGH | P1 |
| Keychain secrets management | HIGH | MEDIUM | P1 |
| Telegram channel | HIGH | MEDIUM | P1 |
| Notion decision log | HIGH | MEDIUM | P1 |
| GitHub integration | HIGH | MEDIUM | P1 |
| Email agent (echo.sys.bot) | HIGH | MEDIUM | P1 |
| User review/approval workflow | HIGH | HIGH | P1 |
| /openclaw-status skill | MEDIUM | LOW | P1 |
| Dream routines | HIGH | MEDIUM | P2 |
| Beads task graph | HIGH | HIGH | P2 |
| Morning standup brief | MEDIUM | LOW | P2 |
| CI/CD monitoring agent | MEDIUM | MEDIUM | P2 |
| Autonomous PR merge + queue | HIGH | HIGH | P2 |
| Project context switching | MEDIUM | MEDIUM | P3 |
| Experiment framework | MEDIUM | MEDIUM | P3 |
| Self-evolution capability | HIGH | HIGH | P3 |

**Priority key:**
- P1: Must have for launch (v1 core fleet)
- P2: Should have once core fleet validated (v1.x automation layer)
- P3: Nice to have, requires v1+v1.x proven (v2 self-evolution)

---

## Competitor Feature Analysis

This is a personal, bespoke system — there are no direct competitors. The relevant comparison is "vs. not having the system" and "vs. manual Claude Code use."

| Feature | Manual Claude Code | Commercial AI Agent Platforms | This System |
|---------|-------------------|-------------------------------|-------------|
| Configuration consistency | Agent reinvents conventions each time; context-dependent quality | Platform-enforced, but vendor lock-in and no customization | cc-openclaw skills: model-independent, convention-enforcing, open-source |
| Task completion reliability | Agents skip steps (attention decay + satisficing) | Workflow engines exist but are rigid DSLs | Beads task graph: structural enforcement, dependency-aware, atomic claim/close |
| Autonomous actions trust model | No audit trail; unclear what happened | Varies; often opaque | Notion decision log before execution; user reviews on return; revert capability |
| Memory across sessions | None (context window resets) | Vendor-specific, often opaque | Dream routines: QMD-backed, nightly distillation, user-owned, token-budgeted |
| Notification channel | Must actively check Claude | Push to Slack/email | Telegram: proactive paging, approval buttons, morning brief |
| Disaster recovery | N/A (no infrastructure) | Vendor-dependent | Git clone + stow: 10 minutes; every config is a git commit |
| Self-evolution | None | None at personal scale | Skill scaffolding when patterns repeat; agents propose their own tooling |

---

## Sources

- PROJECT.md — primary requirements and constraints document (direct source)
- "Managing OpenClaw with Claude Code" — Rahul Subramaniam, Trilogy AI CoE, March 2026 (cc-openclaw reference architecture, skills catalog, secrets pipeline, operational patterns)
- "Why Your AI Agents Skip Steps — and How Task Graphs Prevent It" — Rahul Subramaniam, Trilogy AI CoE, March 2026 (Beads motivation, failure mode taxonomy, decomposition templates)
- [OpenClaw Dreaming v2026.4.5 announcement](https://clawtask.app/news/dreaming-in-openclaw-latest-version-2026-4-5) — dream routine implementation details confirmed
- [AI Agent Fleet Management: Complete Scaling Guide](https://fast.io/resources/ai-agent-fleet-management/) — ecosystem confirmation of table stakes patterns
- [IBM: Alert Fatigue Reduction with AI Agents](https://www.ibm.com/think/insights/alert-fatigue-reduction-with-ai-agents) — alert design principles for CI monitoring feature
- [Building Self-Evolving AI Agents](https://medium.com/@nir.shilon/building-self-evolving-ai-agents-52c6745c8a85) — self-evolution pattern confirmation
- [Human-in-the-Loop Infrastructure for Agentic Workflows](https://www.awaithuman.dev/) — approval queue pattern confirmation

---
*Feature research for: Personal AI developer operations hub (OpenClaw + Claude Code fleet)*
*Researched: 2026-05-20*

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

---

# Features Research — v2.0 Intelligence Layer

**Researched:** 2026-05-21
**Scope:** Four intelligence upgrade features for the existing OpenClaw fleet
**Architecture constraint:** Shell scripts + Node.js + OpenClaw only — no Python ML pipelines

The four features below upgrade the fleet from reactive execution (run task, report result) to proactive intelligence (learn patterns, score risk, surface insights). Each section maps table-stakes vs differentiator behaviors so the roadmap can phase them correctly.

---

## Feature Categories

### 1. Smarter Email Triage

**What v1.0 does today:** `email-triage.sh` via gogcli fetches unread Gmail, SOUL.md categorizes into 5 buckets (Action Required / FYI / Automated-Noise / Newsletter / Unknown), drafts replies for Action Required, escalates urgent items via sessions_yield. Categories are determined by a single LLM pass with no memory of prior emails or senders.

**Table stakes:**
- Numeric priority score (0–100) attached to every categorized email, not just a bucket label. Callers (morning standup, User Orchestrator) can threshold on the score rather than re-deriving urgency.
- Sender context: flag if sender has sent Action Required emails before (repeat contact signal), flag VIP senders by domain or explicit list. Both signals are derivable from the existing `memory/triage-YYYY-MM-DD.md` logs without external storage.
- False-positive suppression for Automated-Noise: CI alerts, monitoring pings, and GitHub notifications from known senders should never generate Telegram pings. A per-sender allowlist stored in agent memory prevents re-alerting on known noise sources.
- Idempotent processing: emails already triaged (marked read or in a `triaged` label) are skipped on re-run. V1.0 has `mark-read` support via gogcli; v2.0 must check label before scoring to avoid double-processing.

**Differentiators:**
- Auto-draft reply for common patterns: "can you join a call?" → draft with calendar link; "what's the status of X?" → draft citing the relevant GitHub issue or PR URL. Pattern matching runs against the email body using an LLM prompt with a few-shot template library stored in agent memory. The draft is written to a `drafts/` memory file, not auto-sent — user reviews on return.
- Sender reputation history: scan the last 30 days of `memory/triage-*.md` logs to compute per-sender action-rate (what fraction of their emails needed action) and inflate/deflate priority scores accordingly. High action-rate senders get score boost; known-noise senders get suppression. Implementable as a Node.js script that reads the memory log directory.
- Thread awareness: gogcli's `gog gmail get <messageId> --sanitize-content` fetches the full thread. Triage decisions that look at the full thread avoid the "no rush" misclassification problem where a polite opener hides urgency.
- Category drift detection: if the Unknown bucket exceeds 20% of a run, record a Synapse learning flagging category confusion — this surfaces to the dream routine for rubric refinement.

**Complexity:** Medium
- Table stakes changes are SOUL.md + scoring logic additions to the existing categorization prompt — low effort.
- Auto-draft patterns require a template library (flat JSON file in agent memory) and a second LLM pass — medium effort.
- Sender reputation history requires a small Node.js aggregation script over the memory logs — medium effort.
- Thread awareness requires the gogcli `get` call per email which multiplies API calls — test latency.

**Depends on:** email-triage agent (SOUL.md, email-triage.sh, gogcli), Synapse learning.record (for drift detection), `memory/triage-*.md` log history (for reputation scoring)

---

### 2. Cross-Agent Learning via Synapse

**What v1.0 does today:** Every agent has Synapse mandatory loop in TOOLS.md — they call `synapse.learning.record` at session end. But agents only record their own learnings; they do not query what other agents have learned before starting a task. The learning pipeline is write-heavy, read-light.

**Table stakes:**
- Pre-task learning query: before each agent starts a non-trivial task, it calls `synapse.learning.query` with tags matching its domain (e.g., ci-monitor queries `["ci","github-actions"]`; email-triage queries `["email","gmail","triage"]`). Retrieved learnings are injected into the session context as an advisory block.
- Cross-silo flag: the existing Synapse API supports `cross_silo: true` on queries. Agents should use this flag when their task touches a domain another agent also works in (e.g., DevBot querying CI Monitor learnings when triaging a PR with CI failures).
- Structured learning schema: learnings currently can be free-text. Table stakes for cross-agent value is a consistent format: `claim` (what was learned), `applies_to` (tags), `confidence` (low/medium/high), and `evidence_artifact_id` (optional). The existing Synapse API already supports this shape — agents need to commit to populating all fields.
- Dream routine reinforcement: the nightly dream routine for each agent should include a step that queries Synapse for new cross-silo learnings since the last distillation and merges relevant ones into the agent's MEMORY.md. This closes the loop: learnings recorded during the day become part of the agent's durable context.

**Differentiators:**
- Learning propagation graph: when CI Monitor records a learning tagged `["ci","github-actions","flaky-test"]`, DevBot and the morning standup brief agent should receive it proactively rather than waiting for the next query. This can be approximated by the Task Orchestrator broadcasting a `synapse.brief.create` to relevant agents after a high-confidence learning is recorded — no new infrastructure needed.
- Conflict detection: if two agents record contradictory learnings about the same domain (e.g., "PR #X always passes" vs "PR #X flaky"), the Task Orchestrator or a dedicated reconciliation step should flag the conflict as a question via `synapse.question.ask`. The human resolves it on return, and the resolution becomes a high-confidence learning.
- Learning age decay: learnings older than 30 days get `confidence` downgraded automatically during the dream routine. A shell script comparing learning timestamps against today's date and writing updated confidence values keeps the knowledge base fresh without manual curation.

**Complexity:** Low-to-Medium
- Pre-task query addition is a TOOLS.md edit per agent and a 3-line curl in each agent's startup — low effort.
- Dream routine reinforcement step is a DREAM_ROUTINE.md edit per agent — low effort.
- Learning propagation graph via Task Orchestrator broadcast is medium effort (requires Task Orchestrator to monitor Synapse for new high-confidence learnings on a heartbeat cycle).
- Conflict detection is medium effort and should be deferred until learning volume justifies it.

**Depends on:** Synapse integration (Phase 13, all agents already wired), dream routines (Phase 5), Task Orchestrator heartbeat cycle (Phase 4), all agents having consistent learning schema

---

### 3. Proactive Standup Insights

**What v1.0 does today:** `standup-brief.sh` delivers: overnight PRs merged, CI failures, stale PRs. These are factual summaries — "here is what happened." There is no interpretation of what the facts mean or what the user should do first.

**Table stakes:**
- Blocker surfacing: classify each open PR and issue as Blocked / At Risk / On Track based on observable signals. Blocked = has CI failure AND no commits in 24h. At Risk = stale review request older than 48h. On Track = recent commit, CI passing, review in progress. Derivable entirely from `gh pr list --json` + the existing `state/` files in ci-monitor.
- Priority recommendation: produce a ranked "tackle first" list of 3–5 items. Ranking inputs: CI failure (highest signal), PR age, whether the item blocks other PRs (check `closingIssuesReferences` and `reviewRequests`). The ranking is computed by a jq pipeline over the `gh pr list` output — no LLM needed for the ranking itself; LLM adds a one-sentence explanation per item.
- Pattern detection (same-day): if more than 2 items in the brief share a common signal (e.g., 3 PRs all blocked on the same CI workflow, 2 issues both waiting on the same reviewer), surface that as a "pattern notice" at the top of the brief. Derivable with jq grouping.
- Delivered format change: current brief is plain text. Proactive insights format adds a "Top 3 actions" block before the detailed facts, so the user reads the prescription before the raw data.

**Differentiators:**
- Recurring blocker history: compare today's blockers against the last 7 days of standup summaries (stored in `memory/standup-YYYY-MM-DD.md`). If the same PR or issue has been blocked for 3+ consecutive days, flag it as "chronic blocker" with a suggested intervention (reassign, break into smaller PR, remove from sprint). This is a shell script loop over the memory log directory.
- Velocity trend: compute a 7-day rolling PR merge rate and compare it to the prior 7-day window. A >20% decline is surfaced as a "velocity drop" notice with the top contributing factor (CI failures? Stale reviews? Large PRs?). Derivable from memory logs + gh API — no external analytics tooling.
- GitHub Copilot Workspace / issue dependency awareness: if a PR's linked issue has sub-tasks in Beads, include the Beads subtask completion percentage in the standup entry. This connects the "what got done" view (GitHub) to the "how done are we really" view (Beads).

**Complexity:** Low (table stakes) / Medium (differentiators)
- Table stakes are jq pipeline additions to `standup-brief.sh` + a one-sentence LLM call for the "top 3 actions" block — low effort.
- Recurring blocker history requires reading memory log files and comparing across days — medium effort (shell script with date arithmetic).
- Velocity trend requires accumulating per-day merge counts in a simple JSON file in agent memory — medium effort.
- Beads integration in standup is medium effort (requires the standup script to query the Beads graph, which only works if Beads is healthy and contains the relevant epics).

**Depends on:** standup-brief.sh (Phase 6/14), ci-monitor state files, gh CLI, Beads task graph (for Beads integration differentiator only), `memory/standup-*.md` logs

---

### 4. Decision Quality — Pre-Notion Risk Gate

**What v1.0 does today:** Decision Reviewer receives a decision object `{action, rationale, reversibility, evidence}` and produces `{verdict: pass|flag|reject, comments, must_fix}`. The rubric checks rationale soundness, reversibility specificity, evidence observability, and action specificity. It catches low-quality submissions (vague rationale, unknown reversibility) but does not assess the RISK of the action itself — a well-specified high-risk action (e.g., "merge PR #42 with squash, permanent, CI passing") receives a `pass` with no risk annotation.

**Table stakes:**
- Risk score output: Decision Reviewer adds a `risk_score` (0–100, normalized) and `risk_tier` (low/medium/high) to every verdict, even `pass` verdicts. The score reflects action impact, not submission quality. Tier thresholds: 0–30 = low (auto-proceed), 31–60 = medium (async notify), 61–100 = high (synchronous Telegram approval required before Notion write).
- Risk dimensions scored: (1) reversibility — permanent actions score higher; (2) blast radius — single-file vs repo-wide vs cross-repo; (3) external side effects — email sent, PR merged, issue created are higher than read-only queries; (4) recency — first time performing this action type scores higher than a repeated action with a history of successful outcomes. All four are derivable from the existing `{action, reversibility}` fields with no new input required.
- Tier-based routing: Task Orchestrator checks `risk_tier` from the verdict before writing to Notion. High-tier actions pause and send a Telegram message requesting explicit approval before proceeding. Medium-tier actions proceed but get a Telegram notification. Low-tier actions proceed silently. This is a TOOLS.md + SOUL.md change in the Task Orchestrator, not a new agent.
- Audit trail: `risk_score` and `risk_tier` are written as fields in the Notion decision log entry. This means the user's review queue shows risk context alongside the decision, enabling triage of the review backlog by risk level.

**Differentiators:**
- Historical calibration: after 30+ decisions, the Task Orchestrator can compare predicted risk tier against actual outcomes (did the action cause problems? did the user override it?). Outcomes are recorded as Synapse learnings tagged `["decision-quality","risk-calibration"]`. Over time, the risk scoring dimensions can be reweighted based on what actually caused problems vs what was predicted to.
- Action-class risk profiles: build a risk profile per action class (merge-pr, create-issue, close-issue, send-email, config-change). Each profile stores the historical mean score and variance for that class. New actions of a known class are scored against the class profile — outliers (score more than 2 standard deviations above the class mean) get escalated regardless of tier. Stored as a flat JSON file in Decision Reviewer's memory.
- Compound risk detection: if two actions are queued back-to-back and each is medium-risk, but they affect the same repo and branch, the compound risk may be high. Task Orchestrator checks the pending Notion entries before routing the second action and escalates if compound risk is detected. Medium effort, high safety value.

**Complexity:** Low (table stakes) / Medium (differentiators)
- Risk score and tier are an addition to Decision Reviewer's SOUL.md rubric and output schema — the LLM already reads `reversibility` and `action`; scoring the four dimensions is a prompt addition, not a new agent.
- Tier-based routing in Task Orchestrator is a TOOLS.md + SOUL.md edit plus a Telegram message call — low-to-medium effort.
- Notion field additions are a schema change to the existing Notion DB — low effort.
- Historical calibration and action-class profiles are medium effort (require accumulating data before they provide value — defer to later phase iteration).
- Compound risk detection is medium effort but has direct safety value; worth building in the same phase as tier-based routing.

**Depends on:** Decision Reviewer v1.0 (Phase 9/11), Notion decision log (Phase 9), Task Orchestrator Telegram send capability, Synapse learning.record (for calibration differentiator)

---

## v2.0 Feature Dependencies

```
[Synapse Learning (Phase 13 — all agents wired)]
    └──required-by──> [Cross-Agent Learning — pre-task query]
    └──required-by──> [Cross-Agent Learning — dream routine reinforcement]
    └──required-by──> [Decision Quality — historical calibration]
    └──enhances──> [Email Triage — category drift detection]

[email-triage.sh + gogcli (Phase 14)]
    └──required-by──> [Smarter Email Triage — all features]

[memory/triage-*.md log history]
    └──required-by──> [Sender reputation scoring]
    └──required-by──> [Auto-draft pattern library]

[standup-brief.sh (Phase 6/14)]
    └──required-by──> [Proactive Standup Insights — all features]

[memory/standup-*.md log history]
    └──required-by──> [Recurring blocker history]
    └──required-by──> [Velocity trend]

[Decision Reviewer v1.0 (Phase 11)]
    └──required-by──> [Decision Quality — risk scoring additions]

[Notion decision log (Phase 9)]
    └──required-by──> [Decision Quality — audit trail with risk fields]

[Task Orchestrator (Phase 4)]
    └──required-by──> [Decision Quality — tier-based routing]
    └──required-by──> [Cross-Agent Learning — propagation broadcasting]

[Beads task graph (Phase 4)]
    └──required-by──> [Proactive Standup — Beads subtask completion view]
    └──optional-for──> [All other v2.0 features]

[Dream Routines (Phase 5)]
    └──required-by──> [Cross-Agent Learning — dream routine reinforcement step]
```

---

## v2.0 Anti-Features (Explicitly Out of Scope)

| Feature | Why Tempting | Why Out of Scope |
|---------|--------------|-----------------|
| ML-based email classifier (embeddings, fine-tuning) | Higher classification accuracy at scale | Requires Python pipeline and model hosting; contradicts the no-custom-server-infrastructure constraint; LLM-based classification already achieves 90–95% accuracy which is sufficient |
| Email auto-send without draft review | Speed | Any outbound action from echo.sys.bot@gmail.com affects the user's reputation and relationships; drafts-only is the correct default; auto-send requires explicit per-pattern user opt-in, not a blanket feature |
| Real-time risk dashboard | Visibility into decision queue | No-dashboard constraint from PROJECT.md; Telegram notifications + morning standup provide sufficient visibility |
| Centralized shared memory store (Redis, Postgres) | Richer cross-agent sharing | Adds infrastructure dependency; Synapse already provides the shared memory surface; duplicating it creates consistency problems |
| Learning from email content (extract facts from emails into Synapse) | Richer context | Prompt injection risk — email content is untrusted; SOUL.md already has the guardrail rule; extracting facts from untrusted input would require sandboxing that adds complexity |
| Automated decision reversal | Faster recovery when something goes wrong | Revert scripts exist (devbot-revert-merge.sh) but should always be user-triggered; automated reversal of autonomous actions requires trusting the agent's judgment about its own mistakes — a level of autonomy not warranted yet |

---

## Sources

- [Email Triage Agent for OpenClaw — ShopClawMart](https://www.shopclawmart.com/blog/email-triage-agent-openclaw) — OpenClaw-specific email triage patterns, permission-based action routing, dry-run mode (MEDIUM confidence — OpenClaw ecosystem source)
- [AURA: Agent Autonomy Risk Assessment Framework](https://arxiv.org/html/2510.15739v1) — risk tier thresholds (0–30 low, 31–60 medium, 61–100 high), HITL escalation patterns (HIGH confidence — peer-reviewed)
- [Designing Approval Workflows for High-Stakes Agent Actions — Prefactor](https://prefactor.tech/learn/designing-agent-approval-workflows) — synchronous vs asynchronous approval patterns, risk dimension taxonomy (MEDIUM confidence)
- [Quantitative Risk Scoring for Autonomous AI Agents — Medium](https://medium.com/@ruchikd/quantitative-risk-scoring-for-autonomous-ai-agents-integrating-intent-capabilities-and-a83a78ae9ce9) — risk scoring formula incorporating intent, capability, behavioral history, cross-agent interaction (MEDIUM confidence)
- [Cross-Agent Organizational Memory — Augment Code](https://www.augmentcode.com/guides/cross-agent-organizational-memory) — cross-agent memory patterns, selective sharing vs broadcast, episodic vs semantic separation (MEDIUM confidence)
- [Multi-Agent Memory Systems — Hindsight](https://hindsight.vectorize.io/guides/2026/04/21/guide-building-multi-agent-systems-with-shared-memory) — shared memory consistency tradeoffs, write controls, review loops (MEDIUM confidence)
- [Using Confidence Scoring to Reduce Risk in AI Decisions — Multimodal](https://www.multimodal.dev/post/using-confidence-scoring-to-reduce-risk-in-ai-driven-decisions) — tiered confidence thresholds for approval routing (MEDIUM confidence)
- [AI Email Triage Complete Guide — NewMail](https://www.newmail.ai/feeds/blog/ai-email-triage) — sender reputation, VIP routing, repeat-contact priority inflation, 90–95% LLM classification accuracy (MEDIUM confidence)
- [n8n AI Email Triage + Auto-Response](https://n8n.io/workflows/9157-ai-powered-email-triage-and-auto-response-system-with-openai-agents-and-gmail/) — cascading heuristics → LLM pipeline, draft-for-review pattern (MEDIUM confidence)
- [Developer Interaction Patterns with Proactive AI — arXiv](https://arxiv.org/html/2601.10253v1) — proactive suggestions at natural workflow boundaries, lower interpretation time vs reactive AI (HIGH confidence — peer-reviewed)
- Existing agent TOOLS.md and SOUL.md files — direct inspection of v1.0 capabilities and constraints (HIGH confidence — primary source)

---
*v2.0 intelligence layer feature research appended: 2026-05-21*

# Stack Research — v2.0 Intelligence Layer

**Domain:** Personal AI Operations Hub — Intelligence Upgrades
**Researched:** 2026-05-21
**Confidence:** HIGH for versions/patterns; MEDIUM for Synapse feed-back pattern (proprietary, limited external docs)

> This file extends the Phase 1 STACK.md with additions needed for the four v2.0 intelligence
> upgrades only. All Phase 1 stack (OpenClaw, Node 24, cc-openclaw, Beads, Notion, Gmail,
> gh CLI, GNU Stow) is validated and unchanged.

---

## New Dependencies

| Library/Tool | Version | Purpose | Integration Point |
|---|---|---|---|
| `natural` | 8.1.1 | TF-IDF term scoring + Naive Bayes classifier for email body/subject analysis | `scripts/email-triage/` — replaces hand-rolled regex; install locally, not globally |
| `sentiment` | 5.0.2 | AFINN-165 sentiment score (-5 to +5) per email sentence | Same directory as `natural`; used to escalate urgently negative emails regardless of keyword match |
| `json-rules-engine` | 7.3.1 | Declarative priority scoring rules (sender domain, subject keywords, sentiment score, thread age) wired to email triage actions | `scripts/email-triage/rules/` — rules expressed as JSON, version-controlled in git |
| `compromise` | 14.15.0 | English NLP — extract proper nouns, dates, action verbs from email/standup text without a model call | Standup brief script and email subject parsing; ~300 KB, zero network calls, runs in Node subprocess |

**Confidence on versions:** HIGH — confirmed via `npm info` against live registry (2026-05-21). `natural` last published 2026-02-27; `compromise` 14.x is the actively-maintained major.

---

## Integration Notes

### 1. Email Triage Priority Scoring (Feature: smarter triage, auto-draft, fewer false positives)

**Pattern:** Rule engine over extracted features, not raw text matching.

The existing `gmail-triage.sh` fetches emails via gogcli and outputs JSON. Add a thin Node.js scoring layer between fetch and action:

```
gmail-triage.sh (fetch) → score-emails.js (natural + sentiment + json-rules-engine) → triage-actions.sh (label/draft/archive)
```

`score-emails.js` does three things:
1. TF-IDF (`natural`) over subject + snippet to weight domain-specific signal words (PR, merge, blocked, urgent, invoice, SLA)
2. Sentiment score (`sentiment`) on the first 3 sentences — strongly negative (<-3) overrides a low keyword score for escalation
3. `json-rules-engine` evaluates structured facts (sender domain, TF-IDF score, sentiment, thread age, CC count) against JSON rules in `rules/email-priority.json`

Rules output a `priority` (1-5), `action` (read/draft/archive/escalate), and `reason` string. The `reason` goes into the Notion log entry. Rules file is human-readable JSON — adjustable without touching Node code.

**Auto-draft:** When action=draft, the scoring layer appends a `draftPrompt` field to the JSON output. The downstream Claude Code agent reads that field and calls the model once to generate the draft body. No new library needed — this is prompt construction, not a new dependency.

**Why `json-rules-engine` over hand-coded `if/else`:** Rules are version-controlled JSON objects, not code. The agent that learns from Synapse history can write a new rule to the JSON file without understanding the Node logic. Async fact providers let rules query Keychain-backed facts (sender reputation, thread history) without blocking.

### 2. Cross-Agent Learning via Synapse (Feature: agents learn from history across sessions)

**Pattern:** MEMORY.md write-back, not a new library.

Synapse already exists (token in Keychain, `synapse.learning.query` + `synapse.learning.record` REST calls via curl). The gap is the feedback loop from Synapse back into agent context.

**Implementation:** No new npm dependency. Use two shell functions:

- `synapse-briefing.sh` — called by each agent's dream routine cron job (after OpenClaw's own dream phase). Queries `synapse.learning.query` with the agent's tags, formats the top 5 learnings (confidence >= medium) as bullet points, and appends them to the agent's `MEMORY.md` under a `## Synapse Learnings` section.
- OpenClaw then injects `MEMORY.md` into the model context at session start (this is the existing bootstrap injection mechanism — `agents.defaults.bootstrapMaxChars` controls truncation, default 20000 chars). No new injection machinery needed.

**Token budget:** The existing dream budget (2,500 tokens daily / 7,500 for 3-day digest) is the constraint. Synapse learnings must be pre-summarized to 5 bullets max before write-back. Each bullet targets ≤80 chars. This keeps the Synapse block under ~500 chars, well inside the bootstrap budget.

**Why not a dedicated library:** Synapse's API is a REST endpoint over HTTPS. The existing curl pattern used everywhere in this stack is sufficient. A dedicated SDK would add a dependency, a versioning surface, and a global install risk — none of which is justified for 3 curl calls per dream cycle.

**Confidence:** MEDIUM. Synapse (synapse-os.ai) is a proprietary platform with limited public documentation. The pattern described above is correct given the Synapse API surface visible in the CLAUDE.md system prompt (`synapse.learning.query`, `synapse.learning.record`, `synapse.brief.fetch`). The MEMORY.md bootstrap injection is HIGH confidence from OpenClaw docs.

### 3. Proactive Standup Insights (Feature: blocker detection, priority suggestions, pattern recognition)

**Pattern:** `compromise` for entity/date extraction + `json-rules-engine` for pattern classification.

Both libraries are already pulled in for email triage (see above), so no net-new dependency.

The standup brief script (`standup-brief.sh`) currently emits a narrative summary. Add a `detect-patterns.js` step after data collection:

- `compromise` parses PR titles, CI failure messages, and issue descriptions to extract: person names (who is blocking), dates (SLA deadlines, meeting times), action verbs (merge, deploy, fix, review), and duration phrases (2 days ago, 3 open)
- `json-rules-engine` evaluates extracted facts against pattern rules: PR open > 2 days with no review activity → `blocker_candidate`, CI failure rate > 2 in last 24h on same job → `recurring_failure`, issue labeled "blocked" + assignee → `escalate_to_standup`
- Output is a `insights` array in the standup JSON, each with `type`, `description`, and `suggested_action`

The Claude Code agent that formats the standup brief reads the `insights` array and inlines them as callout blocks. No model call for detection — `compromise` + `json-rules-engine` do the classification deterministically.

### 4. Decision Quality Improvement — Pre-Notion Risk Flagging (Feature: Decision Reviewer flags risky actions pre-Notion)

**Pattern:** Keyword + tier scoring in a Node.js module, no external library needed.

The four-tier risk framework (Tier 0: read-only → Tier 4: irreversible/financial) is well-established and can be implemented as a lookup table:

```javascript
// risk-classifier.js — no npm dependency, ships as scripts/lib/
const RISK_PATTERNS = {
  tier4: /\b(payment|billing|deploy|merge.to.main|delete|irreversible|broad.segment|GDPR|PCI)\b/i,
  tier3: /\b(email|send|create.issue|webhook|notify|external)\b/i,
  tier2: /\b(fetch|read.api|search|list)\b/i,
};
```

The Decision Reviewer agent passes the decision description string through `risk-classifier.js` before calling `notion-log-decision.js`. If tier >= 3, the Notion log entry gets a `risk_flag: true` field and a `risk_reason` string. The Telegram notification for tier-4 decisions includes a `[HIGH RISK]` prefix.

**Why no library:** The risk patterns are small, domain-specific, and need to be adjusted as the agent fleet evolves. Encoding them in a 30-line module with a JSON rules file keeps them reviewable in git history. `json-rules-engine` is an option here too, but adds overhead for what is a single linear pass over one string.

**Confidence:** HIGH. Pattern drawn directly from the runcycles.io risk tier documentation (verified via WebFetch). The Tier 0-4 classification with keyword indicators is a recognized framework, not proprietary.

---

## What NOT to Add

| Avoid | Why | Use Instead |
|---|---|---|
| Python ML (scikit-learn, spaCy, transformers) | No Python in this stack. Introduces a second runtime, package manager, and venv to manage on macOS. The constraint is Node.js + zsh. | `natural` 8.x + `json-rules-engine` — covers 90% of the same use cases without leaving the Node.js runtime |
| OpenAI / Anthropic API calls in the triage scoring path | Latency + cost per email. Email volume can spike; a model call per email creates runaway cost and blocks the triage loop. | Deterministic scoring (TF-IDF + sentiment + rules) for classification; Claude Code agent call only for the auto-draft step on the shortlist |
| Vector DB (Chroma, Pinecone, pgvector) | No new infrastructure. This stack runs on macOS with no server processes outside OpenClaw. A vector DB requires a daemon, a port, and a backup strategy. | QMD (OpenClaw's built-in retrieval sidecar) already provides BM25 + semantic search for agent memory. Use it for any retrieval-augmented step. |
| Global npm installs for new libraries | Breaks reproducibility across agents, creates version conflicts. | Install `natural`, `sentiment`, `json-rules-engine`, `compromise` locally in each agent's `scripts/` directory that needs them |
| A dedicated "Synapse SDK" or wrapper | No such library exists in the public ecosystem (synapse-os.ai is proprietary). The curl pattern already used throughout the stack is sufficient. | `curl` with Keychain token — same pattern as Notion and Gmail calls |
| `brain.js` or `ml.js` neural networks | Trained models need labeled datasets to be useful. This stack has no training pipeline. A rule-based + TF-IDF approach with Bayesian classification is sufficient and transparent (rules are readable in git). | `natural` Naive Bayes classifier with hand-curated training phrases per category — 20-30 examples per class is enough for email routing |
| Separate NLP microservice / sidecar | Adds network hop, service management, and a new failure domain. | Node.js subprocess called from zsh scripts — same pattern as `notion-log-decision.js` |
| `compromise` for non-English content | `compromise` is English-only. If international email handling is ever needed, this creates silent failures. | Flag non-English emails (detected by charset or lang header) as `needs_review` before scoring, bypass NLP entirely |

---

## Version Compatibility for New Dependencies

| Package | Node.js | Notes |
|---|---|---|
| `natural` 8.1.1 | 16+ (Node 24 confirmed) | Last published 2026-02-27. No native binaries — pure JS, no build step. |
| `sentiment` 5.0.2 | 14+ (Node 24 confirmed) | Pure JS. AFINN-165 wordlist is bundled — no network calls. |
| `json-rules-engine` 7.3.1 | 18+ (Node 24 confirmed) | Full async support. Rules can be async functions for Keychain lookups. |
| `compromise` 14.15.0 | 14+ (Node 24 confirmed) | ~1.2 MB bundle. English-only. No native binaries. |

All four are pure JavaScript — no node-gyp build step, no native binaries, no post-install scripts. They install reliably in agent `scripts/` directories without sudo or global state.

---

## Sources

- [natural npm package](https://www.npmjs.com/package/natural) — v8.1.1, 210k weekly downloads, TF-IDF + Naive Bayes (HIGH — verified via `npm info`)
- [sentiment npm package](https://www.npmjs.com/package/sentiment) — v5.0.2, AFINN-165 (HIGH — verified via `npm info`)
- [json-rules-engine GitHub](https://github.com/CacheControl/json-rules-engine) — v7.3.1, async facts, priority scoring (HIGH)
- [compromise GitHub](https://github.com/spencermountain/compromise) — v14.15.0, English NLP, entity extraction (HIGH)
- [AI Agent Risk Assessment Tiers](https://runcycles.io/blog/ai-agent-risk-assessment-score-classify-enforce-tool-risk) — Tier 0-4 framework, keyword indicators (MEDIUM — single source, but corroborated by MindStudio four-tier article)
- [How to Classify AI Agent Actions by Risk — MindStudio](https://www.mindstudio.ai/blog/classify-ai-agent-actions-by-risk) — corroborating four-tier framework (MEDIUM)
- [OpenClaw Memory Concepts](https://docs.openclaw.ai/concepts/memory) — MEMORY.md bootstrap injection, bootstrapMaxChars default (HIGH)
- [OpenClaw Dreaming Guide 2026 — DEV Community](https://dev.to/czmilo/openclaw-dreaming-guide-2026-background-memory-consolidation-for-ai-agents-585e) — dream phases, MEMORY.md promotion (MEDIUM)
- [OpenClaw Memory Token Config](https://velvetshark.com/openclaw-memory-masterclass) — bootstrapMaxChars (20000 default) and bootstrapTotalMaxChars (150000 default) (MEDIUM — secondary source)
- [Agent Memory Architecture Trends 2025-2026 — Zylos Research](https://zylos.ai/research/2026-04-05-ai-agent-memory-architectures-persistent-knowledge) — context injection patterns, static vs dynamic procedural memory (MEDIUM)

---
*Stack research for: Personal AI Operations Hub v2.0 Intelligence Layer*
*Researched: 2026-05-21*

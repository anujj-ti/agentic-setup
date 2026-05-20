## **Why Your AI Agents Skip Steps - and How Task Graphs Prevent It** 

Using Beads with OpenClaw for Dependency-Aware Agent Orchestration 

RAHUL SUBRAMANIAM MAR 26, 2026 

**Subscribed** 

## **The Problem Nobody Talks About** 

You’ve built an agent system. You’ve written detailed instructions. You’ve specified exactly what each agent should do - step by step, in a SOUL.md or system prompt that took you hours to craft. The agent reads it, acknowledges it, and then does about 40% of what you asked. 

The natural reaction is to make the instructions more explicit. So you do. You add bold headers. You add numbered steps. You add “MANDATORY” and “DO NOT SKIP” markers. You add a checklist the agent must fill out before reporting back. You make it impossible to misunderstand what “done” means. 

And the agent still skips steps. 

This is the part that surprises people. The problem isn’t vague instructions. You can have the most explicit, detailed, unambiguous instructions ever written, and an LLM will still selectively ignore parts of them. Understanding why this happens is essential to fixing it. 

## **Why explicit instructions aren’t enough** 

**LLMs don’t execute instructions - they predict completions.** When a model receives a 3,000-word system prompt with 12 mandatory steps, it doesn’t build an internal checklist and work through it mechanically. It generates the most likely next token given the full context. If the most natural-sounding completion after step 3 is to summarize and report success, the model will do that - even if steps 4 through 12 are staring at it from the prompt. 

**Long instruction lists suffer from attention decay.** In a transformer architecture, the model attends to the entire context, but not uniformly. Instructions at the beginning and end of a prompt get more attention than those in the middle. Your step 7 (”open the app in a browser and take a screenshot”) is competing for attention with the task description, the conversation history, and whatever the model just generated. In practice, the early steps that feel like natural prerequisites (install, build) get executed, and the later steps that require more effort (browser validation, login testing, documentation) get dropped. 

**The model optimizes for plausible completion, not thoroughness.** From the model’s perspective, “I installed dependencies, ran the build, 

and verified it compiles - setup complete!” is a perfectly coherent, confident, and plausible response. It reads like a reasonable completion of the task. The model has no internal mechanism that says “wait, I only addressed 3 of 12 points.” It doesn’t count. It doesn’t track coverage. It generates what sounds right. 

**Instruction-following degrades under cognitive load.** When the task itself is complex - navigating a large codebase, starting Docker services, debugging a migration - the model spends most of its reasoning capacity on the immediate problem. The system prompt fades into background context. The agent isn’t deliberately ignoring your instructions; it’s genuinely focused on the hard part of the task and has lost track of the procedural checklist it was supposed to follow. 

**Agents satisfice, they don’t optimize.** Herbert Simon’s concept applies perfectly: the model finds a response that is “good enough” and stops. Starting a dev server, opening a browser, taking screenshots, attempting login, navigating pages, and writing three documentation files is expensive and difficult. Reporting a successful build is cheap and sufficient-sounding. The model takes the satisficing path every time unless something forces it not to. 

This is why writing better prompts has diminishing returns. You’re fighting against how the model fundamentally works. No amount of bold text, capital letters, or threatening language in a system prompt changes the underlying completion dynamics. The model will still predict the most plausible next token, and “done after 3 steps” is always more plausible than “done after 12 steps.” 

## **The structural solution** 

If you can’t make the model follow all 12 steps from a single prompt, the answer is: **don’t give it 12 steps in a single prompt.** Give it one step. When it finishes that step, give it the next one. Make each step a separate, trackable task with a dependency on the previous one. Make 

“done” unambiguous for each individual task. Make skipping structurally impossible. 

This is what a dependency-aware task graph does. It’s not a better prompt. It’s a different architecture. 

## **What Goes Wrong Without Task Decomposition** 

In an OpenClaw setup with multiple agents - an orchestrator that delegates to specialized subagents for design, implementation, review, QA, and environment setup - we observed these failure patterns repeatedly: 

## **1. The Shortcut Agent** 

A subagent tasked with deploying and validating a repository locally would: 

- Install npm packages ✅ 

- Run the build ✅ 

- Run lint ✅ 

- Report “Setup Complete” ✅ 

What it was supposed to also do: 

- Start the database via Docker Compose ❌ 

- Run migrations and seed data ❌ 

- Start the dev server ❌ 

- Open the app in a real browser ❌ 

- Attempt login ❌ 

- Navigate key user flows ❌ 

- Take screenshots as evidence ❌ 

## Write a runbook for other agents ❌ 

The agent’s system prompt had explicit instructions for all of these. It ignored them because “set up this repo” left room for interpretation, and the path of least resistance was build + lint + done. 

## **2. The Rubber Stamp Reviewer** 

A review agent tasked with “review this diff before PR” would return “PASS - code looks good” after what appeared to be a cursory glance. No edge case analysis. No migration safety check. No verification that error handling paths were covered. The system prompt said to check all of these. The agent checked none of them because the task was “review this” and “PASS” was a valid response. 

## **3. The Invisible Dependency** 

An orchestrator would spawn an implementation agent before the design agent had finished. Not because it was deliberately ignoring the dependency, but because it was managing state in a flat JSON file and the “design complete” flag was ambiguous. Was the design posted to the issue? Was it approved? The JSON didn’t track dependencies - just statuses. The orchestrator guessed, and guessed wrong. 

## **4. The Polling Tax** 

To compensate for not knowing when subagents finished, the orchestrator polled them every 30 seconds. “What’s your status?” The subagent paused its actual work, generated a status update, and resumed. For a task that took 10 minutes, the subagent spent 30% of its context window on status reports. Expensive, slow, and counterproductive. 

## **5. The Lost Handoff** 

Agent A completed work that Agent B needed to continue. The handoff was a free-text message: “Design is done, here’s the summary.” Agent B 

received it, interpreted it differently, and started implementation with the wrong assumptions. There was no structured record of what A actually decided, what was considered and rejected, or what the evidence was. 

## **Enter Beads** 

Beads (bd) is a distributed graph issue tracker designed for AI agents, built on Dolt (a version-controlled SQL database). It replaces flat task lists with a dependency-aware graph structure. 

The key features that matter for agent orchestration: 

**Dependency graph.** Tasks can block other tasks. If Task B depends on Task A, bd ready will not show Task B until Task A is closed. The agent literally cannot skip ahead - the tool won’t surface the next task. 

**Atomic claim/close operations.** bd update <id> --claim atomically assigns the task and marks it in-progress. bd close <id> --reason “...” requires a reason string - the agent’s proof of work. No silent “done” without evidence. 

**Hierarchical IDs.** An epic proj-a3f8 has subtasks proj-a3f8.1, proja3f8.2, etc. Subtasks can have their own subtasks. The hierarchy is visible and navigable. 

**JSON output.** Every command supports --json for programmatic parsing. Agents query bd ready --json to find their work, not by reading prose instructions. 

**Audit trail.** Every state change is versioned. You can see when a task was created, claimed, and closed, and by whom. Status changes don’t overwrite - they append. 

**Zero-conflict concurrency.** Hash-based IDs and Dolt’s cell-level merge mean multiple agents can work on the same task graph without merge 

conflicts. 

## **How This Changes Agent Behavior** 

The core insight is this: **a single vague task gives the agent room to decide what “done” means. A sequence of atomic tasks with dependencies removes that room.** 

## **Before Beads** 

Orchestrator → Agent: “Deploy and validate the payments-api repository” 

Agent: *reads system prompt* *does 3 of 12 steps* “Setup complete!” 

## **After Beads** 

Orchestrator creates task graph: 

proj-a3f8       “Deploy & validate: payments-api”               (epic) proj-a3f8.1     “Identify stack, deps, and services” proj-a3f8.2     “Discover and document env vars”                (blocked by .1� proj-a3f8.3     “Start local services (docker/db/cache)”        (blocked by .2� proj-a3f8.4     “Run migrations + seed data”                    (blocked by .3� proj-a3f8.5     “Start dev server, verify on port”              (blocked by .4� proj-a3f8.6     “Open browser, screenshot homepage”             (blocked by .5� proj-a3f8.7     “Attempt login, screenshot post-login”          (blocked by .6� proj-a3f8.8     “Navigate 3�5 key pages, screenshot each”       (blocked by .7� proj-a3f8.9     “Run tests, record results”                     (blocked by .5� proj-a3f8.10    “Write setup runbook”                           (blocked by .8, .9� proj-a3f8.11    “Write machine-readable manifest”               (blocked by .10� proj-a3f8.12    “Write verification report with evidence”       (blocked by .10� 

Orchestrator → Agent: “Your tasks are in Beads. Run bd ready to start.” Agent: bd ready → sees proj-a3f8.1 (only unblocked task) Agent: bd update proj-a3f8.1 --claim 

Agent: *does reconnaissance* 

Agent: bd close proj-a3f8.1 --reason “Next.js 15 + Supabase + PostgreSQL + 173 migrations” 

Agent: bd ready → sees proj-a3f8.2 (now unblocked) 

...continues through all 12 steps... 

The agent can’t skip step 6 (browser screenshot) because step 7 (login screenshot) is blocked by it. And it can’t close step 6 without a reason string that the orchestrator can audit. The structural enforcement is in the tool, not in the prompt. 

## **Patterns That Work** 

## **Pattern 1� Decompose Before Spawning** 

The orchestrator must break every task into atomic subtasks _before_ handing work to a subagent. This is the single most important pattern. If the orchestrator sends a single task, the subagent will take shortcuts. If it sends a decomposed graph, the subagent follows the graph. 

The orchestrator’s job shifts from “tell the agent what to do” to “define the dependency graph of what done looks like.” The subagent’s job shifts from “interpret what I should do” to “claim, execute, close, next.” 

## **Pattern 2� Evidence in Close Reasons** 

Every bd close requires a reason string. This is the agent’s proof of work. Enforce that reasons must be specific: 

Bad: “done” 

Bad: “completed setup” 

Good: “Dev server running on port 3000, screenshot saved to artifacts/screenshots/01-homepage.png” 

Good: “Design posted to issue, 3 subtasks proposed, PR split recommended” 

The close reason is what the next agent in the dependency chain reads for context. Vague reasons create vague handoffs. 

## **Pattern 3� Replace Polling with Graph Queries** 

Instead of polling subagents every 30 seconds, the orchestrator checks the Beads graph on its regular heartbeat cycle: 

# What’s currently being worked on? bd list --status in_progress --json 

# What’s unblocked and waiting? bd ready --json 

# Is anything stuck? (in_progress for too long) 

bd list --status in_progress --json | filter by claim_time > 30min 

This is zero-cost between heartbeats. The subagent works uninterrupted. The orchestrator sees progress without asking. 

## **Pattern 4� One Graph Per Tier, Not Per Repo** 

In a multi-repo setup where the orchestrator manages work across many repositories, use a single Beads database. This gives the orchestrator cross-repo visibility - it can see that Agent A is working on repo X while Agent B is blocked on repo Y, and make scheduling decisions accordingly. 

The alternative (one Beads DB per repo) creates visibility silos where the orchestrator can’t see the full picture. 

## **Pattern 5� Template the Decomposition** 

For recurring task types, define standard decomposition templates. The orchestrator applies the template and adjusts for the specific case rather than inventing the subtask list from scratch each time. 

**Setup template** �12 subtasks): reconnaissance → env vars → services → migrations → dev server → browser → login → navigation → tests → runbook → manifest → results 

**Feature implementation template** �5 subtasks): design → implement → self-review → QA evidence → open PR 

**Bug fix template** �4 subtasks): reproduce → fix → verify → open PR 

Templates make decomposition fast and consistent. The orchestrator’s job is to pick the right template and fill in the specifics, not to reinvent the task graph every time. 

## **Pattern 6� Blocked Is a Valid State** 

Subagents should mark tasks as blocked rather than silently failing or closing with a fake “done.” A blocked task surfaces in the orchestrator’s dashboard as something that needs human or orchestrator intervention. 

bd update proj-a3f8.7 --status blocked 

# Close reason when eventually resolved: 

bd close proj-a3f8.7 --reason “BLOCKED� OAuth login requires CLIENT_ID not in .env.example. Blocker type: missing_secret” 

This is better than the subagent inventing credentials, faking a login, or silently skipping the step. 

## **Setup Runbook** 

## **Prerequisites** 

An OpenClaw instance with agents configured 

Node.js (for bd CLI� 

Homebrew (for Dolt on macOS� 

## **Step 1� Install Beads and Dolt** 

# SSH into your OpenClaw server ssh your-openclaw-server 

# Install Dolt (database backend) 

brew install dolt 

# Install Beads 

npm install -g @beads/bd 

# Verify bd --version dolt version 

## **Step 2� Initialize Beads in the Orchestrator’s Workspace** 

# Navigate to your orchestrator agent’s workspace 

cd ~/.openclaw/agents/your-orchestrator/ 

# Initialize in stealth mode (no git commits to the workspace) bd init --stealth 

This creates a .beads/ directory with a Dolt database. The issue prefix will be derived from the directory name (e.g., if your orchestrator directory is mybot/, issues will be mybot-a3f8, mybot-a3f8.1, etc.). 

## **Step 3� Export BEADS_DIR in Your Gateway Start Script** 

Add this to your gateway start script so all agents in the tier inherit access: 

# Beads task tracker (shared across all agents in this tier) 

export BEADS_DIR�”$HOME/.openclaw/agents/your-orchestrator/.beads” 

Restart the gateway to pick up the new env var. 

## **Step 4� Update the Orchestrator’s TOOLS.md** 

Add the full Beads command reference and the mandatory decomposition protocol. The orchestrator needs to know: 

-  How to create epics and subtasks 

-  How to set dependencies 

-  How to assign tasks to agents 

-  The decomposition templates for each task type 

-  The rule: **never spawn a subagent without first creating the task graph** 

Key commands for the orchestrator: 

# Create an epic for a GitHub issue 

bd create “repo-name#123� Feature title” -p 1 -t epic 

# Create subtasks under it 

bd create “Design proposal” --parent proj-a3f8 --assignee design-agent bd create “Implementation” --parent proj-a3f8 

- # Set dependencies (implementation blocked by design) 

bd dep add proj-a3f8.2 proj-a3f8.1 

# Check progress 

bd ready --json bd list --status in_progress --json bd dep tree proj-a3f8 

## **Step 5� Update Subagent TOOLS.md Files** 

Each subagent needs the claim/close protocol. Add this to every subagent’s TOOLS.md: 

## **## Beads Task Tracker** 

Your tasks are tracked in Beads via $BEADS_DIR. 

## **### Workflow** 

1. `b ready --json`  find your unblocked tasks 

2. `b update <task-id> --claim`  claim it 

3. Do the work 

4. `b close <task-id> --reason “<evidence>”`  close with proof 

5. `b ready --json`  next task 

## **### Rules** 

- Never skip a task. Dependencies enforce ordering. 

- Never close without completing. The reason string is your proof. 

- Never use vague reasons. Be specific: ports, filenames, counts. 

- If blocked, update status: `bd update <id> --status blocked` 

## **Step 6� Update the Orchestrator’s Spawn Protocol** 

When the orchestrator spawns a subagent, include this in the task message: 

Your tasks are tracked in Beads. Run `bd ready --json` to see your current unblocked tasks. 

For each task: 

1. `bd update <task-id> --claim` to claim it 

2. Do the work 

3. `bd close <task-id> --reason “<what you did + evidence>”` to close it 

4. Run `bd ready --json` again for your next task 

Do NOT skip tasks. Do NOT close a task without completing it. 

## **Step 7� Test the Full Loop** 

Create a test epic manually and verify the round trip: 

# As orchestrator: create a small task graph 

bd create “Test: verify agent loop” -p 2 -t epic 

# Note the ID that bd returns (e.g., proj-a1b2�, then use it below: 

bd create “Step 1� read a file” --parent proj-a1b2 

bd create “Step 2� write a summary” --parent proj-a1b2 

bd dep add proj-a1b2.2 proj-a1b2.1 

# Verify only step 1 is ready 

bd ready   # Should show only step 1 

# Simulate agent claiming and closing 

bd update proj-a1b2.1 --claim 

bd close proj-a1b2.1 --reason “Read file: 42 lines, Node.js project” 

# Verify step 2 is now ready 

bd ready   # Should show step 2 

# Clean up 

bd close proj-a1b2.2 --reason “Test complete” 

## **Step 8� Monitor via Heartbeats** 

Add Beads status checks to your orchestrator’s heartbeat routine: 

- # What’s in progress? 

bd list --status in_progress --json 

- # What’s ready but unclaimed? 

bd ready --json 

# Full view of all open work 

bd list --status open --json 

Flag anything that’s been in_progress for longer than expected as a potential stuck agent. 

## **What Changes and What Doesn’t** 

## **Changes** 

## **Stays the Same** 

- Agent identities and system prompts 

- Model and provider configuration 

- Channel integrations �Telegram, Slack, Google Chat, etc.) 

- Your existing git workflow and branch isolation 

- Deterministic scripts and automation 

- Your issue tracker �GitHub, Linear, Jira, etc.) remains the source of truth for issues - Beads tracks the agent’s work decomposition, not the issue itself 

## **The Deeper Point** 

The problem with multi-agent systems isn’t that agents are lazy or that models are bad. It’s that most orchestration gives agents too much interpretive latitude. A well-written system prompt is necessary but not sufficient - it tells the agent what to do, but doesn’t structurally prevent it from deciding which parts are optional. 

Beads doesn’t make agents smarter. It makes the definition of “done” explicit, atomic, and dependency-ordered. The agent’s job shrinks from 

“figure out what to do and do all of it” to “do this one small thing and prove you did it, then ask what’s next.” 

That’s a fundamentally different contract. And it’s the difference between agents that consistently deliver and agents that consistently cut corners. 

Thanks for reading Trilogy AI Center of Excellence! Subscribe for free to receive new posts and support my work. 

**==> picture [60 x 9] intentionally omitted <==**

**----- Start of picture text -----**<br>
Subscribed<br>**----- End of picture text -----**<br>



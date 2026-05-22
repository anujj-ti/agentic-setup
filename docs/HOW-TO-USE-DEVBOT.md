# How to Give DevBot Work

DevBot watches your GitHub repos and autonomously picks up, works, and closes issues.
You don't need to delegate via Telegram — just tag the issue.

---

## Give DevBot an issue in 2 steps

**Step 1 — Tag the issue as safe for the agent:**
```
Label: automation:safe
```

**Step 2 — Tag the effort size:**
```
Label: e1   (small — under 1 hour)
Label: e2   (medium — 1-2 hours)
Label: e3   (larger — half day)
```

That's it. DevBot picks it up within 5 minutes, assigns itself, and starts working.

---

## What DevBot does after you tag it

1. Assigns itself (`echosysbot`) and adds `status:in-progress`
2. Creates a branch tied to the issue
3. Works through the task (design → implement → self-review → PR)
4. Opens a draft PR with `Resolves #N` in the body
5. Sets auto-merge — PR merges when CI passes
6. Issue closes automatically when PR merges

---

## What the labels mean

| Label | Meaning |
|-------|---------|
| `automation:safe` | ✅ Agent is allowed to pick this up |
| `e1` | Small task (< 1 hour) |
| `e2` | Medium task (1-2 hours) |
| `e3` | Larger task (half day) |
| `status:in-progress` | 🤖 Agent is working this — don't touch |

---

## To stop DevBot on an issue

Remove the `automation:safe` label or unassign `echosysbot`.
DevBot will not pick it up again until you re-tag it.

---

## To check what DevBot is working on

```
gh issue list --assignee echosysbot --state open
```

Or ask via Telegram: *"What are you working on right now?"*

---

## Issues DevBot will NOT touch

- Issues without `automation:safe` label
- Issues already assigned to someone else
- Issues tagged `automation:hold`
- PRs, discussions, drafts

---

*DevBot runs on a 5-minute poll cycle via launchd. It logs every decision to Notion before acting.*

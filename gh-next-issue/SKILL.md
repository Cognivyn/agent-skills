---
name: gh-next-issue
description: >-
  Pick the next GitHub issue to work on in the current repository. Use when
  the user asks what to work on next, to pick a task, choose an issue, or
  start the next item from the backlog or a GitHub Project. Ranks open issues
  by project status/priority fields when available, falls back to labels and
  milestones, presents candidates for confirmation, and can create a branch
  and self-assign on approval. Operates on the current working repository.
---

# gh-next-issue

Select the next issue to work on from the current repository's backlog, using
GitHub Project fields when configured and label/milestone conventions
otherwise. Runs against the current working repository - never hardcode a repo
path.

## When to use

- User asks "what should I work on next", "pick the next issue", "what's next",
  or wants to start the next backlog item.
- User wants to self-assign and branch for the next available issue.

## Workflow

### 1. Detect the repository and gather open issues

    gh repo view --json name,owner          # confirm current repo
    gh issue list --state open \
      --json number,title,labels,assignees,milestone,createdAt \
      --limit 50

If the list is empty, report that there are no open issues and stop - do not
invent work.

### 2. Check for a linked GitHub Project (optional)

If a project is configured for the repo or user, query item ordering. See the
`gh-project` skill for project discovery and the `project` scope requirement.
When project data is available, prefer its Status/Priority fields over local
heuristics. When it is unavailable or ambiguous, say so and continue with
step 3 - never block on project access.

### 3. Rank candidates

Apply these signals in order, and state the reasoning to the user:

1. Project Status field (e.g. Todo/Ready) and Priority field, when available.
2. Milestone proximity and due dates.
3. Existing repo label conventions - read `gh label list` and recent closed
   issues (`gh issue list --state closed --limit 10`) to learn what "ready"
   looks like here. Do NOT invent label meanings.
4. Unassigned issues before assigned ones; smaller/older issues as a tiebreak
   are reasonable defaults, but explain them.

Filter out issues that are clearly blocked: body contains "blocked by",
open sub-issues all incomplete, or assignee is someone else unless the user
asks to pick up others' work.

### 4. Present candidates and confirm

Show the top 3-5 candidates with number, title, and why each ranks where it
does. Let the user pick - do not auto-select unless they asked for an
unattended pick, in which case choose the top-ranked and say why.

### 5. On selection, set up work (only after confirmation)

    gh issue view <number>                  # read full context first
    gh issue edit <number> --add-assignee @me   # only if user wants assignment
    git checkout -b <branch-name>           # branch from default branch

Branch naming: follow the repo's existing convention - check
`git branch -a` and recent merged branches before inventing one. Common safe
default: `issue-<number>-<slug>`.

### 6. Report

Summarize: issue number, title, URL, branch created, assignee status. Remind
the user the issue is ready to implement and that `gh-task-complete` closes
the loop when done.

## Anti-patterns

- Do not create issues here - that is `gh-issue-create` / `gh-epic-issue`.
- Do not close or edit issue content beyond assignment.
- Do not assume the highest issue number is the priority.
- Do not hardcode repository paths; work from the current directory.
- Do not assign or branch without user confirmation of the selected issue.

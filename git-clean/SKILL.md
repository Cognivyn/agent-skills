---
name: git-clean
description: >-
  Safely synchronize a local main branch with origin by checking for local
  changes, switching to main, pruning stale remote-tracking branches, and
  rebasing from origin/main. Use when the user asks to clean, sync, refresh,
  or update a repository's main branch without losing local work.
---

# git-clean

Synchronize the local `main` branch with `origin` without silently discarding
local work. Follow this order exactly.

## Workflow

### 1. Check the working tree first

Run this before any checkout, fetch, pull, or stash:

```bash
git status --porcelain
```

- Empty output: continue.
- Non-empty output: run `git status --short`, list the affected files, and
  stop. Ask the user to choose **Stash**, **Commit**, or **Abort**.
  - **Stash**: run `git stash push -u -m "git-clean auto-stash"`, remember that
    an auto-stash exists, and continue. Restore it only at the end with
    `git stash pop`; report any restore conflict and do not resolve it.
  - **Commit**: stop and ask the user to stage and commit, then rerun this
    workflow.
  - **Abort**: make no further changes and report cancellation.

Do not checkout, fetch, or pull from a dirty tree unless the user selected
**Stash** and the stash command succeeded.

### 2. Confirm the current branch

Run:

```bash
git branch --show-current
```

Capture the branch for the final report. If no branch is printed, stop because
HEAD is detached; ask for explicit intent before checking out `main`. If the
branch is a feature branch, note that its commits remain preserved when
switching to `main`.

### 3. Switch to `main`

If the current branch is not `main`, run:

```bash
git checkout main
```

If checkout fails, stop. Do not force checkout or discard changes.

### 4. Prune stale remotes

Run:

```bash
git fetch -p
```

Capture any `pruning` lines. Report `nothing to prune` when none appear.

### 5. Rebase-pull `main`

Run:

```bash
git pull origin main --rebase
```

Report whether `main` was already up to date or how many commits were
rebased. If the command fails, stop and report the error; do not retry
 destructively.

### 6. Check for conflicts and final state

Run:

```bash
git status --porcelain
git status -sb
git log -1 --pretty=format:'%h %s'
```

If output indicates `REBASE`, `UU `, or other unmerged paths, stop immediately
and report that manual conflict resolution is required. Do not run
`git rebase --continue`, `git rebase --abort`, reset, or auto-resolve files.

If an auto-stash was used, run `git stash pop` only after the sync and conflict
check, then run `git status -sb` again. If stash restoration conflicts, stop
without resolving it and distinguish the restored-work conflict from sync
status.

## Required report

For a completed sync, use:

```text
## git-clean

**Branch**: main (was: <previous-branch>)
**Fetched**: pruned <list> / nothing to prune
**Pull**: up to date / rebased N commit(s)
**HEAD**: <short-sha> <subject>

<git status -sb output>
```

For cancellation or a stop condition, state the reason, identify preserved or
stashed changes, and state the next action. Never claim success without the
final status and HEAD checks.

## Safety rules

- Never use `git reset --hard`, `git clean`, forced checkout, or destructive
  branch operations.
- Never pull before checking the working tree and current branch.
- Preserve feature branches and their commits.
- Treat rebase and stash-pop conflicts as manual-recovery states.
- Report observed command output, not assumptions.

## Validation

From the parent of the skill directory, run:

```bash
python /home/ubuntu/skills/skill-creator/scripts/quick_validate.py git-clean
```

The skill directory must contain `SKILL.md` and no unused generated template
resources.

## Compatibility and scope

The commands require Git, a configured `origin` remote, and a local `main`
branch. This skill operates only on the current repository; it does not resolve
conflicts, rewrite history, delete branches, or publish changes.

Complete license terms are provided in the repository's `LICENSE.txt`.

---
name: git-clean-local
description: >-
  Delete stale local branches while keeping protected branches intact. Runs a
  dry-run preview first, then requires explicit confirmation before deleting
  branches. Use when the user wants to prune local branches after work has been
  merged, with configurable protected branches and optional pruning of stale
  remote-tracking branches.
---

# git-clean-local

Delete non-protected local branches without losing protected work. Follow this
order exactly. Deleting a branch is destructive: the workflow previews every
deletion and requires explicit confirmation before anything is removed.

## Slash command

OpenCode exposes this skill as `/git-clean-local` through
`.opencode/commands/git-clean-local.md` in this repository. That file is a thin
wrapper: it asks the agent to load this skill and forwards the typed text as
`$ARGUMENTS`. It adds no steps of its own, so the workflow and safety rules
below are authoritative and run unchanged.

Argument handling:

- Arguments are intent for the whole workflow, not a shortcut around it. They
  never authorize deletion without confirmation unless `--force` is given.
- With no arguments, run the workflow with defaults: protected branches
  `main`, `master`, `develop`, dry-run first, confirmation required.
- An unrecognized argument is not a reason to improvise. Ask what the user
  meant, then continue with the unadorned workflow.

Supported arguments:

- `--protected "main,release"` — comma-separated list of branches to keep,
  overriding the defaults.
- `--force` — skip the explicit confirmation step (dangerous; warn the user
  before each deletion).
- `--merged-only` — only delete branches already merged into their upstream
  with `git branch -d`; unmerged branches are reported but not deleted.

A repo-root `.git-clean-local.yml` with a `protected_branches` list can also
override the defaults, for example:

```yaml
protected_branches:
  - main
  - release
```

Command-line `--protected` takes precedence over the config file.

## Workflow

### 1. Parse arguments

Read `$ARGUMENTS` and extract the protected branches list, the `--force` flag,
and the `--merged-only` flag. Default protected branches are `main`, `master`,
`develop`, unless `.git-clean-local.yml` or `--protected` overrides them.

### 2. Check the working tree first

Run this before any fetch or deletion:

```bash
git status --porcelain
```

- Empty output: continue.
- Non-empty output: run `git status --short`, list the affected files, and
  stop. Ask the user to choose **Stash**, **Commit**, or **Abort**.
  - **Stash**: run `git stash push -u -m "git-clean-local auto-stash"`,
    remember that an auto-stash exists, and continue. Restore it only at the
    end with `git stash pop`; report any restore conflict and do not resolve
    it.
  - **Commit**: stop and ask the user to stage and commit, then rerun this
    workflow.
  - **Abort**: make no further changes and report cancellation.

Do not fetch or delete from a dirty tree unless the user selected **Stash** and
the stash command succeeded.

### 3. Confirm the current branch

Run:

```bash
git branch --show-current
```

If nothing is printed, HEAD is detached; stop and ask for explicit intent
before continuing. The current branch is never a deletion candidate; record it
for the final report.

### 4. Prune stale remote-tracking branches

Run:

```bash
git fetch -p
```

Capture any `pruning` lines. Report `nothing to prune` when none appear. If
`git fetch` fails, report the error and continue without pruning.

### 5. List local branches

Run:

```bash
git branch --format='%(refname:short) %(upstream:short)'
```

Treat each line as one local branch. A branch whose upstream field is empty
has no upstream; warn but still allow deletion if not protected.

### 6. Filter protected branches

Remove from the candidate list:

- every branch in the protected list (`main`, `master`, `develop` by default,
  or `--protected` / `.git-clean-local.yml` override),
- the current branch from step 3.

### 7. Dry-run preview and confirmation

Show every remaining branch as a deletion candidate, including whether each is
merged (`git branch --merged` / `--no-merged` status where applicable) and
whether it has an upstream.

If `--merged-only` is set, show only merged branches and mark unmerged ones as
skipped.

Unless `--force` is given, stop after the preview and ask the user to confirm
with an explicit **yes**. Any other answer cancels with no branches deleted.

If there are no candidates, report `nothing to clean` and stop.

### 8. Delete branches

For each confirmed candidate:

- If the branch is merged into its upstream (or `--merged-only`), run:
  ```bash
  git branch -d <branch>
  ```
- If the branch is unmerged and `--force` was given, run:
  ```bash
  git branch -D <branch>
  ```
  Warn that `-D` discards unmerged work before each unmerged deletion.
- If the branch is unmerged and `--force` was not given, report it as skipped
  and do not delete it.

Continue with remaining branches even if one deletion fails; report each
failure.

### 9. Restore stash and report

If an auto-stash was created in step 2, run:

```bash
git stash pop
```

only after deletion completes. Report any restore conflict without resolving
it.

## Required report

For a completed run, use:

```text
## git-clean-local

**Protected**: main, master, develop
**Current branch**: <branch> (never deleted)
**Fetched**: pruned <list> / nothing to prune
**Dry-run**: <N> candidate(s) shown / nothing to clean
**Confirmed**: yes / no
**Deleted**: <list> / none
**Skipped (unmerged)**: <list> / none
**Errors**: <list> / none

<git branch --list output after cleanup>
```

For cancellation or a stop condition, state the reason, identify preserved or
stashed changes, and state the next action. Never claim success without
listing candidates and the deletion outcome.

## Safety rules

- **Never delete the currently checked-out branch.**
- **Never delete protected branches** (default: `main`, `master`, `develop`).
- **Require explicit "yes" confirmation after dry-run** unless `--force` is
  given; warn that `--force` deletes without asking.
- **Abort on uncommitted changes** unless the user chooses Stash, Commit, or
  Abort; never delete from a dirty tree.
- **Distinguish merged (`-d`) from unmerged (`-D`) branches**; `-D` discards
  unmerged work and requires `--force`.
- **Report observed command output, not assumptions.**
- **Stop on detached HEAD** and ask for explicit intent before continuing.

## Validation

From the repository root, run:

```bash
./agent-skills validate git-clean-local
python -m unittest discover -s tests -v
```

The skill directory must contain `SKILL.md` and no unused generated template
resources.

Functional deletion testing (`git branch -d` / `git branch -D`) cannot run in
this repository's bash sandbox because destructive git verbs are blocked;
verify the workflow by reading SKILL.md and confirming command blocks match the
listed git invocations (`git status --porcelain`, `git branch --show-current`,
`git fetch -p`, `git branch --format='%(refname:short) %(upstream:short)'`,
`git branch -d`, `git branch -D`, `git stash push -u -m "git-clean-local auto-stash"`, `git stash pop`).

## Compatibility and scope

Requires Git. Works in any repository with local branches. No external
dependencies beyond Git. Operates only on local branches and local
remote-tracking references; it does not push, rewrite history, or publish
changes. This skill deletes branches — unlike `git-clean`, it is explicitly
destructive, which is why every deletion is previewed and confirmed first.

This skill is distributed under the repository's MIT license.

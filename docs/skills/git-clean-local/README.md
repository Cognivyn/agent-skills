# git-clean-local

`git-clean-local` deletes stale local branches while keeping protected branches
intact (`main`, `master`, `develop` by default). It runs a dry-run preview,
requires explicit confirmation before deleting anything, prunes stale
remote-tracking branches with `git fetch -p`, and aborts on uncommitted
changes unless the user chooses to stash, commit, or abort.

## Use it when

Ask an agent to **run git-clean-local**, **delete stale local branches**, or
**prune local branches after merged work**.

## Safety behavior

The skill never deletes the currently checked-out branch or a protected branch.
A dry-run preview always precedes deletion and requires an explicit yes
confirmation unless `--force` is given. Unmerged branches are deleted only with
`git branch -D` under `--force`; merged branches use `git branch -d`. A dirty
tree requires the user to choose stash, commit-and-rerun, or abort.

See [`../../../git-clean-local/SKILL.md`](../../../git-clean-local/SKILL.md)
for the complete agent workflow, required report format, and command-line
arguments (`--protected`, `--force`, `--merged-only`).

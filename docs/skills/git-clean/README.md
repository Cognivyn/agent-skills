# git-clean

`git-clean` safely synchronizes a local `main` branch with `origin`. It checks
for uncommitted work before changing branches, preserves user changes through
an explicit stash choice, prunes stale remote-tracking branches, rebases from
`origin/main`, and stops for detached HEADs or conflicts.

## Use it when

Ask an agent to **run git-clean**, **safely sync main with origin**, or **refresh
main without losing local work**.

## Safety behavior

The skill never uses `git reset --hard`, `git clean`, forced checkout, or
automatic conflict resolution. A dirty tree requires the user to choose stash,
commit-and-rerun, or abort. Rebase and stash-restore conflicts are reported for
manual recovery.

See [`../../../git-clean/SKILL.md`](../../../git-clean/SKILL.md) for the complete
agent workflow and required report format.

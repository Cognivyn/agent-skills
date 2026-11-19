---
description: Delete stale local branches while keeping protected branches intact
agent: build
---

Load the `git-clean-local` skill with the skill tool, then follow its workflow
exactly as written.

Honor every stop condition in that skill. If the working tree is dirty, HEAD is
detached, or an unmerged branch requires `-D` without `--force`, stop and ask
instead of deleting. Never delete the current branch or a protected branch, and
never run `git branch -D` without explicit confirmation unless `--force` was
given.

Treat the text below as the user's intent for this invocation. Empty means run
the workflow with no extra direction.

$ARGUMENTS

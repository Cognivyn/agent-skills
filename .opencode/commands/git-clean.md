---
description: Safely synchronize the local main branch with origin/main
agent: build
---

Load the `git-clean` skill with the skill tool, then follow its workflow
exactly as written.

Honor every stop condition in that skill. If the working tree is dirty, a
HEAD is detached, or a rebase or stash-restore conflict appears, stop and ask
instead of resolving it. Never use `git reset --hard`, `git clean`, a forced
checkout, or automatic conflict resolution.

Treat the text below as the user's intent for this invocation. Empty means run
the workflow with no extra direction.

$ARGUMENTS
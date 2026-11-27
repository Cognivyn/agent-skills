---
description: Complete a GitHub task - verify, close the issue, update project status
agent: build
---

Load the `gh-task-complete` skill with the skill tool, then follow its
workflow exactly as written.

The skill resolves the target issue from the argument, current branch, or
linked PR, surfaces PR check status, drafts a completion comment for approval
before closing anything, moves the project item to Done when configured, and
only cleans up branches after separate confirmation.

Treat the text below as the issue/PR number, URL, or "current" for branch
resolution. Empty means resolve from the current branch.

$ARGUMENTS

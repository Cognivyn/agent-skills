---
description: Create an epic issue with child issues in the current repository
agent: build
---

Load the `gh-epic-issue` skill with the skill tool, then follow its workflow
exactly as written.

The skill confirms the epic scope and child task list before creating
anything, writes every body to a temp file passed via `--body-file`, creates
the parent before children, links children as native sub-issues when
supported with a task-list fallback, and verifies the result.

Treat the text below as the epic title and source material (plan path or
description). Relative paths resolve against the current working directory.

$ARGUMENTS

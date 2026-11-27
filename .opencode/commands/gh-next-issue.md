---
description: Pick the next GitHub issue to work on in the current repository
agent: build
---

Load the `gh-next-issue` skill with the skill tool, then follow its workflow
exactly as written.

The skill gathers open issues, prefers GitHub Project Status/Priority fields
when configured, ranks candidates with visible reasoning, and presents the top
options for the user to pick. It must not assign issues, create branches, or
start work without explicit confirmation.

Treat the text below as optional hints (labels, milestone, project name).
Empty means rank the whole open backlog.

$ARGUMENTS

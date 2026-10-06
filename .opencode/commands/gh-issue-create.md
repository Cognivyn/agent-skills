---
description: File a GitHub issue in the current repository from a title or plan
agent: build
---

Load the `gh-issue-create` skill with the skill tool, then follow its workflow
exactly as written.

The skill's shell detection is mandatory: detect whether the shell is bash,
Git Bash, or PowerShell before writing the body, and always pass the body with
`--body-file` rather than an inline `--body` string. Reuse only labels that
already exist, verify with `gh issue list`, and never hardcode an absolute
repository path.

Treat the text below as the issue title and optional source plan. Relative
paths resolve against the current working directory. Empty means ask the user
for a title instead of guessing one.

$ARGUMENTS
---
description: Inspect and audit Windows storage volumes, locked NT kernel space, and developer bloat
agent: build
---

Load the `win-disk-diagnostics` skill with the skill tool, then follow its workflow
exactly as written.

Honor every safety rule in that skill: all initial diagnostics must remain strictly
read-only, no files may be deleted without explicit confirmation, and all cleanup
recommendations must be categorized by risk tier.

Treat the text below as the user's intent for this invocation. Empty means run
the default volume health assessment workflow.

$ARGUMENTS

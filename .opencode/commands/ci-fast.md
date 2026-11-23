---
description: Accelerate repository CI to sub-minute turnaround with strict time budgets and no skipped tests
agent: build
---

Load the `ci-fast` skill with the skill tool, then follow its workflow
exactly as written.

Honor every non-negotiable rule in that skill:
- The full test suite must always run before anything reaches main in a merge queue. Selection only narrows PR feedback.
- Never hide failures: zero retries, no widened timeouts, no skipped tests.
- Never check less: lint rules, typecheck strictness, and required checks only stay or grow.
- Any external service requiring a secret, account, or billed cost must be presented as a single itemized monthly cost list for user confirmation before implementation.

Treat the text below as the user's intent for this invocation. Empty means run
the full phased CI optimization lifecycle.

$ARGUMENTS

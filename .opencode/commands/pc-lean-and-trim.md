---
description: Audits, leans, and trims Windows 11 PC storage safely with mandatory Dry-Run previews and confirmation gates
agent: build
---

Load the `pc-lean-and-trim` skill with the skill tool, then follow its workflow
exactly as written.

Honor every safety rule in that skill:
- All initial scans must remain 100% strictly read-only (`-DryRun`).
- An itemized Dry-Run report must be generated and presented in chat before any file is touched.
- Explicit user confirmation must be obtained before invoking any execution switch.
- Hard-coded Forbidden Zone Sentinels and strict whitelists must be respected at all times.

Treat the text below as the user's intent for this invocation. Empty means run
the default safe dry-run storage assessment.

$ARGUMENTS

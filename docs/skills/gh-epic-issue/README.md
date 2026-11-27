# gh-epic-issue

`gh-epic-issue` creates a parent "epic" GitHub issue plus its child issues in the current repository, then links them together - preferably as native sub-issues via the GitHub GraphQL API, with a markdown task-list fallback in the epic body.

## Use it when

Ask an agent to **create an epic**, a **parent issue**, a **feature broken into tasks**, or a **tracked multi-issue plan**.

## Installation

Install via the CLI (`./agent-skills add gh-epic-issue`) or manually link or copy the skill directory (see [Installation without the CLI](../../../README.md#installation-without-the-cli)). Requires the GitHub CLI (`gh`) installed and authenticated. Issue bodies follow the shell-detection and `--body-file` rules documented in [`gh-issue-create`](../gh-issue-create/README.md).

## Safety behavior

The skill confirms the child task list before creating anything, creates the parent before children so every child can reference it, verifies sub-issue linkage or the task-list fallback, and reuses only existing repository labels.

See [`SKILL.md`](../../../gh-epic-issue/SKILL.md) for the authoritative workflow.

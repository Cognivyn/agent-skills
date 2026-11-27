# gh-project

`gh-project` lets an agent read and update GitHub Projects v2 boards via the `gh` CLI: list items, add issues or PRs, and move items between Status or Priority options. It auto-detects the project from the current repository's owner and asks the user when the choice is ambiguous.

## Use it when

Ask an agent to **view the project board**, **add an issue to a project**, **move an item to Done/In Progress**, **set priority**, or **list project items**.

## Installation

Install via the CLI (`./agent-skills add gh-project`) or manually link or copy the skill directory (see [Installation without the CLI](../../../README.md#installation-without-the-cli)). Requires the GitHub CLI (`gh`) authenticated with the `project` scope (`gh auth refresh -s project`).

## Safety behavior

The skill resolves project, field, and option IDs fresh on every invocation instead of hardcoding them, reports scope errors with the exact `gh auth refresh` fix, and requires explicit user confirmation showing the exact change before any project mutation.

See [`SKILL.md`](../../../gh-project/SKILL.md) for the authoritative workflow.

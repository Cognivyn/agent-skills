# gh-task-complete

`gh-task-complete` runs the task-completion workflow for a GitHub issue: resolve the target issue or PR, surface check status, draft a completion summary for approval, close the issue with that comment, move the project item to Done when a project is configured, and optionally clean up the merged branch.

## Use it when

Ask an agent to **close the issue**, **complete the task**, **wrap up**, or **finish the task-completion workflow** after work is done.

## Installation

Install via the CLI (`./agent-skills add gh-task-complete`) or manually link or copy the skill directory (see [Installation without the CLI](../../../README.md#installation-without-the-cli)). Requires the GitHub CLI (`gh`) installed and authenticated; project updates additionally need the `project` scope (see [`gh-project`](../gh-project/README.md)).

## Safety behavior

The skill never closes an issue without showing the completion comment and getting approval, surfaces failing or pending PR checks before closing, and only deletes branches with safe flags after separate confirmation - never force-pushing or deleting unmerged work.

See [`SKILL.md`](../../../gh-task-complete/SKILL.md) for the authoritative workflow.

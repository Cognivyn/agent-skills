# gh-next-issue

`gh-next-issue` helps an agent pick the next GitHub issue to work on in the current repository. It gathers open issues, prefers GitHub Project Status/Priority fields when a project is configured, falls back to label and milestone conventions observed in the repo, and presents ranked candidates for the user to confirm before any branch or assignment is created.

## Use it when

Ask an agent **what to work on next**, to **pick the next issue**, or to **start the next backlog item** with a branch and self-assignment.

## Installation

Install via the CLI (`./agent-skills add gh-next-issue`) or manually link or copy the skill directory (see [Installation without the CLI](../../../README.md#installation-without-the-cli)). Requires the GitHub CLI (`gh`) installed and authenticated.

## Safety behavior

The skill never assigns issues, creates branches, or starts work without user confirmation of the selected issue. It reports empty backlogs instead of inventing work, and it surfaces blocked or already-assigned issues rather than silently picking them.

See [`SKILL.md`](../../../gh-next-issue/SKILL.md) for the authoritative workflow.

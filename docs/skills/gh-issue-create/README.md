# gh-issue-create

`gh-issue-create` creates GitHub issues reliably using the GitHub CLI (`gh`), avoiding common body-passing and shell escaping pitfalls that cause silent failures. It operates against the current working repository without requiring hardcoded repository paths.

## Use it when

Ask an agent to **create a GitHub issue**, **file a bug report or feature request**, or **turn a Markdown plan or checklist into a tracked issue**.

## Installation

Install via the CLI (`./agent-skills add gh-issue-create`) or manually link or copy the skill directory (see [Installation without the CLI](../../../README.md#installation-without-the-cli)). Before first use, authenticate the GitHub CLI with `gh auth login`.

## Safety behavior

The skill detects the running shell environment before choosing a body-writing method to prevent silent failures in PowerShell. It writes issue content to a temporary file passed via `--body-file`, reuses existing repository labels rather than inventing new ones, and verifies issue creation with `gh issue list`.

See [`SKILL.md`](../../../gh-issue-create/SKILL.md) for the authoritative workflow and shell-specific guidance.

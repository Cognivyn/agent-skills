---
name: gh-project
description: >-
  Manage GitHub Projects v2 items for the current repository or owner using
  the gh CLI. Use when the user asks to view, add, or move issues/PRs on a
  project board, change an item's Status or Priority field, list project
  items, or wire project status into issue workflows. Auto-detects the
  relevant project, requires the `project` OAuth scope, resolves field and
  option IDs via gh project field-list, and confirms every mutation. Operates
  on the current working repository.
---

# gh-project

Read and update GitHub Projects v2 boards via `gh project`. All commands run
from the current working directory; the project is auto-detected from the
repo's owner, and the user is asked when the choice is ambiguous.

## When to use

- User asks to see the project board, add an issue/PR to a project, move an
  item between Status columns (Todo/In Progress/Done), set Priority, or list
  what's on a project.

## Workflow

### 1. Confirm repo and auth scope

    gh repo view --json name,owner
    gh auth status

Projects v2 commands need the `project` scope. If `gh project list` fails
with a scope/permission error, instruct the user to run
`gh auth refresh -s project` (interactive - the agent cannot complete the
browser flow) and stop until it succeeds.

### 2. Auto-detect the project

    gh project list --owner <owner> --format json --limit 20

Also check repo-linked projects:

    gh project list --owner <owner> --format json | jq '.projects[] | select(.repo .name?)'

If exactly one project clearly matches the repo, use it. If several match or
none do, list the candidates (number, title, owner) and ask the user which to
use. Capture the project number - all subsequent commands take `--owner` and
the project number.

### 3. Resolve fields and options (needed for writes)

    gh project field-list <number> --owner <owner> --format json

From the JSON, find the Status field (or Priority/etc.) and the option ID for
the desired column. Field IDs and option IDs are opaque strings - never guess
them; always read them fresh because they differ per project.

### 4. Read operations (no confirmation needed)

List items with their field values:

    gh project item-list <number> --owner <owner> --format json --limit 100

Filter client-side for status, assignee, or issue number.

### 5. Write operations (explicit confirmation required)

Add an issue or PR to the project:

    gh project item-add <number> --owner <owner> --url <issue-or-pr-url>

Move an item to a Status/Priority option:

    gh project item-edit --project-id <project-node-id> \
      --id <item-id> --field-id <field-id> \
      --single-select-option-id <option-id>

`--project-id` is the project's GraphQL node ID (from `gh project view
<number> --owner <owner> --format json`), not the project number. `--id` is
the item ID from `item-list`/`item-add` output.

Before any write: state exactly what will change (item, field, from -> to)
and get user confirmation. After the write, re-run `item-list` (or
`item-edit` output) to verify the new value stuck.

## Anti-patterns

- Do not mutate project items without showing the exact change and getting
  confirmation.
- Do not hardcode field IDs, option IDs, or project numbers - resolve them
  per invocation.
- Do not confuse the project number with the project node ID; `item-edit`
  needs the node ID from `gh project view --format json`.
- Do not retry scope errors in a loop; tell the user to run
  `gh auth refresh -s project`.
- Do not hardcode repository paths; derive owner/repo from `gh repo view`.

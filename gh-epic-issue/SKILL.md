---
name: gh-epic-issue
description: >-
  Create an epic GitHub issue with child issues in the current repository.
  Use when the user asks to create an epic, a parent issue, a feature broken
  into tasks, or a tracked multi-issue plan. Writes all bodies to temp files
  and passes them via --body-file (see gh-issue-create for shell pitfalls),
  creates child issues one at a time, links them as native sub-issues via the
  GitHub GraphQL API when supported, and falls back to a markdown task list
  in the epic body. Operates on the current working repository.
---

# gh-epic-issue

Create a parent "epic" issue and its child issues, then link them together.
Body writing follows the same shell-detection and `--body-file` rules as
`gh-issue-create` - read that skill's workflow if shell specifics are
unclear. Never hardcode a repository path.

## When to use

- User asks to create an epic, parent issue, feature breakdown, or a set of
  child tasks under one tracker issue.

## Workflow

### 0. Gather epic scope from the user

An epic needs: title, goal, scope/in-scope and out-of-scope notes, acceptance
criteria, and the list of child tasks (title + short description each). If
the user provides a plan file, use it as the source; otherwise ask for the
child list before writing anything. Confirm the child list explicitly -
each child becomes a real GitHub issue.

### 1. Detect environment and confirm repo conventions

    gh repo view --json name,owner
    gh label list
    gh issue list --state all --limit 10

Detect the shell per `gh-issue-create` (bash heredoc vs pwsh here-string) and
always write bodies to `./gh-epic-*.md` temp files passed with `--body-file`.
Reuse existing labels only; ask before inventing one.

### 2. Create the epic (parent) issue

Write the parent body: goal, scope, acceptance criteria, and a placeholder
child task list (filled in step 4). Create with:

    gh issue create --title "Epic: <title>" --label "<existing-label>" \
      --body-file ./gh-epic-body.md

Capture the issue number/URL from the output.

### 3. Create child issues one at a time

For each child task, write `./gh-child-<slug>.md` (summary + acceptance
criteria + `Part of #<epic-number>`) and run `gh issue create`. Create them
sequentially so a failure stops the batch cleanly instead of leaving an
unknown partial state. Track each created issue number.

### 4. Link children to the parent

Prefer native sub-issues via GraphQL. Resolve node IDs first:

    gh api graphql -f query='query { repository(owner:"<owner>",name:"<repo>") {
      parent: issue(number:<epic>) { id }
      child: issue(number:<child>) { id } } }'

Then add each child:

    gh api graphql -f query='mutation($p:ID!,$c:ID!){
      addSubIssue(input:{issueId:$p,subIssueId:$c}){ issue { number } } }' \
      -f p=<parent-id> -f c=<child-id>

If `addSubIssue` fails (older GitHub Enterprise, permissions), fall back:
update the epic body with a markdown task list linking every child
(`#<num> - title`) using `gh issue edit <epic> --body-file`. Note in the epic
body that children are tracked via the task list.

### 5. Verify and report

    gh issue view <epic-number> --json title,body,url
    gh issue list --state open --limit 20

Report the epic URL, each child URL, which linking method was used, and any
children that failed to link. Clean up temp body files.

## Anti-patterns

- Do not inline multi-line bodies with `--body "..."`; always `--body-file`.
- Do not create children before the parent exists and its number is known.
- Do not invent labels; reuse `gh label list` output.
- Do not claim sub-issue linkage succeeded without verifying - check the epic
  page or the task list fallback actually contains the children.
- Do not hardcode absolute repository paths.

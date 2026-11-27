---
name: gh-task-complete
description: >-
  Complete a GitHub task end to end: verify the work, post a completion
  summary, close the issue, move the project item to Done, and optionally
  clean up the branch. Use when the user says a task/issue/PR is done, asks
  to close out an issue, wrap up work, or finish the task-completion
  workflow. Resolves the target issue from an argument, the current branch,
  or a linked PR; checks PR status when one exists; requires confirmation of
  the closing summary before mutating anything. Operates on the current
  working repository.
---

# gh-task-complete

Close the loop on a GitHub issue: verify, summarize, close, update project
status, and clean up. Works against the current working repository - never
hardcode a repo path.

## When to use

- User says the task is done, asks to close the issue, complete the ticket,
  wrap up, or run the task-completion workflow.
- Finishing work that was tracked by `gh-next-issue` or an epic child.

## Workflow

### 1. Resolve the target

In priority order:

1. Explicit issue/PR number or URL from the user or slash-command argument.
2. Issue linked to the current branch: `gh issue list --state open` plus
   branch-name hints, or `gh pr view --json closingIssuesReferences` when a
   PR exists for the branch.
3. If still ambiguous, ask the user - never guess between multiple issues.

    gh issue view <number> --json number,title,state,body,url
    gh pr view --json number,state,statusCheckRollup,closingIssuesReferences \
      --jq '.' 2>/dev/null || true

If the issue is already closed, report that and stop (unless the user wants
to reopen or add a comment - ask).

### 2. Verify readiness (report, do not block silently)

- If a PR exists: `gh pr checks <pr>` - report pass/fail/pending. Pending or
  failing checks are surfaced to the user; closing the issue anyway requires
  explicit confirmation.
- If no PR: run whatever local verification the repo defines (tests, lint)
  only if the user asks; otherwise note that no automated check was run.
- Confirm the working tree state with `git status` so uncommitted work is not
  forgotten.

### 3. Draft the completion summary and confirm

Draft a closing comment: what was delivered, PR/commit references, test
results, and any follow-ups. Show it to the user and get explicit approval
before posting or closing. The comment is the permanent record - keep it
factual, no emojis unless the repo's issues use them.

### 4. Close and update on approval

    gh issue close <number> --comment "<approved summary>"

Then, if a GitHub Project tracks this repo (see `gh-project`): move the item
to the Done column. Resolve project, item ID, Status field ID, and Done
option ID fresh each time - never reuse cached IDs. Skip project updates
silently-failing: if no project is configured, note that and continue.

### 5. Optional branch cleanup (confirm separately)

Only if the user asks or the branch is merged:

    git branch -d <branch>            # safe delete; -D only with confirmation
    git push origin --delete <branch> # only if remote branch exists and merged

Never force-push, never delete the default branch, never delete unmerged
work without explicit confirmation.

### 6. Report

Issue URL + closed state, comment posted, project status (or "no project"),
branch cleanup result. If any step failed, say which and leave the issue in
its actual state - do not claim success from partial output.

## Anti-patterns

- Do not close an issue without showing the summary comment and getting
  approval.
- Do not ignore failing/pending PR checks; surface them before closing.
- Do not delete branches with `-D` or push deletes without confirmation.
- Do not hardcode project/field/item IDs; resolve via `gh project` commands.
- Do not hardcode repository paths.

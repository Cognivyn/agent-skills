---
name: gh-issue-create
description: >-
  Create GitHub issues from the CLI using the gh tool, robustly handling
  multi-line bodies and PowerShell/Windows shells. Use when the user asks to
  create a GitHub issue, file an issue, open an issue for this, or turn a
  plan/markdown checklist into a tracked GitHub issue. Covers pitfalls around
  gh issue create body passing, label selection, and shell quoting on
  PowerShell (pwsh) and win32. Operates on the current working repository.
---

# gh-issue-create

Create GitHub issues reliably with gh, avoiding the body-passing and shell
pitfalls that cause silent failures. Runs against the current working
repository (where the shell is already located), so never hardcode a repo path.

## When to use

- User asks to create/open/file a GitHub issue for the current repo or from a
  plan/README in the current working directory.
- Turning a markdown checklist or plan (e.g. *-plan.md) into a tracked issue.

## Workflow

### 1. Gather context from the repo (read-only)

Run these from the current working directory so the issue targets the right
repo and matches its conventions:

    gh repo view --json name,owner        # confirm current repo
    gh label list                         # pick an existing label
    gh issue list --state all --limit 10  # avoid duplicates, match style

Do NOT invent labels. Use one that already exists (e.g. enhancement, bug,
documentation). If none fits, ask the user or omit --label.

If you are not already in the target repo, cd into it first (a single cd, never
combined with an assignment):

    cd ./path/to/repo   # relative to current location, no hardcoded absolute path

### 2. Write the body to a temp file - NEVER inline a heredoc

This is the key pitfall. On PowerShell (pwsh) / win32:

- gh issue create with a bash-style heredoc body does NOT work and fails
  silently - the command succeeds with no output and creates nothing.
- cd dir && $body = heredoc fails with "Unexpected token =" because
  cd ... && before an assignment breaks the PowerShell parser.
- The agent's Write/Set-Content file tools may be restricted by permission
  rules, so we write the body from a shell instead.

The safe pattern is always: write the body to a temp file, then pass it via
--body-file. The body file lives in the current directory (e.g.
./gh-issue-body.md) so no absolute path is needed. Clean it up afterward with
`Remove-Item ./gh-issue-body.md` if desired.

#### Bash shell

    # Write body with a bash heredoc (heredoc works in bash, NOT pwsh)
    cat > ./gh-issue-body.md << 'MD'
    ## Summary
    ...markdown body here...
    MD

    # Create from the current working directory
    gh issue create \
      --title "Short descriptive title" \
      --label "enhancement" \
      --body-file ./gh-issue-body.md

#### PowerShell (pwsh) shell

Heredocs do NOT work in pwsh. Use bash to write the body, then call gh
separately with backtick line-continuation:

    # Write the body using a bash sub-shell (heredoc is a bash feature)
    bash -c 'cat > ./gh-issue-body.md << '"'"'MD'"'"'
    ## Summary
    ...markdown body here...
    MD'

    # Create from the current working directory (backtick = pwsh continuation)
    gh issue create `
      --title "Short descriptive title" `
      --label "enhancement" `
      --body-file ./gh-issue-body.md

Do NOT combine cd with a variable assignment. gh resolves the target repo from
the current directory's git remote automatically, so there is no need to cd if
you are already inside the repo - and no need to hardcode an absolute path.

### 3. Verify

    gh issue list --state open --limit 5

If the list is empty after creation, the create silently failed - re-run step 2
using --body-file (the most common fix).

## Anti-patterns (do not do these)

- Do not pass a long multi-line body with --body "..." inline on PowerShell.
- Do not use a bash-style heredoc for the gh body on pwsh.
- Do not prefix an assignment ($x =) with cd dir &&.
- Do not invent label names; reuse existing ones from gh label list.
- Do not assume success from no output - always verify with gh issue list.
- Do not hardcode absolute repo paths (e.g. Z:\... or /home/user/...); use the
  current working directory and relative paths.

## Example (end to end)

    # already in the target repo (current working directory)
    gh label list
    cat > ./gh-issue-body.md << 'MD'
    ## Tasks
    - [ ] Add Dockerfile
    - [ ] Add CI workflow
    MD
    gh issue create --title "Implement runner image" --label "enhancement" --body-file ./gh-issue-body.md
    gh issue list --state open --limit 5
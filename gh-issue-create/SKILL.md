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

### 0. Detect the running environment first

Before choosing a command style, identify the active shell and platform. The
wrong body-writing method is the #1 cause of silent gh issue create failures, so
detection must happen first - do NOT assume bash or pwsh.

Probe the environment with the safest universal check, then confirm the shell:

    # Works on both bash and pwsh; prints the OS and a shell hint
    uname 2>$null; $env:OS 2>$null; (Get-Command gh -ErrorAction SilentlyContinue).Name

Use these signals to classify the environment:

| Signal | Environment |
| --- | --- |
| `$env:PSVersionTable` exists / `PSVersionTable` outputs a version | PowerShell (pwsh / Windows PowerShell) |
| `$SHELL` set and `uname` returns `Linux`/`Darwin` | bash / POSIX shell on Linux or macOS |
| `uname` returns `MINGW*`, `CYGWIN*`, or `MSYS*` | bash-compatible shell on Windows (Git Bash) |
| `bash -c` returns "command not found" / errors | pure-Windows pwsh with no WSL/Git Bash - bash fallback is UNAVAILABLE |

Decision rule - which body-writing method per detected shell:

- **bash / POSIX / Git Bash (Linux, macOS, MINGW/CYGWIN/MSYS):** heredoc with
  `cat > file << 'MD'` is the simplest and works natively. Line-continuation is
  `\`.
- **PowerShell (pwsh) WITH bash available (WSL, Git Bash, or bash on PATH):**
  use a `bash -c '... heredoc ...'` sub-shell to write the body, then call `gh`
  separately. Line-continuation in pwsh is the backtick `` ` ``.
- **Pure-Windows pwsh, NO bash available (no WSL, no Git Bash):** the `bash -c`
  fallback FAILS because bash is not installed. Write the body with a pwsh
  here-string (`@' ... '@`) or `Set-Content`. Line-continuation is the backtick
  `` ` ``.

Note the line-continuation difference explicitly: bash uses a trailing backslash
`\`, while PowerShell uses a trailing backtick `` ` ``. Mixing them up breaks
both shells.

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

This is the key pitfall. Pick the body-writing method that matches the shell you
detected in step 0. The universal rule: always write the body to a temp file,
then pass it via --body-file. The body file lives in the current directory (e.g.
./gh-issue-body.md) so no absolute path is needed. Clean it up afterward with
`Remove-Item ./gh-issue-body.md` (pwsh) or `rm ./gh-issue-body.md` (bash) if
desired.

The agent's own Write/Set-Content file tools may be restricted by permission
rules, so prefer writing the body from a shell using the matching method below.

#### Bash / POSIX / Git Bash

    # Write body with a bash heredoc (heredoc works in bash, NOT pwsh)
    # Line-continuation in bash is the trailing backslash \
    cat > ./gh-issue-body.md << 'MD'
    ## Summary
    ...markdown body here...
    MD

    # Create from the current working directory (backslash = bash continuation)
    gh issue create \
      --title "Short descriptive title" \
      --label "enhancement" \
      --body-file ./gh-issue-body.md

#### PowerShell (pwsh) WITH bash available (WSL / Git Bash / bash on PATH)

Heredocs do NOT work in pwsh, so use a bash sub-shell to write the body, then
call gh separately. Line-continuation in pwsh is the backtick `` ` ``.

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

#### Pure-Windows pwsh, NO bash available (no WSL, no Git Bash)

bash is NOT installed here, so the `bash -c` fallback FAILS. Do not attempt it.
Write the body with a pwsh here-string (`@' ... '@`) or `Set-Content`, then call
gh with backtick line-continuation:

    # Write the body with a pwsh here-string (no bash required)
    @'
    ## Summary
    ...markdown body here...
    '@ | Set-Content -Path ./gh-issue-body.md -Encoding utf8

    # Create from the current working directory (backtick = pwsh continuation)
    gh issue create `
      --title "Short descriptive title" `
      --label "enhancement" `
      --body-file ./gh-issue-body.md

Do NOT combine cd with a variable assignment. On pwsh, `cd dir && $body = ...`
fails with "Unexpected token =" because cd ... && before an assignment breaks
the PowerShell parser. gh resolves the target repo from the current directory's
git remote automatically, so there is no need to cd if you are already inside the
repo - and no need to hardcode an absolute path.

### 3. Verify

    gh issue list --state open --limit 5

If the list is empty after creation, the create silently failed - re-run step 2
using --body-file (the most common fix).

## Anti-patterns (do not do these)

Each pitfall below is tied to the environment that triggers it:

- **All shells:** do not pass a long multi-line body with --body "..." inline -
  it breaks on quoting/escaping and fails silently.
- **pwsh:** do not use a bash-style heredoc for the gh body. Heredocs are a bash
  feature and do not work in PowerShell.
- **Pure-Windows pwsh (no WSL/Git Bash):** do not use the `bash -c '... heredoc
  ...'` fallback - bash is not installed and the command fails. Use a pwsh
  here-string or `Set-Content` instead.
- **pwsh:** do not prefix an assignment ($x =) with cd dir && - it errors with
  "Unexpected token =".
- **All shells:** do not invent label names; reuse existing ones from gh label
  list.
- **All shells:** do not assume success from no output - always verify with gh
  issue list.
- **All shells:** do not hardcode absolute repo paths (e.g. Z:\... or
  /home/user/...); use the current working directory and relative paths.

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
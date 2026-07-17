# gh-issue-create

Create GitHub issues reliably with `gh`, avoiding the body-passing and shell
pitfalls that cause silent failures. Runs against the **current working
repository** (where the shell is already located), so no repo path is
hardcoded.

## What it does

- Creates GitHub issues from the CLI on Windows/pwsh and bash.
- Turns a markdown plan or checklist into a tracked issue.
- Handles the PowerShell pitfall where inline multi-line bodies fail silently.

## When to use

- User asks to create/open/file a GitHub issue for the current repo.
- Turning a markdown checklist or plan (e.g. `*-plan.md`) into a tracked issue.

## Installation

Clone this repo and link the `gh-issue-create` folder into your client's skills
directory (see the [root README](../../README.md#installing-a-skill)).

## Workflow

### 1. Gather context (read-only)

Run from the current working directory:

```bash
gh repo view --json name,owner        # confirm current repo
gh label list                         # pick an existing label
gh issue list --state all --limit 10  # avoid duplicates, match style
```

Do **not** invent labels. Use one that already exists. If none fits, ask the
user or omit `--label`.

### 2. Write the body to a temp file — NEVER inline a heredoc

This is the key pitfall. On PowerShell (pwsh) / win32:

- `gh issue create` with a bash-style heredoc body fails silently.
- `cd dir && $body = heredoc` fails with `Unexpected token =`.

The safe pattern is always: write the body to a temp file, then pass it via
`--body-file`.

#### Bash shell

```bash
cat > ./gh-issue-body.md << 'MD'
## Summary
...markdown body here...
MD

gh issue create \
  --title "Short descriptive title" \
  --label "enhancement" \
  --body-file ./gh-issue-body.md
```

#### PowerShell (pwsh) shell

Heredocs do NOT work in pwsh. Use bash to write the body, then call gh
separately with backtick line-continuation:

```powershell
bash -c 'cat > ./gh-issue-body.md << '"'"'MD'"'"'
## Summary
...markdown body here...
MD'

gh issue create `
  --title "Short descriptive title" `
  --label "enhancement" `
  --body-file ./gh-issue-body.md
```

### 3. Verify

```bash
gh issue list --state open --limit 5
```

If the list is empty after creation, the create silently failed — re-run step 2
using `--body-file`.

## Anti-patterns (do not do these)

- Do not pass a long multi-line body with `--body "..."` inline on PowerShell.
- Do not use a bash-style heredoc for the gh body on pwsh.
- Do not prefix an assignment (`$x =`) with `cd dir &&`.
- Do not invent label names; reuse existing ones from `gh label list`.
- Do not assume success from no output — always verify with `gh issue list`.
- Do not hardcode absolute repo paths; use the current working directory.

## Example (end to end)

```bash
# already in the target repo (current working directory)
gh label list
cat > ./gh-issue-body.md << 'MD'
## Tasks
- [ ] Add Dockerfile
- [ ] Add CI workflow
MD
gh issue create --title "Implement runner image" --label "enhancement" --body-file ./gh-issue-body.md
gh issue list --state open --limit 5
```

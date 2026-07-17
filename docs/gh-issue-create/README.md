# gh-issue-create

Create GitHub issues reliably with `gh`, avoiding the body-passing and shell
pitfalls that cause silent failures. Runs against the **current working
repository** (where the shell is already located), so no repo path is
hardcoded.

## What it does

- Creates GitHub issues from the CLI on Windows/pwsh and bash.
- Turns a markdown plan or checklist into a tracked issue.
- Detects the running shell/environment and picks the correct body-writing
  method, handling the PowerShell pitfall where inline multi-line bodies fail
  silently.

## When to use

- User asks to create/open/file a GitHub issue for the current repo.
- Turning a markdown checklist or plan (e.g. `*-plan.md`) into a tracked issue.

## Installation

Clone this repo and link the `gh-issue-create` folder into your client's skills
directory (see the [root README](../../README.md#installing-a-skill)).

## Workflow

### 0. Detect the running environment first

The wrong body-writing method is the #1 cause of silent `gh issue create`
failures, so detect the shell before choosing a command style. Probe with a
universal check, then confirm the shell:

```bash
# Works on both bash and pwsh; prints the OS and a shell hint
uname 2>$null; $env:OS 2>$null; (Get-Command gh -ErrorAction SilentlyContinue).Name
```

| Signal | Environment |
| --- | --- |
| `$env:PSVersionTable` exists | PowerShell (pwsh / Windows PowerShell) |
| `$SHELL` set and `uname` is `Linux`/`Darwin` | bash / POSIX shell on Linux or macOS |
| `uname` is `MINGW*`, `CYGWIN*`, or `MSYS*` | bash-compatible shell on Windows (Git Bash) |
| `bash -c` errors / not found | pure-Windows pwsh with no WSL/Git Bash — bash fallback is UNAVAILABLE |

Decision rule — which body-writing method per detected shell:

- **bash / POSIX / Git Bash:** heredoc with `cat > file << 'MD'`. Line-continuation is `\`.
- **pwsh WITH bash available (WSL / Git Bash / bash on PATH):** `bash -c '... heredoc ...'` sub-shell to write the body, then `gh` separately. Line-continuation is the backtick `` ` ``.
- **Pure-Windows pwsh, NO bash (no WSL, no Git Bash):** the `bash -c` fallback FAILS because bash is not installed. Write the body with a pwsh here-string (`@' ... '@`) or `Set-Content`. Line-continuation is the backtick `` ` ``.

> bash uses a trailing backslash `\` for line-continuation; PowerShell uses a
> trailing backtick `` ` ``. Mixing them up breaks both shells.

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

Always write the body to a temp file, then pass it via `--body-file`. The body
file lives in the current directory (e.g. `./gh-issue-body.md`) so no absolute
path is needed. Pick the method that matches the shell detected in step 0.

#### Bash / POSIX / Git Bash

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

#### PowerShell (pwsh) WITH bash available (WSL / Git Bash / bash on PATH)

Heredocs do NOT work in pwsh, so use a bash sub-shell to write the body, then
call `gh` separately with backtick line-continuation:

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

#### Pure-Windows pwsh, NO bash available (no WSL, no Git Bash)

bash is NOT installed, so the `bash -c` fallback FAILS. Write the body with a
pwsh here-string, then call `gh` with backtick line-continuation:

```powershell
@'
## Summary
...markdown body here...
'@ | Set-Content -Path ./gh-issue-body.md -Encoding utf8

gh issue create `
  --title "Short descriptive title" `
  --label "enhancement" `
  --body-file ./gh-issue-body.md
```

Do **not** combine `cd` with a variable assignment — on pwsh, `cd dir && $body = ...`
fails with `Unexpected token =`. `gh` resolves the target repo from the current
directory's git remote automatically, so there is no need to `cd` if you are
already inside the repo, and no need to hardcode an absolute path.

### 3. Verify

```bash
gh issue list --state open --limit 5
```

If the list is empty after creation, the create silently failed — re-run step 2
using `--body-file`.

## Anti-patterns (do not do these)

- **All shells:** do not pass a long multi-line body with `--body "..."` inline — it breaks on quoting/escaping and fails silently.
- **pwsh:** do not use a bash-style heredoc for the gh body. Heredocs are a bash feature and do not work in PowerShell.
- **Pure-Windows pwsh (no WSL/Git Bash):** do not use the `bash -c '... heredoc ...'` fallback — bash is not installed and the command fails. Use a pwsh here-string or `Set-Content` instead.
- **pwsh:** do not prefix an assignment (`$x =`) with `cd dir &&`.
- **All shells:** do not invent label names; reuse existing ones from `gh label list`.
- **All shells:** do not assume success from no output — always verify with `gh issue list`.
- **All shells:** do not hardcode absolute repo paths; use the current working directory.

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

# Cognivyn Open Agent Skills

This repository contains open-source skills for Cognivyn agent clients (like Kilo or Claude Code).

## Skills Index

| Skill | Purpose | Trigger | Visibility | Docs |
|-------|---------|---------|------------|------|
| `gh-issue-create` | Create GitHub issues from the CLI robustly on Windows/pwsh | "create a GitHub issue", "file an issue" | Public | [docs/gh-issue-create](./docs/gh-issue-create/README.md) |

See the [docs](./docs) folder for skill-specific documentation.

## Prerequisites

Before using these skills you need:

- The [`gh` CLI](https://cli.github.com/) installed and authenticated (`gh auth login`).
- An agent client that supports skills (e.g. Kilo, Claude Code) with a local skills directory.
- Git, and the target repository cloned locally (skills operate on the current working repository).

## Installing a skill

Skills are discovered by the agent from a **skills directory** — a folder where each
subdirectory contains a `SKILL.md` file. The agent reads the `name` and `description`
frontmatter at the top of `SKILL.md` to learn when the skill applies (its trigger).

Typical skills directory locations:

| Client | Skills directory |
|--------|------------------|
| Kilo | `C:\Users\<you>\.kilocode\skills\` (Windows) / `~/.config/kilo/skills/` (Linux/macOS) |
| Claude Code | `~/.agents/skills/` |

To install a skill, clone this repo and link (or copy) the skill folder into your
skills directory. Linking keeps it in sync with the repo.

### Windows (directory junction)

Run from an elevated (Administrator) PowerShell prompt:

```powershell
mklink /J "$env:USERPROFILE\.agents\skills\gh-issue-create" "Z:\path\to\agent-skills\gh-issue-create"
```

Replace the target path with wherever you cloned this repository. Use the matching
skills directory for your client (see the table above).

### macOS / Linux (symlink)

```bash
ln -s "/path/to/agent-skills/gh-issue-create" "$HOME/.agents/skills/gh-issue-create"
```

### Copy instead of linking (any OS)

If you prefer a standalone copy (no live sync with the repo):

```powershell
# Windows
Copy-Item -Recurse ".\gh-issue-create" "$env:USERPROFILE\.agents\skills\gh-issue-create"
```

```bash
# macOS / Linux
cp -r ./gh-issue-create "$HOME/.agents/skills/gh-issue-create"
```

After installing, restart or reload the agent client so it picks up the new `SKILL.md`.

## How skills are discovered

Each skill lives in its own folder containing a `SKILL.md` with YAML frontmatter:

```markdown
---
name: gh-issue-create
description: >-
  Create GitHub issues from the CLI using the gh tool, robustly handling
  multi-line bodies and PowerShell/Windows shells. Use when the user asks to
  create a GitHub issue, file an issue, open an issue for this, or turn a
  plan/markdown checklist into a tracked GitHub issue.
---
```

The agent matches the `description` (the trigger) against the user's request. When
it fits, the agent follows the workflow documented in the body of the skill.

## Using the gh-issue-create skill

When you ask the agent to "create a GitHub issue", "file an issue", or turn a
markdown plan/checklist into a tracked issue, the skill runs. It works against the
**current working repository** (no hardcoded repo path).

The key thing the skill handles is the PowerShell pitfall: passing a long
multi-line body inline with `--body "..."` on pwsh often fails silently. The safe
pattern is to write the body to a temp file, then pass it with `--body-file`:

```powershell
# pwsh: write the body with a single-quoted here-string (backticks are literal)
$body = @'
## Summary
...
'@
Set-Content -Encoding utf8 ./gh-issue-body.md $body

gh issue create `
  --title "Short descriptive title" `
  --label "enhancement" `
  --body-file ./gh-issue-body.md

# Always verify - no output does NOT mean success
gh issue list --state open --limit 5

# Clean up the temp file
Remove-Item ./gh-issue-body.md
```

On a bash shell the same idea uses a heredoc:

```bash
cat > ./gh-issue-body.md << 'MD'
## Summary
...
MD

gh issue create \
  --title "Short descriptive title" \
  --label "enhancement" \
  --body-file ./gh-issue-body.md

rm ./gh-issue-body.md
```

Pick labels from `gh label list` — do not invent them.

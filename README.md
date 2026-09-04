# Cognivyn Open Agent Skills

Open-source, task-focused skills for agent clients such as [Kilo](https://kilo.ai/) and [Claude Code](https://docs.anthropic.com/en/docs/claude-code). Each skill is a self-contained directory with a `SKILL.md` file that tells an agent when and how to use it.

## Skills at a glance

| Skill | Use it when you want to… | Main requirements | Documentation |
| --- | --- | --- | --- |
| [`gh-issue-create`](./gh-issue-create/) | Create a GitHub issue from the current repository, including a plan or Markdown checklist | GitHub CLI (`gh`) installed and authenticated | [Overview](./docs/gh-issue-create/README.md) · [`SKILL.md`](./gh-issue-create/SKILL.md) |
| [`git-clean`](./git-clean/) | Safely synchronize the local `main` branch with `origin` without losing local work | Git and an `origin` remote | [Overview](./docs/git-clean/README.md) · [`SKILL.md`](./git-clean/SKILL.md) |

The [skill-specific documentation](./docs/) contains concise usage and safety notes. The corresponding `SKILL.md` is the authoritative workflow an agent follows.

## Quick start

1. Clone this repository.
2. Link or copy the skill folder you need into your agent client’s skills directory.
3. Restart or reload the client so it discovers the skill.
4. Ask the agent using language that matches the skill’s trigger, for example:
   - “Create a GitHub issue from this checklist.”
   - “Safely sync `main` with `origin` without losing local work.”

For the GitHub issue skill, authenticate the CLI once before use:

```bash
gh auth login
gh auth status
```

## Installation

Skills are discovered from a **skills directory**. Install an individual skill by cloning this repository and then linking or copying that skill’s folder. Replace `<skill>` with `gh-issue-create` or `git-clean`.

```bash
git clone https://github.com/Cognivyn/agent-skills.git
cd agent-skills
```

### Link on macOS or Linux

```bash
mkdir -p "$HOME/.agents/skills"
ln -s "$PWD/<skill>" "$HOME/.agents/skills/<skill>"
```

### Link on Windows

Run the following from an elevated PowerShell prompt. Update the destination if your client uses a different skills directory:

```powershell
New-Item -ItemType Directory -Force "$env:USERPROFILE\.agents\skills" | Out-Null
cmd /c mklink /J "$env:USERPROFILE\.agents\skills\<skill>" "$PWD\<skill>"
```

### Copy instead of linking

Use a copy when you want an independent installation that does not track repository changes:

```bash
# macOS / Linux
mkdir -p "$HOME/.agents/skills/<skill>"
cp -R "./<skill>/"* "$HOME/.agents/skills/<skill>/"
```

```powershell
# Windows PowerShell
Copy-Item -Recurse -Force ".\<skill>" "$env:USERPROFILE\.agents\skills\<skill>"
```

After installation, restart or reload the agent client. If your client uses a different skills directory, follow that client’s documentation and substitute its path in the commands above.

## How discovery works

Every skill directory contains a `SKILL.md` with YAML frontmatter:

```markdown
---
name: git-clean
description: >-
  Safely synchronize a local main branch with origin ...
---
```

The agent uses the `name` and `description` to decide when the skill applies, then follows the workflow in the body of `SKILL.md`. Keep trigger descriptions specific enough to avoid accidental matches and include the important safety boundaries in the workflow itself.

## Safety and scope

- **`gh-issue-create`** detects the active shell before writing a multi-line issue body. It uses `--body-file`, reuses existing labels, avoids hardcoded repository paths, and verifies the result with `gh issue list`.
- **`git-clean`** checks for local changes before switching branches or fetching. It never uses `git reset --hard`, `git clean`, forced checkout, or automatic conflict resolution. Dirty trees, detached HEADs, rebase conflicts, and stash-restore conflicts stop for explicit user action.

Read each skill’s `SKILL.md` before adapting it for another agent client or workflow.

## Contributing

Contributions are welcome. Add each new skill as its own top-level directory containing a `SKILL.md` with valid YAML frontmatter, concise trigger language, a deterministic workflow, safety rules, and validation instructions. Add a short companion guide under `docs/<skill>/README.md`, then update the skills table above.

Before opening a pull request, run the repository’s skill validator from the repository root:

```bash
python /home/ubuntu/skills/skill-creator/scripts/quick_validate.py <skill>
```

Also verify Markdown links and examples, test shell-specific commands in the environments they target, and confirm that the README describes the current skill inventory.

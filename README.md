# Cognivyn Open Agent Skills

Open-source, task-focused skills for agent clients such as [Kilo](https://kilo.ai/) and [Claude Code](https://docs.anthropic.com/en/docs/claude-code). Each skill is a self-contained directory with a `SKILL.md` file that tells an agent when and how to use it.

## Skills at a glance

| Skill | Use it when you want to… | Main requirements | Documentation |
| --- | --- | --- | --- |
| [`bun-dokploy-infisical`](./bun-dokploy-infisical/) | Generate Bun monorepo Dockerfile and Compose deployment assets for Dokploy, Traefik, and Infisical runtime secret injection | Bun monorepo, Docker Compose, Dokploy, Traefik, and an Infisical Universal Auth machine identity | [Overview](./docs/skills/bun-dokploy-infisical/README.md) · [`SKILL.md`](./bun-dokploy-infisical/SKILL.md) |
| [`gh-issue-create`](./gh-issue-create/) | Create a GitHub issue from the current repository, including a plan or Markdown checklist | GitHub CLI (`gh`) installed and authenticated | [Overview](./docs/skills/gh-issue-create/README.md) · [`SKILL.md`](./gh-issue-create/SKILL.md) |
| [`git-clean`](./git-clean/) | Safely synchronize the local `main` branch with `origin` without losing local work | Git and an `origin` remote | [Overview](./docs/skills/git-clean/README.md) · [`SKILL.md`](./git-clean/SKILL.md) |

The [skill-specific documentation](./docs/skills/) contains concise usage and safety notes. The corresponding `SKILL.md` is the authoritative workflow an agent follows.

## Repository documentation

The repository-wide guidance is organized under [`docs/`](./docs/):

- [Architecture](./docs/architecture.md) explains the package contract and discovery boundaries.
- [Scalability](./docs/scalability.md) explains progressive disclosure and safe catalog growth.
- [Authoring guide](./docs/authoring-guide.md) explains how to create and update skills.
- [Validation](./docs/validation.md) lists local checks and pull-request quality gates.

Skill packages intentionally remain top-level directories because the CLI and supported agent clients discover them by locating `SKILL.md`. Shared policy belongs in `docs/`; skill-specific detail belongs in each package's `references/`, `scripts/`, or `templates/` directory.

## Quick start

1. Clone this repository.
2. Initialize a local skills workspace.
3. List available skills.
4. Add the skill folders you need to your agent client’s skills directory.
5. Restart or reload the client so it discovers the skill.

```bash
./agent-skills init
./agent-skills list
./agent-skills validate
./agent-skills add git-clean
```

For the GitHub issue skill, authenticate the CLI once before use:

```bash
gh auth login
gh auth status
```

## CLI commands

The repository includes a dependency-free Python CLI. Run it from the repository root or any subdirectory.

```text
agent-skills init [--skills-dir PATH]
agent-skills create NAME [--directory PATH]
agent-skills list
agent-skills validate [NAME ...]
agent-skills add NAME [NAME ...] [--link]
agent-skills remove NAME [NAME ...] [--force]
```

### `init`

Creates `.agent-skills/config.json` and `.agent-skills/manifest.json` in the repository and creates the configured skills directory. The default destination is `$HOME/.agents/skills`. Run it repeatedly without changing existing configuration.

### `create`

Creates a new top-level skill directory containing a valid `SKILL.md`. When creating in the repository root, it also creates `docs/skills/<name>/README.md`. Names must use lowercase letters, numbers, and single hyphens, such as `release-notes`.

```bash
./agent-skills create release-notes
```

The command refuses to overwrite an existing skill. Complete the generated trigger description, workflow, safety rules, and validation instructions before committing the skill.

### `list`

Lists repository skills and labels each local skill as `available` or `added`. It also lists skills visible on the local `origin/main` remote-tracking branch. The command does not fetch from the network, so the remote section reflects the most recent local Git fetch. It is read-only and can be used before `init`.

```text
local:
  git-clean       added
  gh-issue-create available
remote (origin/main):
  git-clean
  gh-issue-create
```

If no `origin/main` tracking branch is available, the command reports the remote section as unavailable or empty while still showing local skills.

### `validate`

Checks one named skill or all repository skills when no name is supplied. Validation verifies the `SKILL.md` frontmatter, that the declared skill name matches its directory, and that optional dependencies exist. Dependencies use the supported metadata form:

```markdown
---
name: release-notes
description: >-
  Create release notes from a repository history.
metadata:
  dependencies:
    - git-clean
---
```

The command is read-only and returns a non-zero exit status when any skill is invalid, a dependency is missing, or dependencies form a cycle. It detects malformed or unterminated frontmatter, missing required fields, name mismatches, invalid dependency names, self-dependencies, and circular dependency chains.

### `add`

Copies skills into the initialized skills directory by default. Use `--link` to create a directory symlink when the client and platform support it.

```bash
./agent-skills add gh-issue-create git-clean
./agent-skills add git-clean --link
```

Skills are validated before being added. Existing destinations are never silently overwritten.

### `remove`

Removes only skills recorded in the workspace manifest. If a copied skill contains local modifications, removal stops unless `--force` is provided. Unmanaged directories are never removed.

```bash
./agent-skills remove git-clean
./agent-skills remove git-clean --force
```

`remove` affects only the local added copy or link; it does not delete the source skill from this repository.

## Installation without the CLI

Skills are discovered from a **skills directory**. The CLI above is the recommended workflow. You can also install an individual skill manually by cloning this repository and then linking or copying that skill’s folder.

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
mkdir -p "$HOME/.agents/skills/<skill>"
cp -R "./<skill>/"* "$HOME/.agents/skills/<skill>/"
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
- The CLI validates skills before adding them, tracks added names in `.agent-skills/manifest.json`, and restricts removal to manifest-managed destinations.
- `agent-skills validate` checks frontmatter and `metadata.dependencies` without modifying the repository.

Read each skill’s `SKILL.md` before adapting it for another agent client or workflow.

## Contributing

Contributions are welcome. Read the [authoring guide](./docs/authoring-guide.md) and [validation guide](./docs/validation.md) before making changes. Add each new skill as its own top-level directory containing a `SKILL.md` with valid YAML frontmatter, concise trigger language, a deterministic workflow, safety rules, and validation instructions. Add a short companion guide under `docs/skills/<skill>/README.md`, then update the skills table above.

Create a scaffold with:

```bash
./agent-skills create my-skill
```

Before opening a pull request, run the repository’s skill validator and test suite from the repository root:

```bash
./agent-skills validate
python -m unittest discover -s tests -v
```

Run the CLI test suite and also verify Markdown links and examples, test shell-specific commands in the environments they target, and confirm that the README describes the current skill inventory.

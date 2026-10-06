# Skill Authoring Guide

## Create a package

From the repository root, scaffold a skill with:

```bash
./agent-skills create my-skill
```

Use lowercase letters, numbers, and single hyphens in the name. The command creates a top-level package and a companion guide under `docs/skills/my-skill/`.

A valid package includes:

```text
my-skill/
├── SKILL.md
├── references/   # optional
├── scripts/      # optional
└── templates/    # optional
```

Remove unused resource directories or placeholder files before committing. Do not add a README inside the skill package unless a client integration explicitly requires it; the companion guide belongs under `docs/skills/`.

## Expose a skill as a slash command

A `SKILL.md` never registers a slash command. Skills and commands are separate registries: the model loads a skill through the `skill` tool or an `@skill-id` mention, while a slash command comes from a command file. To offer `/my-skill` in OpenCode, add a wrapper under `.opencode/commands/` at the repository root:

```text
.opencode/commands/my-skill.md
```

Only `.md` files are discovered, and the file path determines the command name, so `my-skill.md` becomes `/my-skill`. Nested paths become slash-separated names such as `/team/review`.

```markdown title=".opencode/commands/my-skill.md"
---
description: One line shown in the command list
agent: build
---

Load the `my-skill` skill with the skill tool, then follow its workflow
exactly as written. Honor every stop condition in that skill.

Treat the text below as the user's intent. Empty means ask rather than assume.

$ARGUMENTS
```

Keep the wrapper thin. It should tell the agent to load the skill and forward `$ARGUMENTS`; it must not restate or extend the workflow, because that creates a second source of truth that drifts from `SKILL.md`. Use `$1`, `$2` for positional arguments only when the skill needs them. Do not put `template` in frontmatter; the body is the template.

Skills must also be installed in the client before a command can load them, for example with `./agent-skills add my-skill`.

## Write `SKILL.md`

Include YAML frontmatter with:

```yaml
---
name: my-skill
description: >-
  Explain what the skill does and when an agent should use it.
---
```

Keep the description specific enough to trigger correctly. Write the body in imperative or infinitive form. Cover the workflow, safety boundaries, required inputs, failure handling, and validation. Keep long or variant-specific material in references and tell the agent when to read each file.

## Write the companion guide

Use `docs/skills/my-skill/README.md` for a short human-facing overview. Link to `../../../my-skill/SKILL.md`, summarize when to use the skill, and call out important safety behavior. Do not maintain a second copy of the complete workflow.

## Update an existing skill

Read the current package, references, companion guide, README catalog, tests, and relevant repository policy before editing. Keep changes focused. If a file moves, search for its old path and update every link and example in the same change.

## Validate before review

Run the repository checks from the root:

```bash
./agent-skills validate
python -m unittest discover -s tests -v
```

Review local Markdown links, shell examples, secret-handling rules, and the final diff before opening a pull request.

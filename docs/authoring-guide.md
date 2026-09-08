# Skill Authoring Guide

## Create a package

From the repository root, scaffold a skill with:

```bash
./agent-skills create my-skill
```

Use lowercase letters, numbers, and single hyphens in the name. The command creates a top-level package and a companion guide under `docs/my-skill/`.

A valid package includes:

```text
my-skill/
├── SKILL.md
├── references/   # optional
├── scripts/      # optional
└── templates/    # optional
```

Remove unused resource directories or placeholder files before committing. Do not add a README inside the skill package unless a client integration explicitly requires it; the companion guide belongs under `docs/`.

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

Use `docs/my-skill/README.md` for a short human-facing overview. Link to `../../my-skill/SKILL.md`, summarize when to use the skill, and call out important safety behavior. Do not maintain a second copy of the complete workflow.

## Update an existing skill

Read the current package, references, companion guide, README catalog, tests, and relevant repository policy before editing. Keep changes focused. If a file moves, search for its old path and update every link and example in the same change.

## Validate before review

Run the repository checks from the root:

```bash
./agent-skills validate
python -m unittest discover -s tests -v
```

Also run the skill-creator validator for each changed skill when available:

```bash
python /home/ubuntu/skills/skill-creator/scripts/quick_validate.py my-skill
```

Review local Markdown links, shell examples, secret-handling rules, and the final diff before opening a pull request.

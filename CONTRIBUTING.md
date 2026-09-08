# Contributing

Thank you for contributing to Cognivyn Open Agent Skills.

## Before editing

Read the [architecture](./docs/architecture.md), [scalability](./docs/scalability.md), and [authoring guide](./docs/authoring-guide.md). Skills remain top-level self-contained packages because that is the repository's discovery contract.

## Add or update a skill

Use the CLI scaffold for new packages:

```bash
./agent-skills create my-skill
```

Keep the required `SKILL.md` concise and place detailed material in `references/`, deterministic helpers in `scripts/`, and reusable assets in `templates/`. Add or update the companion guide under `docs/my-skill/README.md` and the catalog entry in `README.md`.

## Validate

Run the repository validator and test suite:

```bash
./agent-skills validate
python -m unittest discover -s tests -v
```

Run the skill-creator validator for each changed skill when available. Review links, examples, path references, and the final diff. Do not commit secrets or generated local workspace state.

## Pull requests

Keep pull requests focused. Describe the package or documentation changes, explain any compatibility considerations, and list every validation command that was run. If a check could not run, state why.

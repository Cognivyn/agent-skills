# Validation and Review

Validation protects the package contract while allowing the catalog to grow. Run checks from the repository root before opening a pull request.

## Required checks

### Skill validation

```bash
./agent-skills validate
```

This checks every discovered skill's frontmatter, directory/name match, dependency syntax, missing dependencies, self-dependencies, and circular dependencies. Validate a single package during iteration with `./agent-skills validate <skill-name>`.

### CLI regression suite

```bash
python -m unittest discover -s tests -v
```

The suite covers workspace initialization, scaffolding, discovery, installation/removal safety, frontmatter errors, and dependency validation.

### Package-specific validation

Inspect the skill's documented examples and run safe, representative commands where practical. Never use real secrets or paste sensitive command output into a review.

## Documentation checks

Search for stale paths after any move. Confirm that every top-level skill has exactly one `SKILL.md`, every companion guide points to the correct authoritative file, and README tables match the discovered inventory. Review Markdown links and code examples manually when no repository link checker is configured.

## Pull-request gate

A pull request is ready when the required checks pass, the working tree contains only intended changes, no stale paths remain, and the description lists commands that were run. If an environment prevents a check, report the command and reason explicitly rather than claiming success.

# Repository Architecture

## Purpose

`agent-skills` is a catalog of self-contained agent skills plus a small, dependency-free CLI for discovering, validating, and installing them. The repository intentionally keeps skill packages at the top level because the CLI and supported agent clients discover a skill by finding a directory containing `SKILL.md`.

## Package contract

Every skill package has this minimum shape:

```text
<skill-name>/
└── SKILL.md
```

`SKILL.md` is the authoritative agent-facing entry point. Its YAML frontmatter must include a `name` matching the directory name and a useful `description`. The body contains the core workflow, safety boundaries, and validation expectations.

Optional package resources are grouped by function:

| Directory | Responsibility |
| --- | --- |
| `references/` | Detailed material that an agent should load only when the workflow requires it. |
| `scripts/` | Deterministic, reusable utilities that can run without reproducing their implementation in the prompt. |
| `templates/` | Boilerplate or output assets used by the skill. |

A skill-specific companion guide belongs at `docs/skills/<skill-name>/README.md`. It is for concise human-facing orientation; it must not duplicate the complete workflow in `SKILL.md`.

## Repository boundaries

| Location | Scope | Change guidance |
| --- | --- | --- |
| Top-level `<skill-name>/` | Runtime skill package | Keep self-contained and preserve the `SKILL.md` entry point. |
| `docs/skills/<skill-name>/` | Human-facing skill overview | Link to the authoritative skill and explain usage or safety notes. |
| `docs/` root documents | Cross-skill policy and contributor guidance | Put shared rules here rather than copying them into every skill. |
| `agent_skills/` | CLI and repository-management implementation | Change only when repository behavior or path contracts change. |
| `tests/` | Automated behavior coverage | Add regression coverage for CLI or validation changes. |

## Discovery and compatibility

The CLI identifies available skills by scanning top-level directories for `SKILL.md`, excluding repository support directories such as `docs`, `tests`, and `agent_skills`. Do not move skill packages under a new aggregate directory without first changing the discovery contract and documenting the migration for supported clients.

This layout is therefore deliberately conservative: it separates shared documentation without breaking existing installation commands, links, or client discovery behavior.

## Source of truth

Use `SKILL.md` for agent instructions, the companion guide for concise human orientation, and root `docs/` documents for repository-wide policy. When information changes, update the narrowest authoritative location and link to it from broader documents.

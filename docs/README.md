# Documentation

This directory contains concise human-facing skill guides and repository-wide documentation.

## Repository guidance

- [Architecture](./architecture.md) — package contract, discovery behavior, and directory responsibilities.
- [Scalability](./scalability.md) — progressive disclosure, shared-resource boundaries, and safe growth.
- [Authoring guide](./authoring-guide.md) — create and update a skill package.
- [Validation](./validation.md) — local checks and pull-request quality gates.

## Skill guides

Each skill has a companion guide at `docs/skills/<skill-name>/README.md`. The corresponding top-level `<skill-name>/SKILL.md` remains the authoritative workflow for agents.

- [`env-sync-infisical`](./skills/env-sync-infisical/README.md) — Audit `.env.example` against code usage and Infisical secrets.
- [`gh-issue-create`](./skills/gh-issue-create/README.md) — Create a GitHub issue from the current repository.
- [`git-clean`](./skills/git-clean/README.md) — Safely synchronize the local `main` branch with `origin`.

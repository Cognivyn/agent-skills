# Scalability Guidelines

The repository should remain easy to discover and safe to extend as the number of skills grows. Scale by keeping each skill package independent, moving detail behind progressive-disclosure boundaries, and centralizing only rules that are truly shared.

## Growth principles

1. **Preserve one predictable package contract.** A new skill is a top-level directory with one required `SKILL.md`; optional resources use named functional directories.
2. **Keep the trigger surface small.** The frontmatter description and the first workflow sections should tell an agent when to use the skill without loading every reference file.
3. **Defer detail.** Put long decision trees, provider-specific material, schemas, and examples in `references/`. Link to the relevant file from `SKILL.md` so an agent can load it on demand.
4. **Automate repetition.** Put deterministic transformations and checks in `scripts/` rather than expanding the prompt instructions with procedural code.
5. **Avoid shared-resource coupling.** Copy a small stable pattern into a skill when it improves portability. Create a shared repository utility only when multiple skills need the same behavior and its compatibility contract can be maintained.
6. **Keep human and agent documentation distinct.** Companion guides should orient people; `SKILL.md` should remain the executable operating contract for an agent.

## Adding a skill at scale

Use the CLI scaffold, complete the generated frontmatter and workflow, add only justified resources, create the companion guide, and update the README catalog. Validate the new skill before opening a pull request. Do not add a second registry that can drift from the filesystem; if an index becomes necessary later, generate it from the package tree or document its update check.

## Managing references

Prefer a few topic-focused reference files over one large manual. Name files for the decision or domain they cover, such as `references/troubleshooting.md` or `references/provider-matrix.md`. Keep `SKILL.md` under the repository's documented context budget and include a clear instruction for when each reference should be read.

Avoid duplicating the same policy in multiple skills. Put organization-wide rules in `docs/`, then link to them from contribution and validation guidance. When a policy is skill-specific, keep it with that skill so the package remains portable.

## Safe evolution

Before moving a file, search the repository for its path, filename, and headings. Update links, CLI assumptions, examples, tests, and CI together. Prefer additive documentation changes over breaking moves. If a future reorganization changes the discovery root, provide a compatibility migration and update all supported clients in the same change.

## Future automation

The current repository can scale without a generated index because the CLI discovers top-level packages directly. Future automation may generate a catalog, link report, or package metadata file, but generated output must have one clear source of truth and a deterministic regeneration check. Automation should fail on duplicate skill names, missing entry points, invalid frontmatter, broken local links, or stale catalog entries.

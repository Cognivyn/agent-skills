---
name: env-sync-infisical
description: >-
  Audit a monorepo .env.example files against env-var usage in source code and
  secrets stored in Infisical, then report gaps and drift across environments.
  Use when the user wants to analyze, validate, or reconcile environment variable
  documentation with actual usage and Infisical secret configuration.
---

# env-sync-infisical

Analyze a monorepo's `.env.example` files against env-var references in source
code and secrets stored in Infisical. The skill is read-only by default: it
never writes to `.env.example`, never mutates Infisical secrets, never prompts
for credentials, and never prints secret values.

## Preflight

1. Confirm the `infisical` CLI is available:
   ```bash
   infisical --version
   ```
2. Confirm an active login session:
   ```bash
   infisical whoami
   ```
3. If either check fails, stop and report:
   "Install or authenticate the Infisical CLI, then rerun."

Never attempt to authenticate on the user's behalf.

## Package discovery

Read the root `package.json` and look for a top-level `workspaces` array.
If absent, check for `pnpm-workspace.yaml` or `yarn` workspace configuration.
For each discovered package directory, locate a `.env.example` file. Packages
without one are skipped and noted in the report.

Supported workspace formats:

- **npm**: `package.json` contains `workspaces` array
- **pnpm**: `pnpm-workspace.yaml` with `packages:` globs
- **yarn**: `.yarnrc.yml` contains `workspaces` or `package.json` `workspaces`

## Env-var parsing

For each `.env.example` file, parse line by line:

- Ignore blank lines and lines starting with `#`.
- Extract keys from lines matching `KEY=value`, `KEY=`, or `KEY`.
- Never read, store, or echo values.

## Code usage scanning

For each package, scan source files for env-var references using these
patterns:

- `process.env.NAME` in JavaScript/TypeScript
- `os.environ.get(NAME)` / `os.getenv(NAME)` in Python
- `import.meta.env.NAME` in Vite projects
- `Bun.env.NAME` in Bun projects
- Any default value or fallback counts as usage

Exclude files in `node_modules`, `dist`, `build`, and `.git` directories.

## Infisical secret fetching

Map each package directory to an Infisical folder path equal to the package
name relative to the repository root. For each environment in the Infisical
project, run:

```bash
infisical secrets --path <package-folder> --recursive --format=json
```

Retrieve the list of environments from:

```bash
infisical environments list --format=json
```

Never print secret values. Compare only secret keys.

## Report generation

For each package, produce four sections:

1. **Required but missing from Infisical**: variables used in code but with no
   secret in Infisical for the environment.
2. **Missing from .env.example**: secrets in Infisical but not documented in
   `.env.example`.
3. **Unused in code**: variables in `.env.example` never referenced in source.
4. **Drift across environments**: variables that exist in one Infisical
   environment but not another.

Omit secret values from all sections. Report only keys.

## Sync suggestions (opt-in only)

When the user explicitly opts in to synchronization, suggest these commands
for review:

- Regenerate `.env.example` from Infisical:
  ```bash
  infisical generate-example-env --path <package-folder> --recursive \
    --env <environment> --format dotenv
  ```
- Add missing secrets to Infisical:
  ```bash
  infisical secrets set --path <package-folder> --file <env-file> \
    --env <environment>
  ```

Never execute these commands automatically. Display them as suggestions and
require explicit user approval before running.

## Safety rules

- Read-only by default. Do not modify `.env.example` or Infisical.
- Never write, print, or log secret values.
- Never prompt for credentials or read credential files.
- Use the existing `infisical login` session only.
- All sync commands are suggestions; never execute without explicit approval.

## References

- `references/cli-reference.md` — detailed Infisical CLI command reference.
- `scripts/analyze.sh` — deterministic analysis script for batch processing.

## Validation

From the repository root, run:

```bash
./agent-skills validate env-sync-infisical
python -m unittest discover -s tests -v
```

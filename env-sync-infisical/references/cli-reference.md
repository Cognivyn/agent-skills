# Infisical CLI Reference

Compact reference for Infisical CLI commands used by the skill. Read this file
only when the workflow requires a specific flag or behavior not covered in
`SKILL.md`.

## Authentication

```bash
infisical whoami
```

Returns the authenticated identity or an error. The skill requires an active
login session. Do not run `infisical login` from within the skill.

## Environments

List all environments in the current project:

```bash
infisical environments list --format=json
```

Output contains slugs such as `dev`, `staging`, `prod`.

## Secrets

Retrieve secrets under a folder path recursively:

```bash
infisical secrets --path <folder> --recursive --format=json
```

Returned keys are compared only. Secret values are never printed to stdout by
the skill.

## Generate example .env

Create a `.env.example`-style file from Infisical secrets:

```bash
infisical generate-example-env --path <folder> --recursive \
  --env <environment> --format dotenv
```

The output is a suggestion only. The skill never runs this without explicit
approval.

## Set secrets from file

Write secrets from a file into Infisical:

```bash
infisical secrets set --path <folder> --file <env-file> \
  --env <environment>
```

The skill never executes this without explicit approval.

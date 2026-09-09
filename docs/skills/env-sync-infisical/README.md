# env-sync-infisical

Audit a monorepo `.env.example` files against env-var usage in source code and
secrets stored in Infisical. The skill reports gaps and drift across
environments without modifying any files or secrets.

## When to use

Use this skill when you want to:

- Verify that every environment variable used in code is documented in
  `.env.example`.
- Confirm that every Infisical secret has a corresponding `.env.example`
  entry.
- Identify environment variables that are documented but no longer used.
- Detect drift between Infisical environments such as `dev`, `staging`, and
  `prod`.

This skill is read-only. Do not use it to apply changes or rotate secrets.

## How it works

1. **Preflight**: verifies the `infisical` CLI is available and an active login
   session exists.
2. **Package discovery**: scans the root `package.json`, `pnpm-workspace.yaml`,
   or Yarn workspace config to find all packages.
3. **Env-var parsing**: reads each `.env.example` and extracts variable names.
4. **Code scanning**: scans source files for `process.env`, `os.environ.get`,
   `import.meta.env`, and `Bun.env` references.
5. **Infisical fetch**: retrieves secret keys from every Infisical environment
   for each package folder.
6. **Report**: produces a gap and drift report per package.

## Safety behavior

- Never writes to `.env.example` or any configuration file.
- Never modifies Infisical secrets.
- Never prints, logs, or stores secret values.
- Never prompts for credentials.
- All sync commands are suggestions only; never executed automatically.

## Workflow

See [`SKILL.md`](../../../env-sync-infisical/SKILL.md) for the agent workflow.

## References

- [`references/cli-reference.md`](../../../env-sync-infisical/references/cli-reference.md) — Infisical CLI command reference.

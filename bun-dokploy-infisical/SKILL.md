---
name: bun-dokploy-infisical
description: >-
  Generate production Dockerfile and Docker Compose deployment assets for a
  Bun/TypeScript monorepo running on Dokploy behind Traefik, with Infisical
  Universal Auth secrets fetched at container startup. Use when a repository
  needs Dokploy deployment files, Traefik routing labels, Infisical runtime
  injection, or troubleshooting for this deployment pattern.
---

# Bun monorepo deployment with Dokploy, Traefik, and Infisical

Generate a reproducible Docker deployment for a Bun TypeScript monorepo. Use
Infisical's **fetch-at-startup** pattern: the image contains the Infisical CLI,
the deployment platform supplies only bootstrap credentials, the entrypoint
logs in immediately before application startup, and `infisical run` injects
secrets into the application process.

## Non-negotiable design decisions

- Never put `INFISICAL_CLIENT_SECRET`, an access token, or any secret value in a
  Dockerfile, Git repository, image layer, build argument, or committed `.env`.
- Use an Infisical **Machine Identity with Universal Auth**, scoped to the
  target project and least-privilege read role. The Client ID is not secret;
  the Client Secret is secret.
- Pass bootstrap values from Dokploy's protected environment editor or an
  equivalent secret store. At minimum use `INFISICAL_CLIENT_ID`,
  `INFISICAL_CLIENT_SECRET`, `INFISICAL_SECRET_PATH`, and `INFISICAL_URL`.
- Infisical still needs a non-secret project ID and environment slug. Prefer a
  committed `infisical.yaml` containing only `projectId` and `environment`, or
  explicit non-secret `INFISICAL_PROJECT_ID` and `INFISICAL_ENVIRONMENT` values.
  Do not claim that a path alone identifies a project or environment.
- Obtain a fresh token on every container start. Do not bake a token into the
  image or persist it in a volume.
- Make Traefik routing explicit: `traefik.enable=true`, the shared external
  network, a host rule, TLS entrypoint/resolver as supplied by the deployment,
  and the internal application port. Do not publish the application port to
  the host unless the user specifically needs direct access.
- Treat `docker compose config` output as sensitive: it can render interpolated
  values. Validate with redacted or placeholder values and never paste resolved
  secrets into logs.

## Workflow

1. **Inspect the repository.** Read the root `package.json`, `bun.lockb` or
   `bun.lock`, workspace configuration, TypeScript build scripts, app package
   scripts, server listen host/port, and any existing Docker files. Determine
   the exact workspace/package to build and start; do not invent `bun run`
   scripts. Confirm the app binds to `0.0.0.0`, not only `localhost`.
2. **Resolve Infisical coordinates.** Confirm the Infisical project ID and
   environment slug. If absent, add a non-secret `infisical.yaml` or use
   clearly documented Compose variables. Confirm the secret path (usually `/`)
   and the Infisical site URL (`https://app.infisical.com`, the EU site, or a
   reachable self-hosted URL). A self-hosted URL must be reachable from inside
   the container; never use container-local `localhost` for a host service.
3. **Create a multi-stage Dockerfile.** Use an official Bun image, copy lockfiles
   before source for cache efficiency, install with the repository's frozen-lock
   command, build the selected workspace, and copy only required runtime output
   and production dependencies into the final stage when the monorepo permits
   it. Install a pinned Infisical CLI version when the project has a production
   pinning policy; otherwise document the chosen CLI version and upgrade plan.
   Install `bash`, `curl`, and `ca-certificates` only as needed by the chosen
   Debian/Ubuntu or Alpine base. Run as a non-root user where the Bun app allows.
4. **Create a fail-fast entrypoint.** Validate required bootstrap variables,
   export `INFISICAL_DOMAIN="$INFISICAL_URL"`, run:

   ```bash
   infisical login --method=universal-auth \
     --client-id="$INFISICAL_CLIENT_ID" \
     --client-secret="$INFISICAL_CLIENT_SECRET" \
     --plain --silent
   ```

   Capture the token without printing it, then `exec infisical run` with the
   project ID, environment slug, secret path, and the application command.
   Unset the Client Secret and bootstrap variables before `exec`; preserve only
   the token needed by the CLI. Use `exec` so signals and exit codes reach Bun.
   Do not write an `.env` file.
5. **Create `compose.yaml`.** Define the app service with `build`, explicit
   runtime environment mappings, a healthcheck if the repository exposes a
   health endpoint, restart policy appropriate for Dokploy, and the external
   Traefik network. Use Compose required-variable syntax for bootstrap values so
   a missing Dokploy variable fails before deployment. Keep the command generic
   enough for the inspected workspace, for example an entrypoint plus the
   actual `bun run start --filter <workspace>` command.
6. **Add Traefik labels.** Use the actual public hostname and internal port.
   Prefer labels equivalent to:

   ```yaml
   traefik.enable: "true"
   traefik.docker.network: traefik-public
   traefik.http.routers.app.rule: Host(`app.example.com`)
   traefik.http.routers.app.entrypoints: websecure
   traefik.http.routers.app.tls: "true"
   traefik.http.routers.app.tls.certresolver: letsencrypt
   traefik.http.services.app.loadbalancer.server.port: "3000"
   ```

   Replace the network, hostname, entrypoint, resolver, and port with the
   user's Dokploy/Traefik values. If Dokploy already owns domain labels, avoid
   creating a second conflicting router and document which system is the source
   of truth. Explicitly set the Docker network when containers join more than
   one network.
7. **Document Dokploy setup.** Tell the user to deploy as Docker Compose, put
   the four bootstrap values in protected environment variables, add the
   non-secret project/environment coordinates, attach the provider/network as
   needed, and redeploy after rotating Infisical secrets. Do not use Dokploy's
   Infisical Secrets Provider as a substitute for this runtime pattern unless
   the user chooses deploy-time injection; that is a different, valid design.
8. **Validate without exposing secrets.** Run `docker compose config` with safe
   placeholders, `docker build` if Docker is available, `docker compose config
   --quiet`, and repository tests/typecheck/build. Inspect the final image for
   credentials with a source scan and verify that the application command is
   reached only after login. Report any checks that could not run.

## Required generated files

Create only files justified by the repository, normally:

- `Dockerfile` — multi-stage Bun build with Infisical CLI installation.
- `docker/entrypoint-infisical.sh` — login, token capture, fail-fast checks,
  and `exec infisical run`.
- `compose.yaml` or `docker-compose.yml` — Dokploy-ready app service and
  Traefik labels.
- `.dockerignore` — exclude `.git`, local `.env*`, dependencies, logs, and
  build output while retaining required lockfiles/source.
- `infisical.yaml` — only if project ID/environment are not already represented;
  it must contain no secret values.

Adapt names and commands to the inspected monorepo. Do not blindly copy a
single-service example into a workspace with multiple deployable apps; create
one service per independently deployed app when required.

## Infisical troubleshooting decision tree

- **Login returns 401/invalid credentials:** verify the Client ID/Client Secret
  pair, that the Client Secret was copied when created, that it is not expired
  or over its max-use limit, and that the machine identity has Universal Auth.
  Rotate the secret rather than printing it for diagnosis.
- **Login reaches the wrong server or fails TLS/DNS:** verify
  `INFISICAL_URL` has scheme and no accidental path suffix, that it is reachable
  from the container, and that `INFISICAL_DOMAIN` is exported for the CLI.
  For a host-local self-hosted server use a host-reachable address such as
  `host.docker.internal` where supported, not container `localhost`.
- **Login succeeds but `infisical run` cannot read secrets:** verify project ID,
  environment slug, secret path, project membership, read permission, and that
  the secret exists at that exact path. A successful authentication does not
  prove project-level access.
- **Variables are empty or missing:** confirm the app command is the child of
  `infisical run`, not a sibling process; confirm the entrypoint uses `exec` and
  does not invoke `env -i`; verify the secret names match the app's expected
  names. Never fall back to a checked-in `.env`.
- **Compose fails before startup:** inspect only the names of missing variables.
  Dokploy writes environment values for Compose interpolation, but values are
  not automatically injected into containers unless referenced in
  `environment` or `env_file`; this skill uses explicit mappings.
- **Traefik returns 404/502:** verify `traefik.enable`, shared network, exact
  Host rule, TLS entrypoint/resolver, and the internal port label. Check that
  Bun listens on `0.0.0.0` and that the container healthcheck is passing. Use
  `docker inspect` and Traefik logs without dumping the full environment.
- **Redeploy loses files or config:** do not bind-mount repository files in
  Dokploy deployments; Dokploy reclones the repository. Use image contents,
  Dokploy File Mounts, or persistent `../files`/named volumes only when needed.
- **Token expires:** obtain a new token at each container start. For long-lived
  processes that must renew credentials, use Infisical's documented periodic
  token strategy rather than reusing a static access token.

## Anti-patterns

- Do not use `ARG` or `ENV` in a Dockerfile for Client Secret or token.
- Do not run `infisical login` during `docker build`.
- Do not generate a plaintext `.env` in the container or on the Dokploy host.
- Do not log `env`, `set`, the login response, or the token.
- Do not use `latest` for the Bun base image or Infisical CLI when reproducible
  production builds are required.
- Do not expose every Compose service through Traefik by default; expose only
  the intended HTTP service and set `exposedByDefault=false` in Traefik where
  you control the provider.
- Do not assume Dokploy's deploy-time Secrets Provider and this container
  startup injection pattern are interchangeable; explain the security and
  rotation trade-off if offering both.

## References

Read these official references when details change or troubleshooting requires
more depth:

- [Infisical: Inject secrets into a Docker application](https://infisical.com/docs/integrations/platforms/docker)
- [Infisical: Universal Auth](https://infisical.com/docs/documentation/platform/identities/universal-auth)
- [Dokploy: Infisical Secrets Provider](https://docs.dokploy.com/docs/core/secrets-providers/infisical)
- [Dokploy: Docker Compose](https://docs.dokploy.com/docs/core/docker-compose)
- [Traefik: Docker provider](https://doc.traefik.io/traefik/providers/docker/)

Use `references/troubleshooting.md` for the compact verification matrix and
`templates/` for starting points; always adapt them after repository
inspection.

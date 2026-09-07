# bun-dokploy-infisical

Use this skill when generating deployment assets for a Bun/TypeScript monorepo that will run as a Docker Compose application on Dokploy behind Traefik and obtain application secrets from Infisical at container startup.

The skill follows Infisical's recommended fetch-at-startup approach. It generates or adapts a multi-stage `Dockerfile`, an Infisical-login entrypoint, Compose configuration, Traefik labels, and a troubleshooting path. The Client ID, Client Secret, secret path, and Infisical URL are supplied at runtime; tokens and application secrets are never baked into the image.

Before using it, have an Infisical Machine Identity with Universal Auth, project membership with read access, a project ID and environment slug, and a reachable Infisical URL. Dokploy should provide bootstrap credentials through protected environment variables. The skill deliberately distinguishes this startup flow from Dokploy's separate deploy-time Infisical Secrets Provider.

See [`SKILL.md`](../../bun-dokploy-infisical/SKILL.md) for the authoritative workflow and official references.

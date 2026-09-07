# Adapt workspace names and build/start commands after inspecting the monorepo.
FROM oven/bun:1.1.38-slim AS build
WORKDIR /app

COPY package.json bun.lock* ./
# Copy workspace manifests here when the repository uses Bun workspaces.
COPY apps ./apps
COPY packages ./packages
RUN bun install --frozen-lockfile
RUN bun run build

FROM oven/bun:1.1.38-slim AS runtime
WORKDIR /app

RUN apt-get update \
  && apt-get install -y --no-install-recommends bash ca-certificates curl \
  && curl -1sLf 'https://artifacts-cli.infisical.com/setup.deb.sh' | bash \
  && apt-get update \
  && apt-get install -y --no-install-recommends infisical \
  && rm -rf /var/lib/apt/lists/*

COPY --from=build /app /app
COPY docker/entrypoint-infisical.sh /usr/local/bin/entrypoint-infisical.sh
RUN chmod 0755 /usr/local/bin/entrypoint-infisical.sh

USER bun
EXPOSE 3000
ENTRYPOINT ["/usr/local/bin/entrypoint-infisical.sh"]
CMD ["bun", "run", "start"]

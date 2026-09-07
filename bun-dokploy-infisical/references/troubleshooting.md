# Runtime deployment verification matrix

Use placeholders such as `REDACTED` during validation. Never print a resolved
Compose configuration containing real secrets.

| Layer | Check | Safe evidence | Likely correction |
| --- | --- | --- | --- |
| Bootstrap | Required variables exist | Names only, e.g. `INFISICAL_URL set` | Add protected Dokploy variables |
| Auth | Universal Auth login | Exit status; redact token | Rotate secret; verify identity and URL |
| Reachability | Container can resolve Infisical URL | `curl -fsS --head "$INFISICAL_URL"` if allowed | Fix DNS, TLS, firewall, or host-local URL |
| Authorization | Project/environment/path access | Secret names only | Assign identity to project with read role |
| Injection | App is child of `infisical run` | Process tree and app health | Fix `exec` command and flags |
| App | Bun binds correctly | Healthcheck response from container | Bind `0.0.0.0`; correct internal port |
| Routing | Traefik discovers app | Router/service names in Traefik logs | Fix labels, network, hostname, TLS |
| Redeploy | No repository bind mounts | Compose mounts list | Use image, File Mounts, or persistent volume |

## Safe diagnostics

```bash
# Do not use real values in this command or paste its output into chat.
INFISICAL_URL=https://example.invalid \
INFISICAL_CLIENT_ID=placeholder \
INFISICAL_CLIENT_SECRET=placeholder \
INFISICAL_SECRET_PATH=/ \
INFISICAL_PROJECT_ID=placeholder \
INFISICAL_ENVIRONMENT=prod \
  docker compose config --quiet

docker inspect <container> --format '{{json .NetworkSettings.Networks}}'
docker logs --tail=100 <container>
```

Do not run `env`, `set`, `docker inspect` with full configuration, or shell
tracing around authentication. If a token is exposed, revoke it immediately.

## Two supported secret delivery designs

**Startup injection (this skill):** the container logs in and fetches secrets
when it starts. Dokploy stores only bootstrap credentials and non-secret
coordinates. Rotation takes effect on restart/redeploy, and application
secrets do not become image layers.

**Dokploy Secrets Provider:** Dokploy authenticates to Infisical and resolves
`${{vault.provider.SECRET_NAME}}` at deploy time. This is useful when the
platform should own injection, but it is not the same runtime flow and should
not be silently mixed with it. Use one source of truth per variable.

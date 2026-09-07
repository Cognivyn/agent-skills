#!/usr/bin/env bash
set -Eeuo pipefail

required=(INFISICAL_CLIENT_ID INFISICAL_CLIENT_SECRET INFISICAL_URL INFISICAL_SECRET_PATH)
for name in "${required[@]}"; do
  if [[ -z "${!name:-}" ]]; then
    printf 'missing required variable: %s\n' "$name" >&2
    exit 64
  fi
done

: "${INFISICAL_PROJECT_ID:?set a non-secret Infisical project ID}"
: "${INFISICAL_ENVIRONMENT:?set a non-secret Infisical environment slug}"
export INFISICAL_DOMAIN="$INFISICAL_URL"

# Keep token output out of logs. The token is passed only to the child CLI.
INFISICAL_TOKEN="$(infisical login \
  --method=universal-auth \
  --client-id="$INFISICAL_CLIENT_ID" \
  --client-secret="$INFISICAL_CLIENT_SECRET" \
  --plain --silent)"
export INFISICAL_TOKEN
unset INFISICAL_CLIENT_SECRET INFISICAL_CLIENT_ID INFISICAL_URL

exec infisical run \
  --projectId="$INFISICAL_PROJECT_ID" \
  --env="$INFISICAL_ENVIRONMENT" \
  --path="$INFISICAL_SECRET_PATH" \
  -- "$@"

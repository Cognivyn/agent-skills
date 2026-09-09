#!/usr/bin/env bash
set -euo pipefail

ROOT="${1:-.}"
FORMAT="${2:-json}"

if ! command -v infisical >/dev/null 2>&1; then
  echo "error: infisical CLI not found" >&2
  exit 1
fi

infisical whoami >/dev/null 2>&1 || {
  echo "error: infisical login session not found; run 'infisical login' first" >&2
  exit 1
}

WORKSPACES_JSON=$(node -e "
  const fs = require('fs');
  const root = '$ROOT';
  let pkg;
  try { pkg = JSON.parse(fs.readFileSync(root + '/package.json', 'utf8')); }
  catch { pkg = {}; }
  const ws = pkg.workspaces;
  if (Array.isArray(ws)) {
    console.log(JSON.stringify({type:'npm', packages: ws}));
    exit(0);
  }
  try {
    const txt = fs.readFileSync(root + '/pnpm-workspace.yaml', 'utf8');
    const pkgs = [];
    for (const line of txt.split('\n')) {
      const m = line.match(/^-\\s+(.+)$/);
      if (m) pkgs.push(m[1].trim());
    }
    if (pkgs.length) { console.log(JSON.stringify({type:'pnpm', packages: pkgs})); exit(0); }
  } catch {}
  try {
    const txt = fs.readFileSync(root + '/.yarnrc.yml', 'utf8');
    if (txt.includes('workspaces:')) {
      console.log(JSON.stringify({type:'yarn', packages:[]}));
      exit(0);
    }
  } catch {}
  console.log(JSON.stringify({type:'none', packages:[]}));
" 2>/dev/null) || {
  echo "error: failed to detect workspaces" >&2
  exit 1
}

ENVIRONMENTS=$(infisical environments list --format=json 2>/dev/null || echo '[]')

packages=$(echo "$WORKSPACES_JSON" | node -e "
  const input = require('fs').readFileSync(0, 'utf8');
  const data = JSON.parse(input);
  const pkgs = data.packages || [];
  pkgs.forEach(p => {
    if (p.endsWith('/*')) p = p.slice(0, -2);
    if (p.startsWith('./')) p = p.slice(2);
    console.log(p);
  });
")

for pkg in $packages; do
  env_file="$ROOT/$pkg/.env.example"
  if [ ! -f "$env_file" ]; then
    echo "{\"package\":\"$pkg\",\"skipped\":true,\"reason\":\"no .env.example\"}"
    continue
  fi

  keys=$(grep -E '^[A-Za-z_][A-Za-z0-9_]*=' "$env_file" | cut -d= -f1 | sort -u)

  used=$(find "$ROOT/$pkg" -type f \( -name '*.ts' -o -name '*.js' -o -name '*.py' \) \
    ! -path '*/node_modules/*' ! -path '*/dist/*' ! -path '*/build/*' ! -path '*/.git/*' \
    -exec grep -hEo 'process\.env\.[A-Za-z_][A-Za-z0-9_]*|os\.environ\.get\("?[A-Za-z_][A-Za-z0-9_]*"?\)|os\.getenv\("?[A-Za-z_][A-Za-z0-9_]*"?\)|import\.meta\.env\.[A-Za-z_][A-Za-z0-9_]*|Bun\.env\.[A-Za-z_][A-Za-z0-9_]*' {} + 2>/dev/null \
    | sed -E 's/.*\\.([A-Za-z_][A-Za-z0-9_]*)$/\\1/' \
    | sort -u || true)

  infisical_keys=$(infisical secrets --path "$pkg" --recursive --format=json 2>/dev/null \
    | grep -oP '"key":\s*"\K[^"]+' | sort -u || true)

  infisical_environments=$(echo "$ENVIRONMENTS" | grep -oP '"slug":\s*"\K[^"]+' || true)

  declare -a required=()
  declare -a missing_from_example=()
  declare -a unused=()
  declare -A env_counts=()

  for k in $infisical_keys; do
    env_counts["$k"]=0
  done

  while IFS= read -r k; do
    [ -z "$k" ] && continue
    if ! echo " $infisical_keys " | grep -q " $k "; then
      required+=("$k")
    fi
    if ! echo " $keys " | grep -q " $k "; then
      missing_from_example+=("$k")
    fi
  done <<< "$used"

  while IFS= read -r k; do
    [ -z "$k" ] && continue
    if ! echo " $used " | grep -q " $k "; then
      unused+=("$k")
    fi
  done <<< "$keys"

  while IFS= read -r env; do
    [ -z "$env" ] && continue
    env_keys=$(infisical secrets --path "$pkg" --recursive --env "$env" --format=json 2>/dev/null \
      | grep -oP '"key":\s*"\K[^"]+' | sort -u || true)
    while IFS= read -r k; do
      [ -z "$k" ] && continue
      if [ -z "${env_counts[$k]+_}" ]; then
        env_counts["$k"]=1
      else
        env_counts["$k"]=$(( ${env_counts[$k]} + 1 ))
      fi
    done <<< "$env_keys"
  done <<< "$infisical_environments"

  drift=()
  total_envs=$(echo "$infisical_environments" | grep -c . || true)
  for k in "${!env_counts[@]}"; do
    if [ "${env_counts[$k]}" -gt 0 ] && [ "${env_counts[$k]}" -lt "$total_envs" ]; then
      drift+=("$k")
    fi
  done

  echo "{\"package\":\"$pkg\",\"required_but_missing\":[$(printf '\"%s\"' "${required[@]}" 2>/dev/null | tr ' ' ',' || echo '')],\"missing_from_example\":[$(printf '\"%s\"' "${missing_from_example[@]}" 2>/dev/null | tr ' ' ',' || echo '')],\"unused\":[$(printf '\"%s\"' "${unused[@]}" 2>/dev/null | tr ' ' ',' || echo '')],\"drift\":[$(printf '\"%s\"' "${drift[@]}" 2>/dev/null | tr ' ' ',' || echo '')]}"
done

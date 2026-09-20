#!/usr/bin/env bash
set -euo pipefail

# validate-journey.sh
# Syntax and basic structural validator for journey YAML/JSON files.

JOURNEY_FILE="${1:-}"

if [[ -z "$JOURNEY_FILE" ]]; then
  echo "Usage: $0 <journey-file>"
  exit 1
fi

if [[ ! -f "$JOURNEY_FILE" ]]; then
  echo "Error: Journey file not found: $JOURNEY_FILE"
  exit 1
fi

echo "Validating journey file: $JOURNEY_FILE"

# Basic checks: ensure file contains required keys 'name', 'start_url', and 'steps'
MISSING=""
if ! grep -qE "^name:" "$JOURNEY_FILE" && ! grep -q '"name"' "$JOURNEY_FILE"; then
  MISSING="$MISSING name"
fi

if ! grep -qE "^start_url:" "$JOURNEY_FILE" && ! grep -q '"start_url"' "$JOURNEY_FILE"; then
  MISSING="$MISSING start_url"
fi

if ! grep -qE "^steps:" "$JOURNEY_FILE" && ! grep -q '"steps"' "$JOURNEY_FILE"; then
  MISSING="$MISSING steps"
fi

if [[ -n "$MISSING" ]]; then
  echo "Validation Error: Missing required journey fields:$MISSING"
  exit 1
fi

# Check for destructive actions in step definitions
DESTRUCTIVE_TERMS=("delete" "remove" "cancel account" "unsubscribe" "purge" "destroy")
for term in "${DESTRUCTIVE_TERMS[@]}"; do
  if grep -i -q "$term" "$JOURNEY_FILE"; then
    echo "Warning: Journey file contains potentially destructive action keyword: '$term'."
    echo "Make sure to pass --allow-destructive if executing with run-journey.sh."
  fi
done

echo "Journey file validation successful: $JOURNEY_FILE"
exit 0

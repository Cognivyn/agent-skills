#!/usr/bin/env bash
set -euo pipefail

# validate-journey.sh
# Syntax and structural validator for journey specification files.

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

# Validate structure using Python stdlib JSON/YAML parser
python3 - "$JOURNEY_FILE" <<'PYEOF'
import sys
import json
import os

journey_file = sys.argv[1]

def parse_journey(filepath):
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()

    try:
        return json.loads(content)
    except json.JSONDecodeError:
        pass

    data = {'name': '', 'start_url': '', 'steps': []}
    lines = content.splitlines()
    current_step = None
    in_steps = False

    for line in lines:
        stripped = line.strip()
        if not stripped or stripped.startswith('#'):
            continue

        indent = len(line) - len(line.lstrip())

        if indent == 0:
            if current_step and in_steps:
                data['steps'].append(current_step)
                current_step = None

            if line.startswith('name:'):
                data['name'] = line.split(':', 1)[1].strip().strip('"\'')
                in_steps = False
            elif line.startswith('start_url:'):
                data['start_url'] = line.split(':', 1)[1].strip().strip('"\'')
                in_steps = False
            elif line.startswith('steps:'):
                in_steps = True
            continue

        if in_steps:
            if stripped.startswith('- '):
                if current_step:
                    data['steps'].append(current_step)
                current_step = {}
                item = stripped[2:].strip()
                if ':' in item:
                    k, v = item.split(':', 1)
                    current_step[k.strip()] = v.strip().strip('"\'')
            elif current_step and ':' in stripped:
                k, v = stripped.split(':', 1)
                val = v.strip().strip('"\'')
                if val.lower() == 'true': val = True
                elif val.lower() == 'false': val = False
                current_step[k.strip()] = val

    if current_step and in_steps:
        data['steps'].append(current_step)

    return data

journey = parse_journey(journey_file)
errors = []

name = journey.get('name')
if not name:
    errors.append("Field 'name' is missing or empty.")

start_url = journey.get('start_url')
if not start_url:
    errors.append("Field 'start_url' is missing or empty.")

steps = journey.get('steps', [])
if not isinstance(steps, list) or len(steps) == 0:
    errors.append("Field 'steps' is missing, empty, or not a list.")

VALID_ACTIONS = {"click", "fill", "type", "press", "navigate", "wait"}

for idx, step in enumerate(steps, 1):
    s_name = step.get('name')
    if not s_name:
        errors.append(f"Step {idx} is missing required 'name' field.")

    action = step.get('action')
    if not action:
        errors.append(f"Step {idx} ('{s_name}') is missing required 'action' field.")
    elif action not in VALID_ACTIONS:
        errors.append(f"Step {idx} ('{s_name}') specifies invalid action '{action}'. Valid: {sorted(list(VALID_ACTIONS))}")

    if action in {"click", "fill", "type"} and not step.get('target'):
        errors.append(f"Step {idx} ('{s_name}') action '{action}' requires 'target' field.")

if errors:
    print("Validation Error(s):")
    for err in errors:
        print(f"  - {err}")
    sys.exit(1)

PYEOF

# Check for destructive actions
DESTRUCTIVE_TERMS=("delete" "remove" "cancel account" "unsubscribe" "purge" "destroy")
for term in "${DESTRUCTIVE_TERMS[@]}"; do
  if grep -i -q "$term" "$JOURNEY_FILE"; then
    echo "Warning: Journey file contains potentially destructive action keyword: '$term'."
    echo "Make sure to pass --allow-destructive if executing with run-journey.sh."
  fi
done

echo "Journey file validation successful: $JOURNEY_FILE"
exit 0

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

python3 - "$JOURNEY_FILE" <<'PYEOF'
import sys
import json
import re

journey_file = sys.argv[1]

def parse_journey(filepath):
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()

    try:
        return json.loads(content)
    except json.JSONDecodeError:
        pass

    data = {'name': '', 'start_url': '', 'viewport': {}, 'before_journey': [], 'steps': []}
    lines = content.splitlines()

    current_section = None
    current_item = None

    for line in lines:
        # Strip inline YAML comments (unquoted #)
        if '#' in line:
            # Simple comment stripping respecting quotes
            parts = re.split(r'\s+#', line, 1)
            line = parts[0]

        stripped = line.strip()
        if not stripped:
            continue

        indent = len(line) - len(line.lstrip())

        if indent == 0:
            if current_item and current_section in ('before_journey', 'steps'):
                data[current_section].append(current_item)
                current_item = None

            if line.startswith('name:'):
                data['name'] = line.split(':', 1)[1].strip().strip('"\'')
                current_section = None
            elif line.startswith('start_url:'):
                data['start_url'] = line.split(':', 1)[1].strip().strip('"\'')
                current_section = None
            elif line.startswith('viewport:'):
                current_section = 'viewport'
            elif line.startswith('before_journey:'):
                current_section = 'before_journey'
            elif line.startswith('steps:'):
                current_section = 'steps'
            continue

        if current_section == 'viewport' and ':' in stripped:
            k, v = stripped.split(':', 1)
            try:
                data['viewport'][k.strip()] = int(v.strip())
            except ValueError:
                pass
        elif current_section in ('before_journey', 'steps'):
            if stripped.startswith('- '):
                if current_item:
                    data[current_section].append(current_item)
                current_item = {}
                item = stripped[2:].strip()
                if ':' in item:
                    k, v = item.split(':', 1)
                    current_item[k.strip()] = parse_scalar(v.strip())
            elif current_item and ':' in stripped:
                k, v = stripped.split(':', 1)
                current_item[k.strip()] = parse_scalar(v.strip())

    if current_item and current_section in ('before_journey', 'steps'):
        data[current_section].append(current_item)

    return data

def parse_scalar(val_str):
    val_str = val_str.strip().strip('"\'')
    if val_str.lower() == 'true': return True
    if val_str.lower() == 'false': return False
    return val_str

journey = parse_journey(journey_file)
errors = []

name = journey.get('name')
if not name:
    errors.append("Field 'name' is missing or empty.")

start_url = journey.get('start_url')
if not start_url:
    errors.append("Field 'start_url' is missing or empty.")

VALID_ACTIONS = {"click", "fill", "type", "press", "navigate", "wait"}

def validate_step_list(section_name, step_list):
    for idx, step in enumerate(step_list, 1):
        s_name = step.get('name', f"{section_name}-{idx}")
        action = step.get('action')
        if not action:
            errors.append(f"{section_name} step {idx} ('{s_name}') is missing required 'action' field.")
        elif action not in VALID_ACTIONS:
            errors.append(f"{section_name} step {idx} ('{s_name}') specifies invalid action '{action}'. Valid: {sorted(list(VALID_ACTIONS))}")

        if action in {"click", "fill", "type"} and not step.get('target'):
            errors.append(f"{section_name} step {idx} ('{s_name}') action '{action}' requires 'target' field.")

validate_step_list("before_journey", journey.get('before_journey', []))

steps = journey.get('steps', [])
if not isinstance(steps, list) or len(steps) == 0:
    errors.append("Field 'steps' is missing, empty, or not a list.")
else:
    validate_step_list("steps", steps)

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

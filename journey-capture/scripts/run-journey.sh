#!/usr/bin/env bash
set -euo pipefail

# run-journey.sh
# Runner script for journey-capture flows using agent-browser CLI.

JOURNEY_FILE=""
OUTPUT_DIR=""
DRY_RUN=false
ALLOW_DESTRUCTIVE=false
ALLOW_SENSITIVE=false
ALLOW_CROSS_ORIGIN=false
STEP_TIMEOUT=30
GLOBAL_TIMEOUT=600

show_help() {
  cat <<'EOF'
Usage: run-journey.sh [options] <journey-file>

Options:
  --output-dir <path>       Directory to save screenshots and manifest (default: ./journey-screenshots/<name>)
  --dry-run                 Preview actions and outputs without launching browser
  --allow-destructive       Allow actions matching destructive keyword deny-list
  --allow-sensitive-capture Capture unmasked screenshots of sensitive fields
  --allow-cross-origin      Allow navigation to external domain origins
  --step-timeout <seconds>  Per-step timeout limit (default: 30)
  --global-timeout <seconds> Overall execution timeout limit (default: 600)
  -h, --help                Show help
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --output-dir)
      OUTPUT_DIR="$2"
      shift 2
      ;;
    --dry-run)
      DRY_RUN=true
      shift
      ;;
    --allow-destructive)
      ALLOW_DESTRUCTIVE=true
      shift
      ;;
    --allow-sensitive-capture)
      ALLOW_SENSITIVE=true
      shift
      ;;
    --allow-cross-origin)
      ALLOW_CROSS_ORIGIN=true
      shift
      ;;
    --step-timeout)
      STEP_TIMEOUT="$2"
      shift 2
      ;;
    --global-timeout)
      GLOBAL_TIMEOUT="$2"
      shift 2
      ;;
    -h|--help)
      show_help
      exit 0
      ;;
    -*)
      echo "Unknown option: $1"
      show_help
      exit 1
      ;;
    *)
      if [[ -z "$JOURNEY_FILE" ]]; then
        JOURNEY_FILE="$1"
      else
        echo "Unexpected argument: $1"
        exit 1
      fi
      shift
      ;;
  esac
done

if [[ -z "$JOURNEY_FILE" ]]; then
  echo "Error: Journey file required."
  show_help
  exit 1
fi

if [[ ! -f "$JOURNEY_FILE" ]]; then
  echo "Error: Journey file not found: $JOURNEY_FILE"
  exit 1
fi

# Run pre-validation
"$(dirname "$0")/validate-journey.sh" "$JOURNEY_FILE"

# Execute journey using Python helper (stdlib only)
python3 - "$JOURNEY_FILE" "$OUTPUT_DIR" "$DRY_RUN" "$ALLOW_DESTRUCTIVE" "$ALLOW_SENSITIVE" "$ALLOW_CROSS_ORIGIN" "$STEP_TIMEOUT" "$GLOBAL_TIMEOUT" <<'PYEOF'
import sys
import os
import json
import re
import subprocess
import time
from datetime import datetime, timezone
from urllib.parse import urlparse

journey_file = sys.argv[1]
custom_output_dir = sys.argv[2]
dry_run = sys.argv[3].lower() == 'true'
allow_destructive = sys.argv[4].lower() == 'true'
allow_sensitive = sys.argv[5].lower() == 'true'
allow_cross_origin = sys.argv[6].lower() == 'true'
step_timeout = int(sys.argv[7])
global_timeout = int(sys.argv[8])

DESTRUCTIVE_KEYWORDS = ["delete", "remove", "cancel account", "unsubscribe", "purge", "destroy"]

def parse_simple_yaml(filepath):
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

        if line.startswith('name:'):
            data['name'] = line.split(':', 1)[1].strip().strip('"\'')
        elif line.startswith('start_url:'):
            data['start_url'] = line.split(':', 1)[1].strip().strip('"\'')
        elif line.startswith('steps:'):
            in_steps = True
        elif in_steps:
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

    if current_step:
        data['steps'].append(current_step)

    return data

journey = parse_simple_yaml(journey_file)
journey_name = journey.get('name', 'journey')
start_url = journey.get('start_url', 'http://localhost')
output_dir = custom_output_dir if custom_output_dir else f"./journey-screenshots/{journey_name}"

print(f"=== Journey Execution Configuration ===")
print(f"Journey Name      : {journey_name}")
print(f"Start URL         : {start_url}")
print(f"Output Directory  : {output_dir}")
print(f"Dry Run           : {dry_run}")
print(f"Allow Destructive : {allow_destructive}")
print(f"Allow Sensitive   : {allow_sensitive}")
print(f"Allow Cross-Origin: {allow_cross_origin}")
print(f"Step Count        : {len(journey.get('steps', []))}")
print(f"=======================================")

if dry_run:
    print(f"[DRY-RUN] Would create directory: {output_dir}")
    print(f"[DRY-RUN] Would open session: agent-browser open \"{start_url}\" --session \"{journey_name}-session\"")
    for idx, step in enumerate(journey.get('steps', []), 1):
        slug = re.sub(r'[^a-z0-9]+', '-', step.get('name', f'step-{idx}').lower()).strip('-')
        img_name = f"{idx:02d}-{slug}.png"
        print(f"[DRY-RUN] Step {idx:02d}: {step.get('name')} -> {img_name}")
    print("[DRY-RUN] Dry run complete.")
    sys.exit(0)

os.makedirs(output_dir, exist_ok=True)
session_name = f"{journey_name}-session"
initial_origin = urlparse(start_url).netloc

def run_agent_cmd(args):
    cmd = ["agent-browser"] + args + ["--session", session_name]
    try:
        res = subprocess.run(cmd, capture_output=True, text=True, timeout=step_timeout)
        return res.stdout.strip(), res.returncode
    except Exception as e:
        return str(e), 1

def resolve_env_vars(val):
    if isinstance(val, str) and val.startswith("${") and val.endswith("}"):
        var_name = val[2:-1]
        return os.getenv(var_name, val)
    return val

manifest_steps = []
start_time = time.time()

try:
    print(f"Opening initial browser session ({session_name})...")
    stdout, code = run_agent_cmd(["open", start_url])
    if code != 0:
        print(f"Error initializing session: {stdout}")
        sys.exit(1)

    for idx, step in enumerate(journey.get('steps', []), 1):
        if time.time() - start_time > global_timeout:
            print(f"Error: Global journey timeout of {global_timeout}s exceeded.")
            sys.exit(1)

        step_name = step.get('name', f'step-{idx}')
        slug = re.sub(r'[^a-z0-9]+', '-', step_name.lower()).strip('-')
        img_name = f"{idx:02d}-{slug}.png"
        img_path = os.path.join(output_dir, img_name)

        action = step.get('action', 'wait')
        target = step.get('target', '')
        raw_val = step.get('value', '')
        val = resolve_env_vars(raw_val)
        is_sensitive = step.get('sensitive', False)

        # Destructive Action Safety Check
        step_str = f"{action} {target} {raw_val}".lower()
        if not allow_destructive and any(kw in step_str for kw in DESTRUCTIVE_KEYWORDS):
            print(f"Error: Step {idx:02d} contains potentially destructive action '{step_name}'. Pass --allow-destructive to run.")
            sys.exit(1)

        # Cross-origin check for navigation
        if action == 'navigate' and val:
            target_origin = urlparse(str(val)).netloc
            if not allow_cross_origin and target_origin and target_origin != initial_origin:
                print(f"Error: Cross-origin navigation to '{target_origin}' blocked. Pass --allow-cross-origin to permit.")
                sys.exit(1)

        log_val = "[REDACTED]" if is_sensitive and not allow_sensitive else val
        print(f"Executing Step {idx:02d}: {step_name} [{action}] {target} {log_val if log_val else ''}".strip())

        # Snapshot to resolve refs if interaction action
        ref = None
        if action in ['click', 'fill', 'type'] and target:
            snapshot_out, _ = run_agent_cmd(["snapshot", "-i"])
            for line in snapshot_out.splitlines():
                if target.lower() in line.lower() and '[ref=' in line:
                    match = re.search(r'\[ref=(e\d+)\]', line)
                    if match:
                        ref = "@" + match.group(1)
                        break

            if not ref:
                print(f"Error: Could not resolve element ref for target '{target}' in Step {idx:02d}.")
                manifest_steps.append({
                    "step": idx,
                    "name": step_name,
                    "filename": img_name,
                    "action": action,
                    "sensitive": is_sensitive,
                    "status": "failed",
                    "error": f"Element target '{target}' not found"
                })
                sys.exit(1)

        # Perform Action
        if action == 'click' and ref:
            stdout, code = run_agent_cmd(["click", ref])
        elif action in ['fill', 'type'] and ref:
            stdout, code = run_agent_cmd([action, ref, str(val)])
        elif action == 'press' and val:
            stdout, code = run_agent_cmd(["press", str(val)])
        elif action == 'navigate' and val:
            stdout, code = run_agent_cmd(["open", str(val)])

        # Settle wait
        wait_text = step.get('wait_for_text')
        if wait_text:
            run_agent_cmd(["wait", "--text", str(wait_text)])
        else:
            run_agent_cmd(["wait", "--load", "networkidle"])
        time.sleep(0.25)

        # Screenshot
        cmd_screen = ["screenshot", img_path]
        if step.get('full_page', False):
            cmd_screen.append("--full-page")
        run_agent_cmd(cmd_screen)

        manifest_steps.append({
            "step": idx,
            "name": step_name,
            "filename": img_name,
            "action": action,
            "sensitive": is_sensitive,
            "value": "[REDACTED]" if is_sensitive else str(raw_val),
            "status": "completed"
        })

finally:
    print(f"Cleaning up browser session ({session_name})...")
    subprocess.run(["agent-browser", "--session", session_name, "close"], capture_output=True, text=True)

manifest = {
    "journey_name": journey_name,
    "start_url": start_url,
    "timestamp": datetime.now(timezone.utc).isoformat(),
    "output_directory": output_dir,
    "steps": manifest_steps,
    "status": "completed"
}

with open(os.path.join(output_dir, "journey.json"), "w", encoding="utf-8") as f:
    json.dump(manifest, f, indent=2)

print(f"Journey execution finished. Screenshots and manifest saved to {output_dir}/")
PYEOF

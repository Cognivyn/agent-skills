#!/usr/bin/env bash
set -euo pipefail

# run-journey.sh
# Modular, robust runner script for journey-capture flows using agent-browser CLI.

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

# Execute journey using modular Python helper (stdlib only)
python3 - "$JOURNEY_FILE" "$OUTPUT_DIR" "$DRY_RUN" "$ALLOW_DESTRUCTIVE" "$ALLOW_SENSITIVE" "$ALLOW_CROSS_ORIGIN" "$STEP_TIMEOUT" "$GLOBAL_TIMEOUT" <<'PYEOF'
import sys
import os
import json
import re
import subprocess
import time
from datetime import datetime, timezone
from urllib.parse import urlparse

# CLI arguments
journey_file = sys.argv[1]
custom_output_dir = sys.argv[2]
dry_run = sys.argv[3].lower() == 'true'
allow_destructive = sys.argv[4].lower() == 'true'
allow_sensitive = sys.argv[5].lower() == 'true'
allow_cross_origin = sys.argv[6].lower() == 'true'
step_timeout = int(sys.argv[7])
global_timeout = int(sys.argv[8])

DESTRUCTIVE_KEYWORDS = ["delete", "remove", "cancel account", "unsubscribe", "purge", "destroy"]
LOCAL_HOSTS = ["localhost", "127.0.0.1", "::1", "[::1]"]
GENERIC_ROLES = {"button", "input", "select", "textarea", "link", "field", "form", "option"}

# ==========================================
# 1. YAML / JSON Parser Module
# ==========================================
def parse_journey(filepath):
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()

    try:
        return json.loads(content)
    except json.JSONDecodeError:
        pass

    # Indentation-aware lightweight YAML parser for journey schemas
    data = {'name': '', 'start_url': '', 'viewport': {}, 'before_journey': [], 'steps': []}
    lines = content.splitlines()

    current_section = None
    current_item = None

    for line in lines:
        stripped = line.strip()
        if not stripped or stripped.startswith('#'):
            continue

        indent = len(line) - len(line.lstrip())

        if indent == 0:
            if current_item and current_section:
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
            data['viewport'][k.strip()] = int(v.strip())
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

# ==========================================
# 2. Variable Resolution & Safety Module
# ==========================================
def resolve_env_vars(val, step_name):
    if isinstance(val, str) and val.startswith("${") and val.endswith("}"):
        var_name = val[2:-1]
        resolved = os.getenv(var_name)
        if resolved is None:
            print(f"Error: Environment variable '{var_name}' required for step '{step_name}' is not set.")
            sys.exit(1)
        return resolved
    return val

def check_destructive(step_name, action, target, raw_val):
    step_str = f"{action} {target} {raw_val}".lower()
    if not allow_destructive and any(kw in step_str for kw in DESTRUCTIVE_KEYWORDS):
        print(f"Error: Step '{step_name}' contains potentially destructive action keyword. Pass --allow-destructive to run.")
        sys.exit(1)

def check_transport(step_name, current_url, is_sensitive):
    parsed = urlparse(current_url)
    if is_sensitive and parsed.scheme == "http" and parsed.hostname not in LOCAL_HOSTS:
        print(f"Error: Step '{step_name}' handles sensitive input over unencrypted HTTP ({current_url}) (CWE-319). HTTPS required.")
        sys.exit(1)

# ==========================================
# 3. Agent-Browser CLI Command Module
# ==========================================
session_name = ""

def run_agent_cmd(args):
    cmd = ["agent-browser"] + args + ["--session", session_name]
    try:
        res = subprocess.run(cmd, capture_output=True, text=True, timeout=step_timeout)
        return res.stdout.strip(), res.stderr.strip(), res.returncode
    except Exception as e:
        return "", str(e), 1

def check_origin(initial_origin):
    if allow_cross_origin:
        return True
    url_out, stderr, code = run_agent_cmd(["eval", "window.location.href"])
    if code != 0 or not url_out:
        print(f"Error: Could not verify current page origin (CWE-346 closed-fail). {stderr}")
        return False
    cur_origin = urlparse(url_out.strip().strip('"\'')).netloc
    if not cur_origin or cur_origin != initial_origin:
        print(f"Error: Cross-origin redirect/navigation to '{cur_origin}' detected (CWE-346). Pass --allow-cross-origin to permit.")
        return False
    return True

# ==========================================
# 4. Element Target Ref Resolution Module
# ==========================================
def resolve_target_ref(target):
    snapshot_out, stderr, code = run_agent_cmd(["snapshot", "-i"])
    if code != 0:
        return None, f"Snapshot failed: {stderr}"

    target_clean = target.lower().strip()
    words = [w for w in re.findall(r'\w+', target_clean) if len(w) > 1]
    meaningful_words = [w for w in words if w not in GENERIC_ROLES]

    best_ref = None
    best_score = -1

    for line in snapshot_out.splitlines():
        if '[ref=' not in line:
            continue
        line_clean = line.lower()
        match = re.search(r'\[ref=(e\d+)\]', line)
        if not match:
            continue
        ref = "@" + match.group(1)

        # Require all meaningful non-generic words to match
        if meaningful_words and not all(w in line_clean for w in meaningful_words):
            continue

        score = sum(1 for w in words if w in line_clean)
        if target_clean in line_clean:
            score += 100

        if score > best_score:
            best_score = score
            best_ref = ref

    if not best_ref and not meaningful_words:
        # Strict fall-back if target consists entirely of words
        for line in snapshot_out.splitlines():
            if target_clean in line.lower() and '[ref=' in line:
                match = re.search(r'\[ref=(e\d+)\]', line)
                if match:
                    return "@" + match.group(1), ""

    if not best_ref:
        return None, f"Target '{target}' did not match any snapshot element with confidence."

    return best_ref, ""

# ==========================================
# 5. Sensitive Style Masking Module
# ==========================================
def mask_sensitive_elements():
    mask_js = """
    (function() {
        const saved = [];
        document.querySelectorAll('input, select, textarea, [sensitive]').forEach(el => {
            if (el.type === 'password' || el.hasAttribute('sensitive') || (el.name && el.name.includes('password')) || (el.id && el.id.includes('password'))) {
                saved.push({ element: el, prevFilter: el.style.filter || '' });
                el.style.filter = 'blur(10px) brightness(0.5)';
            }
        });
        window.__journey_masked_styles = saved;
    })();
    """
    run_agent_cmd(["eval", mask_js])

def unmask_sensitive_elements():
    unmask_js = """
    (function() {
        if (window.__journey_masked_styles) {
            window.__journey_masked_styles.forEach(item => {
                if (item.element) item.element.style.filter = item.prevFilter;
            });
            delete window.__journey_masked_styles;
        }
    })();
    """
    run_agent_cmd(["eval", unmask_js])

# ==========================================
# 6. Main Journey Execution Controller
# ==========================================
journey = parse_journey(journey_file)
journey_name = journey.get('name', 'journey')
start_url = journey.get('start_url', 'http://localhost')
viewport = journey.get('viewport', {})
before_journey = journey.get('before_journey', [])
steps = journey.get('steps', [])

output_dir = custom_output_dir if custom_output_dir else f"./journey-screenshots/{journey_name}"

print(f"=== Journey Execution Configuration ===")
print(f"Journey Name      : {journey_name}")
print(f"Start URL         : {start_url}")
print(f"Output Directory  : {output_dir}")
print(f"Viewport          : {viewport.get('width', 1280)}x{viewport.get('height', 800)}")
print(f"Dry Run           : {dry_run}")
print(f"Allow Destructive : {allow_destructive}")
print(f"Allow Sensitive   : {allow_sensitive}")
print(f"Allow Cross-Origin: {allow_cross_origin}")
print(f"Setup Steps       : {len(before_journey)}")
print(f"Main Steps        : {len(steps)}")
print(f"=======================================")

if dry_run:
    print(f"[DRY-RUN] Would create directory: {output_dir}")
    print(f"[DRY-RUN] Would open session: agent-browser open \"{start_url}\" --session \"{journey_name}-session\"")
    if viewport:
        print(f"[DRY-RUN] Would set viewport: {viewport.get('width', 1280)}x{viewport.get('height', 800)}")
    for idx, b_step in enumerate(before_journey, 1):
        print(f"[DRY-RUN] Setup Step {idx}: {b_step.get('action')} {b_step.get('target', '')}")
    for idx, step in enumerate(steps, 1):
        slug = re.sub(r'[^a-z0-9]+', '-', step.get('name', f'step-{idx}').lower()).strip('-')
        img_name = f"{idx:02d}-{slug}.png"
        print(f"[DRY-RUN] Step {idx:02d}: {step.get('name')} -> {img_name}")
    print("[DRY-RUN] Dry run complete.")
    sys.exit(0)

os.makedirs(output_dir, exist_ok=True)
session_name = f"{journey_name}-session"
initial_origin = urlparse(start_url).netloc
start_time = time.time()
manifest_steps = []

def execute_action(step_name, action, target, val, is_sensitive):
    ref = None
    if action in ['click', 'fill', 'type'] and target:
        ref, err = resolve_target_ref(target)
        if not ref:
            return False, f"Target ref resolution failed: {err}"

    if action == 'click' and ref:
        out, err, code = run_agent_cmd(["click", ref])
    elif action in ['fill', 'type'] and ref:
        out, err, code = run_agent_cmd([action, ref, str(val)])
    elif action == 'press' and val:
        out, err, code = run_agent_cmd(["press", str(val)])
    elif action == 'navigate' and val:
        out, err, code = run_agent_cmd(["open", str(val)])
    elif action == 'wait':
        if str(val).lower() == 'networkidle':
            out, err, code = run_agent_cmd(["wait", "--load", "networkidle"])
        else:
            out, err, code = run_agent_cmd(["wait", "--text", str(val)])
    else:
        out, err, code = "", "", 0

    if code != 0:
        return False, f"Action '{action}' failed: {err if err else out}"
    return True, ""

try:
    print(f"Opening browser session ({session_name})...")
    out, err, code = run_agent_cmd(["open", start_url])
    if code != 0:
        print(f"Error initializing session: {err if err else out}")
        sys.exit(1)

    if viewport:
        vw = viewport.get('width', 1280)
        vh = viewport.get('height', 800)
        run_agent_cmd(["viewport", str(vw), str(vh)])

    # Execute Setup Steps (before_journey)
    for idx, b_step in enumerate(before_journey, 1):
        if time.time() - start_time > global_timeout:
            print(f"Error: Global journey timeout of {global_timeout}s exceeded during setup.")
            sys.exit(1)

        b_action = b_step.get('action', 'wait')
        b_target = b_step.get('target', '')
        b_raw_val = b_step.get('value', '')
        b_val = resolve_env_vars(b_raw_val, f"before_journey-{idx}")
        b_sens = b_step.get('sensitive', False)

        check_destructive(f"before_journey-{idx}", b_action, b_target, b_raw_val)

        url_out, _, _ = run_agent_cmd(["eval", "window.location.href"])
        cur_url = url_out.strip().strip('"\'') if url_out else start_url
        check_transport(f"before_journey-{idx}", cur_url, b_sens)

        print(f"Executing Setup Step {idx}: [{b_action}] {b_target}".strip())
        ok, err_msg = execute_action(f"before_journey-{idx}", b_action, b_target, b_val, b_sens)
        if not ok:
            print(f"Error in setup step {idx}: {err_msg}")
            sys.exit(1)

        if not check_origin(initial_origin):
            sys.exit(1)

    # Execute Main Journey Steps
    for idx, step in enumerate(steps, 1):
        if time.time() - start_time > global_timeout:
            print(f"Error: Global journey timeout of {global_timeout}s exceeded.")
            sys.exit(1)

        if not check_origin(initial_origin):
            sys.exit(1)

        step_name = step.get('name', f'step-{idx}')
        slug = re.sub(r'[^a-z0-9]+', '-', step_name.lower()).strip('-')
        img_name = f"{idx:02d}-{slug}.png"
        img_path = os.path.join(output_dir, img_name)

        action = step.get('action', 'wait')
        target = step.get('target', '')
        raw_val = step.get('value', '')
        val = resolve_env_vars(raw_val, step_name)
        is_sensitive = step.get('sensitive', False)

        url_out, _, _ = run_agent_cmd(["eval", "window.location.href"])
        cur_url = url_out.strip().strip('"\'') if url_out else start_url
        check_transport(step_name, cur_url, is_sensitive)
        check_destructive(step_name, action, target, raw_val)

        log_val = "[REDACTED]" if is_sensitive and not allow_sensitive else val
        print(f"Executing Step {idx:02d}: {step_name} [{action}] {target} {log_val if log_val else ''}".strip())

        ok, err_msg = execute_action(step_name, action, target, val, is_sensitive)
        if not ok:
            print(f"Error in Step {idx:02d} ({step_name}): {err_msg}")
            manifest_steps.append({
                "step": idx,
                "name": step_name,
                "filename": img_name,
                "action": action,
                "sensitive": is_sensitive,
                "status": "failed",
                "error": err_msg
            })
            sys.exit(1)

        if not check_origin(initial_origin):
            sys.exit(1)

        # Settle Wait Handling
        wait_text = step.get('wait_for_text')
        if wait_text:
            w_out, w_err, w_code = run_agent_cmd(["wait", "--text", str(wait_text)])
        else:
            w_out, w_err, w_code = run_agent_cmd(["wait", "--load", "networkidle"])

        if w_code != 0:
            print(f"Error during wait settling in Step {idx:02d}: {w_err if w_err else w_out}")
            sys.exit(1)

        time.sleep(0.25)

        # Screenshot Capture with Masking Style Preservation
        if is_sensitive and not allow_sensitive:
            mask_sensitive_elements()

        cmd_screen = ["screenshot", img_path]
        if step.get('full_page', False):
            cmd_screen.append("--full-page")
        s_out, s_err, s_code = run_agent_cmd(cmd_screen)

        if is_sensitive and not allow_sensitive:
            unmask_sensitive_elements()

        if s_code != 0:
            print(f"Error capturing screenshot in Step {idx:02d}: {s_err if s_err else s_out}")
            sys.exit(1)

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

# Write Manifest
manifest = {
    "journey_name": journey_name,
    "start_url": start_url,
    "timestamp": datetime.now(timezone.utc).isoformat(),
    "output_directory": output_dir,
    "steps": manifest_steps,
    "status": "completed" if len(manifest_steps) == len(steps) else "failed"
}

manifest_path = os.path.join(output_dir, "journey.json")
with open(manifest_path, "w", encoding="utf-8") as f:
    json.dump(manifest, f, indent=2)

# ==========================================
# 7. Terminal Summary Report Output
# ==========================================
print("\n## journey-capture\n")
print(f"**Journey**: {journey_name}")
print(f"**Start URL**: {start_url}")
print(f"**Output Directory**: {output_dir}")
print(f"**Screenshots Captured**: {len(manifest_steps)} step(s)")
print(f"**Manifest**: {manifest_path}\n")
print("| Step | Name | Filename | Status |")
print("| --- | --- | --- | --- |")
for s in manifest_steps:
    status_str = "Success" if s["status"] == "completed" else "Failed"
    print(f"| {s['step']:02d} | {s['name']} | {s['filename']} | {status_str} |")
print("\nJourney execution complete.")
PYEOF

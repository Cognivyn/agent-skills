# journey-capture

`journey-capture` automates multi-step screenshot capture across web application user flows (such as signup, onboarding, checkout, and multi-step forms) using the [`agent-browser`](https://agent-browser.dev/) CLI.

It executes journey definitions, captures zero-padded, ordered screenshots for each step, and generates a structured `journey.json` manifest.

## Use it when

Ask an agent to:
- **Screenshot a user flow / journey / funnel.**
- **Document the signup / onboarding / checkout process.**
- **Capture every screen in [named flow].**
- **Visually test [multi-step process].**
- **Run this journey file and give me screenshots.**

## Quick Start

1. Ensure `agent-browser` is installed and initialized:
   ```bash
   npm install -g agent-browser
   agent-browser install
   ```
2. Validate a journey specification file:
   ```bash
   ./journey-capture/scripts/validate-journey.sh journey-capture/references/examples/signup-journey.yaml
   ```
3. Run the journey in dry-run mode or full execution:
   ```bash
   ./journey-capture/scripts/run-journey.sh journey-capture/references/examples/signup-journey.yaml --dry-run
   ./journey-capture/scripts/run-journey.sh journey-capture/references/examples/signup-journey.yaml --output-dir ./journey-screenshots/signup
   ```

## CLI Usage and Flags

```text
run-journey.sh [options] <journey-file>

Options:
  --output-dir <path>       Directory to save screenshots and manifest (default: ./journey-screenshots/<name>)
  --dry-run                 Preview actions and outputs without launching browser
  --allow-destructive       Allow actions matching destructive keyword deny-list
  --allow-sensitive-capture Capture unmasked screenshots of sensitive fields
  --allow-cross-origin      Allow navigation to external domain origins
  --step-timeout <seconds>  Per-step timeout limit (default: 30)
  --global-timeout <seconds> Overall execution timeout limit (default: 600)
```

## Output Layout

Output directories contain numbered screenshot files and metadata:

```text
journey-screenshots/signup/
├── 01-landing-page.png
├── 02-enter-email.png
├── 03-welcome-dashboard.png
└── journey.json
```

## Safety Behavior & Security Boundaries

- **Destructive Action Block**: Automatically blocks actions matching `delete`, `remove`, `cancel account`, `unsubscribe`, `purge`, `destroy` unless `--allow-destructive` is supplied.
- **Process Secret Protection**: Sensitive values are passed via environment variables during CLI execution to prevent exposure in process lists (`ps` / `CWE-214`).
- **Transport Security**: Requires HTTPS transport for non-local hosts when processing sensitive inputs (`CWE-319`).
- **Sensitive Field Masking**: Password inputs and sensitive fields are blurred/masked in screenshots (`CWE-200`) unless `--allow-sensitive-capture` is enabled. Values are redacted (`[REDACTED]`) from logs and `journey.json`.
- **Origin Enforcement**: Enforces same-origin boundaries after redirects and actions (`CWE-346`) unless `--allow-cross-origin` is passed.
- **Session Cleanup**: Active browser sessions are automatically closed on exit (`finally` / `trap`) even when errors occur.

## Schema & Cheatsheet

For full journey YAML specifications and CLI commands, consult:
- [`SKILL.md`](../../../journey-capture/SKILL.md)
- [`journey-schema.md`](../../../journey-capture/references/journey-schema.md)
- [`agent-browser-cheatsheet.md`](../../../journey-capture/references/agent-browser-cheatsheet.md)

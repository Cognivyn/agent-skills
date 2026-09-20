# journey-capture

`journey-capture` automates multi-step screenshot capture across web application user flows (such as signup, onboarding, checkout, and multi-step forms) using the [`agent-browser`](https://agent-browser.dev/) CLI.

It executes journey definitions, captures zero-padded, ordered screenshots for each step, and generates a structured `journey.json` manifest.

## Quick Start

1. Ensure `agent-browser` is installed:
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

## Output Layout

Output directories contain numbered screenshot files and metadata:

```text
journey-screenshots/signup/
├── 01-landing-page.png
├── 02-enter-email.png
├── 03-welcome-dashboard.png
└── journey.json
```

## Workflow & Safety Policies

See [`SKILL.md`](../../../journey-capture/SKILL.md) for the authoritative workflow, CLI flag reference, credential hygiene rules, transport security requirements, and same-origin guardrails.

## Reference Guides

- [`SKILL.md`](../../../journey-capture/SKILL.md)
- [`journey-schema.md`](../../../journey-capture/references/journey-schema.md)
- [`agent-browser-cheatsheet.md`](../../../journey-capture/references/agent-browser-cheatsheet.md)

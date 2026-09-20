---
name: journey-capture
description: >-
  Automates step-by-step screenshot capture across a web application user journey
  (signup, onboarding, checkout, multi-step forms, etc.) using the agent-browser
  CLI. Produces a numbered set of screenshots plus a journey.json manifest for
  documentation, visual regression, or UX review.
---

# journey-capture

Automate multi-step user journey screen captures across web applications using
`agent-browser`. This skill executes user flows (e.g. signup, onboarding, checkout),
captures screenshots at each state transition, and writes structured metadata to
`journey.json`.

## When to use

Use this skill when asked to:
- "Screenshot a user flow / journey / funnel."
- "Document the signup / onboarding / checkout process."
- "Capture every screen in [named flow]."
- "Visually test [multi-step process]."
- "Run this journey file and give me screenshots."

Do **NOT** use this skill for single, one-off screenshots without a multi-step user
flow (use `agent-browser screenshot` directly instead) or general non-interactive browser tasks.

## Workflow

Follow this sequence for executing a user journey flow:

### 1. Preparation & Dry Run

1. Identify or load the journey steps (YAML file or step list).
2. Validate journey format using `./journey-capture/scripts/validate-journey.sh <journey-file>`.
3. Set destination output directory (default: `./journey-screenshots/<journey-name>/`).
4. (Optional) Perform dry run with `./journey-capture/scripts/run-journey.sh --dry-run <journey-file>` to preview steps and resolved paths.

### 2. Session Initialization & Authentication

1. Initialize a named `agent-browser` session to maintain state across steps:
   ```bash
   agent-browser open "<start-url>" --session "<journey-name>"
   ```
2. If authentication or initial setup (`before_journey`) is specified:
   - Load credentials from environment variables only (e.g. `${TEST_USER_EMAIL}`).
   - Never pass hardcoded passwords via CLI flags or log statements.

### 3. Step Execution Loop

For each step in the journey:

#### A. Snapshot Before Action (Mandatory)
Before interacting with any element, inspect the current page state:
```bash
agent-browser snapshot -i
```
Parse the returned accessibility tree refs (`@e1`, `@e2`, ...). Select the matching element ref dynamically for the action target. **Never reuse or hardcode ref identifiers across steps.**

#### B. Perform Action
Execute target interaction using the resolved ref:
- Click: `agent-browser click @eN`
- Fill / Type: `agent-browser fill @eN "<value>"` or `agent-browser type @eN "<value>"`
- Key Press: `agent-browser press <key>`

If a step is marked `sensitive: true`:
- Redact value from console output and manifest logs.
- Mask target field in screenshots unless explicit user override `--allow-sensitive-capture` is enabled.

#### C. Wait Strategy
Prior to taking a screenshot, enforce settling:
1. `agent-browser wait --load networkidle`
2. `agent-browser wait --text "<expected-text>"` (if step defines expected text/SPA target)
3. Fixed 250 ms delay for rendering/animations to settle.

#### D. Screenshot Capture
Capture step state with zero-padded sequence numbers and kebab-case step names:
```bash
agent-browser screenshot ./journey-screenshots/<journey-name>/<NN>-<step-slug>.png
```
- Example filenames: `01-landing-page.png`, `02-signup-form.png`, `03-welcome.png`.
- Multi-shot sub-steps use letter suffixes: `03a-form-filled.png`, `03b-validation-error.png`.

#### E. Modal & State Checks
- Modal dialogs should be handled as explicit journey steps.
- If an unhandled modal or unexpected blocking element appears, pause execution and report error. Do not blindly dismiss dialogs.
- Loop detection: If identical URL + DOM snapshot hash repeats 3 times without progress, abort and report stuck journey.

### 4. Manifest Generation & Cleanup

1. Generate `journey.json` in the output directory containing:
   - Journey name, start URL, timestamp, `agent-browser` CLI version.
   - Per-step metadata (step name, image filename, URL, viewport, full-page flag).
   - Sensitive fields redacted (`"[REDACTED]"`).
2. Clean up browser session safely:
   ```bash
   agent-browser --session "<journey-name>" close
   ```

## Helper Scripts

Use the provided scripts to execute and validate journeys without cluttering agent context:

```bash
# Validate journey schema
./journey-capture/scripts/validate-journey.sh path/to/journey.yaml

# Run journey flow
./journey-capture/scripts/run-journey.sh path/to/journey.yaml --output-dir ./journey-screenshots/signup
```

## Safety Rules & Guardrails

- **Destructive Actions Deny-list**: Automatically block actions containing `delete`, `remove`, `cancel account`, `unsubscribe`, `purge`, `destroy` unless explicitly overridden with `--allow-destructive`.
- **Credential Hygiene**: Credentials must come strictly from environment variables. Never print, write to `journey.json`, or log passwords/tokens.
- **Session Cleanup**: Always close open sessions via exit trap (`agent-browser --session <name> close`), even upon error or failure.
- **Same-Origin Enforcement**: Restrict navigation to same-origin URLs unless `--allow-cross-origin` is passed.
- **Timeouts**: Per-step timeout max 30s; global journey timeout max 600s.

## Required Report

Upon completion, output a summary report formatted as:

```text
## journey-capture

**Journey**: <journey-name>
**Start URL**: <start-url>
**Output Directory**: ./journey-screenshots/<journey-name>/
**Screenshots Captured**: <N> step(s)
**Manifest**: ./journey-screenshots/<journey-name>/journey.json

| Step | Name | Filename | Status |
| --- | --- | --- | --- |
| 01 | Landing Page | 01-landing-page.png | Success |
| 02 | Signup Form | 02-signup-form.png | Success |
```

## Validation

Validate this skill package from the repository root:

```bash
./agent-skills validate journey-capture
python -m unittest discover -s tests -v
python scripts/check_md_links.py
```

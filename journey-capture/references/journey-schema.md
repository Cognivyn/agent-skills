# Journey Specification & Schema

This reference guide describes the schema and parameters for specifying user journey YAML files with `journey-capture`.

## Schema Structure

A journey file is written in YAML or JSON format and contains top-level configuration plus an ordered list of step definitions.

```yaml
name: string               # Required: Kebab-case identifier for the journey
description: string        # Optional: Human-readable description
start_url: string          # Required: Initial URL to open
viewport:                  # Optional: Custom screen resolution
  width: number            # Default: 1280
  height: number           # Default: 800
before_journey:            # Optional: Setup or login actions before main steps
  - action: string
    target: string
    value: string
steps:                     # Required: Ordered list of journey steps
  - name: string           # Required: Step name (converted to filename slug)
    description: string    # Optional: Explanation of step purpose
    action: string         # Required: click | fill | type | press | wait | navigate
    target: string         # Description of target UI element (matched against snapshot refs)
    value: string          # Input string for fill/type actions
    sensitive: boolean     # If true, masks inputs and screenshot field
    wait_for_text: string  # Optional text to wait for before capturing screenshot
    full_page: boolean     # Capture full-page screenshot if true
```

## Supported Action Types

| Action | Required Fields | Description | Example |
| --- | --- | --- | --- |
| `navigate` | `value` | Navigates to a specific URL | `action: navigate, value: "https://example.com/signup"` |
| `click` | `target` | Clicks target element matched via `snapshot -i` | `action: click, target: "Submit button"` |
| `fill` | `target`, `value` | Clears and sets input value | `action: fill, target: "Email input", value: "${TEST_EMAIL}"` |
| `type` | `target`, `value` | Types keystrokes into targeted input | `action: type, target: "Search input", value: "query"` |
| `press` | `value` | Emits single keypress (e.g. `Enter`, `Tab`, `Escape`) | `action: press, value: "Enter"` |
| `wait` | `value` | Pauses for explicit text or network idle state | `action: wait, value: "networkidle"` |

## Variable Expansion & Credential Hygiene

- Use environment variable references like `${TEST_USER_EMAIL}` or `${TEST_USER_PASSWORD}` inside `value` fields.
- Never place raw passwords, API tokens, or personal identifiers directly in the YAML file.
- Setting `sensitive: true` on a step ensures that input values are replaced with `"[REDACTED]"` in logs and manifest files.

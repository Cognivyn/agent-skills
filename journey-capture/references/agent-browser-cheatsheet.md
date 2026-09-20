# agent-browser Cheatsheet for journey-capture

Quick reference of `agent-browser` CLI commands used during journey execution.

## Core Commands

### Navigation & Session Management
```bash
# Open URL in named session
agent-browser open "https://example.com" --session "signup-flow"

# Close session
agent-browser --session "signup-flow" close
```

### Element Inspection & Ref Resolution
```bash
# Take interactive snapshot (returns ref IDs like @e1, @e2)
agent-browser snapshot -i
```

### Target Interaction using Refs
```bash
# Click target
agent-browser click @e2

# Fill text into input
agent-browser fill @e1 "user@example.com"

# Press key
agent-browser press Enter
```

### Settling & Wait Controls
```bash
# Wait for network idle
agent-browser wait --load networkidle

# Wait for expected text on page
agent-browser wait --text "Welcome back"

# Custom JS expression wait
agent-browser wait --fn "document.fonts.ready"
```

### Screenshot Capture
```bash
# Capture standard screenshot
agent-browser screenshot ./journey-screenshots/signup/01-landing.png

# Capture full page screenshot
agent-browser screenshot ./journey-screenshots/signup/01-landing-full.png --full-page
```

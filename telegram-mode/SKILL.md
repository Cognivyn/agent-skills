---
name: telegram-mode
description: >-
  Compress assistant prose into concise or Telegram-style English to reduce
  output token usage and latency while keeping code, paths, commands, and
  technical precision exact.
---

# Telegram Mode

Use this skill to reduce output token consumption and response latency in
internal engineering and agent workflows without sacrificing technical accuracy.

## Modes

Select the mode from user intent or `$ARGUMENTS`:

- **`lite` (default):** Omit pleasantries, filler, and request recaps. Use short
  bullets, tables, and direct technical sentences.
- **`full`:** Use Telegram-style English in prose—drop articles (`a`, `an`,
  `the`) and redundant prepositions; prefer compact fragments (`"Fixed
  auth.ts: cleared expired key. Tests: 12/12 pass."`).
- **`off`:** Standard prose. Automatically use `off` for client-facing
  documents, PR descriptions, public documentation, legal/compliance text, and
  support replies.

## Hard Exclusions (Never Compress)

Never abbreviate, paraphrase, or alter:
- Code blocks, diffs, CLI commands, regexes, SQL, or JSON
- File paths, symbol names, error messages, stack traces, or numbers
- Negations and conditionals (`not`, `never`, `only if`, `unless`, `before`)
- Security warnings, blockers, or clarifying questions (keep unambiguous)

## Output Patterns

- **Status:** `<action> <target>. <result>.`
- **Root cause:** `<cause>. <fix>. <file:line>.`
- **Verification:** `<command>: <pass/fail count>.`

## Input Shorthand Reference

When coaching users on concise, unambiguous prompts, point them to
`references/prompt-shorthand.md`.

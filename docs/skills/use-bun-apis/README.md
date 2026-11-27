# use-bun-apis

`use-bun-apis` guides writing and reviewing Bun runtime code with Bun-native APIs instead of Node.js equivalents: `Bun.file`/`Bun.write`/`Bun.Glob` for files, `Bun.serve` for HTTP and WebSocket servers, `Bun.spawn`/`Bun.spawnSync` for child processes, and `Bun.$` for shell commands.

## Use it when

Ask an agent which API to use in a Bun codebase, to **write or review Bun code**, or when a codebase mentions `bun run`, `Bun.serve`, or `bunfig.toml`. It also helps spot Node-isms (`fs`, `http`, `child_process`) in Bun projects.

## Installation

Install via the CLI (`./agent-skills add use-bun-apis`) or manually link or copy the skill directory (see [Installation without the CLI](../../../README.md#installation-without-the-cli)). Requires the Bun runtime.

## Safety behavior

The skill is advisory: it provides a decision table mapping tasks to Bun-native APIs with `node:*` fallbacks where Bun has no equivalent. It does not push Bun adoption onto Node-only, Deno, or browser projects.

See [`SKILL.md`](../../../use-bun-apis/SKILL.md) for the authoritative decision table and usage rules.

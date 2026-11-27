# pc-lean-and-trim

`pc-lean-and-trim` audits, leans, and prevents disk space bloat on Windows 11 developer systems without impacting performance. It enforces a 100% read-only dry-run first, strict path whitelisting, hard-coded forbidden-zone sentinels, and explicit user confirmation gates. It handles WSL2/Docker sparse VHDs, Delivery Optimization, WinSxS/DISM component cleanup, hibernation tuning, temp purging, and cleanup of idle project `node_modules`.

## Use it when

Ask an agent to **clean disk space**, **audit PC storage**, **trim Windows bloat**, or **reduce WSL/Docker VHD size** on a Windows 11 machine.

## Installation

Install via the CLI (`./agent-skills add pc-lean-and-trim`) or manually link or copy the skill directory (see [Installation without the CLI](../../../README.md#installation-without-the-cli)). Requires PowerShell 5.1+ on Windows.

## Safety behavior

The skill is built around an ironclad safety contract: every run starts with a read-only audit and dry-run report, deletions are limited to a hard-coded whitelist with forbidden-zone sentinels (user profiles, source code, system directories are never touched), and every destructive step requires explicit user confirmation — including a checkbox confirmation in the GUI flow.

See [`SKILL.md`](../../../pc-lean-and-trim/SKILL.md) for the authoritative workflow and the mandatory agent behavioral contract.

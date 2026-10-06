# Windows Disk & Storage Diagnostics (`win-disk-diagnostics`)

A unified, non-destructive diagnostic skill for investigating, analyzing, and reclaiming storage space on Windows 10 and 11 workstations.

## Overview

This skill equips agents to conduct storage investigations on Windows machines without risking accidental file deletion or service interruption. It brings together:

- **Zero-Dependency Native PowerShell Engine**: Instant drive volume health meters, top-N largest file audits, and directory footprint calculations without external dependencies.
- **Developer-Aware Storage Intelligence**: Detection of WSL2 virtual disks (`ext4.vhdx`), Docker Desktop allocations, package caches (Bun, Cargo, npm, pip), and stale `node_modules` trees.
- **NT Storage Diagnostics**: Accounting for locked kernel space (`pagefile.sys`, `hiberfil.sys`, `swapfile.sys`), Volume Shadow Copies (VSS), and WinSxS Component Store deduplication.
- **Graded Remediation Runbook**: Copy-ready cleanup commands classified by safety tier (`Zero`, `Low`, `Medium`).

For the complete diagnostic agent instructions, refer to [`SKILL.md`](../../../win-disk-diagnostics/SKILL.md).

---

## When to Use

- A Windows drive partition (particularly `C:`) is running low on disk space or flagged critical (>90% full).
- Space calculations reported by standard folder properties do not match actual drive consumption.
- Identifying developer bloat (WSL2 disk expansion, package manager caches, stale project dependencies).
- Performing a structured storage audit before executing any disk cleanup routine.

---

## Safety Guarantees

1. **Strictly Read-Only by Default**: Diagnostic inspections do not modify, move, or delete files.
2. **Least Privilege**: Standard scans run under non-administrator user permissions without prompting for elevation.
3. **No Blind Cloud Hydration**: Safeguards against traversing cloud reparse points that trigger forced downloads.
4. **Explicit Human Confirmation**: All suggested remediations require explicit review and confirmation before execution.

---

## Core Resources

- **Main Agent Runbook**: [`SKILL.md`](../../../win-disk-diagnostics/SKILL.md)
- **PowerShell Diagnostics Utility**: [`scripts/Analyze-DiskSpace.ps1`](../../../win-disk-diagnostics/scripts/Analyze-DiskSpace.ps1)
- **Node Modules Audit Utility**: [`scripts/Clean-NodeModules.ps1`](../../../win-disk-diagnostics/scripts/Clean-NodeModules.ps1)
- **WinSpace Lens Technical Guide**: [`references/winspace-lens-guide.md`](../../../win-disk-diagnostics/references/winspace-lens-guide.md)

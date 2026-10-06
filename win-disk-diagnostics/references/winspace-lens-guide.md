# WinSpace Lens Storage Diagnostic Reference

This reference explains the Windows-specific storage mechanics that make naive
disk reporting wrong, and maps each to the bundled PowerShell tooling.

> **Scope note.** Earlier revisions of this guide described a separate
> "WinSpace Lens" command-line engine invoked with `bun run`. That engine is
> **not part of this skill and is not present in this repository**. Every command
> below ships here and runs on stock Windows with PowerShell only. If you find a
> `bun run` invocation referenced anywhere in this skill, it is stale documentation.

## Core Storage Realities on Windows 11

Traditional recursive folder crawlers frequently fail or report misleading numbers on Windows systems due to NT-specific storage primitives:

1. **Locked Kernel Virtual Memory**:
   - `pagefile.sys`, `hiberfil.sys` (Fast Startup/Hibernate), and `swapfile.sys` reside at the drive root and are permanently locked by the NT kernel.
   - Directory walkers report access-denied and miss this space entirely. On a typical workstation this is 16–64 GB.
   - `Analyze-DiskSpace.ps1 -Drive C: -TopFiles` surfaces these because it enumerates the root directory itself, where they appear as ordinary file entries.
2. **Volume Shadow Copies (VSS)**:
   - System Restore points and shadow copies in `System Volume Information` occupy storage without appearing as standard files.
   - Can consume tens of gigabytes silently. Query with `vssadmin list shadowstorage` (read-only).
3. **WinSxS & Hardlink Deduplication**:
   - The Windows Component Store (`C:\Windows\WinSxS`) uses extensive NTFS hardlinks.
   - Naive tools multi-count hardlinks and report bloated sizes. A logical sum is an upper bound, not the true on-disk cost.
4. **Cloud Reparse Points & Hydration**:
   - Cloud sync providers (OneDrive, iCloud, Dropbox) use NTFS reparse points. Unfiltered recursion can trigger background network hydration, filling the drive with unwanted downloads.
   - `Get-StorageTreeFiles` in `src/Collectors.ps1` skips every reparse point and excludes cloud root names, so the bundled tooling cannot hydrate a cloud-synced tree.
5. **Developer Workstation Footprints**:
   - WSL2 virtual hard disks (`ext4.vhdx`) grow dynamically and do not automatically shrink when files are deleted inside Linux.
   - Docker Desktop data images (`docker_data.vhdx` / WSL backend).
   - Package manager global caches: Bun, Cargo, npm, pnpm, pip, Gradle, and HuggingFace cache models.

## Bounded Traversal

Every bundled traversal is depth-bounded. On a whole-drive scan the bound is
what keeps the run finite: an unbounded `C:` walk exceeded ten minutes on a
358 GB volume during testing, whereas `-MaxDepth 3` returns in roughly a minute.

| Switch | Default | Effect |
| --- | --- | --- |
| `-MaxDepth` | `4` | Directory levels to descend beneath the target. Range 1–16. |

Depth raises cost and breadth together. Widen it only for a specific tree whose
depth genuinely exceeds the default.

## Diagnostic Commands

### 1. Volume Health Audit

```powershell
# All fixed local volumes
powershell.exe -NoProfile -ExecutionPolicy Bypass -File ./win-disk-diagnostics/scripts/Analyze-DiskSpace.ps1

# Scope to one drive; omitting this reports every volume
powershell.exe -NoProfile -ExecutionPolicy Bypass -File ./win-disk-diagnostics/scripts/Analyze-DiskSpace.ps1 -Drive C:
```

### 2. Heaviest Files and Folders

```powershell
# Top 20 files on C:, descending at most 4 levels
powershell.exe -NoProfile -ExecutionPolicy Bypass -File ./win-disk-diagnostics/scripts/Analyze-DiskSpace.ps1 -Drive C: -TopFiles 20

# Top 10 immediate subdirectories of C:
powershell.exe -NoProfile -ExecutionPolicy Bypass -File ./win-disk-diagnostics/scripts/Analyze-DiskSpace.ps1 -Drive C: -TopFolders 10

# Go deeper when the default bound is too shallow
powershell.exe -NoProfile -ExecutionPolicy Bypass -File ./win-disk-diagnostics/scripts/Analyze-DiskSpace.ps1 -Drive C: -TopFiles 20 -MaxDepth 8
```

### 3. Machine-Readable Output

Use `-Json` when consuming results programmatically or as a sub-agent. It emits
JSON on stdout and suppresses all human-facing tables, so the output parses
without stripping ANSI or box-drawing characters.

```powershell
# Parseable JSON on stdout
powershell.exe -NoProfile -ExecutionPolicy Bypass -File ./win-disk-diagnostics/scripts/Analyze-DiskSpace.ps1 -Drive C: -TopFiles 20 -Json
```

`-Quiet` keeps the tables but drops the branded header and recommendations.

### 4. Stale `node_modules` Audit

```powershell
# Audit only, no deletions
powershell.exe -NoProfile -ExecutionPolicy Bypass -File ./win-disk-diagnostics/scripts/Clean-NodeModules.ps1 -Path "C:\Projects" -DryRun

# Preview exactly what a real run would delete
powershell.exe -NoProfile -ExecutionPolicy Bypass -File ./win-disk-diagnostics/scripts/Clean-NodeModules.ps1 -Path "C:\Projects" -WhatIf
```

`-WhatIf` is honoured for every deletion. `-DryRun` additionally skips the
interactive prompt entirely. Both are read-only.

### 5. NT Storage Commands

These ship with Windows and are read-only as invoked:

```cmd
vssadmin list shadowstorage
Dism.exe /Online /Cleanup-Image /AnalyzeComponentStore
```

## Safe Remediation Guidelines

All remediations must be presented as copy-ready PowerShell commands with explicit risk classifications:

| Category | Typical Location | Remediation Method | Risk Level |
| :--- | :--- | :--- | :--- |
| **Package Caches** | `~/.bun/install/cache`, `~/.cargo/registry` | `bun pm cache rm`, `cargo cache -a` | **Zero** |
| **Node Modules** | Stale development repos | `Clean-NodeModules.ps1 -DryRun` or `-WhatIf` first | **Zero** |
| **Windows Update Cache** | `SoftwareDistribution\Download` | Stop `wuauserv`, remove folder contents, restart service | **Low** |
| **WinSxS Component Store** | `C:\Windows\WinSxS` | `Dism.exe /Online /Cleanup-Image /StartComponentCleanup` | **Low** |
| **WSL2 Virtual Disk** | `%LOCALAPPDATA%\Packages\...\ext4.vhdx` | Shutdown WSL (`wsl --shutdown`), compact via `diskpart` | **Medium** |
| **Hibernation** | `C:\hiberfil.sys` | `powercfg /hibernate off` (disables Fast Startup) | **Medium** |

*Always prompt the user for confirmation before executing any cleanup or remediation commands.*

## Why Not Rust or Go?

Measured on the tooling in this repository, `Get-ChildItem -Recurse` was 4x to
15x slower than the raw `System.IO.Directory` walk this skill now uses, and the
walk runs at roughly 48,000 files/sec. That is syscall and metadata latency, not
language overhead, so a compiled rewrite does not change the order of magnitude.
The genuine step change would come from reading the NTFS Master File Table
directly, as WizTree and Everything do, but raw volume access (`\\.\C:`) requires
elevation and would break the skill's least-privilege guarantee. Keeping the
engine in PowerShell preserves zero-dependency, non-elevated operation.

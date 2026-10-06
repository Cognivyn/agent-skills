---
name: win-disk-diagnostics
description: >-
  Inspect, diagnose, and audit Windows storage volumes, locked NT kernel space,
  developer bloat (WSL2 vhdx, Docker blobs, package caches, node_modules), and
  OS waste. Use when a Windows system is low on disk space, when assessing
  reclaimable storage, or when generating privacy-safe storage diagnostic reports.
---

# Windows Disk & Storage Diagnostics (`win-disk-diagnostics`)

Comprehensive, strictly read-only diagnostics runbook for Windows storage volumes. Combines zero-dependency native PowerShell volume health checks with developer-aware NT storage diagnostics (locked kernel space, VSS shadow storage, OS component store, WSL2 vhdx, and package cache audits).

## Non-Negotiable Safety & Privacy Rules

- **Zero State Mutation by Default**: All investigative steps, directory measurements, and volume evaluations are strictly read-only. Never delete, relocate, or truncate files without explicit human confirmation.
- **Least Privilege Execution**: Standard inspections run in non-elevated user sessions. Do not demand administrative rights or bypass UAC unless running explicit OS-level DISM cleanup tasks with user approval.
- **Privacy First**: When reporting file paths or generating diagnostic logs, scrub personal usernames (`C:\Users\<USER>`), environment secrets, and sensitive leaf directory names.
- **No Blind Hydration**: Do not run naive recursive file scanners across cloud-synced storage roots (OneDrive, iCloud, Dropbox) that trip reparse points and trigger unwanted cloud downloads.
- **Classified Remediation**: All cleanup recommendations must be clearly graded by risk level (`Zero`, `Low`, `Medium`) with exact copy-ready commands.

---

## Workflow

### 1. Volume Health Assessment

Audit mounted storage drives, calculate total/used/free metrics, and identify critically constrained partitions (>90% full).

Execute the bundled zero-dependency PowerShell script from the skill package:

```powershell
# Run volume summary audit
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\Analyze-DiskSpace.ps1
```

If specific drive capacity is constrained (e.g. `C:`), inspect the top heaviest directories and files:

```powershell
# Measure top 10 heaviest directories on drive C:
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\Analyze-DiskSpace.ps1 -Drive C: -TopFolders 10

# Identify top 20 largest individual files on drive C:
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\Analyze-DiskSpace.ps1 -Drive C: -TopFiles 20
```

### 2. Identify NT Kernel & Hidden Space Allocation

When standard folder calculations do not account for missing space on `C:`, check locked kernel files and shadow storage:

1. **Kernel Virtual Memory Files**:
   - `pagefile.sys` and `swapfile.sys`: Paging and virtual memory allocations.
   - `hiberfil.sys`: Fast Startup and Hibernation image (typically 40–100% of physical RAM).
2. **Volume Shadow Copies (VSS)**:
   - Check allocated shadow storage used by System Restore points:
     ```powershell
     vssadmin list shadowstorage
     ```
3. **WinSpace Lens Diagnostics Engine**:
   - For detailed breakdown of locked kernel space, VSS allocations, and developer toolchain caches, refer to [WinSpace Lens Guide](./references/winspace-lens-guide.md).

### 3. Developer Workstation Bloat Audit

On developer machines, major space consumers reside in virtualized environments and package managers:

1. **WSL2 Virtual Hard Disks**:
   - Locate dynamically expanded `ext4.vhdx` disks:
     ```powershell
     Get-ChildItem -Path "$env:LOCALAPPDATA\Packages" -Filter "ext4.vhdx" -Recurse -ErrorAction SilentlyContinue | Select-Object FullName, Length
     ```
2. **Docker Desktop**:
   - Inspect Docker WSL data storage under `$env:LOCALAPPDATA\Docker\wsl\data\ext4.vhdx`.
3. **Stale `node_modules` Trees**:
   - Audit abandoned or duplicated `node_modules` folders across developer workspaces using the bundled scanner in dry-run mode:
     ```powershell
     powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\Clean-NodeModules.ps1 -Path "Z:\WSL\Consultancy\Git_Repos" -DryRun
     ```
4. **Global Package Caches**:
   - Bun: `~/.bun/install/cache`
   - Cargo: `~/.cargo/registry` and `~/.cargo/git`
   - npm: `npm cache verify` / `%LOCALAPPDATA%\npm-cache`
   - pip: `%LOCALAPPDATA%\pip\cache`

### 4. Windows OS Waste Audit

Inspect redundant operating system build remnants:

1. **SoftwareDistribution Download Cache**:
   - `%WINDIR%\SoftwareDistribution\Download` (remnants of completed Windows updates).
2. **Component Store (WinSxS)**:
   - Query if component cleanup is recommended:
     ```cmd
     Dism.exe /Online /Cleanup-Image /AnalyzeComponentStore
     ```
3. **Previous Windows Installations**:
   - `C:\Windows.old` (retained after major feature upgrades).
4. **Crash Dumps & Temp Directories**:
   - `%LOCALAPPDATA%\CrashDumps`
   - `%TEMP%` and `%WINDIR%\Temp`

---

## Remediation Runbook & Risk Classification

Present cleanup opportunities to the user categorized by risk tier:

### Risk Level: Zero (Safe, immediate reclaim)
- **Developer Package Caches**:
  ```powershell
  bun pm cache rm
  npm cache clean --force
  cargo cache --autoclean
  ```
- **Stale `node_modules`**: Execute directory removal only after interactive confirmation or explicit target selection.
- **User Temp Files**: Purge files older than 7 days in `$env:TEMP`.

### Risk Level: Low (System caches, recreatable assets)
- **Windows Update Download Cache**:
  ```powershell
  Stop-Service -Name wuauserv -Force
  Remove-Item -Path "$env:WINDIR\SoftwareDistribution\Download\*" -Recurse -Force -ErrorAction SilentlyContinue
  Start-Service -Name wuauserv
  ```
- **DISM Component Store Cleanup**:
  ```cmd
  Dism.exe /Online /Cleanup-Image /StartComponentCleanup /ResetBase
  ```

### Risk Level: Medium (System configuration changes)
- **Compact WSL2 Virtual Disk**:
  ```powershell
  # 1. Shutdown WSL instances
  wsl --shutdown
  # 2. Compact vhdx disk file via diskpart
  # select vdisk file="<path_to_ext4.vhdx>"
  # compact vdisk
  ```
- **Disable Hibernation (Reclaims hiberfil.sys equal to RAM size)**:
  ```powershell
  powercfg /hibernate off
  ```
  *(Note: Disables Windows Fast Startup and Sleep-to-Hibernate transition).*

---

## Verification & Output Format

1. Summarize inspected drives with capacity, used, and free metrics.
2. Highlight primary drivers of storage consumption.
3. List candidate items for reclamation with quantified estimated savings.
4. Provide verified copy-ready commands with clear warnings for any elevated or configuration-altering steps.

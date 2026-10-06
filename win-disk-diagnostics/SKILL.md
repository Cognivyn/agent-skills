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

## When to use

Use this skill when asked to:

- "Check why my C: drive is full" or "audit my disk usage".
- "Find the largest files on drive X".
- "How much space can I reclaim?" before a cleanup.
- "Space calculations don't match what Explorer reports" — see
  [NT Kernel & Hidden Space](#2-nt-kernel-hidden-space-allocation).
- "Audit my developer bloat" — WSL2 disks, Docker data, package caches, stale
  `node_modules`.

Do **NOT** use this skill for:

- Deleting files. It diagnoses and reports; remediation commands are surfaced
  for the user to run after review.
- Non-Windows hosts. Every command here targets Windows storage.
- Live monitoring or scheduled audits. These are one-shot point-in-time runs.

## Non-Negotiable Safety & Privacy Rules

- **Zero State Mutation by Default**: All investigative steps, directory measurements, and volume evaluations are strictly read-only. Never delete, relocate, or truncate files without explicit human confirmation.
- **`-WhatIf` Is Enforced**: Every deletion in `Clean-NodeModules.ps1` passes through `ShouldProcess`. Never bypass it, and never add a deletion path that skips it.
- **Least Privilege Execution**: Standard inspections run in non-elevated user sessions. Do not demand administrative rights or bypass UAC unless running explicit OS-level DISM cleanup tasks with user approval.
- **Privacy First**: All paths reported by the bundled scripts are scrubbed of the account name (`C:\Users\<USER>`) by `Protect-SensitivePath` before display or export. Never reintroduce raw `$env:USERPROFILE` into output, and never commit a real user path into these files.
- **No Blind Hydration**: Traversal skips NTFS reparse points and excludes cloud-sync roots, so it cannot trigger unwanted cloud downloads. Do not add an unfiltered recursive scan.
- **Bounded Depth**: Every traversal takes `-MaxDepth` (default 4). An unbounded whole-drive walk can exceed ten minutes.
- **Classified Remediation**: All cleanup recommendations must be clearly graded by risk level (`Zero`, `Low`, `Medium`) with exact copy-ready commands.

---

## Workflow

### 1. Volume Health Assessment

Audit mounted storage drives, calculate total/used/free metrics, and identify critically constrained partitions.

Run from the repository root so the paths below resolve:

```powershell
# Volume summary for every fixed local drive
powershell.exe -NoProfile -ExecutionPolicy Bypass -File ./win-disk-diagnostics/scripts/Analyze-DiskSpace.ps1

# Scope to one drive. Omitting -Drive reports all volumes.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File ./win-disk-diagnostics/scripts/Analyze-DiskSpace.ps1 -Drive C:
```

If a drive is constrained, inspect its heaviest contents:

```powershell
# Top 10 heaviest directories on C:
powershell.exe -NoProfile -ExecutionPolicy Bypass -File ./win-disk-diagnostics/scripts/Analyze-DiskSpace.ps1 -Drive C: -TopFolders 10

# Top 20 largest files on C:
powershell.exe -NoProfile -ExecutionPolicy Bypass -File ./win-disk-diagnostics/scripts/Analyze-DiskSpace.ps1 -Drive C: -TopFiles 20
```

If the default depth of 4 is too shallow for the tree in question, widen it
explicitly. Expect proportionally more work:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File ./win-disk-diagnostics/scripts/Analyze-DiskSpace.ps1 -Drive C: -TopFiles 20 -MaxDepth 8
```

### 2. NT Kernel & Hidden Space Allocation

When folder totals do not account for missing space on `C:`, check locked kernel files and shadow storage:

1. **Kernel Virtual Memory Files**:
   - `pagefile.sys` and `swapfile.sys`: Paging and virtual memory allocations.
   - `hiberfil.sys`: Fast Startup and Hibernation image (typically 40–100% of physical RAM).
   - These are visible to `-TopFiles` because the walk enumerates the drive root.
2. **Volume Shadow Copies (VSS)**:
   ```powershell
   vssadmin list shadowstorage
   ```
3. **Component Store**:
   ```cmd
   Dism.exe /Online /Cleanup-Image /AnalyzeComponentStore
   ```
4. **Reference**: [WinSpace Lens Guide](./references/winspace-lens-guide.md) maps each hidden-space source to the bundled tooling.

### 3. Developer Workstation Bloat Audit

On developer machines, major space consumers reside in virtualized environments and package managers:

1. **WSL2 Virtual Hard Disks**: dynamically expanded `ext4.vhdx` under `$env:LOCALAPPDATA\Packages`.
2. **Docker Desktop**: data under `$env:LOCALAPPDATA\Docker\wsl\data\ext4.vhdx`.
3. **Stale `node_modules` Trees**: audit with the bundled scanner. Always pass an explicit `-Path`; the script no longer ships a machine-specific default.
   ```powershell
   # Audit only, zero deletions
   powershell.exe -NoProfile -ExecutionPolicy Bypass -File ./win-disk-diagnostics/scripts/Clean-NodeModules.ps1 -Path "C:\Projects" -DryRun

   # Preview exactly what a real run would delete
   powershell.exe -NoProfile -ExecutionPolicy Bypass -File ./win-disk-diagnostics/scripts/Clean-NodeModules.ps1 -Path "C:\Projects" -WhatIf
   ```
   Folders modified within `-DaysOlderThan` (default 14) are always preserved.
4. **Global Package Caches**: Bun `~/.bun/install/cache`, Cargo `~/.cargo/registry`, npm `%LOCALAPPDATA%\npm-cache`, pip `%LOCALAPPDATA%\pip\cache`.

### 4. Windows OS Waste Audit

1. **SoftwareDistribution Download Cache**: `%WINDIR%\SoftwareDistribution\Download`.
2. **Component Store (WinSxS)**: run the DISM analyze command from step 2.
3. **Previous Windows Installations**: `C:\Windows.old`. Excluded from traversal by default.
4. **Crash Dumps & Temp Directories**: `%LOCALAPPDATA%\CrashDumps`, `%TEMP%`, `%WINDIR%\Temp`.

---

## Output Modes for Sub-Agents

Prefer machine-readable output when you need to reason over the results rather
than show them to a human. Parsing the ANSI-colored tables is unnecessary work.

| Switch | Behaviour |
| --- | --- |
| `-Json` | JSON on stdout, all tables suppressed. Implies `-Quiet`. |
| `-Quiet` | Result tables only; drops the branded header and recommendations. |
| `-ExportFormat CSV\|JSON -OutFile <path>` | Write a report file as well. |

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File ./win-disk-diagnostics/scripts/Analyze-DiskSpace.ps1 -Drive C: -TopFiles 20 -Json
```

---

## Remediation Runbook & Risk Classification

Present cleanup opportunities to the user categorized by risk tier. Do not run
these yourself; surface them for review.

### Risk Level: Zero (Safe, immediate reclaim)
- **Developer Package Caches**:
  ```powershell
  bun pm cache rm
  npm cache clean --force
  cargo cache --autoclean
  ```
- **Stale `node_modules`**: `Clean-NodeModules.ps1` after `-DryRun` or `-WhatIf`.
- **User Temp Files**: purge files older than 7 days in `$env:TEMP`.

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
- **Compact WSL2 Virtual Disk**: `wsl --shutdown`, then compact the vhdx via `diskpart`.
- **Disable Hibernation** (reclaims `hiberfil.sys`, equal to RAM size):
  ```powershell
  powercfg /hibernate off
  ```
  *(Disables Windows Fast Startup and Sleep-to-Hibernate transition.)*

---

## Required Report

```text
## win-disk-diagnostics

**Drives Audited**: <n> (<letters>)
**Critical/Warning**: <list or "none">
**Scan Depth**: <MaxDepth used>

| Drive | Total | Used | Free | % Free | Health |
| --- | --- | --- | --- | --- | --- |
| C: | ... | ... | ... | ... | WARNING |

**Primary Consumers**
- <path> — <size>

**Hidden / Locked Space**
- pagefile.sys / hiberfil.sys — <size>
- VSS shadow storage — <size or "not queried">

**Reclaimable**
- Zero risk: <item — size>
- Low risk: <item — size>
- Medium risk: <item — size>

**Not Measured**
- <source deliberately skipped, with reason>
```

Always state what was **not** measured. A depth-bounded or excluded scan is a
partial answer, and an unqualified total invites acting on bad numbers.

## Validation

From the repository root:

```bash
./agent-skills validate win-disk-diagnostics
python -m unittest discover -s tests -v
python scripts/check_md_links.py
```

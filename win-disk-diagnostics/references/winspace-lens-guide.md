# WinSpace Lens Storage Diagnostic Reference

This reference outlines advanced Windows NT storage mechanics and diagnostic capabilities provided by the WinSpace Lens engine.

## Core Storage Realities on Windows 11

Traditional recursive folder crawlers frequently fail or report misleading numbers on Windows systems due to NT-specific storage primitives:

1. **Locked Kernel Virtual Memory**:
   - `pagefile.sys`, `hiberfil.sys` (Fast Startup/Hibernate), and `swapfile.sys` reside at the drive root and are permanently locked by the NT kernel.
   - Traditional directory iterators fail with access denied or report 0 bytes, missing 16–64 GB of actual consumed disk space.
2. **Volume Shadow Copies (VSS)**:
   - System Restore points and shadow copies in `System Volume Information` occupy storage without appearing as standard files.
   - Can consume tens of gigabytes silently.
3. **WinSxS & Hardlink Deduplication**:
   - The Windows Component Store (`C:\Windows\WinSxS`) uses extensive NTFS hardlinks. Naive tools multi-count hardlinks, reporting bloated sizes.
4. **Cloud Reparse Points & Hydration**:
   - Cloud sync providers (OneDrive, iCloud, Dropbox) use NTFS reparse points. Unfiltered recursion can trigger background network hydration, filling the drive with unwanted downloads.
5. **Developer Workstation Footprints**:
   - WSL2 virtual hard disks (`ext4.vhdx`) grow dynamically and do not automatically shrink when files are deleted inside Linux.
   - Docker Desktop data images (`docker_data.vhdx` / WSL backend).
   - Package manager global caches: Bun, Cargo, npm, pnpm, pip, Gradle, and HuggingFace cache models.

---

## Diagnostic Commands

When the WinSpace Lens engine is available, execute these non-destructive CLI commands:

### 1. Instant System Storage Audit
Audits drive volume health, locked NT kernel files, VSS shadow storage allocations, and developer package caches:

```bash
bun run src/index.ts --system-only
```

### 2. Windows OS Waste Audit
Scans the 8 major OS bloat categories (WinSxS component store, Windows Update cache `SoftwareDistribution\Download`, Previous Windows installations `Windows.old`, memory crash dumps, and temp trees):

```bash
# Standard OS waste scan
bun run os-audit

# Deep component store analysis
bun run src/index.ts --os-audit --deep
```

### 3. Drive Treemap Generation (Bounded Recursion)
Scans target volume or folder tree with bounded depth, applying built-in privacy scrubbing (anonymizing usernames and hostnames) and generating an offline, standalone SVG treemap report:

```bash
# Scan drive C: up to depth 3
bun run scan --depth 3

# Targeted scan on a specific user or project folder
bun run scan --target "C:\Projects" --depth 3
```

---

## Safe Remediation Guidelines

All remediations must be presented as copy-ready PowerShell commands with explicit risk classifications:

| Category | Typical Location | Remediation Method | Risk Level |
| :--- | :--- | :--- | :--- |
| **Package Caches** | `~/.bun/install/cache`, `~/.cargo/registry` | `bun pm cache rm`, `cargo cache -a` | **Zero** |
| **Node Modules** | Stale development repos | Interactive dry-run scan before removal | **Zero** |
| **Windows Update Cache** | `SoftwareDistribution\Download` | Stop `wuauserv`, remove folder contents, restart service | **Low** |
| **WinSxS Component Store** | `C:\Windows\WinSxS` | `Dism.exe /Online /Cleanup-Image /StartComponentCleanup` | **Low** |
| **WSL2 Virtual Disk** | `%LOCALAPPDATA%\Packages\...\ext4.vhdx` | Shutdown WSL (`wsl --shutdown`), compact via `diskpart` | **Medium** |
| **Hibernation** | `C:\hiberfil.sys` | `powercfg /hibernate off` (disables Fast Startup) | **Medium** |

*Always prompt the user for confirmation before executing any cleanup or remediation commands.*

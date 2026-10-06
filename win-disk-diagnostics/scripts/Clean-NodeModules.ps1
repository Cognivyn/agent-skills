<#
.SYNOPSIS
    Safe, interactive node_modules scanner and storage pruner.

.DESCRIPTION
    Scans a target root path (defaulting to Z:\WSL\Consultancy\Git_Repos) for top-level
    node_modules directories, calculates disk space consumed, records their age, and
    prompts the user for explicit permission to delete candidate folders that have
    not been modified in more than 2 days.

.SECURITY GUARANTEES
    - EXPLICIT CONFIRMATION: Never deletes automatically without human permission unless -Force is passed.
    - RECENT FOLDER SHIELD: Protects folders modified within 2 days (configurable via -DaysOlderThan).
    - EXCLUSION BOUNDARIES: Skips 04-Archives, Archives, .git, .pnpm-store, and nested node_modules.
    - DRY-RUN DEFAULT: Supports -DryRun for audit-only execution with zero file modifications.

.PARAMETER Path
    Root directory to scan (Default: "Z:\WSL\Consultancy\Git_Repos").

.PARAMETER DaysOlderThan
    Age threshold in days. Folders older than this are eligible for pruning (Default: 2.0).

.PARAMETER DryRun
    Audit-only switch. Displays inventory and storage analysis without prompting for deletion.

.PARAMETER ExportFormat
    Export format for audit log: "CSV" or "JSON".

.PARAMETER OutFile
    Path to destination export file when -ExportFormat is specified.

.PARAMETER Force
    Bypasses interactive prompt and deletes all eligible folders (Automation only).

.EXAMPLE
    .\Clean-NodeModules.ps1 -DryRun
    Scans and reports all node_modules and space consumed without deleting anything.

.EXAMPLE
    .\Clean-NodeModules.ps1 -Path "Z:\WSL\Consultancy\Git_Repos" -DaysOlderThan 2
    Scans repos, displays audit table, and interactively prompts for confirmation.
#>

[CmdletBinding(SupportsShouldProcess = $true)]
param (
    [Parameter(Position = 0)]
    [string]$Path = "Z:\WSL\Consultancy\Git_Repos",

    [Parameter()]
    [ValidateRange(0.0, 365.0)]
    [double]$DaysOlderThan = 2.0,

    [Parameter()]
    [switch]$DryRun,

    [Parameter()]
    [ValidateSet('CSV', 'JSON')]
    [string]$ExportFormat,

    [Parameter()]
    [string]$OutFile,

    [Parameter()]
    [switch]$Force
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

try {
    [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
} catch {}

# --- Helper Functions ---
function Format-ByteSize {
    param([double]$Bytes)
    if ($Bytes -ge 1TB) { return "$([math]::Round($Bytes / 1TB, 2)) TB" }
    elseif ($Bytes -ge 1GB) { return "$([math]::Round($Bytes / 1GB, 2)) GB" }
    elseif ($Bytes -ge 1MB) { return "$([math]::Round($Bytes / 1MB, 2)) MB" }
    elseif ($Bytes -ge 1KB) { return "$([math]::Round($Bytes / 1KB, 2)) KB" }
    else { return "$Bytes B" }
}

function Show-HeaderBanner {
    param([string]$ScanPath, [double]$ThresholdDays, [bool]$IsDryRun)

    $modeText = if ($IsDryRun) { "AUDIT ONLY (DRY-RUN - NO DELETIONS)" } else { "INTERACTIVE AUDIT & PRUNING" }
    $modeColor = if ($IsDryRun) { "Green" } else { "Yellow" }

    Write-Host ""
    Write-Host "╭─────────────────────────────────────────────────────────────────────────────╮" -ForegroundColor Cyan
    Write-Host "│ " -ForegroundColor Cyan -NoNewline
    Write-Host "NODE_MODULES SPACE CLEANER" -ForegroundColor White -NoNewline
    Write-Host (" " * (42 - "NODE_MODULES SPACE CLEANER".Length)) -NoNewline
    Write-Host "Cognivyn Maintenance" -ForegroundColor DarkCyan -NoNewline
    Write-Host " │" -ForegroundColor Cyan
    Write-Host "│ " -ForegroundColor Cyan -NoNewline
    Write-Host "Mode: $modeText" -ForegroundColor $modeColor -NoNewline
    $remSpaces = 75 - ("Mode: $modeText".Length)
    if ($remSpaces -gt 0) { Write-Host (" " * $remSpaces) -NoNewline }
    Write-Host "│" -ForegroundColor Cyan
    Write-Host "│ " -ForegroundColor Cyan -NoNewline
    Write-Host "Scan Root: $ScanPath" -ForegroundColor DarkGray -NoNewline
    $remSpaces2 = 75 - ("Scan Root: $ScanPath".Length)
    if ($remSpaces2 -gt 0) { Write-Host (" " * $remSpaces2) -NoNewline }
    Write-Host "│" -ForegroundColor Cyan
    Write-Host "│ " -ForegroundColor Cyan -NoNewline
    Write-Host "Stale Threshold: > $ThresholdDays days since last write" -ForegroundColor DarkGray -NoNewline
    $remSpaces3 = 75 - ("Stale Threshold: > $ThresholdDays days since last write".Length)
    if ($remSpaces3 -gt 0) { Write-Host (" " * $remSpaces3) -NoNewline }
    Write-Host "│" -ForegroundColor Cyan
    Write-Host "╰─────────────────────────────────────────────────────────────────────────────╯" -ForegroundColor Cyan
    Write-Host ""
}

# --- Validation ---
if (-not (Test-Path -LiteralPath $Path)) {
    Write-Error "Scan path '$Path' does not exist."
    exit 1
}

Show-HeaderBanner -ScanPath $Path -ThresholdDays $DaysOlderThan -IsDryRun $DryRun

Write-Host "Searching for top-level node_modules directories (skipping Archives, .git)..." -ForegroundColor Cyan

# --- Fast Breadth-First Search ---
$excludedDirNames = @('04-Archives', 'Archives', '.git', '.pnpm-store', '$RECYCLE.BIN', '.next', '.cache')
$queue = [System.Collections.Generic.Queue[string]]::new()
$queue.Enqueue($Path)

$foundDirs = [System.Collections.Generic.List[System.IO.DirectoryInfo]]::new()

while ($queue.Count -gt 0) {
    $currentDir = $queue.Dequeue()
    $subDirs = Get-ChildItem -LiteralPath $currentDir -Directory -Force -ErrorAction SilentlyContinue

    foreach ($dir in $subDirs) {
        if ($dir.Name -eq 'node_modules') {
            # Discovered top-level node_modules: Do NOT enqueue its children!
            $foundDirs.Add($dir)
        } elseif ($dir.Name -in $excludedDirNames) {
            # Safely skip excluded folders without traversing them
            continue
        } else {
            $queue.Enqueue($dir.FullName)
        }
    }
}

if ($foundDirs.Count -eq 0) {
    Write-Host "`nNo node_modules directories found under '$Path'. Your workspace is completely clean!" -ForegroundColor Green
    exit 0
}

Write-Host "Found $($foundDirs.Count) node_modules directories. Calculating disk space consumed..." -ForegroundColor Cyan
Write-Host ""

# --- Measure Sizes and Age ---
$inventory = @()
$now = Get-Date

$idx = 0
foreach ($dir in $foundDirs) {
    $idx++
    Write-Progress -Activity "Calculating node_modules Sizes" -Status "[$idx/$($foundDirs.Count)] $($dir.Parent.Name)" -PercentComplete (($idx / $foundDirs.Count) * 100)

    $measure = Get-ChildItem -LiteralPath $dir.FullName -Recurse -File -Force -ErrorAction SilentlyContinue |
        Measure-Object -Property Length -Sum

    $sizeBytes = if ($null -ne $measure -and $null -ne $measure.Sum) { [double]$measure.Sum } else { 0.0 }
    $ageDays = [math]::Round(($now - $dir.LastWriteTime).TotalDays, 1)
    $isEligible = ($ageDays -ge $DaysOlderThan)

    $inventory += [PSCustomObject]@{
        ProjectName   = $dir.Parent.Name
        FullPath      = $dir.FullName
        ParentPath    = $dir.Parent.FullName
        SizeBytes     = $sizeBytes
        SizeFormatted = Format-ByteSize $sizeBytes
        LastWriteTime = $dir.LastWriteTime
        AgeDays       = $ageDays
        Eligible      = $isEligible
        Status        = if ($isEligible) { "ELIGIBLE (> 2d)" } else { "KEEP (RECENT)" }
        StatusColor   = if ($isEligible) { "Yellow" } else { "Green" }
    }
}
Write-Progress -Activity "Calculating node_modules Sizes" -Completed

# --- Aggregate Metrics ---
$totalSize = 0.0
$reclaimableSize = 0.0
$eligibleCount = 0
$keptCount = 0

foreach ($item in $inventory) {
    $totalSize += $item.SizeBytes
    if ($item.Eligible) {
        $reclaimableSize += $item.SizeBytes
        $eligibleCount++
    } else {
        $keptCount++
    }
}

# --- Summary Bar ---
Write-Host "  DISCOVERED: $($inventory.Count) node_modules" -ForegroundColor White -NoNewline
Write-Host "  │  TOTAL FOOTPRINT: $(Format-ByteSize $totalSize)" -ForegroundColor DarkCyan -NoNewline
Write-Host "  │  RECLAIMABLE (> 2d): " -ForegroundColor DarkGray -NoNewline
Write-Host "$(Format-ByteSize $reclaimableSize) ($eligibleCount projects)" -ForegroundColor Yellow -NoNewline
Write-Host "  │  RECENT (< 2d): " -ForegroundColor DarkGray -NoNewline
Write-Host "$keptCount projects" -ForegroundColor Green
Write-Host ""

# --- Render Inventory Table ---
Write-Host "┌────┬─────────────────────────────┬───────────┬─────────────────────┬──────────┬─────────────────┐" -ForegroundColor DarkCyan
Write-Host "│ " -ForegroundColor DarkCyan -NoNewline
Write-Host "#  " -ForegroundColor White -NoNewline
Write-Host "│ " -ForegroundColor DarkCyan -NoNewline
Write-Host "PROJECT                      " -ForegroundColor White -NoNewline
Write-Host "│ " -ForegroundColor DarkCyan -NoNewline
Write-Host "SIZE      " -ForegroundColor White -NoNewline
Write-Host "│ " -ForegroundColor DarkCyan -NoNewline
Write-Host "LAST MODIFIED       " -ForegroundColor White -NoNewline
Write-Host "│ " -ForegroundColor DarkCyan -NoNewline
Write-Host "AGE (DAYS)" -ForegroundColor White -NoNewline
Write-Host "│ " -ForegroundColor DarkCyan -NoNewline
Write-Host "ACTION STATUS   " -ForegroundColor White -NoNewline
Write-Host "│" -ForegroundColor DarkCyan
Write-Host "├────┼─────────────────────────────┼───────────┼─────────────────────┼──────────┼─────────────────┤" -ForegroundColor DarkCyan

$rowNum = 1
foreach ($item in ($inventory | Sort-Object SizeBytes -Descending)) {
    $rStr   = "$rowNum".PadLeft(2)
    $pTrim  = if ($item.ProjectName.Length -gt 27) { $item.ProjectName.Substring(0, 24) + "..." } else { $item.ProjectName.PadRight(27) }
    $szStr  = $item.SizeFormatted.PadLeft(9)
    $dtStr  = $item.LastWriteTime.ToString("yyyy-MM-dd HH:mm").PadRight(19)
    $ageStr = ("$($item.AgeDays) d").PadLeft(8)
    $stStr  = $item.Status.PadRight(15)

    Write-Host "│ " -ForegroundColor DarkCyan -NoNewline
    Write-Host $rStr -ForegroundColor DarkGray -NoNewline
    Write-Host " │ " -ForegroundColor DarkCyan -NoNewline
    Write-Host $pTrim -ForegroundColor White -NoNewline
    Write-Host " │ " -ForegroundColor DarkCyan -NoNewline
    Write-Host $szStr -ForegroundColor Yellow -NoNewline
    Write-Host " │ " -ForegroundColor DarkCyan -NoNewline
    Write-Host $dtStr -ForegroundColor DarkGray -NoNewline
    Write-Host " │ " -ForegroundColor DarkCyan -NoNewline
    Write-Host $ageStr -ForegroundColor White -NoNewline
    Write-Host " │ " -ForegroundColor DarkCyan -NoNewline
    Write-Host $stStr -ForegroundColor $item.StatusColor -NoNewline
    Write-Host " │" -ForegroundColor DarkCyan
    $rowNum++
}
Write-Host "└────┴─────────────────────────────┴───────────┴─────────────────────┴──────────┴─────────────────┘" -ForegroundColor DarkCyan
Write-Host ""

# --- Optional Export ---
if ($ExportFormat -and $OutFile) {
    try {
        $parentOut = Split-Path -Path $OutFile -Parent
        if ($parentOut -and -not (Test-Path -LiteralPath $parentOut)) {
            New-Item -ItemType Directory -Path $parentOut -Force | Out-Null
        }
        if ($ExportFormat -eq 'CSV') {
            $inventory | Select-Object ProjectName, SizeFormatted, SizeBytes, LastWriteTime, AgeDays, Eligible, FullPath |
                Export-Csv -Path $OutFile -NoTypeInformation -Encoding UTF8
            Write-Host "[EXPORT] Saved CSV audit log to: $OutFile" -ForegroundColor Green
        } elseif ($ExportFormat -eq 'JSON') {
            $inventory | Select-Object ProjectName, SizeFormatted, SizeBytes, LastWriteTime, AgeDays, Eligible, FullPath |
                ConvertTo-Json -Depth 3 | Set-Content -Path $OutFile -Encoding UTF8
            Write-Host "[EXPORT] Saved JSON audit log to: $OutFile" -ForegroundColor Green
        }
    } catch {
        Write-Warning "Failed to export audit log: $_"
    }
}

# --- Decision Point: DryRun or Pruning ---
if ($DryRun) {
    Write-Host "[DRY-RUN COMPLETE] Zero files were modified or deleted." -ForegroundColor Green
    Write-Host "To safely reclaim $(Format-ByteSize $reclaimableSize), run without the -DryRun switch." -ForegroundColor Cyan
    exit 0
}

if ($eligibleCount -eq 0) {
    Write-Host "[STATUS] All node_modules were modified within the last $DaysOlderThan days. Nothing to purge." -ForegroundColor Green
    exit 0
}

# --- Interactive Permission Prompt ---
Write-Host "─────────────────────────────────────────────────────────────────────────────" -ForegroundColor DarkGray
Write-Host "PERMISSION REQUIRED TO PROCEED WITH CLEANUP:" -ForegroundColor Yellow
Write-Host "  Potential space to reclaim: $(Format-ByteSize $reclaimableSize) across $eligibleCount projects." -ForegroundColor White
Write-Host ""
Write-Host "  [A] Delete ALL eligible node_modules (> $DaysOlderThan days old)" -ForegroundColor Red
Write-Host "  [I] Interactive confirmation (prompt for EACH folder individually)" -ForegroundColor Yellow
Write-Host "  [S] Skip / Cancel (Exit without deleting anything)" -ForegroundColor Green
Write-Host ""

$choice = ""
if ($Force) {
    $choice = "A"
    Write-Host "[FORCE] Proceeding with automated purge of all eligible folders." -ForegroundColor Red
} else {
    $choice = (Read-Host "Enter your choice [A / I / S]").Trim().ToUpper()
}

if ($choice -ne 'A' -and $choice -ne 'I') {
    Write-Host "`n[CANCELLED] No files were deleted. Workspace unchanged." -ForegroundColor Green
    exit 0
}

# --- Deletion Routine ---
$purgedBytes = 0.0
$purgedCount = 0

$eligibleItems = $inventory | Where-Object { $_.Eligible }

foreach ($target in $eligibleItems) {
    $doDelete = $false

    if ($choice -eq 'A') {
        $doDelete = $true
    } elseif ($choice -eq 'I') {
        $prompt = Read-Host "Delete node_modules in '$($target.ProjectName)' ($($target.SizeFormatted), $($target.AgeDays)d old)? [Y/N]"
        if ($prompt.Trim().ToUpper() -eq 'Y') {
            $doDelete = $true
        }
    }

    if ($doDelete) {
        Write-Host "Purging '$($target.FullPath)'..." -ForegroundColor Yellow -NoNewline
        try {
            # Use long-path prefix for safe and robust deletion of deep node_modules trees on Windows
            $targetLiteral = $target.FullPath
            if (-not $targetLiteral.StartsWith('\\?\')) {
                $targetLiteral = "\\?\" + $targetLiteral
            }
            Remove-Item -LiteralPath $targetLiteral -Recurse -Force -ErrorAction Stop
            Write-Host " [DELETED]" -ForegroundColor Green
            $purgedBytes += $target.SizeBytes
            $purgedCount++
        } catch {
            Write-Host " [FAILED: $_]" -ForegroundColor Red
        }
    } else {
        Write-Host "Skipped '$($target.ProjectName)'." -ForegroundColor DarkGray
    }
}

Write-Host ""
Write-Host "╭─────────────────────────────────────────────────────────────────────────────╮" -ForegroundColor Green
Write-Host "│ CLEANUP SUMMARY                                                             │" -ForegroundColor Green
Write-Host "│ Purged Projects: $purgedCount" -ForegroundColor White
Write-Host "│ Reclaimed Space: $(Format-ByteSize $purgedBytes)" -ForegroundColor White
Write-Host "│ Note: Run 'bun install' in any project to restore dependencies when needed. │" -ForegroundColor DarkGray
Write-Host "╰─────────────────────────────────────────────────────────────────────────────╯" -ForegroundColor Green
Write-Host ""

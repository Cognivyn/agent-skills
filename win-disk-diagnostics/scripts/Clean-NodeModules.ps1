<#
.SYNOPSIS
    Safe, interactive node_modules scanner and storage pruner.

.DESCRIPTION
    Scans a target root path for node_modules directories, calculates disk space
    consumed, records their age, and deletes candidate folders only after the
    user explicitly agrees. Folders modified within the staleness threshold are
    always preserved.

.SECURITY GUARANTEES
    - EXPLICIT CONFIRMATION: Never deletes without a ShouldProcess decision, so
      -WhatIf and -Confirm are honoured. -Force additionally skips the prompt.
    - RECENT FOLDER SHIELD: Protects folders modified within -DaysOlderThan days.
    - EXCLUSION BOUNDARIES: Skips archive folders, .git, and pnpm stores, and
      does not descend into a node_modules tree it has already recorded.
    - DRY-RUN DEFAULT: Supports -DryRun for audit-only execution with zero
      file modifications.
    - PRIVACY: Reported paths are scrubbed of the account name.

.PARAMETER Path
    Root directory to scan. Defaults to the current working directory. Pass an
    explicit path; no machine-specific path is baked into this script.

.PARAMETER DaysOlderThan
    Age threshold in days. Folders older than this are eligible for pruning (Default: 14.0).

.PARAMETER DryRun
    Audit-only switch. Displays inventory and storage analysis without prompting for deletion.

.PARAMETER ExportFormat
    Export format for audit log: "CSV" or "JSON".

.PARAMETER OutFile
    Path to destination export file when -ExportFormat is specified.

.PARAMETER Force
    Skips the interactive prompt and proceeds with all eligible folders. Still
    subject to -WhatIf.

.PARAMETER WhatIf
    Shows what would be deleted without deleting anything. Handled by
    SupportsShouldProcess; deletion of every folder is wrapped in ShouldProcess.

.EXAMPLE
    .\Clean-NodeModules.ps1 -DryRun
    Scans the current directory and reports all node_modules and space consumed without deleting anything.

.EXAMPLE
    .\Clean-NodeModules.ps1 -Path "C:\Projects" -DaysOlderThan 30 -DryRun
    Scans an explicit workspace, reporting only folders untouched for 30 days.

.EXAMPLE
    .\Clean-NodeModules.ps1 -Path "C:\Projects" -WhatIf
    Lists the folders that would be deleted without deleting any.
#>

# ConfirmImpact is deliberately left at its default (Medium).
#
# Raising it to High makes ShouldProcess raise its own interactive confirmation
# for every folder. That is wrong twice over: -Force already records the user's
# decision, so a second prompt is redundant, and an agent invoking this script
# with -File has no host UI to render the prompt, which makes PowerShell throw
# NullReferenceException from ShouldProcess instead of deleting or reporting.
#
# With the default impact, ShouldProcess still honours -WhatIf (the safety
# guarantee that matters) and still prompts under an explicit -Confirm.
[CmdletBinding(SupportsShouldProcess = $true)]
param (
    [Parameter(Position = 0)]
    [string]$Path = '.',

    [Parameter()]
    [ValidateRange(0.0, 365.0)]
    [double]$DaysOlderThan = 14.0,

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

function Protect-SensitivePath {
    <#
    .SYNOPSIS
        Scrubs the account name from a filesystem path for display and export.
    #>
    param([Parameter(Mandatory = $true)][AllowEmptyString()][string]$PathValue)

    if ([string]::IsNullOrWhiteSpace($PathValue)) { return $PathValue }

    $scrubbed = $PathValue
    foreach ($profileRoot in @('\Users\', '\Documents and Settings\')) {
        $pattern = [regex]::Escape($profileRoot) + '[^\\]+'
        $scrubbed = [regex]::Replace($scrubbed, $pattern, ($profileRoot + '<USER>'), [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
    }

    $homePath = $env:USERPROFILE
    if (-not [string]::IsNullOrWhiteSpace($homePath)) {
        $trimmedHome = $homePath.TrimEnd('\')
        if ($trimmedHome.Length -gt 3 -and $scrubbed.StartsWith($trimmedHome, [System.StringComparison]::OrdinalIgnoreCase)) {
            $scrubbed = '<USERPROFILE>' + $scrubbed.Substring($trimmedHome.Length)
        }
    }

    return $scrubbed
}

function Show-HeaderBanner {
    param([string]$ScanPath, [double]$ThresholdDays, [bool]$IsDryRun)

    $modeText = if ($IsDryRun) { "AUDIT ONLY (DRY-RUN - NO DELETIONS)" } else { "INTERACTIVE AUDIT & PRUNING" }
    $modeColor = if ($IsDryRun) { "Green" } else { "Yellow" }

    Write-Host ""
    Write-Host "=================================================================" -ForegroundColor Cyan
    Write-Host " NODE_MODULES SPACE CLEANER" -ForegroundColor White
    Write-Host " Cognivyn Maintenance" -ForegroundColor DarkCyan
    Write-Host "-----------------------------------------------------------------" -ForegroundColor Cyan
    Write-Host " Mode          : $modeText" -ForegroundColor $modeColor
    Write-Host " Scan Root     : $(Protect-SensitivePath -PathValue $ScanPath)" -ForegroundColor DarkGray
    Write-Host " Stale Cutoff  : older than $ThresholdDays days since last write" -ForegroundColor DarkGray
    Write-Host "=================================================================" -ForegroundColor Cyan
    Write-Host ""
}

# --- Validation ---
if (-not (Test-Path -LiteralPath $Path)) {
    Write-Error "Scan path '$Path' does not exist."
    exit 1
}

$resolvedPath = (Get-Item -LiteralPath $Path -Force).FullName

Show-HeaderBanner -ScanPath $resolvedPath -ThresholdDays $DaysOlderThan -IsDryRun $DryRun

Write-Host "Searching for node_modules directories (skipping archives, .git, pnpm store)..." -ForegroundColor Cyan

# --- Fast Breadth-First Search ---
$excludedDirNames = @('04-Archives', 'Archives', '.git', '.pnpm-store', '$RECYCLE.BIN', '.next', '.cache')
$queue = [System.Collections.Generic.Queue[string]]::new()
$queue.Enqueue($resolvedPath)

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
        } elseif ($dir.Attributes -band [System.IO.FileAttributes]::ReparsePoint) {
            # Never traverse a junction or symlink; it can cycle or leave the scan root.
            continue
        } else {
            $queue.Enqueue($dir.FullName)
        }
    }
}

if ($foundDirs.Count -eq 0) {
    Write-Host "`nNo node_modules directories found under '$(Protect-SensitivePath -PathValue $resolvedPath)'. Your workspace is completely clean!" -ForegroundColor Green
    exit 0
}

Write-Host "Found $($foundDirs.Count) node_modules directories. Calculating disk space consumed..." -ForegroundColor Cyan
Write-Host ""

# --- Measure Sizes and Age ---
$inventory = @()
$now = Get-Date
$statusEligible = "ELIGIBLE (> $DaysOlderThan d)"
$statusKeep = "KEEP (RECENT)"

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
        DisplayPath   = Protect-SensitivePath -PathValue $dir.FullName
        ParentPath    = $dir.Parent.FullName
        SizeBytes     = $sizeBytes
        SizeFormatted = Format-ByteSize $sizeBytes
        LastWriteTime = $dir.LastWriteTime
        AgeDays       = $ageDays
        Eligible      = $isEligible
        # Threshold is interpolated so the label never contradicts -DaysOlderThan.
        Status        = if ($isEligible) { $statusEligible } else { $statusKeep }
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
Write-Host "  |  TOTAL FOOTPRINT: $(Format-ByteSize $totalSize)" -ForegroundColor DarkCyan -NoNewline
Write-Host "  |  RECLAIMABLE (> $DaysOlderThan d): " -ForegroundColor DarkGray -NoNewline
Write-Host "$(Format-ByteSize $reclaimableSize) ($eligibleCount projects)" -ForegroundColor Yellow -NoNewline
Write-Host "  |  RECENT (< $DaysOlderThan d): " -ForegroundColor DarkGray -NoNewline
Write-Host "$keptCount projects" -ForegroundColor Green
Write-Host ""

# --- Render Inventory Table ---
Write-Host "+----+-----------------------------+-----------+---------------------+-----------+-----------------+" -ForegroundColor DarkCyan
Write-Host "| " -ForegroundColor DarkCyan -NoNewline
Write-Host "#  " -ForegroundColor White -NoNewline
Write-Host "| " -ForegroundColor DarkCyan -NoNewline
Write-Host "PROJECT                      " -ForegroundColor White -NoNewline
Write-Host "| " -ForegroundColor DarkCyan -NoNewline
Write-Host "SIZE      " -ForegroundColor White -NoNewline
Write-Host "| " -ForegroundColor DarkCyan -NoNewline
Write-Host "LAST MODIFIED       " -ForegroundColor White -NoNewline
Write-Host "| " -ForegroundColor DarkCyan -NoNewline
Write-Host "AGE (DAYS)" -ForegroundColor White -NoNewline
Write-Host "| " -ForegroundColor DarkCyan -NoNewline
Write-Host "ACTION STATUS   " -ForegroundColor White -NoNewline
Write-Host "|" -ForegroundColor DarkCyan
Write-Host "+----+-----------------------------+-----------+---------------------+-----------+-----------------+" -ForegroundColor DarkCyan

$rowNum = 1
foreach ($item in ($inventory | Sort-Object SizeBytes -Descending)) {
    $rStr   = "$rowNum".PadLeft(2)
    $pTrim  = if ($item.ProjectName.Length -gt 27) { $item.ProjectName.Substring(0, 24) + "..." } else { $item.ProjectName.PadRight(27) }
    $szStr  = $item.SizeFormatted.PadLeft(9)
    $dtStr  = $item.LastWriteTime.ToString("yyyy-MM-dd HH:mm").PadRight(19)
    $ageStr = ("$($item.AgeDays) d").PadLeft(8)
    $stStr  = $item.Status.PadRight(15)

    Write-Host "| " -ForegroundColor DarkCyan -NoNewline
    Write-Host $rStr -ForegroundColor DarkGray -NoNewline
    Write-Host " | " -ForegroundColor DarkCyan -NoNewline
    Write-Host $pTrim -ForegroundColor White -NoNewline
    Write-Host " | " -ForegroundColor DarkCyan -NoNewline
    Write-Host $szStr -ForegroundColor Yellow -NoNewline
    Write-Host " | " -ForegroundColor DarkCyan -NoNewline
    Write-Host $dtStr -ForegroundColor DarkGray -NoNewline
    Write-Host " | " -ForegroundColor DarkCyan -NoNewline
    Write-Host $ageStr -ForegroundColor White -NoNewline
    Write-Host " | " -ForegroundColor DarkCyan -NoNewline
    Write-Host $stStr -ForegroundColor $item.StatusColor -NoNewline
    Write-Host " |" -ForegroundColor DarkCyan
    $rowNum++
}
Write-Host "+----+-----------------------------+-----------+---------------------+-----------+-----------------+" -ForegroundColor DarkCyan
Write-Host ""

# --- Optional Export ---
if ($ExportFormat -and $OutFile) {
    try {
        $parentOut = Split-Path -Path $OutFile -Parent
        if ($parentOut -and -not (Test-Path -LiteralPath $parentOut)) {
            New-Item -ItemType Directory -Path $parentOut -Force | Out-Null
        }
        $exportItems = $inventory | Select-Object ProjectName, SizeFormatted, SizeBytes, LastWriteTime, AgeDays, Eligible, DisplayPath
        if ($ExportFormat -eq 'CSV') {
            $exportItems | Export-Csv -Path $OutFile -NoTypeInformation -Encoding UTF8
        } elseif ($ExportFormat -eq 'JSON') {
            $exportItems | ConvertTo-Json -Depth 3 | Set-Content -Path $OutFile -Encoding UTF8
        }
    } catch {
        Write-Warning "Failed to export audit log: $_"
    }
}

# --- Decision Point: DryRun or Pruning ---
if ($DryRun) {
    Write-Host "[DRY-RUN COMPLETE] Zero files were modified or deleted." -ForegroundColor Green
    Write-Host "To reclaim $(Format-ByteSize $reclaimableSize), rerun without -DryRun. Preview first with -WhatIf." -ForegroundColor Cyan
    exit 0
}

if ($eligibleCount -eq 0) {
    Write-Host "[STATUS] All node_modules were modified within the last $DaysOlderThan days. Nothing to purge." -ForegroundColor Green
    exit 0
}

# --- Interactive Permission Prompt ---
Write-Host "-----------------------------------------------------------------" -ForegroundColor DarkGray
Write-Host "PERMISSION REQUIRED TO PROCEED WITH CLEANUP:" -ForegroundColor Yellow
Write-Host "  Potential space to reclaim: $(Format-ByteSize $reclaimableSize) across $eligibleCount projects." -ForegroundColor White
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
# Every deletion passes through ShouldProcess, so -WhatIf reports instead of
# deleting and -Confirm prompts even under -Force.
$purgedBytes = 0.0
$purgedCount = 0
$plannedCount = 0

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

    if (-not $doDelete) {
        Write-Host "Skipped '$($target.ProjectName)'." -ForegroundColor DarkGray
        continue
    }

    $plannedCount++
    $action = "Delete node_modules in '$($target.DisplayPath)' ($($target.SizeFormatted), $($target.AgeDays)d old)"

    if (-not $PSCmdlet.ShouldProcess($target.DisplayPath, $action)) {
        continue
    }

    Write-Host "Purging '$($target.DisplayPath)'..." -ForegroundColor Yellow -NoNewline
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
}

Write-Host ""
Write-Host "=================================================================" -ForegroundColor Green
Write-Host " CLEANUP SUMMARY" -ForegroundColor Green
Write-Host " Purged Projects : $purgedCount of $plannedCount approved" -ForegroundColor White
Write-Host " Reclaimed Space : $(Format-ByteSize $purgedBytes)" -ForegroundColor White
Write-Host " Note: Run 'bun install' in any project to restore dependencies when needed." -ForegroundColor DarkGray
Write-Host "=================================================================" -ForegroundColor Green
Write-Host ""

<#
.SYNOPSIS
    Read-only Windows disk space analysis and diagnostic CLI utility.

.DESCRIPTION
    Analyze-DiskSpace provides high-visibility storage diagnostics directly in the terminal,
    auditing local storage volumes, identifying space-consuming files, and calculating
    directory footprints without modifying system state.
    Engineered with a clean Single Responsibility Principle (SRP) architecture.

.SECURITY GUARANTEE
    - ZERO MUTATION: Strictly read-only. Contains NO code paths to modify, clean, or delete files.
    - LEAST PRIVILEGE: Executes safely in standard non-administrator sessions.
    - SAFE GUARDS: Bypasses locked and protected system paths gracefully without elevation.

.PARAMETER Drive
    Target drive letter to inspect (e.g., "C:", "D", "E:").

.PARAMETER Path
    Target directory path to inspect.

.PARAMETER TopFiles
    Number of largest files to report (Range: 1-1000, Default: 20).

.PARAMETER TopFolders
    Number of largest subdirectories to report (Range: 1-100, Default: 10).

.PARAMETER OpenSettings
    Launches native Windows Storage Sense settings GUI (ms-settings:storagesense).

.PARAMETER ExportFormat
    Export results to structured file format: "CSV" or "JSON".

.PARAMETER OutFile
    Path to destination export file when -ExportFormat is specified.

.EXAMPLE
    .\Analyze-DiskSpace.ps1
    Displays a beautified TUI summary card and volume audit table.

.EXAMPLE
    .\Analyze-DiskSpace.ps1 -Drive C: -TopFiles 20
    Finds the 20 largest files on drive C:.

.EXAMPLE
    .\Analyze-DiskSpace.ps1 -Drive C: -TopFolders 10
    Displays the top 10 largest folders on drive C:.

.EXAMPLE
    .\Analyze-DiskSpace.ps1 -OpenSettings
    Opens the native Windows Storage Sense panel.
#>

[CmdletBinding(DefaultParameterSetName = 'Summary')]
param (
    [Parameter(ParameterSetName = 'AnalyzeDrive')]
    [Parameter(ParameterSetName = 'Files')]
    [Parameter(ParameterSetName = 'Folders')]
    [ValidatePattern('^[a-zA-Z]:?$')]
    [string]$Drive,

    [Parameter(ParameterSetName = 'AnalyzeDrive')]
    [Parameter(ParameterSetName = 'Files')]
    [Parameter(ParameterSetName = 'Folders')]
    [string]$Path,

    [Parameter(ParameterSetName = 'Files')]
    [ValidateRange(1, 1000)]
    [int]$TopFiles = 20,

    [Parameter(ParameterSetName = 'Folders')]
    [ValidateRange(1, 100)]
    [int]$TopFolders = 10,

    [Parameter(ParameterSetName = 'Settings')]
    [switch]$OpenSettings,

    [Parameter(ParameterSetName = 'Summary')]
    [switch]$Summary,

    [Parameter()]
    [ValidateSet('CSV', 'JSON')]
    [string]$ExportFormat,

    [Parameter()]
    [string]$OutFile
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Ensure console supports UTF-8 Unicode characters (borders, blocks)
try {
    [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
} catch {}

# --- Load SRP Core Modules ---
$moduleRoot = Join-Path -Path $PSScriptRoot -ChildPath "src"
. (Join-Path -Path $moduleRoot -ChildPath "Formatters.ps1")
. (Join-Path -Path $moduleRoot -ChildPath "Collectors.ps1")
. (Join-Path -Path $moduleRoot -ChildPath "TerminalUI.ps1")
. (Join-Path -Path $moduleRoot -ChildPath "Exporters.ps1")

# Always render branded security card
Show-SecurityHeader

# Action: Open Windows Storage Sense
if ($OpenSettings) {
    Write-Host "Opening Windows Storage Sense (ms-settings:storagesense)...`n" -ForegroundColor Cyan
    Start-Process "ms-settings:storagesense"
    exit 0
}

# Resolve target path
$targetPath = if ($Path) { $Path } elseif ($Drive) { "$($Drive.TrimEnd(':')):\ " } else { $null }
if ($targetPath) { $targetPath = $targetPath.Trim() }

# Action: Top Files Scanner
if ($PSCmdlet.ParameterSetName -eq 'Files') {
    $rawFiles = Get-HeaviestFiles -TargetPath $targetPath -Count $TopFiles
    Show-FilesTable -Files $rawFiles -TargetPath $targetPath

    if ($ExportFormat -and $OutFile) {
        $exportItems = foreach ($f in $rawFiles) {
            [PSCustomObject]@{
                FileName  = $f.FileName
                Size      = Format-ByteSize $f.SizeBytes
                SizeBytes = $f.SizeBytes
                Extension = $f.Extension
                Directory = $f.Directory
            }
        }
        Export-DiagnosticReport -Data $exportItems -Format $ExportFormat -DestinationPath $OutFile
    }
    exit 0
}

# Action: Top Folders Breakdown
if ($PSCmdlet.ParameterSetName -eq 'Folders') {
    Write-Host "Measuring top-level folders under '$targetPath' (Read-Only)...`n" -ForegroundColor Cyan
    $rawFolders = Get-HeaviestFolders -TargetPath $targetPath -Count $TopFolders
    Show-FoldersTable -Folders $rawFolders -TargetPath $targetPath

    if ($ExportFormat -and $OutFile) {
        $exportItems = foreach ($f in $rawFolders) {
            [PSCustomObject]@{
                FolderName = $f.FolderName
                Size       = Format-ByteSize $f.SizeBytes
                SizeBytes  = $f.SizeBytes
                FullPath   = $f.FullPath
            }
        }
        Export-DiagnosticReport -Data $exportItems -Format $ExportFormat -DestinationPath $OutFile
    }
    exit 0
}

# Action: Volume Summary Overview (Default)
$rawVolumes = Get-SystemVolumes
$enrichedVolumes = foreach ($v in $rawVolumes) {
    $health = Get-HealthAssessment -TotalBytes $v.TotalBytes -FreeBytes $v.FreeBytes
    $meter  = Get-AsciiProgressBar -UsedPercent $health.UsedPercent

    [PSCustomObject]@{
        DriveLetter  = $v.DriveLetter
        Label        = $v.Label
        TotalBytes   = $v.TotalBytes
        UsedBytes    = $v.UsedBytes
        FreeBytes    = $v.FreeBytes
        FreePercent  = $health.FreePercent
        UsedPercent  = $health.UsedPercent
        ProgressBar  = $meter
        HealthStatus = $health.HealthStatus
        StatusColor  = $health.StatusColor
    }
}

Show-StorageSummary -EnrichedVolumes $enrichedVolumes
Show-VolumeTable -EnrichedVolumes $enrichedVolumes
Show-Recommendations

if ($ExportFormat -and $OutFile) {
    $exportItems = foreach ($v in $enrichedVolumes) {
        [PSCustomObject]@{
            Drive        = $v.DriveLetter
            Label        = $v.Label
            Total        = Format-ByteSize $v.TotalBytes
            Used         = Format-ByteSize $v.UsedBytes
            Free         = Format-ByteSize $v.FreeBytes
            "% Free"     = "$($v.FreePercent)%"
            Health       = $v.HealthStatus
            TotalBytes   = $v.TotalBytes
            FreeBytes    = $v.FreeBytes
        }
    }
    Export-DiagnosticReport -Data $exportItems -Format $ExportFormat -DestinationPath $OutFile
}

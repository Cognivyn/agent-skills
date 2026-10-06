# src/Collectors.ps1
# Single Responsibility: Pure data collection from OS storage subsystems (strictly read-only).

function Get-SystemVolumes {
    <#
    .SYNOPSIS
        Safely collects storage volume metrics across all fixed local drives.
    #>
    [CmdletBinding()]
    param()

    $volumeList = @()
    try {
        $vols = Get-Volume -ErrorAction Stop | Where-Object { $_.DriveType -eq 'Fixed' -and $_.Size -gt 0 }
        foreach ($v in $vols) {
            $driveLetter = if ($v.DriveLetter) { "$($v.DriveLetter):" } else { $v.Name }
            $volumeList += [PSCustomObject]@{
                DriveLetter = $driveLetter
                Label       = if ($v.FileSystemLabel) { $v.FileSystemLabel } else { "" }
                TotalBytes  = [double]$v.Size
                FreeBytes   = [double]$v.SizeRemaining
                UsedBytes   = [double]($v.Size - $v.SizeRemaining)
            }
        }
    } catch {
        # Fallback to Get-PSDrive for environments where Get-Volume is restricted or unavailable
        $psDrives = Get-PSDrive -PSProvider FileSystem -ErrorAction SilentlyContinue | Where-Object { $_.Used -gt 0 }
        foreach ($d in $psDrives) {
            $total = [double]($d.Used + $d.Free)
            $volumeList += [PSCustomObject]@{
                DriveLetter = "$($d.Name):"
                Label       = if ($d.Description) { $d.Description } else { "" }
                TotalBytes  = $total
                FreeBytes   = [double]$d.Free
                UsedBytes   = [double]$d.Used
            }
        }
    }

    return $volumeList
}

function Get-HeaviestFiles {
    <#
    .SYNOPSIS
        Scans a target directory or drive for the largest files, bypassing protected paths.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$TargetPath,
        [int]$Count = 20
    )

    if (-not (Test-Path -LiteralPath $TargetPath)) {
        throw "Target path '$TargetPath' does not exist."
    }

    $fileItems = @()
    try {
        $rawFiles = Get-ChildItem -LiteralPath $TargetPath -Recurse -File -Force -ErrorAction SilentlyContinue |
            Sort-Object Length -Descending |
            Select-Object -First $Count

        foreach ($f in $rawFiles) {
            $fileItems += [PSCustomObject]@{
                FileName  = $f.Name
                SizeBytes = [double]$f.Length
                Extension = $f.Extension
                Directory = $f.DirectoryName
                FullPath  = $f.FullName
            }
        }
    } catch {
        Write-Warning "File scanner encountered non-fatal error: $_"
    }

    return $fileItems
}

function Get-HeaviestFolders {
    <#
    .SYNOPSIS
        Measures the aggregate size of top-level subdirectories under a target path.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$TargetPath,
        [int]$Count = 10
    )

    if (-not (Test-Path -LiteralPath $TargetPath)) {
        throw "Target path '$TargetPath' does not exist."
    }

    $folderMetrics = @()
    $subDirs = Get-ChildItem -LiteralPath $TargetPath -Directory -Force -ErrorAction SilentlyContinue

    foreach ($dir in $subDirs) {
        $measure = Get-ChildItem -LiteralPath $dir.FullName -Recurse -File -Force -ErrorAction SilentlyContinue |
            Measure-Object -Property Length -Sum

        $sizeBytes = if ($null -ne $measure -and $null -ne $measure.Sum) { [double]$measure.Sum } else { 0.0 }

        $folderMetrics += [PSCustomObject]@{
            FolderName = $dir.Name
            SizeBytes  = $sizeBytes
            FullPath   = $dir.FullName
        }
    }

    return ($folderMetrics | Sort-Object SizeBytes -Descending | Select-Object -First $Count)
}

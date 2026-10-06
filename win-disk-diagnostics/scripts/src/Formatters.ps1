# src/Formatters.ps1
# Single Responsibility: Pure data transformation, unit formatting, and visual gauge calculations.

function Format-ByteSize {
    <#
    .SYNOPSIS
        Converts raw bytes into human-readable binary storage units.
    #>
    param([double]$Bytes)

    if ($Bytes -ge 1TB) {
        return "$([math]::Round($Bytes / 1TB, 2)) TB"
    } elseif ($Bytes -ge 1GB) {
        return "$([math]::Round($Bytes / 1GB, 2)) GB"
    } elseif ($Bytes -ge 1MB) {
        return "$([math]::Round($Bytes / 1MB, 2)) MB"
    } elseif ($Bytes -ge 1KB) {
        return "$([math]::Round($Bytes / 1KB, 2)) KB"
    } else {
        return "$Bytes B"
    }
}

function Get-HealthAssessment {
    <#
    .SYNOPSIS
        Evaluates storage capacity health based on percentage of free space.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [double]$TotalBytes,
        [Parameter(Mandatory = $true)]
        [double]$FreeBytes
    )

    $freePercent = if ($TotalBytes -gt 0) { [math]::Round(($FreeBytes / $TotalBytes) * 100, 1) } else { 0.0 }
    $usedPercent = [math]::Round((100.0 - $freePercent), 1)

    $status = 'HEALTHY'
    $color = 'Green'

    if ($freePercent -lt 10.0) {
        $status = 'CRITICAL'
        $color = 'Red'
    } elseif ($freePercent -lt 25.0) {
        $status = 'WARNING'
        $color = 'Yellow'
    }

    return [PSCustomObject]@{
        FreePercent  = $freePercent
        UsedPercent  = $usedPercent
        HealthStatus = $status
        StatusColor  = $color
    }
}

function Get-AsciiProgressBar {
    <#
    .SYNOPSIS
        Generates a sleek Unicode block progress bar for usage visualization.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [double]$UsedPercent,
        [int]$Width = 20
    )

    $clampedPercent = [math]::Max(0.0, [math]::Min(100.0, $UsedPercent))
    $filledBlocks = [math]::Round(($clampedPercent / 100.0) * $Width)
    $emptyBlocks = $Width - $filledBlocks

    $filledStr = [string]::new([char]0x2588, $filledBlocks) # Solid full block: █
    $emptyStr  = [string]::new([char]0x2591, $emptyBlocks)  # Light shade: ░

    return "[$filledStr$emptyStr]"
}

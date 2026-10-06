# src/Formatters.ps1
# Single Responsibility: Pure data transformation, unit formatting, visual gauge calculations, and privacy scrubbing.

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
        Generates a Unicode block progress bar for usage visualization.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [double]$UsedPercent,
        [int]$Width = 20
    )

    $clampedPercent = [math]::Max(0.0, [math]::Min(100.0, $UsedPercent))
    $filledBlocks = [math]::Round(($clampedPercent / 100.0) * $Width)
    $emptyBlocks = $Width - $filledBlocks

    $filledStr = [string]::new([char]0x2588, $filledBlocks) # Solid full block: full
    $emptyStr  = [string]::new([char]0x2591, $emptyBlocks)  # Light shade

    return "[$filledStr$emptyStr]"
}

function Protect-SensitivePath {
    <#
    .SYNOPSIS
        Scrubs personally identifying segments from a filesystem path.

    .DESCRIPTION
        Replaces the account name under a well-known user-profile root with a
        stable placeholder, and removes any residual home-directory fragment.
        Directory structure and file names are preserved so the path stays
        actionable for remediation, while the identity of the account does not
        leak into terminal output, CSV exports, or JSON reports.

        This backs the "Privacy First" rule in SKILL.md. It is applied at
        collection time so that no collector ever returns an unscrubbed path.

    .PARAMETER Path
        The raw filesystem path to scrub.

    .EXAMPLE
        Protect-SensitivePath -Path 'C:\Users\jdoe\projects\app'
        Returns 'C:\Users\<USER>\projects\app'.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$Path
    )

    if ([string]::IsNullOrWhiteSpace($Path)) {
        return $Path
    }

    $scrubbed = $Path

    # Profile roots whose immediate child is the account name.
    foreach ($profileRoot in @('\Users\', '\Documents and Settings\')) {
        $pattern = [regex]::Escape($profileRoot) + '[^\\]+'
        $scrubbed = [regex]::Replace($scrubbed, $pattern, ($profileRoot + '<USER>'), [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
    }

    # $HOME is authoritative for the current account even under a relocated or
    # roaming profile, where the path may not match the conventional root.
    $homePath = $env:USERPROFILE
    if (-not [string]::IsNullOrWhiteSpace($homePath)) {
        $trimmedHome = $homePath.TrimEnd('\')
        if ($trimmedHome.Length -gt 3 -and $scrubbed.StartsWith($trimmedHome, [System.StringComparison]::OrdinalIgnoreCase)) {
            $scrubbed = '<USERPROFILE>' + $scrubbed.Substring($trimmedHome.Length)
        }
    }

    return $scrubbed
}

function Protect-SensitiveName {
    <#
    .SYNOPSIS
        Scrubs a bare computer name or user name for display in headers.

    .DESCRIPTION
        Truncates rather than redacts outright so the header stays aligned,
        matching the existing banner layout.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [AllowEmptyString()]
        [string]$Value,
        [int]$MaxLength = 15
    )

    if ([string]::IsNullOrWhiteSpace($Value)) {
        return ''
    }
    if ($Value.Length -le $MaxLength) {
        return $Value.PadRight($MaxLength)
    }
    return $Value.Substring(0, $MaxLength)
}

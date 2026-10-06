# src/Exporters.ps1
# Single Responsibility: Serialization and persistence of diagnostic audit reports (CSV/JSON).

function ConvertTo-DiagnosticJson {
    <#
    .SYNOPSIS
        Serializes diagnostic data to a JSON string for stdout emission.

    .DESCRIPTION
        Emitting JSON on stdout is what lets a sub-agent consume results without
        parsing the human-facing tables. Depth is raised above the default so
        nested report envelopes survive the round trip.

        Paths are expected to be pre-scrubbed by the collectors.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [array]$Data,
        [int]$Depth = 6
    )

    return ($Data | ConvertTo-Json -Depth $Depth -Compress:$false)
}

function Export-DiagnosticReport {
    <#
    .SYNOPSIS
        Safely serializes diagnostic datasets to CSV or JSON file formats.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [array]$Data,
        [Parameter(Mandatory = $true)]
        [ValidateSet('CSV', 'JSON')]
        [string]$Format,
        [Parameter(Mandatory = $true)]
        [string]$DestinationPath
    )

    if (-not $DestinationPath -or $Data.Count -eq 0) {
        return
    }

    try {
        $parentDir = Split-Path -Path $DestinationPath -Parent
        if ($parentDir -and -not (Test-Path -LiteralPath $parentDir)) {
            New-Item -ItemType Directory -Path $parentDir -Force | Out-Null
        }

        if ($Format -eq 'CSV') {
            $Data | Export-Csv -Path $DestinationPath -NoTypeInformation -Encoding UTF8
        } elseif ($Format -eq 'JSON') {
            $Data | ConvertTo-Json -Depth 6 | Set-Content -Path $DestinationPath -Encoding UTF8
        }
    } catch {
        Write-Warning "Failed to export diagnostic data to '$DestinationPath': $_"
    }
}

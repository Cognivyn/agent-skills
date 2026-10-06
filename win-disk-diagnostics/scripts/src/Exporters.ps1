# src/Exporters.ps1
# Single Responsibility: Serialization and persistence of diagnostic audit reports (CSV/JSON).

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
            Write-Host "[EXPORT] Saved CSV report to: $DestinationPath" -ForegroundColor Green
        } elseif ($Format -eq 'JSON') {
            $Data | ConvertTo-Json -Depth 4 | Set-Content -Path $DestinationPath -Encoding UTF8
            Write-Host "[EXPORT] Saved JSON report to: $DestinationPath" -ForegroundColor Green
        }
    } catch {
        Write-Warning "Failed to export diagnostic data to '$DestinationPath': $_"
    }
}

<#
.SYNOPSIS
    Audit-DiskSpace.ps1 - Safe, read-only audit of Windows 11 system and developer storage.
#>
[CmdletBinding()]
param()

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "         Windows 11 System & Dev Storage Audit            " -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host ""

# 1. Drive Volumes
Write-Host "[1/6] Drive Volume Capacities:" -ForegroundColor Yellow
Get-PSDrive -PSProvider FileSystem | Where-Object { $_.Free -ne $null } |
    Select-Object Name,
        @{N='Used_GB';E={[math]::round(($_.Used)/1GB,2)}},
        @{N='Free_GB';E={[math]::round(($_.Free)/1GB,2)}},
        @{N='Total_GB';E={[math]::round(($_.Used + $_.Free)/1GB,2)}},
        @{N='Free_%';E={[math]::round(($_.Free / ($_.Used + $_.Free))*100,1)}} |
    Format-Table -AutoSize

# 2. System Memory Files
Write-Host "[2/6] System State Files (C:\):" -ForegroundColor Yellow
$sysFiles = @('hiberfil.sys', 'pagefile.sys', 'swapfile.sys')
& {
    foreach ($f in $sysFiles) {
        $p = "C:\$f"
        if (Test-Path $p) {
            $item = Get-Item $p -Force
            [PSCustomObject]@{ File = $f; Size_GB = [math]::Round($item.Length / 1GB, 2) }
        }
    }
} | Format-Table -AutoSize

# 3. WSL / Docker VHDXs
Write-Host "[3/6] Docker & WSL Virtual Disks:" -ForegroundColor Yellow
Get-ChildItem -Path "$env:LOCALAPPDATA\Docker\wsl" -Recurse -Filter "*.vhdx" -ErrorAction SilentlyContinue |
    Select-Object Name, @{N='Size_GB';E={[math]::Round($_.Length / 1GB, 2)}}, FullName |
    Format-Table -AutoSize

# 4. Delivery Optimization Peer Cache
Write-Host "[4/6] Delivery Optimization Cache:" -ForegroundColor Yellow
$do = Get-DeliveryOptimizationStatus -ErrorAction SilentlyContinue | Measure-Object -Property FileSize -Sum
[PSCustomObject]@{
    CachedItems = $do.Count
    Total_GB    = [math]::Round(($do.Sum / 1GB), 2)
} | Format-Table -AutoSize

# 5. User Temp Directory
Write-Host "[5/6] User Temp Files (%TEMP%):" -ForegroundColor Yellow
$userTemp = (Get-ChildItem -Path $env:TEMP -Recurse -File -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum / 1GB
[PSCustomObject]@{ Path = $env:TEMP; Size_GB = [math]::Round($userTemp, 2) } | Format-Table -AutoSize

# 6. WSL Config & Sparse State
Write-Host "[6/6] WSL Optimization State:" -ForegroundColor Yellow
$wslConfigPath = "$env:USERPROFILE\.wslconfig"
$wslConfigExists = Test-Path $wslConfigPath
$hasSparse = $false
if ($wslConfigExists) {
    $hasSparse = (Get-Content $wslConfigPath | Select-String "sparseVhd=true") -ne $null
}
[PSCustomObject]@{
    HasWslConfig        = $wslConfigExists
    SparseVhdConfigured = $hasSparse
} | Format-Table -AutoSize

Write-Host "Audit completed successfully." -ForegroundColor Green

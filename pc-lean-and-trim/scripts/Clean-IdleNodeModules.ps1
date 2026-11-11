<#
.SYNOPSIS
    Clean-IdleNodeModules.ps1 - Safely purges node_modules from inactive repositories while protecting active projects.
#>
[CmdletBinding(SupportsShouldProcess=$true)]
param(
    [string]$RootPath = (Get-Location).Path,
    [int]$IdleDays = 14,
    [string[]]$ActiveProjects = @()
)

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "      Idle node_modules Purge Tool (Dev Drive Safe)      " -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "Scanning under: $RootPath"
Write-Host "Idle threshold: $IdleDays days"
if ($ActiveProjects.Count -gt 0) {
    Write-Host "Protected active projects: $($ActiveProjects -join ', ')"
} else {
    Write-Host "Auto-protecting all repositories modified within the last $IdleDays days."
}
Write-Host ""

if (!(Test-Path $RootPath)) {
    Write-Warning "Target path '$RootPath' does not exist."
    return
}

# Find sub-repositories without descending into node_modules or archives
$repoContainers = Get-ChildItem -Path $RootPath -Directory -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -notmatch "Archives" -and $_.Name -notmatch "^\." }

$targetRepos = @()
foreach ($container in $repoContainers) {
    if (Test-Path (Join-Path $container.FullName "node_modules")) {
        $targetRepos += $container
    }
    # Check 1 level deeper (e.g. Git_Repos\Github\*)
    $subDirs = Get-ChildItem -Path $container.FullName -Directory -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -notmatch "Archives" }
    foreach ($sub in $subDirs) {
        if (Test-Path (Join-Path $sub.FullName "node_modules")) {
            $targetRepos += $sub
        }
        # Check 2 levels deeper (e.g. Git_Repos\Github\repo\*)
        $deepDirs = Get-ChildItem -Path $sub.FullName -Directory -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -notmatch "Archives" }
        foreach ($d in $deepDirs) {
            if (Test-Path (Join-Path $d.FullName "node_modules")) {
                $targetRepos += $d
            }
        }
    }
}

$thresholdDate = (Get-Date).AddDays(-$IdleDays)
$purgedCount = 0

foreach ($repo in $targetRepos) {
    $repoName = $repo.Name
    $isProtected = $false
    foreach ($active in $ActiveProjects) {
        if ($repo.FullName -match [regex]::Escape($active)) {
            $isProtected = $true
            break
        }
    }

    if ($isProtected) {
        Write-Host "[-] SKIP (Protected active project): $repoName" -ForegroundColor Cyan
        continue
    }

    # Check last activity of files in repository root (excluding node_modules)
    $lastFile = Get-ChildItem -Path $repo.FullName -File -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending | Select-Object -First 1

    $lastActive = if ($lastFile) { $lastFile.LastWriteTime } else { $repo.LastWriteTime }

    if ($lastActive -lt $thresholdDate) {
        $nmPath = Join-Path $repo.FullName "node_modules"
        if ($PSCmdlet.ShouldProcess($nmPath, "Purge idle node_modules (Last active: $lastActive)")) {
            Write-Host "[x] PURGING: $repoName (Idle since $lastActive)" -ForegroundColor Yellow
            cmd.exe /c "rd /s /q `"$nmPath`""
            $purgedCount++
        }
    } else {
        Write-Host "[-] SKIP (Active within $IdleDays days): $repoName ($lastActive)" -ForegroundColor Green
    }
}

Write-Host ""
Write-Host "Completed. Purged $purgedCount idle node_modules folders." -ForegroundColor Green

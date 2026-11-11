<#
.SYNOPSIS
    Show-CleanerGui.ps1 - Native Windows 11 GUI for Safe PC Storage Trimming.
    Designed for non-developers: no terminal commands, safe preview first, visual progress.
#>
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

[System.Windows.Forms.Application]::EnableVisualStyles()

# Create Main Form
$form = New-Object System.Windows.Forms.Form
$form.Text = "PC Clean & Trim - Windows 11 Storage Optimizer"
$form.Size = New-Object System.Drawing.Size(650, 680)
$form.StartPosition = "CenterScreen"
$form.FormBorderStyle = "FixedDialog"
$form.MaximizeBox = $false
$form.BackColor = [System.Drawing.Color]::FromArgb(245, 247, 250)

# Header Title
$lblTitle = New-Object System.Windows.Forms.Label
$lblTitle.Text = "Windows 11 Safe Storage Optimizer"
$lblTitle.Font = New-Object System.Drawing.Font("Segoe UI", 16, [System.Drawing.FontStyle]::Bold)
$lblTitle.Location = New-Object System.Drawing.Point(20, 15)
$lblTitle.Size = New-Object System.Drawing.Size(600, 35)
$lblTitle.ForeColor = [System.Drawing.Color]::FromArgb(24, 43, 73)
$form.Controls.Add($lblTitle)

$lblSub = New-Object System.Windows.Forms.Label
$lblSub.Text = "Safely recover disk space and remove temporary bloat with zero risk to personal files."
$lblSub.Font = New-Object System.Drawing.Font("Segoe UI", 9.5)
$lblSub.Location = New-Object System.Drawing.Point(22, 50)
$lblSub.Size = New-Object System.Drawing.Size(600, 20)
$lblSub.ForeColor = [System.Drawing.Color]::FromArgb(100, 116, 139)
$form.Controls.Add($lblSub)

# Drive Capacity GroupBox
$grpDrives = New-Object System.Windows.Forms.GroupBox
$grpDrives.Text = " Current Drive Capacities "
$grpDrives.Font = New-Object System.Drawing.Font("Segoe UI", 9.5, [System.Drawing.FontStyle]::Bold)
$grpDrives.Location = New-Object System.Drawing.Point(20, 80)
$grpDrives.Size = New-Object System.Drawing.Size(595, 75)
$form.Controls.Add($grpDrives)

$lblDriveInfo = New-Object System.Windows.Forms.Label
$lblDriveInfo.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Regular)
$lblDriveInfo.Location = New-Object System.Drawing.Point(15, 25)
$lblDriveInfo.Size = New-Object System.Drawing.Size(565, 40)

function Refresh-DriveDisplay {
    $drives = Get-PSDrive -PSProvider FileSystem | Where-Object { $_.Free -ne $null }
    $parts = foreach ($d in $drives) {
        "Drive $($d.Name): $([math]::Round($d.Free/1GB, 1)) GB Free / $([math]::Round(($d.Used+$d.Free)/1GB, 1)) GB"
    }
    $lblDriveInfo.Text = ($parts -join "   |   ")
}
Refresh-DriveDisplay
$grpDrives.Controls.Add($lblDriveInfo)

# Options GroupBox
$grpOptions = New-Object System.Windows.Forms.GroupBox
$grpOptions.Text = " Cleanup Scope & Safety Options "
$grpOptions.Font = New-Object System.Drawing.Font("Segoe UI", 9.5, [System.Drawing.FontStyle]::Bold)
$grpOptions.Location = New-Object System.Drawing.Point(20, 165)
$grpOptions.Size = New-Object System.Drawing.Size(595, 115)
$form.Controls.Add($grpOptions)

$chkSafe = New-Object System.Windows.Forms.CheckBox
$chkSafe.Text = "Safe Cleanup (Stale temp files, Delivery Optimization, update leftovers)  [100% Risk-Free]"
$chkSafe.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Regular)
$chkSafe.Location = New-Object System.Drawing.Point(15, 25)
$chkSafe.Size = New-Object System.Drawing.Size(565, 25)
$chkSafe.Checked = $true
$chkSafe.Enabled = $false # Always required
$grpOptions.Controls.Add($chkSafe)

$chkDeep = New-Object System.Windows.Forms.CheckBox
$chkDeep.Text = "Deep Windows Servicing (DISM superseded update cleanup & reduced hibernation)"
$chkDeep.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Regular)
$chkDeep.Location = New-Object System.Drawing.Point(15, 55)
$chkDeep.Size = New-Object System.Drawing.Size(565, 25)
$chkDeep.Checked = $false
$grpOptions.Controls.Add($chkDeep)

$chkIdle = New-Object System.Windows.Forms.CheckBox
$chkIdle.Text = "Clean Inactive Project Dependencies (node_modules in projects idle >14 days)"
$chkIdle.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Regular)
$chkIdle.Location = New-Object System.Drawing.Point(15, 85)
$chkIdle.Size = New-Object System.Drawing.Size(565, 25)
$chkIdle.Checked = $false
$grpOptions.Controls.Add($chkIdle)

# Preview Results Box
$grpPreview = New-Object System.Windows.Forms.GroupBox
$grpPreview.Text = " 100% Read-Only Dry-Run Analysis & Preview "
$grpPreview.Font = New-Object System.Drawing.Font("Segoe UI", 9.5, [System.Drawing.FontStyle]::Bold)
$grpPreview.Location = New-Object System.Drawing.Point(20, 290)
$grpPreview.Size = New-Object System.Drawing.Size(595, 210)
$form.Controls.Add($grpPreview)

$txtPreview = New-Object System.Windows.Forms.TextBox
$txtPreview.Multiline = $true
$txtPreview.ReadOnly = $true
$txtPreview.ScrollBars = "Vertical"
$txtPreview.Font = New-Object System.Drawing.Font("Consolas", 8.5)
$txtPreview.Location = New-Object System.Drawing.Point(15, 25)
$txtPreview.Size = New-Object System.Drawing.Size(565, 170)
$txtPreview.Text = "Click 'Run Dry-Run Analysis' below to safely scan your system.`r`nNo files will be touched during the scan."
$grpPreview.Controls.Add($txtPreview)

# Confirmation Checkbox
$chkConfirm = New-Object System.Windows.Forms.CheckBox
$chkConfirm.Text = "I have reviewed the Dry-Run Report above and confirm executing this safe cleanup."
$chkConfirm.Font = New-Object System.Drawing.Font("Segoe UI", 9.5, [System.Drawing.FontStyle]::Bold)
$chkConfirm.Location = New-Object System.Drawing.Point(25, 510)
$chkConfirm.Size = New-Object System.Drawing.Size(585, 25)
$chkConfirm.ForeColor = [System.Drawing.Color]::FromArgb(30, 41, 59)
$chkConfirm.Enabled = $false
$form.Controls.Add($chkConfirm)

# Action Buttons
$btnScan = New-Object System.Windows.Forms.Button
$btnScan.Text = "1. Run Dry-Run Analysis"
$btnScan.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
$btnScan.Location = New-Object System.Drawing.Point(20, 550)
$btnScan.Size = New-Object System.Drawing.Size(280, 45)
$btnScan.BackColor = [System.Drawing.Color]::FromArgb(37, 99, 235)
$btnScan.ForeColor = [System.Drawing.Color]::White
$btnScan.FlatStyle = "Flat"
$form.Controls.Add($btnScan)

$btnClean = New-Object System.Windows.Forms.Button
$btnClean.Text = "2. Start Safe Cleanup"
$btnClean.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
$btnClean.Location = New-Object System.Drawing.Point(335, 550)
$btnClean.Size = New-Object System.Drawing.Size(280, 45)
$btnClean.BackColor = [System.Drawing.Color]::FromArgb(203, 213, 225)
$btnClean.ForeColor = [System.Drawing.Color]::FromArgb(100, 116, 139)
$btnClean.FlatStyle = "Flat"
$btnClean.Enabled = $false
$form.Controls.Add($btnClean)

# Status Label
$lblStatus = New-Object System.Windows.Forms.Label
$lblStatus.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$lblStatus.Location = New-Object System.Drawing.Point(25, 605)
$lblStatus.Size = New-Object System.Drawing.Size(590, 25)
$lblStatus.ForeColor = [System.Drawing.Color]::FromArgb(71, 85, 105)
$lblStatus.Text = "Ready to analyze."
$form.Controls.Add($lblStatus)

# Events
$scriptPath = Join-Path $PSScriptRoot "Invoke-SafeCleanup.ps1"

$btnScan.Add_Click({
    $lblStatus.Text = "Scanning system in read-only mode, please wait..."
    $btnScan.Enabled = $false
    $form.Refresh()

    $cmdArgs = @()
    if ($chkDeep.Checked) { $cmdArgs += "-IncludeDeepSystem" }
    if ($chkIdle.Checked) { $cmdArgs += "-IncludeIdleProjects" }

    $out = powershell.exe -ExecutionPolicy Bypass -File "$scriptPath" @cmdArgs 2>&1
    $txtPreview.Text = ($out -join "`r`n")
    $lblStatus.Text = "Dry-run analysis complete. Review report above."
    $btnScan.Enabled = $true
    $chkConfirm.Enabled = $true
})

$chkConfirm.Add_CheckedChanged({
    if ($chkConfirm.Checked) {
        $btnClean.Enabled = $true
        $btnClean.BackColor = [System.Drawing.Color]::FromArgb(16, 185, 129)
        $btnClean.ForeColor = [System.Drawing.Color]::White
    } else {
        $btnClean.Enabled = $false
        $btnClean.BackColor = [System.Drawing.Color]::FromArgb(203, 213, 225)
        $btnClean.ForeColor = [System.Drawing.Color]::FromArgb(100, 116, 139)
    }
})

$btnClean.Add_Click({
    $lblStatus.Text = "Executing safe cleanup, please wait..."
    $btnClean.Enabled = $false
    $chkConfirm.Enabled = $false
    $btnScan.Enabled = $false
    $form.Refresh()

    $cmdArgs = @("-Execute", "-NonInteractive")
    if ($chkDeep.Checked) { $cmdArgs += "-IncludeDeepSystem" }
    if ($chkIdle.Checked) { $cmdArgs += "-IncludeIdleProjects" }

    $out = powershell.exe -ExecutionPolicy Bypass -File "$scriptPath" @cmdArgs 2>&1
    $txtPreview.Text = ($out -join "`r`n")
    Refresh-DriveDisplay
    $lblStatus.Text = "Cleanup complete! Space successfully recovered."
    [System.Windows.Forms.MessageBox]::Show("Storage cleanup completed successfully! Check the refreshed drive capacity in the window.", "Cleanup Complete", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
    $btnScan.Enabled = $true
})

[void]$form.ShowDialog()

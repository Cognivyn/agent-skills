@echo off
:: Trim-Windows11.bat - Admin Trim & Lean Script for Windows 11 Pro
:: Automatically requests Administrator elevation if not running as admin.

net session >nul 2>&1
if %errorLevel% neq 0 (
    echo Requesting Administrator privileges...
    powershell -Command "Start-Process cmd -ArgumentList '/k \"\"%~f0\"\"' -Verb RunAs"
    exit /b
)

title Windows 11 Lean & Trim Optimization
echo ==============================================================
echo       Windows 11 Pro - Zero-Degradation System Trimmer
echo ==============================================================
echo.

echo [1/5] Reducing Hibernation footprint while preserving Fast Startup...
powercfg /h /type reduced
echo Done.
echo.

echo [2/5] Cleaning leftover OS upgrade cache ($WINDOWS.~BT)...
if exist "C:\$WINDOWS.~BT" (
    takeown /F "C:\$WINDOWS.~BT" /A /R /D Y >nul 2>&1
    icacls "C:\$WINDOWS.~BT" /grant *S-1-5-32-544:F /T /C /Q >nul 2>&1
    rd /s /q "C:\$WINDOWS.~BT" >nul 2>&1
    echo Cleaned $WINDOWS.~BT
) else (
    echo No $WINDOWS.~BT directory found.
)
echo.

echo [3/5] Cleaning Windows Update download staging cache...
net stop wuauserv >nul 2>&1
del /f /s /q "C:\Windows\SoftwareDistribution\Download\*" >nul 2>&1
net start wuauserv >nul 2>&1
echo Done.
echo.

echo [4/5] Running DISM Component Store Cleanup (pruning superseded updates)...
echo This may take 3-5 minutes, please let it finish...
dism.exe /Online /Cleanup-Image /StartComponentCleanup
echo Done.
echo.

echo [5/5] Compacting Docker WSL Virtual Disk (docker_data.vhdx)...
set DOCKER_VHD=%LOCALAPPDATA%\Docker\wsl\disk\docker_data.vhdx
if exist "%DOCKER_VHD%" (
    echo Shutting down WSL...
    wsl --shutdown
    echo Running diskpart compact...
    (
        echo select vdisk file="%DOCKER_VHD%"
        echo compact vdisk
        echo exit
    ) > "%TEMP%\diskpart_compact.txt"
    diskpart /s "%TEMP%\diskpart_compact.txt"
    del "%TEMP%\diskpart_compact.txt"
    echo Docker virtual disk compacted.
) else (
    echo Docker VHD not found at %DOCKER_VHD%
)
echo.

echo ==============================================================
echo Optimization complete! Checking disk space:
echo ==============================================================
powershell -NoProfile -Command "Get-PSDrive -PSProvider FileSystem | Where-Object { $_.Free -ne $null } | Select-Object Name, @{N='Free_GB';E={[math]::round(($_.Free)/1GB,2)}}, @{N='Used_GB';E={[math]::round(($_.Used)/1GB,2)}} | Format-Table -AutoSize"
echo.
pause

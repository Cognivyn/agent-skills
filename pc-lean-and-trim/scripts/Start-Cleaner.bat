@echo off
:: Start-Cleaner.bat - Universal Easy Windows 11 Storage Cleaner
:: Self-elevating, friendly interactive menu with mandatory dry-run and confirmation gates.

set SCRIPT_DIR=%~dp0
title Windows 11 Easy Storage Cleaner

:MENU
cls
echo ==============================================================
echo             Windows 11 Safe Storage Cleaner
echo ==============================================================
echo.
echo   [1] Run Dry-Run Analysis ^& Preview (100%% Safe - No files touched)
echo   [2] Open Simple Graphical Cleaner Window (Visual GUI)
echo   [3] Quick Safe Clean (Stale temp, Delivery Optimization ^& cache)
echo   [4] Full Deep Clean (Includes Windows Updates, DISM ^& Docker)
echo   [5] Exit
echo.
echo ==============================================================
set /p CHOICE="Select an option (1-5) [Default 1]: "

if "%CHOICE%"=="" set CHOICE=1
if "%CHOICE%"=="1" goto DRYRUN
if "%CHOICE%"=="2" goto GUI
if "%CHOICE%"=="3" goto QUICK
if "%CHOICE%"=="4" goto DEEP
if "%CHOICE%"=="5" goto EXIT
goto MENU

:DRYRUN
cls
echo Running 100%% read-only dry-run scan...
powershell -ExecutionPolicy Bypass -File "%SCRIPT_DIR%Invoke-SafeCleanup.ps1"
echo.
pause
goto MENU

:GUI
cls
echo Launching graphical cleaner window...
start powershell -WindowStyle Hidden -ExecutionPolicy Bypass -File "%SCRIPT_DIR%Show-CleanerGui.ps1"
goto EXIT

:QUICK
cls
echo.
echo ==============================================================
echo Step 1: Running Dry-Run Preview First...
echo ==============================================================
powershell -ExecutionPolicy Bypass -File "%SCRIPT_DIR%Invoke-SafeCleanup.ps1"
echo.
echo ==============================================================
echo Step 2: Confirmation Gate
echo ==============================================================
set /p CONFIRM="Are you sure you want to proceed with Quick Clean? Type YES to confirm: "
if /i not "%CONFIRM%"=="YES" (
    echo.
    echo Operation cancelled. Zero files were modified.
    pause
    goto MENU
)
echo.
echo Executing approved Quick Clean...
powershell -ExecutionPolicy Bypass -File "%SCRIPT_DIR%Invoke-SafeCleanup.ps1" -Execute -NonInteractive
echo.
pause
goto MENU

:DEEP
cls
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo Requesting Administrator privileges for Deep Clean...
    powershell -Command "Start-Process cmd -ArgumentList '/k \"\"%~f0\"\"' -Verb RunAs"
    exit /b
)
echo.
echo ==============================================================
echo Step 1: Running Dry-Run Preview for Deep Clean...
echo ==============================================================
powershell -ExecutionPolicy Bypass -File "%SCRIPT_DIR%Invoke-SafeCleanup.ps1" -IncludeDeepSystem
echo.
echo ==============================================================
echo Step 2: Confirmation Gate
echo ==============================================================
set /p CONFIRM="Are you sure you want to proceed with Deep Clean? Type YES to confirm: "
if /i not "%CONFIRM%"=="YES" (
    echo.
    echo Operation cancelled. Zero files were modified.
    pause
    goto MENU
)
echo.
echo Executing approved Deep Clean...
powershell -ExecutionPolicy Bypass -File "%SCRIPT_DIR%Invoke-SafeCleanup.ps1" -Execute -IncludeDeepSystem -NonInteractive
echo.
pause
goto MENU

:EXIT
exit /b

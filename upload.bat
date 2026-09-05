@echo off
setlocal

:: Determine PowerShell binary (prefer PowerShell Core 'pwsh', fallback to Windows PowerShell 'powershell')
where pwsh >nul 2>nul
if %ERRORLEVEL% equ 0 (
    set "PS_BIN=pwsh"
) else (
    set "PS_BIN=powershell"
)

:: Run the PowerShell script with all arguments passed through
"%PS_BIN%" -NoProfile -ExecutionPolicy Bypass -File "%~dp0upload.ps1" %*
set "EXIT_CODE=%ERRORLEVEL%"

:: If launched without arguments (e.g. double-clicked in Windows Explorer), keep window open
if "%~1"=="" (
    echo.
    pause
)

exit /b %EXIT_CODE%

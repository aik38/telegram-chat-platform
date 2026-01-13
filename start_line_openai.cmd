@echo off
setlocal EnableExtensions
cd /d "%~dp0"
set "REPO=%~dp0"
where pwsh >nul 2>nul && (set "PS=pwsh") || (set "PS=powershell")
%PS% -NoProfile -ExecutionPolicy Bypass -File "%REPO%tools\launcher.ps1" -App line -Provider openai -DotenvFile "%REPO%.env.openai" -Port 8000 -AutoStart
if errorlevel 1 (
  echo Launcher failed. See logs in "%REPO%40_logs".
  pause
  exit /b 1
)

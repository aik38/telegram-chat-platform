@echo off
setlocal EnableExtensions
cd /d "%~dp0"
set "REPO=%~dp0"
where pwsh >nul 2>nul && (set "PS=pwsh") || (set "PS=powershell")
%PS% -NoProfile -ExecutionPolicy Bypass -File "%REPO%tools\start_line_stable.ps1" -Provider gemini -DotenvFile "%REPO%.env.gemini" -Port 8000
if errorlevel 1 (
  echo Launcher failed. See logs in "%REPO%40_logs".
  pause
  exit /b 1
)

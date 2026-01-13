@echo off
set "REPO=%~dp0.."
for %%I in ("%REPO%") do set "REPO=%%~fI"
where pwsh >nul 2>nul && (set "PS=pwsh") || (set "PS=powershell")
%PS% -NoProfile -ExecutionPolicy Bypass -File "%REPO%\tools\start_line_stable.ps1" -Provider openai -DotenvFile "%REPO%\.env.openai" -Port 8000
if errorlevel 1 (
  echo Launcher failed. See logs in "%REPO%\40_logs".
  pause
  exit /b 1
)

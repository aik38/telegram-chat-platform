@echo off
echo Deprecated: use tools\launcher.ps1 instead.
setlocal EnableExtensions
set "REPO=%~dp0..\.."
for %%I in ("%REPO%") do set "REPO=%%~fI"
cd /d "%REPO%"
where pwsh >nul 2>nul && (set "PS=pwsh") || (set "PS=powershell")
%PS% -NoProfile -ExecutionPolicy Bypass -File "%REPO%\tools\launcher.ps1" -App arisa -Provider openai -DotenvFile "%REPO%\.env.arisa.openai" -AutoStart
if errorlevel 1 (
  echo Launcher failed. See logs in "%REPO%\40_logs".
  pause
  exit /b 1
)

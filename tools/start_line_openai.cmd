@echo off
set "REPO=%~dp0.."
for %%I in ("%REPO%") do set "REPO=%%~fI"
set "DOTENV_FILE=%REPO%\.env.openai"
set "LINE_PORT=8001"
where pwsh >nul 2>nul && (set "PS=pwsh") || (set "PS=powershell")
%PS% -NoProfile -ExecutionPolicy Bypass -File "%REPO%\scripts\doctor.ps1"
if errorlevel 1 (
  echo Doctor failed. Fix issues above.
  pause
  exit /b 1
)
start "" /D "%REPO%" %PS% -NoExit -NoProfile -ExecutionPolicy Bypass -File "%REPO%\scripts\run_line.ps1" -DotenvFile "%DOTENV_FILE%"

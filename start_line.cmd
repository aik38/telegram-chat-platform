@echo off
set "REPO=%~dp0"
pushd "%REPO%"
set "DOTENV_FILE=.env"
set "LINE_PORT=8000"
where pwsh >nul 2>nul && (set "PS=pwsh") || (set "PS=powershell")
%PS% -NoProfile -ExecutionPolicy Bypass -File "%REPO%scripts\doctor.ps1"
if errorlevel 1 (
  echo Doctor failed. Fix issues above.
  pause
  exit /b 1
)
start "" /D "%REPO%" %PS% -NoExit -NoProfile -ExecutionPolicy Bypass -File "%REPO%scripts\run_line.ps1" -DotenvFile "%REPO%.env"

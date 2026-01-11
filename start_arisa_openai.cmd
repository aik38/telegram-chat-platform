@echo off
set "REPO=%~dp0"
pushd "%REPO%"
if not exist "%REPO%.env.arisa.openai" (
  echo Missing .env.arisa.openai (please create it first)
  pause
  exit /b 1
)
set "DOTENV_FILE=.env.arisa.openai"
where pwsh >nul 2>nul && (set "PS=pwsh") || (set "PS=powershell")
%PS% -NoProfile -ExecutionPolicy Bypass -File "%REPO%scripts\doctor.ps1"
if errorlevel 1 (
  echo Doctor failed. Fix issues above.
  pause
  exit /b 1
)
start "" /D "%REPO%" %PS% -NoExit -NoProfile -ExecutionPolicy Bypass -File "%REPO%scripts\run_arisa.ps1" -DotenvFile "%REPO%.env.arisa.openai"

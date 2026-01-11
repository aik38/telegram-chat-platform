@echo off
cd /d "%~dp0"
set "DOTENV_FILE=.env.openai"
set "REPO=%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File "%REPO%scripts\doctor.ps1"
if errorlevel 1 (
  echo Doctor checks failed. Fix the issues above and retry.
  pause
  exit /b 1
)
start "" /D "%REPO%" cmd /k "powershell -NoProfile -ExecutionPolicy Bypass -File \"scripts\run_default.ps1\""

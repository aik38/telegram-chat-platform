@echo off
cd /d "%~dp0"
if not exist ".env.arisa.openai" (
  echo Missing .env.arisa.openai (please create it first)
  pause
  exit /b 1
)
set "DOTENV_FILE=.env.arisa.openai"
set "REPO=%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File "%REPO%scripts\doctor.ps1"
if errorlevel 1 (
  echo Doctor checks failed. Fix the issues above and retry.
  pause
  exit /b 1
)
powershell -ExecutionPolicy Bypass -File "scripts\run_arisa.ps1" -DotenvFile ".env.arisa.openai"
pause

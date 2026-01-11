@echo off
cd /d "%~dp0"
set "DOTENV_FILE=.env.gemini"
set "LINE_PORT=8000"
set "REPO=%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File "%REPO%scripts\doctor.ps1"
if errorlevel 1 (
  echo Doctor checks failed. Fix the issues above and retry.
  exit /b 1
)
start "" /D "%REPO%" cmd /k "pwsh -NoExit -ExecutionPolicy Bypass -File \"tools\start_line.ps1\""

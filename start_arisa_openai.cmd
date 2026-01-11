@echo off
cd /d "%~dp0"
if not exist ".env.arisa.openai" (
  echo Missing .env.arisa.openai (please create it first)
  pause
  exit /b 1
)
set "DOTENV_FILE=.env.arisa.openai"
powershell -ExecutionPolicy Bypass -File "scripts\run_arisa.ps1" -DotenvFile ".env.arisa.openai"
pause

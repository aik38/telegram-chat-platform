@echo off
cd /d "%~dp0"
if not exist ".env.arisa.openai" (
  echo Missing .env.arisa.openai (please create it first)
  pause
  exit /b 1
)
copy /Y ".env.arisa.openai" ".env" >nul
powershell -ExecutionPolicy Bypass -File "scripts\run_default.ps1"
pause

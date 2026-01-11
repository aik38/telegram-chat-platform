@echo off
cd /d "%~dp0"
if not exist ".env.arisa.gemini" (
  echo Missing .env.arisa.gemini (please create it first)
  pause
  exit /b 1
)
copy /Y ".env.arisa.gemini" ".env" >nul
powershell -ExecutionPolicy Bypass -File "scripts\run_default.ps1"
pause

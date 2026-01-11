@echo off
cd /d "%~dp0"
set "DOTENV_FILE=.env.arisa"
powershell -ExecutionPolicy Bypass -File "scripts\run_arisa.ps1"
pause

@echo off
cd /d "%~dp0"
set "DOTENV_FILE=.env.openai"
powershell -ExecutionPolicy Bypass -File "scripts\run_default.ps1"
pause

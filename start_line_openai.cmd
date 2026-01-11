@echo off
cd /d "%~dp0"
set "DOTENV_FILE=.env.openai"
set "LINE_PORT=8001"
powershell -ExecutionPolicy Bypass -File "scripts\run_line.ps1"
pause

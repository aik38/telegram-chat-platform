@echo off
cd /d "%~dp0"
set "DOTENV_FILE=.env.gemini"
set "LINE_PORT=8000"
powershell -ExecutionPolicy Bypass -File "scripts\run_line.ps1"
pause

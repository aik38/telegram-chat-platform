@echo off
cd /d "%~dp0"
set "DOTENV_FILE=.env.gemini"
pwsh -NoExit -ExecutionPolicy Bypass -File "tools\start_line.ps1"

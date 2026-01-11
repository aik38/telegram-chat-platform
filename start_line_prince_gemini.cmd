@echo off
cd /d "%~dp0"
set "DOTENV_FILE=.env.gemini"
pwsh -NoExit -ExecutionPolicy Bypass -File "%~dp0tools\start_line.ps1"

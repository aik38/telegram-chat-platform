@echo off
cd /d "%~dp0"
copy /Y ".env.gemini" ".env" >nul
pwsh -NoExit -ExecutionPolicy Bypass -File "%~dp0tools\start_line.ps1"

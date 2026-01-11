@echo off
cd /d "%~dp0"
copy /Y ".env.gemini" ".env" >nul
powershell -ExecutionPolicy Bypass -File "scripts\run_default.ps1"
pause

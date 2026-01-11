@echo off
cd /d "%~dp0"
copy /Y ".env.arisa" ".env" >nul
powershell -ExecutionPolicy Bypass -File "scripts\run_arisa.ps1"
pause

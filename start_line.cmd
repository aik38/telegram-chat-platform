@echo off
cd /d "%~dp0"
pwsh -NoExit -ExecutionPolicy Bypass -File "tools\start_line.ps1"

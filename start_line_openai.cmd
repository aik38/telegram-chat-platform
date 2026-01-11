@echo off
cd /d "%~dp0"
set "DOTENV_FILE=.env.openai"
if exist "scripts\run_line.ps1" (
  powershell -ExecutionPolicy Bypass -File "scripts\run_line.ps1"
) else if exist "scripts\run_api.ps1" (
  powershell -ExecutionPolicy Bypass -File "scripts\run_api.ps1"
) else (
  powershell -ExecutionPolicy Bypass -Command ".\.venv\Scripts\python.exe -m uvicorn api.main:app --host 0.0.0.0 --port 8000"
)
pause

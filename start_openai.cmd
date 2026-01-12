@echo off
setlocal EnableExtensions
cd /d "%~dp0"
set "REPO=%~dp0"
set "DOTENV_FILE=.env.openai"
for %%I in ("%REPO%%DOTENV_FILE%") do set "DOTENV_PATH=%%~fI"
if not exist "%DOTENV_PATH%" (
  echo [ERROR] Dotenv file not found: "%DOTENV_PATH%"
  exit /b 1
)
where pwsh >nul 2>nul && (set "PS=pwsh") || (set "PS=powershell")
for /f %%I in ('%PS% -NoProfile -Command "Get-Date -Format yyyyMMdd_HHmmss"') do set "TS=%%I"
set "LOG_DIR=%REPO%40_logs"
if not exist "%LOG_DIR%" mkdir "%LOG_DIR%"
set "LOG_FILE=%LOG_DIR%\\launcher_%TS%.log"
echo DOTENV_FILE="%DOTENV_PATH%"
echo Log: "%LOG_FILE%"
echo Running: %PS% -NoProfile -ExecutionPolicy Bypass -File "%REPO%scripts\doctor.ps1" -DotenvFile "%DOTENV_PATH%"
%PS% -NoProfile -ExecutionPolicy Bypass -Command "& { $ErrorActionPreference='Stop'; & '%REPO%scripts\doctor.ps1' -DotenvFile '%DOTENV_PATH%' 2>&1 | Tee-Object -FilePath '%LOG_FILE%'; exit $LASTEXITCODE }"
if errorlevel 1 (
  echo Doctor failed. Fix issues above. See "%LOG_FILE%".
  pause
  exit /b 1
)
echo Running: %PS% -NoProfile -ExecutionPolicy Bypass -File "%REPO%scripts\run_default.ps1" -DotenvFile "%DOTENV_PATH%"
%PS% -NoProfile -ExecutionPolicy Bypass -Command "& { $ErrorActionPreference='Stop'; & '%REPO%scripts\run_default.ps1' -DotenvFile '%DOTENV_PATH%' 2>&1 | Tee-Object -FilePath '%LOG_FILE%' -Append; exit $LASTEXITCODE }"
if errorlevel 1 (
  echo Launcher failed. See "%LOG_FILE%".
  pause
  exit /b 1
)

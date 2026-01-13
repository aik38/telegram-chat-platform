@echo off
setlocal enableextensions

set "REPO=%USERPROFILE%\OneDrive\繝・せ繧ｯ繝医ャ繝予telegram-chat-platform"
set "LOG=%USERPROFILE%\launcher_cmd.log"

echo [%DATE% %TIME%] Launcher.cmd start>>"%LOG%" 2>&1
echo REPO=%REPO%>>"%LOG%" 2>&1
echo LOG=%LOG%>>"%LOG%" 2>&1

if not exist "%REPO%" (
  echo [%DATE% %TIME%] ERROR: Repo not found: "%REPO%">>"%LOG%" 2>&1
  echo Repo not found: "%REPO%"
  echo Log: "%LOG%"
  pause
  exit /b 1
)

pushd "%REPO%" >>"%LOG%" 2>&1
if errorlevel 1 (
  echo [%DATE% %TIME%] ERROR: pushd failed.>>"%LOG%" 2>&1
  echo pushd failed. Log: "%LOG%"
  pause
  exit /b 1
)

where pwsh >>"%LOG%" 2>&1
if errorlevel 1 (
  echo [%DATE% %TIME%] ERROR: pwsh not found in PATH.>>"%LOG%" 2>&1
  echo pwsh not found. Log: "%LOG%"
  pause
  popd
  exit /b 1
)
set "PS_EXE=pwsh"

if not exist "%REPO%\tools\launcher.ps1" (
  echo [%DATE% %TIME%] ERROR: tools\launcher.ps1 not found.>>"%LOG%" 2>&1
  echo tools\launcher.ps1 not found. Log: "%LOG%"
  pause
  popd
  exit /b 1
)

"%PS_EXE%" -NoProfile -ExecutionPolicy Bypass -File "%REPO%\tools\launcher.ps1" %* >>"%LOG%" 2>&1
set "EXITCODE=%ERRORLEVEL%"

if not "%EXITCODE%"=="0" (
  echo [%DATE% %TIME%] ERROR: launcher failed with exit code %EXITCODE%.>>"%LOG%" 2>&1
  echo Launcher failed with exit code %EXITCODE%. Log: "%LOG%"
  pause
)

popd >>"%LOG%" 2>&1
exit /b %EXITCODE%

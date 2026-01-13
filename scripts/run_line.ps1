param([string]$Provider="openai")
$ErrorActionPreference="Stop"
$repo = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
& pwsh -NoProfile -ExecutionPolicy Bypass -File (Join-Path $repo "tools\launcher.ps1") -App "line" -Provider $Provider @args
exit $LASTEXITCODE

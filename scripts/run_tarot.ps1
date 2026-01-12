Param(
    [string]$DotenvFile
)

$ErrorActionPreference = "Stop"

$RepoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
Set-Location $RepoRoot

if (-not $DotenvFile) {
    $DotenvFile = $env:DOTENV_FILE
}
if (-not $DotenvFile) {
    $DotenvFile = ".env"
}
$DotenvDisplay = $DotenvFile
$DotenvPath = if ([System.IO.Path]::IsPathRooted($DotenvFile)) { $DotenvFile } else { Join-Path $RepoRoot $DotenvFile }
$DotenvPath = [System.IO.Path]::GetFullPath($DotenvPath)
$env:DOTENV_FILE = $DotenvPath

Write-Host "Starting Tarot bot with DOTENV_FILE=$DotenvDisplay"

$DoctorPath = Join-Path $PSScriptRoot "doctor.ps1"
& powershell -NoProfile -ExecutionPolicy Bypass -File $DoctorPath
if ($LASTEXITCODE -ne 0) {
    Write-Host "Doctor checks failed. Fix the issues above and retry."
    exit $LASTEXITCODE
}

& "$PSScriptRoot\windows_bootstrap.ps1" -DotenvFile $DotenvFile

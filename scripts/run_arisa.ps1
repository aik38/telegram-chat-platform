Param(
    [string]$DotenvFile
)

$ErrorActionPreference = "Stop"

$RepoRoot = Split-Path -Parent $PSScriptRoot
Set-Location $RepoRoot

if (-not $DotenvFile) {
    $DotenvFile = $env:DOTENV_FILE
}
if (-not $DotenvFile) {
    $DotenvFile = ".env.arisa.gemini"
}
if (-not (Test-Path $DotenvFile)) {
    Write-Error "Missing $DotenvFile. Create it (e.g. .env.arisa.gemini or .env.arisa.openai) and retry."
    exit 1
}
$env:DOTENV_FILE = $DotenvFile
$env:CHARACTER = "arisa"
Write-Host "Starting Arisa bot with DOTENV_FILE=$env:DOTENV_FILE and CHARACTER=$env:CHARACTER"

$DoctorPath = Join-Path $RepoRoot "scripts\\doctor.ps1"
& powershell -NoProfile -ExecutionPolicy Bypass -File $DoctorPath
if ($LASTEXITCODE -ne 0) {
    Write-Host "Doctor checks failed. Fix the issues above and retry."
    exit $LASTEXITCODE
}

& "$PSScriptRoot\windows_bootstrap.ps1" -DotenvFile $env:DOTENV_FILE

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
    $DotenvFile = ".env"
}
$env:DOTENV_FILE = $DotenvFile

Write-Host "Starting Tarot bot with DOTENV_FILE=$DotenvFile"
& "$PSScriptRoot\windows_bootstrap.ps1" -DotenvFile $env:DOTENV_FILE

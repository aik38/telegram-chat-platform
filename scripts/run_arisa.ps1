$ErrorActionPreference = "Stop"

$RepoRoot = Split-Path -Parent $PSScriptRoot
Set-Location $RepoRoot

$env:DOTENV_FILE = ".env.arisa"
Write-Host "Starting Arisa bot with DOTENV_FILE=$env:DOTENV_FILE (ensure TELEGRAM_BOT_TOKEN and CHARACTER=arisa)"

& "$PSScriptRoot\windows_bootstrap.ps1" -DotenvFile $env:DOTENV_FILE

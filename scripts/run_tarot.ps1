Param(
    [string]$DotenvFile
)

$ErrorActionPreference = "Stop"

$RepoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
Set-Location $RepoRoot

function Resolve-DotenvPath {
    param(
        [string]$DotenvFile
    )
    if (-not $DotenvFile) {
        return $null
    }
    if ([System.IO.Path]::IsPathRooted($DotenvFile)) {
        return [System.IO.Path]::GetFullPath($DotenvFile)
    }
    return [System.IO.Path]::GetFullPath((Join-Path $RepoRoot $DotenvFile))
}

if (-not $DotenvFile) {
    $DotenvFile = $env:DOTENV_FILE
}
if (-not $DotenvFile) {
    $DotenvFile = ".env"
}
$DotenvPath = Resolve-DotenvPath -DotenvFile $DotenvFile
$DotenvDisplay = $DotenvPath
$env:DOTENV_FILE = $DotenvPath

$PythonExe = Join-Path $RepoRoot ".venv\Scripts\python.exe"
if (-not (Test-Path $PythonExe)) {
    $PythonExe = "python"
}

Write-Host "Starting Tarot bot with DOTENV_FILE=$DotenvDisplay"
& $PythonExe -m bot.main

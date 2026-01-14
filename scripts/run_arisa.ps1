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
    $DotenvFile = ".env.arisa.gemini"
}
$DotenvPath = Resolve-DotenvPath -DotenvFile $DotenvFile
$DotenvDisplay = $DotenvPath
if (-not (Test-Path $DotenvPath)) {
    Write-Error "Missing $DotenvDisplay. Create it (e.g. .env.arisa.gemini or .env.arisa.openai) and retry."
    exit 1
}
$env:DOTENV_FILE = $DotenvPath
$env:CHARACTER = "arisa"
Write-Host "Starting Arisa bot with DOTENV_FILE=$DotenvDisplay and CHARACTER=$env:CHARACTER"

$PythonExe = Join-Path $RepoRoot ".venv\Scripts\python.exe"
if (-not (Test-Path $PythonExe)) {
    $PythonExe = "python"
}

& $PythonExe -m bot.main

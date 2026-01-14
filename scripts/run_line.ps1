Param(
    [string]$DotenvFile,
    [string]$Port
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

if (-not $Port) {
    $Port = $env:LINE_PORT
}
if (-not $Port) {
    $Port = $env:API_PORT
}
if (-not $Port) {
    $Port = "8000"
}

$PythonExe = Join-Path $RepoRoot ".venv\Scripts\python.exe"
if (-not (Test-Path $PythonExe)) {
    $PythonExe = "python"
}

Write-Host "Starting LINE API server with DOTENV_FILE=$DotenvDisplay (port $Port)"
& $PythonExe -m uvicorn api.main:app --host 0.0.0.0 --port $Port

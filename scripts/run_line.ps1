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

$Port = $env:LINE_PORT
if (-not $Port) {
    $Port = $env:API_PORT
}
if (-not $Port) {
    $Port = 8000
}
[int]$ParsedPort = 0
if (-not [int]::TryParse($Port, [ref]$ParsedPort)) {
    throw "Invalid LINE_PORT/API_PORT value: $Port"
}
$Port = $ParsedPort

function Test-PortInUse {
    param(
        [int]$Port
    )
    try {
        $listener = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Any, $Port)
        $listener.Start()
        $listener.Stop()
        return $false
    } catch {
        return $true
    }
}

if (Test-PortInUse -Port $Port) {
    Write-Error "Port $Port is already in use. Set LINE_PORT (or API_PORT) to a free port and retry."
    exit 1
}

if (-not (Test-Path ".venv")) {
    Write-Host "Creating virtual environment in .venv..."
    python -m venv .venv
}

$PythonExe = Join-Path $RepoRoot ".venv\Scripts\python.exe"
if (-not (Test-Path $PythonExe)) {
    throw "Python executable not found at $PythonExe"
}

Write-Host "Upgrading pip/setuptools/wheel..."
& $PythonExe -m pip install -U pip setuptools wheel

if (Test-Path "requirements.txt") {
    Write-Host "Installing dependencies from requirements.txt..."
    & $PythonExe -m pip install -r "requirements.txt"
} elseif (Test-Path "requirements") {
    Write-Host "Installing dependencies from requirements..."
    & $PythonExe -m pip install -r "requirements"
}

Write-Host "Starting LINE API server with DOTENV_FILE=$DotenvFile on port $Port"
& $PythonExe -m uvicorn api.main:app --host 0.0.0.0 --port $Port

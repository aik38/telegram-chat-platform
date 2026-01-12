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
$env:LINE_PORT = $Port

$DoctorPath = Join-Path $PSScriptRoot "doctor.ps1"
& powershell -NoProfile -ExecutionPolicy Bypass -File $DoctorPath
if ($LASTEXITCODE -ne 0) {
    Write-Host "Doctor checks failed. Fix the issues above and retry."
    exit $LASTEXITCODE
}

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

$VenvPath = Join-Path $RepoRoot ".venv"
if (-not (Test-Path $VenvPath)) {
    Write-Host "Creating virtual environment in .venv..."
    python -m venv $VenvPath
}

$PythonExe = Join-Path $RepoRoot ".venv\Scripts\python.exe"
if (-not (Test-Path $PythonExe)) {
    throw "Python executable not found at $PythonExe"
}

Write-Host "Upgrading pip/setuptools/wheel..."
& $PythonExe -m pip install -U pip setuptools wheel

$RequirementsTxt = Join-Path $RepoRoot "requirements.txt"
$RequirementsFile = Join-Path $RepoRoot "requirements"
if (Test-Path $RequirementsTxt) {
    Write-Host "Installing dependencies from requirements.txt..."
    & $PythonExe -m pip install -r $RequirementsTxt
} elseif (Test-Path $RequirementsFile) {
    Write-Host "Installing dependencies from requirements..."
    & $PythonExe -m pip install -r $RequirementsFile
}

Write-Host "Starting LINE API server with DOTENV_FILE=$DotenvDisplay on port $Port"
& $PythonExe -m uvicorn api.main:app --host 0.0.0.0 --port $Port

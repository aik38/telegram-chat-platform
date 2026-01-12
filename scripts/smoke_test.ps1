Param(
    [string]$DotenvFile
)

$ErrorActionPreference = "Stop"

function Mask-Secret {
    param([string]$Value)
    if (-not $Value) {
        return "<not set>"
    }
    $len = $Value.Length
    if ($len -le 8) {
        return ("*" * $len)
    }
    $prefix = $Value.Substring(0, 4)
    $suffix = $Value.Substring($len - 4)
    return "$prefix...$suffix"
}

function Get-EnvDisplay {
    param([string]$Value)
    if (-not $Value) {
        return "<not set>"
    }
    return $Value
}

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
$env:DOTENV_FILE = $DotenvPath

$DoctorPath = Join-Path $PSScriptRoot "doctor.ps1"
& powershell -NoProfile -ExecutionPolicy Bypass -File $DoctorPath
if ($LASTEXITCODE -ne 0) {
    Write-Host "Doctor checks failed. Fix the issues above and retry."
    exit $LASTEXITCODE
}

$PythonExe = Join-Path $RepoRoot ".venv\Scripts\python.exe"
if (-not (Test-Path $PythonExe)) {
    $PythonExe = "python"
}

Write-Host "Loading dotenv from: $DotenvPath"
& $PythonExe -c "from dotenv import load_dotenv; import os; path=os.getenv('DOTENV_FILE', '.env'); loaded=load_dotenv(path, override=False); print(f'DOTENV_FILE={path} loaded={loaded}')"

Write-Host "Environment status:"
Write-Host "  TELEGRAM_BOT_TOKEN: $(Mask-Secret $env:TELEGRAM_BOT_TOKEN)"
Write-Host "  OPENAI_API_KEY: $(Mask-Secret $env:OPENAI_API_KEY)"
Write-Host "  SQLITE_DB_PATH: $(Get-EnvDisplay $env:SQLITE_DB_PATH)"
Write-Host "  CHARACTER: $(Get-EnvDisplay $env:CHARACTER)"
Write-Host "  PAYWALL_ENABLED: $(Get-EnvDisplay $env:PAYWALL_ENABLED)"

Write-Host "aiogram version:"
& $PythonExe -c "import aiogram; print(aiogram.__version__)"

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

$Port = $env:LINE_PORT
if (-not $Port) {
    $Port = $env:API_PORT
}
if (-not $Port) {
    $Port = 8000
}
[int]$ParsedPort = 0
if (-not [int]::TryParse($Port, [ref]$ParsedPort)) {
    Write-Host "Invalid LINE_PORT/API_PORT value: $Port"
    exit 1
}
$Port = $ParsedPort

if (Test-PortInUse -Port $Port) {
    Write-Host "Port $Port is already in use. Set LINE_PORT (or API_PORT) to a free port before running scripts/run_line.ps1."
} else {
    Write-Host "Port $Port looks available for scripts/run_line.ps1."
}

Write-Host "After starting, verify: http://127.0.0.1:$Port/docs returns 200."

if (-not $env:TELEGRAM_BOT_TOKEN) {
    Write-Host "TELEGRAM_BOT_TOKEN is not set. Skipping Telegram API checks."
    exit 0
}

$BaseUrl = "https://api.telegram.org/bot$($env:TELEGRAM_BOT_TOKEN)"

Write-Host "Calling getMe..."
$me = Invoke-RestMethod -Method Get -Uri "$BaseUrl/getMe"
Write-Host "getMe ok: $($me.result.username)"

Write-Host "Calling getWebhookInfo..."
$webhook = Invoke-RestMethod -Method Get -Uri "$BaseUrl/getWebhookInfo"
Write-Host "getWebhookInfo ok: $($webhook.result.url)"

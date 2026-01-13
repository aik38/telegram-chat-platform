param(
    [string]$DotenvFile,
    [ValidateSet("gemini", "openai")]
    [string]$Provider = "gemini",
    [int]$Port,
    [int]$TimeoutSec = 90
)

$ErrorActionPreference = "Stop"

$RepoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
Set-Location $RepoRoot

# ----- logs -----
$logDir = Join-Path $RepoRoot "40_logs"
New-Item -ItemType Directory -Force -Path $logDir | Out-Null
$stamp = Get-Date -Format "yyyyMMdd_HHmmss"

$runtimeLog = Join-Path $logDir ("line_runtime_{0}.txt" -f $stamp)
$apiOut     = Join-Path $logDir ("line_api_{0}_out.log" -f $stamp)
$apiErr     = Join-Path $logDir ("line_api_{0}_err.log" -f $stamp)
$ngrokOut   = Join-Path $logDir ("ngrok_{0}_out.log" -f $stamp)
$ngrokErr   = Join-Path $logDir ("ngrok_{0}_err.log" -f $stamp)

function Log([string]$msg) {
    $line = "[{0}] {1}" -f (Get-Date -Format "HH:mm:ss"), $msg
    $line | Tee-Object -FilePath $runtimeLog -Append | Out-Host
}

function Resolve-DotenvPath {
    param([string]$DotenvFile)
    if (-not $DotenvFile) { return $null }
    if ([System.IO.Path]::IsPathRooted($DotenvFile)) {
        return [System.IO.Path]::GetFullPath($DotenvFile)
    }
    return [System.IO.Path]::GetFullPath((Join-Path $RepoRoot $DotenvFile))
}

function Test-PortListening([int]$p) {
    try {
        $null = Get-NetTCPConnection -LocalPort $p -State Listen -ErrorAction Stop
        return $true
    } catch {
        return $false
    }
}

function Wait-Listening([int]$p, [int]$seconds, [string]$name, [System.Diagnostics.Process]$procToWatch) {
    for ($i = 0; $i -lt $seconds; $i++) {
        if ($procToWatch -and $procToWatch.HasExited) {
            throw "$name process exited early. See logs: $apiErr / $ngrokErr"
        }
        if (Test-PortListening $p) { return }
        Start-Sleep 1
    }
    throw "Timeout: port $p did not become LISTEN within ${seconds}s."
}

function Get-EnvValueFromFile([string]$path, [string]$key) {
    if (-not (Test-Path $path)) { return $null }
    $line = Get-Content $path -ErrorAction SilentlyContinue |
        Where-Object { $_ -match "^\s*$([regex]::Escape($key))\s*=" } |
        Select-Object -First 1
    if (-not $line) { return $null }
    $val = ($line -split "=", 2)[1].Trim()
    $val = $val.Trim('"')
    return $val
}

function Try-GetNgrokPublicUrl {
    try {
        $t = Invoke-RestMethod "http://127.0.0.1:4040/api/tunnels" -TimeoutSec 2
        $https = ($t.tunnels | Where-Object { $_.proto -eq "https" } | Select-Object -First 1).public_url
        if ($https) { return $https }
    } catch {}
    return $null
}

$DotenvCandidate = $null
if ($PSBoundParameters.ContainsKey("DotenvFile") -and $DotenvFile) {
    $DotenvCandidate = $DotenvFile
} elseif ($env:DOTENV_FILE) {
    $DotenvCandidate = $env:DOTENV_FILE
} else {
    $DotenvCandidate = ".env"
}
$DotenvResolved = Resolve-DotenvPath -DotenvFile $DotenvCandidate
$DotenvDisplay = $DotenvResolved
$DotenvPath = $null
if ($DotenvCandidate -and (Test-Path -LiteralPath $DotenvResolved)) {
    $DotenvPath = $DotenvResolved
    $env:DOTENV_FILE = $DotenvPath
} elseif ($PSBoundParameters.ContainsKey("DotenvFile") -or $env:DOTENV_FILE) {
    throw "Dotenv file not found: $DotenvResolved"
} else {
    $DotenvDisplay = "(none)"
}

$PortCandidate = $null
if ($PSBoundParameters.ContainsKey("Port") -and $Port -gt 0) {
    $PortCandidate = $Port
} elseif ($env:LINE_PORT) {
    $PortCandidate = $env:LINE_PORT
} elseif ($env:API_PORT) {
    $PortCandidate = $env:API_PORT
} else {
    $PortCandidate = 8000
}
[int]$ParsedPort = 0
if (-not [int]::TryParse($PortCandidate, [ref]$ParsedPort)) {
    throw "Invalid port value: $PortCandidate"
}
$Port = $ParsedPort
$env:LINE_PORT = $Port

if (-not $PSBoundParameters.ContainsKey("TimeoutSec") -and $env:LINE_TIMEOUT_SEC) {
    [int]$ParsedTimeout = 0
    if ([int]::TryParse($env:LINE_TIMEOUT_SEC, [ref]$ParsedTimeout) -and $ParsedTimeout -gt 0) {
        $TimeoutSec = $ParsedTimeout
    }
}

Log "Doctor: repo root $RepoRoot"
Log "DOTENV_FILE=$DotenvDisplay"
Log "LINE_PORT=$Port"
Log "PROVIDER=$Provider"
Log "TIMEOUT_SEC=$TimeoutSec"

# ----- doctor preflight -----
$DoctorPath = Join-Path $PSScriptRoot "..\scripts\doctor.ps1"
$PsExe = if (Get-Command pwsh -ErrorAction SilentlyContinue) { "pwsh" } else { "powershell" }
& $PsExe -NoProfile -ExecutionPolicy Bypass -File $DoctorPath -Mode Preflight
if ($LASTEXITCODE -ne 0) {
    Log "Doctor checks failed."
    exit $LASTEXITCODE
}

# ----- venv / deps -----
$VenvPath = Join-Path $RepoRoot ".venv"
if (-not (Test-Path $VenvPath)) {
    Log "Creating virtual environment in .venv..."
    python -m venv $VenvPath
}

$PythonExe = Join-Path $RepoRoot ".venv\Scripts\python.exe"
if (-not (Test-Path $PythonExe)) {
    throw "Python executable not found at $PythonExe"
}

Log "Upgrading pip/setuptools/wheel..."
& $PythonExe -m pip install -U pip setuptools wheel

$RequirementsTxt  = Join-Path $RepoRoot "requirements.txt"
$RequirementsFile = Join-Path $RepoRoot "requirements"
if (Test-Path $RequirementsTxt) {
    Log "Installing dependencies from requirements.txt..."
    & $PythonExe -m pip install -r $RequirementsTxt
} elseif (Test-Path $RequirementsFile) {
    Log "Installing dependencies from requirements..."
    & $PythonExe -m pip install -r $RequirementsFile
}

# ----- start API (uvicorn) as child process -----
if (Test-PortListening $Port) {
    throw "Port $Port is already LISTENING. Stop the existing process first (or change LINE_PORT)."
}

Log "Starting LINE API server on port $Port ..."
$apiProc = Start-Process -FilePath $PythonExe `
    -ArgumentList @("-m","uvicorn","api.main:app","--host","0.0.0.0","--port","$Port") `
    -PassThru -WindowStyle Minimized `
    -RedirectStandardOutput $apiOut -RedirectStandardError $apiErr

Wait-Listening -p $Port -seconds $TimeoutSec -name "API" -procToWatch $apiProc
Log "API is LISTENING on $Port (pid=$($apiProc.Id))"

# ----- start/reuse ngrok -----
$publicUrl = Try-GetNgrokPublicUrl
$ngrokProc = $null

if (-not $publicUrl) {
    $ngrokCmd = Get-Command ngrok -ErrorAction SilentlyContinue
    if (-not $ngrokCmd) {
        throw "ngrok command not found. Install ngrok and ensure it is in PATH."
    }

    $ngrokCfg = Join-Path $env:LOCALAPPDATA "ngrok\ngrok.yml"
    if (Test-Path $ngrokCfg) {
        $cfgRaw = Get-Content $ngrokCfg -Raw -ErrorAction SilentlyContinue
        if ($cfgRaw -match "authtoken:\s*(YOUR_TOKEN|\"?YOUR_TOKEN\"?)") {
            throw "ngrok authtoken is placeholder (YOUR_TOKEN). Fix $ngrokCfg or run: ngrok config add-authtoken \"<real token>\""
        }
    }

    Log "Starting ngrok tunnel -> http $Port ..."
    $ngrokProc = Start-Process -FilePath $ngrokCmd.Source `
        -ArgumentList @("http","$Port") `
        -PassThru -WindowStyle Minimized `
        -RedirectStandardOutput $ngrokOut -RedirectStandardError $ngrokErr

    for ($i=0; $i -lt 30; $i++) {
        $publicUrl = Try-GetNgrokPublicUrl
        if ($publicUrl) { break }
        if ($ngrokProc.HasExited) {
            throw "ngrok exited early. See logs: $ngrokErr"
        }
        Start-Sleep 1
    }
}

if (-not $publicUrl) {
    throw "ngrok did not expose public_url. Check ngrok logs: $ngrokErr"
}

Log "ngrok public URL: $publicUrl"
Log "ngrok inspector: http://127.0.0.1:4040"

# ----- detect webhook path from OpenAPI (best-effort) -----
$webhookPath = $env:LINE_WEBHOOK_PATH
try {
    $openapi = Invoke-RestMethod "http://127.0.0.1:$Port/openapi.json" -TimeoutSec 5
    $paths = $openapi.paths.PSObject.Properties.Name
    $cand  = $paths | Where-Object { $_ -match "line" -and $_ -match "webhook" } | Select-Object -First 1
    if ($cand) { $webhookPath = $cand }
} catch {}

if (-not $webhookPath) { $webhookPath = "/line/webhook" }
if (-not $webhookPath.StartsWith("/")) { $webhookPath = "/" + $webhookPath }

Log "Webhook path candidate: $webhookPath"

# ----- (optional) auto-update LINE webhook endpoint -----
$accessToken = $env:LINE_CHANNEL_ACCESS_TOKEN
if (-not $accessToken -and $DotenvPath) {
    $accessToken = Get-EnvValueFromFile -path $DotenvPath -key "LINE_CHANNEL_ACCESS_TOKEN"
}

if ($accessToken) {
    $endpoint = $publicUrl.TrimEnd("/") + $webhookPath
    Log "Updating LINE webhook endpoint -> $endpoint"

    try {
        $headers = @{ Authorization = "Bearer $accessToken" }
        $body = @{ endpoint = $endpoint } | ConvertTo-Json
        $null = Invoke-RestMethod -Method Put -Uri "https://api.line.me/v2/bot/channel/webhook/endpoint" `
            -Headers $headers -ContentType "application/json" -Body $body
        Log "LINE webhook update OK."
    } catch {
        Log "LINE webhook update FAILED: $($_.Exception.Message)"
        Log "You can still set webhook manually to: $endpoint"
    }
} else {
    Log "LINE_CHANNEL_ACCESS_TOKEN not found. Skipping webhook update."
}

# ----- keep running -----
$cleanup = {
    try { if ($ngrokProc -and -not $ngrokProc.HasExited) { Stop-Process -Id $ngrokProc.Id -Force -ErrorAction SilentlyContinue } } catch {}
    try { if ($apiProc   -and -not $apiProc.HasExited)   { Stop-Process -Id $apiProc.Id   -Force -ErrorAction SilentlyContinue } } catch {}
}
Register-EngineEvent PowerShell.Exiting -Action $cleanup | Out-Null

Log "RUNNING. Send a LINE message now. Watch ngrok inspector (4040) and logs under 40_logs."
try {
    Wait-Process -Id $apiProc.Id
} finally {
    & $cleanup
}

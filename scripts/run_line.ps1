Param(
    [string]$DotenvFile,
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

<<<<<<< Updated upstream
$DotenvCandidate = $null
if ($PSBoundParameters.ContainsKey("DotenvFile") -and $DotenvFile) {
    $DotenvCandidate = $DotenvFile
} elseif ($env:DOTENV_FILE) {
    $DotenvCandidate = $env:DOTENV_FILE
} else {
    $DotenvCandidate = ".env"
}
$DotenvPath = Resolve-DotenvPath -DotenvFile $DotenvCandidate
$DotenvDisplay = $DotenvPath
if ($DotenvCandidate -and (Test-Path -LiteralPath $DotenvPath)) {
    $env:DOTENV_FILE = $DotenvPath
} elseif ($PSBoundParameters.ContainsKey("DotenvFile") -or $env:DOTENV_FILE) {
    throw "Dotenv file not found: $DotenvPath"
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
=======
function Test-PortListening([int]$p) {
    try {
        $c = Get-NetTCPConnection -LocalPort $p -State Listen -ErrorAction Stop
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

$DotenvCandidate = $DotenvFile
if (-not $DotenvCandidate) { $DotenvCandidate = $env:DOTENV_FILE }
if (-not $DotenvCandidate) { $DotenvCandidate = ".env" }

$DotenvPath = Resolve-DotenvPath -DotenvFile $DotenvCandidate
$env:DOTENV_FILE = $DotenvPath

$PortCandidate = $Port
if (-not $PortCandidate) { $PortCandidate = $env:LINE_PORT }
if (-not $PortCandidate) { $PortCandidate = $env:API_PORT }
if (-not $PortCandidate) { $PortCandidate = 8000 }

>>>>>>> Stashed changes
[int]$ParsedPort = 0
if (-not [int]::TryParse($PortCandidate, [ref]$ParsedPort)) {
    throw "Invalid port value: $PortCandidate"
}
$Port = $ParsedPort
$env:LINE_PORT = $Port

Log "Doctor: repo root $RepoRoot"
Log "DOTENV_FILE=$DotenvPath"
Log "LINE_PORT=$Port"

# ----- doctor preflight -----
$DoctorPath = Join-Path $PSScriptRoot "doctor.ps1"
$PsExe = if (Get-Command pwsh -ErrorAction SilentlyContinue) { "pwsh" } else { "powershell" }
& $PsExe -NoProfile -ExecutionPolicy Bypass -File $DoctorPath -Mode Preflight
if ($LASTEXITCODE -ne 0) {
    Log "Doctor checks failed."
    exit $LASTEXITCODE
}

<<<<<<< Updated upstream
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

function Wait-ForEndpoint {
    param(
        [string]$Url,
        [int]$TimeoutSec = 60
    )
    $deadline = (Get-Date).AddSeconds($TimeoutSec)
    while ((Get-Date) -lt $deadline) {
        try {
            Invoke-RestMethod -Method Get -Uri $Url -TimeoutSec 2 -ErrorAction Stop | Out-Null
            return $true
        } catch {
            Start-Sleep -Seconds 1
        }
    }
    return $false
}

function Show-LogTail {
    param(
        [string]$Label,
        [string]$OutPath,
        [string]$ErrPath
    )
    if ($OutPath -and (Test-Path -LiteralPath $OutPath)) {
        Write-Host "---- $Label stdout tail ($OutPath) ----"
        Get-Content -LiteralPath $OutPath -Tail 200
    } else {
        Write-Host "---- $Label stdout not found ----"
    }
    if ($ErrPath -and (Test-Path -LiteralPath $ErrPath)) {
        Write-Host "---- $Label stderr tail ($ErrPath) ----"
        Get-Content -LiteralPath $ErrPath -Tail 200
    } else {
        Write-Host "---- $Label stderr not found ----"
    }
}

function Fail-WithLogs {
    param(
        [string]$Message,
        [string]$ServerOut,
        [string]$ServerErr,
        [string]$NgrokOut,
        [string]$NgrokErr
    )
    Write-Error $Message
    Show-LogTail -Label "server" -OutPath $ServerOut -ErrPath $ServerErr
    Show-LogTail -Label "ngrok" -OutPath $NgrokOut -ErrPath $NgrokErr
    exit 1
}

function Get-NgrokPublicUrl {
    param(
        [int]$Port
    )
    $tunnels = Invoke-RestMethod -Method Get -Uri ("http://127.0.0.1:{0}/api/tunnels" -f $Port) -TimeoutSec 5 -ErrorAction Stop
    foreach ($tunnel in $tunnels.tunnels) {
        if ($tunnel.public_url -like "https://*") {
            return $tunnel.public_url
        }
    }
    return $null
}

$Host = "127.0.0.1"
$HealthUrl = "http://$Host:$Port/health"

Write-Host "DOTENV_FILE priority: parameter > env:DOTENV_FILE > .env"
Write-Host "Resolved DOTENV_FILE: $DotenvDisplay"
Write-Host "Resolved LINE_PORT/API_PORT: $Port"

$shouldStartServer = $true
if (Test-PortInUse -Port $Port) {
    if (Wait-ForEndpoint -Url $HealthUrl -TimeoutSec 2) {
        Write-Host "LINE API already responding on $HealthUrl. Reusing existing process."
        $shouldStartServer = $false
    } else {
        Write-Error "Port $Port is already in use and /health is not responding. Set LINE_PORT (or API_PORT) to a free port and retry."
        exit 1
    }
}

=======
# ----- venv / deps -----
>>>>>>> Stashed changes
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

<<<<<<< Updated upstream
$LogDir = Join-Path $RepoRoot "40_logs"
if (-not (Test-Path -LiteralPath $LogDir)) {
    New-Item -ItemType Directory -Path $LogDir | Out-Null
=======
# ----- start API (uvicorn) as child process -----
if (Test-PortListening $Port) {
    throw "Port $Port is already LISTENING. Stop the existing process first (or change LINE_PORT)."
}

Log "Starting LINE API server on port $Port ..."
$apiProc = Start-Process -FilePath $PythonExe `
    -ArgumentList @("-m","uvicorn","api.main:app","--host","0.0.0.0","--port","$Port") `
    -PassThru -WindowStyle Minimized `
    -RedirectStandardOutput $apiOut -RedirectStandardError $apiErr

Wait-Listening -p $Port -seconds 25 -name "API" -procToWatch $apiProc
Log "API is LISTENING on $Port (pid=$($apiProc.Id))"

# ----- start/reuse ngrok -----
$publicUrl = Try-GetNgrokPublicUrl
$ngrokProc = $null

if (-not $publicUrl) {
    $ngrokCmd = Get-Command ngrok -ErrorAction SilentlyContinue
    if (-not $ngrokCmd) {
        throw "ngrok command not found. Install ngrok and ensure it is in PATH."
    }

    # Fail fast if authtoken is clearly placeholder
    $ngrokCfg = Join-Path $env:LOCALAPPDATA "ngrok\ngrok.yml"
    if (Test-Path $ngrokCfg) {
        $cfgRaw = Get-Content $ngrokCfg -Raw -ErrorAction SilentlyContinue
        if ($cfgRaw -match "authtoken:\s*(YOUR_TOKEN|\"?YOUR_TOKEN\"?)") {
            throw "ngrok authtoken is placeholder (YOUR_TOKEN). Fix $ngrokCfg or run: ngrok config add-authtoken ""<real token>"""
        }
    }

    Log "Starting ngrok tunnel -> http $Port ..."
    # NOTE: ngrok v3 does NOT support --web-addr (old flag). Default inspector is 127.0.0.1:4040
    $ngrokProc = Start-Process -FilePath $ngrokCmd.Source `
        -ArgumentList @("http","$Port") `
        -PassThru -WindowStyle Minimized `
        -RedirectStandardOutput $ngrokOut -RedirectStandardError $ngrokErr

    # Wait for inspector + https public URL
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
$accessToken = Get-EnvValueFromFile -path $DotenvPath -key "LINE_CHANNEL_ACCESS_TOKEN"
if ($accessToken) {
    $endpoint = $publicUrl.TrimEnd("/") + $webhookPath
    Log "Updating LINE webhook endpoint -> $endpoint"

    try {
        $headers = @{ Authorization = "Bearer $accessToken" }
        $body = @{ endpoint = $endpoint } | ConvertTo-Json
        $resp = Invoke-RestMethod -Method Put -Uri "https://api.line.me/v2/bot/channel/webhook/endpoint" `
            -Headers $headers -ContentType "application/json" -Body $body
        Log "LINE webhook update OK."
    } catch {
        Log "LINE webhook update FAILED: $($_.Exception.Message)"
        Log "You can still set webhook manually to: $endpoint"
    }
} else {
    Log "LINE_CHANNEL_ACCESS_TOKEN not found in $DotenvPath. Skipping webhook update."
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
>>>>>>> Stashed changes
}
$Timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$ServerOut = Join-Path $LogDir "line_api_${Timestamp}_out.log"
$ServerErr = Join-Path $LogDir "line_api_${Timestamp}_err.log"
$NgrokOut = Join-Path $LogDir "ngrok_${Timestamp}_out.log"
$NgrokErr = Join-Path $LogDir "ngrok_${Timestamp}_err.log"
$PidFile = Join-Path $LogDir "line_runtime_${Timestamp}.txt"

$serverPid = $null
if ($shouldStartServer) {
    Write-Host "Starting uvicorn api.main:app --host $Host --port $Port (DOTENV_FILE=$DotenvDisplay)"
    $serverArgs = @("-m", "uvicorn", "api.main:app", "--host", $Host, "--port", $Port)
    $serverProc = Start-Process -FilePath $PythonExe `
        -ArgumentList $serverArgs `
        -RedirectStandardOutput $ServerOut `
        -RedirectStandardError $ServerErr `
        -PassThru
    $serverPid = $serverProc.Id
}

if (-not (Wait-ForEndpoint -Url $HealthUrl -TimeoutSec $TimeoutSec)) {
    Fail-WithLogs -Message "LINE API server did not become healthy on $HealthUrl." -ServerOut $ServerOut -ServerErr $ServerErr -NgrokOut $NgrokOut -NgrokErr $NgrokErr
}

$NgrokPath = Join-Path $RepoRoot "tools\\run_ngrok.ps1"
$ngrokPid = $null
if (-not (Wait-ForEndpoint -Url "http://127.0.0.1:4040/api/tunnels" -TimeoutSec 3)) {
    Write-Host "Starting ngrok for http://$Host:$Port"
    $ngrokArgs = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", $NgrokPath, "-Port", $Port)
    $ngrokProc = Start-Process -FilePath $PsExe `
        -ArgumentList $ngrokArgs `
        -RedirectStandardOutput $NgrokOut `
        -RedirectStandardError $NgrokErr `
        -PassThru
    $ngrokPid = $ngrokProc.Id
}

if (-not (Wait-ForEndpoint -Url "http://127.0.0.1:4040/api/tunnels" -TimeoutSec 30)) {
    Fail-WithLogs -Message "ngrok API did not become available." -ServerOut $ServerOut -ServerErr $ServerErr -NgrokOut $NgrokOut -NgrokErr $NgrokErr
}

try {
    $publicUrl = Get-NgrokPublicUrl -Port 4040
} catch {
    Fail-WithLogs -Message "Failed to fetch ngrok tunnels." -ServerOut $ServerOut -ServerErr $ServerErr -NgrokOut $NgrokOut -NgrokErr $NgrokErr
}

if (-not $publicUrl) {
    Fail-WithLogs -Message "No https public_url found from ngrok." -ServerOut $ServerOut -ServerErr $ServerErr -NgrokOut $NgrokOut -NgrokErr $NgrokErr
}

Write-Host "ngrok public URL: $publicUrl"
Write-Host ("Set LINE Webhook URL to: {0}/webhooks/line" -f $publicUrl)

"server_pid=$serverPid" | Set-Content -LiteralPath $PidFile
Add-Content -LiteralPath $PidFile ("ngrok_pid={0}" -f $ngrokPid)
Add-Content -LiteralPath $PidFile ("server_stdout={0}" -f $ServerOut)
Add-Content -LiteralPath $PidFile ("server_stderr={0}" -f $ServerErr)
Add-Content -LiteralPath $PidFile ("ngrok_stdout={0}" -f $NgrokOut)
Add-Content -LiteralPath $PidFile ("ngrok_stderr={0}" -f $NgrokErr)
Add-Content -LiteralPath $PidFile ("uvicorn_host={0}" -f $Host)
Add-Content -LiteralPath $PidFile ("uvicorn_port={0}" -f $Port)
Add-Content -LiteralPath $PidFile ("dotenv_file={0}" -f $DotenvDisplay)

Write-Host "Runtime info saved to $PidFile"
Write-Host "LINE webhook is reachable via ngrok."

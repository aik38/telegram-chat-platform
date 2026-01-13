Param(
    [string]$DotenvFile,
    [int]$Port,
    [int]$TimeoutSec = 90
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
[int]$ParsedPort = 0
if (-not [int]::TryParse($PortCandidate, [ref]$ParsedPort)) {
    throw "Invalid port value: $PortCandidate"
}
$Port = $ParsedPort
$env:LINE_PORT = $Port

$DoctorPath = Join-Path $PSScriptRoot "doctor.ps1"
$PsExe = if (Get-Command pwsh -ErrorAction SilentlyContinue) { "pwsh" } else { "powershell" }
& $PsExe -NoProfile -ExecutionPolicy Bypass -File $DoctorPath -Mode Preflight
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

$LogDir = Join-Path $RepoRoot "40_logs"
if (-not (Test-Path -LiteralPath $LogDir)) {
    New-Item -ItemType Directory -Path $LogDir | Out-Null
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

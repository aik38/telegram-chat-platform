param(
    [string]$DotenvFile,
    [ValidateSet("gemini", "openai")]
    [string]$Provider = "gemini",
    [int]$Port = 8000,
    [int]$TimeoutSec = 90
)

$ErrorActionPreference = "Stop"

$RepoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
Set-Location $RepoRoot

function Resolve-DotenvPath {
    param(
        [string]$DotenvFile,
        [string]$Provider
    )
    if ($DotenvFile) {
        if ([System.IO.Path]::IsPathRooted($DotenvFile)) {
            return [System.IO.Path]::GetFullPath($DotenvFile)
        }
        return [System.IO.Path]::GetFullPath((Join-Path $RepoRoot $DotenvFile))
    }
    $providerCandidate = Join-Path $RepoRoot (".env.{0}" -f $Provider)
    if (Test-Path -LiteralPath $providerCandidate) {
        return [System.IO.Path]::GetFullPath($providerCandidate)
    }
    $defaultCandidate = Join-Path $RepoRoot ".env"
    if (Test-Path -LiteralPath $defaultCandidate) {
        return [System.IO.Path]::GetFullPath($defaultCandidate)
    }
    return $null
}

function Import-DotenvFile {
    param(
        [string]$Path
    )
    if (-not $Path) {
        return
    }
    if (-not (Test-Path -LiteralPath $Path)) {
        throw "Dotenv file not found: $Path"
    }
    $lines = Get-Content -LiteralPath $Path
    foreach ($rawLine in $lines) {
        $line = $rawLine.Trim()
        if (-not $line) {
            continue
        }
        if ($line.StartsWith("#")) {
            continue
        }
        if ($line.ToLower().StartsWith("export ")) {
            $line = $line.Substring(7).TrimStart()
        }
        $parts = $line.Split("=", 2)
        if ($parts.Count -ne 2) {
            throw "Invalid dotenv entry: $rawLine"
        }
        $key = $parts[0].Trim()
        $value = $parts[1].Trim()
        if (($value.StartsWith('"') -and $value.EndsWith('"')) -or ($value.StartsWith("'") -and $value.EndsWith("'"))) {
            $value = $value.Substring(1, $value.Length - 2)
        }
        if ($key) {
            Set-Item -Path "Env:$key" -Value $value
        }
    }
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

function Get-ListeningProcessIds {
    param(
        [int]$Port
    )
    $pids = @()
    $netTcpCommand = Get-Command Get-NetTCPConnection -ErrorAction SilentlyContinue
    if ($netTcpCommand) {
        try {
            $pids = @(Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue `
                | Select-Object -ExpandProperty OwningProcess -Unique)
        } catch {
            $pids = @()
        }
        return $pids | ForEach-Object { [int]$_ } | Select-Object -Unique
    }

    $netstatLines = netstat -ano -p TCP | Select-String "LISTENING"
    foreach ($line in $netstatLines) {
        $parts = ($line -replace "\s+", " ").Trim().Split(" ")
        if ($parts.Count -ge 5 -and $parts[1] -like "*:$Port") {
            $pids += [int]$parts[4]
        }
    }
    return $pids | ForEach-Object { [int]$_ } | Select-Object -Unique
}

function Resolve-PortConflict {
    param(
        [int]$Port,
        [string]$HealthUrl,
        [string]$Label
    )
    if ($HealthUrl) {
        if (Wait-ForEndpoint -Url $HealthUrl -TimeoutSec 2) {
            Write-Host "$Label already responding on port $Port. Keeping existing process."
            return
        }
    }

    $pids = @(Get-ListeningProcessIds -Port $Port)
    if (-not $pids -or $pids.Count -eq 0) {
        return
    }

    Write-Warning "$Label port $Port is in use. Stopping conflicting process(es): $($pids -join ', ')"
    foreach ($pid in $pids) {
        try {
            Stop-Process -Id $pid -Force -ErrorAction Stop
            Write-Host "Stopped PID $pid"
        } catch {
            Write-Warning "Failed to stop PID ${pid}: $($_.Exception.Message)"
        }
    }
    Start-Sleep -Seconds 1
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

$DotenvPath = Resolve-DotenvPath -DotenvFile $DotenvFile -Provider $Provider
if ($DotenvFile -and (-not (Test-Path -LiteralPath $DotenvPath))) {
    throw "Dotenv file not found: $DotenvPath"
}
if ($DotenvPath) {
    Import-DotenvFile -Path $DotenvPath
    $env:DOTENV_FILE = $DotenvPath
    Write-Host "Loaded dotenv: $DotenvPath"
} else {
    Write-Host "No dotenv file found. Continuing without DOTENV_FILE."
}

$env:LINE_PORT = $Port

Resolve-PortConflict -Port $Port -HealthUrl "http://127.0.0.1:$Port/api/health" -Label "LINE API"
Resolve-PortConflict -Port 4040 -HealthUrl "http://127.0.0.1:4040/api/tunnels" -Label "ngrok"

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

$PsExe = if (Get-Command pwsh -ErrorAction SilentlyContinue) { "pwsh" } else { "powershell" }
$RunLinePath = Join-Path $RepoRoot "scripts\\run_line.ps1"
$NgrokPath = Join-Path $RepoRoot "tools\\run_ngrok.ps1"

$serverPid = $null
if (-not (Wait-ForEndpoint -Url "http://127.0.0.1:$Port/api/health" -TimeoutSec 5)) {
    Write-Host "Starting LINE API server..."
    $serverArgs = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", $RunLinePath, "-Port", $Port)
    if ($DotenvPath) {
        $serverArgs += @("-DotenvFile", $DotenvPath)
    }
    $serverProc = Start-Process -FilePath $PsExe `
        -ArgumentList $serverArgs `
        -RedirectStandardOutput $ServerOut `
        -RedirectStandardError $ServerErr `
        -PassThru
    $serverPid = $serverProc.Id
}

if (-not (Wait-ForEndpoint -Url "http://127.0.0.1:$Port/api/health" -TimeoutSec $TimeoutSec)) {
    Fail-WithLogs -Message "LINE API server did not become healthy on port $Port." -ServerOut $ServerOut -ServerErr $ServerErr -NgrokOut $NgrokOut -NgrokErr $NgrokErr
}

$ngrokPid = $null
if (-not (Wait-ForEndpoint -Url "http://127.0.0.1:4040/api/tunnels" -TimeoutSec 3)) {
    Write-Host "Starting ngrok..."
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

$ngrokHealthUrl = "$publicUrl/api/health"
if (-not (Wait-ForEndpoint -Url $ngrokHealthUrl -TimeoutSec 15)) {
    Fail-WithLogs -Message "ngrok public health check failed: $ngrokHealthUrl" -ServerOut $ServerOut -ServerErr $ServerErr -NgrokOut $NgrokOut -NgrokErr $NgrokErr
}

if ($env:LINE_CHANNEL_ACCESS_TOKEN) {
    $webhookUrl = "$publicUrl/webhooks/line"
    $headers = @{
        Authorization = "Bearer $($env:LINE_CHANNEL_ACCESS_TOKEN)"
        "Content-Type" = "application/json"
    }
    $body = @{ endpoint = $webhookUrl } | ConvertTo-Json -Compress

    Write-Host "Updating LINE webhook endpoint to $webhookUrl"
    try {
        Invoke-RestMethod -Method Put -Uri "https://api.line.me/v2/bot/channel/webhook/endpoint" -Headers $headers -Body $body -ErrorAction Stop | Out-Null
    } catch {
        Fail-WithLogs -Message "Failed to update LINE webhook endpoint." -ServerOut $ServerOut -ServerErr $ServerErr -NgrokOut $NgrokOut -NgrokErr $NgrokErr
    }

    Write-Host "Testing LINE webhook..."
    try {
        $testResponse = Invoke-RestMethod -Method Post -Uri "https://api.line.me/v2/bot/channel/webhook/test" -Headers $headers -ErrorAction Stop
    } catch {
        Fail-WithLogs -Message "Failed to call LINE webhook test." -ServerOut $ServerOut -ServerErr $ServerErr -NgrokOut $NgrokOut -NgrokErr $NgrokErr
    }

    Write-Host "Webhook test response: $($testResponse | ConvertTo-Json -Compress)"
    if (-not $testResponse.success) {
        Fail-WithLogs -Message "LINE webhook test did not return success:true." -ServerOut $ServerOut -ServerErr $ServerErr -NgrokOut $NgrokOut -NgrokErr $NgrokErr
    }

    try {
        $requests = Invoke-RestMethod -Method Get -Uri "http://127.0.0.1:4040/api/requests/http" -TimeoutSec 5 -ErrorAction Stop
        if (-not $requests.requests -or $requests.requests.Count -eq 0) {
            Fail-WithLogs -Message "ngrok inspector shows no HTTP requests. Webhook URL may be stale." -ServerOut $ServerOut -ServerErr $ServerErr -NgrokOut $NgrokOut -NgrokErr $NgrokErr
        }
    } catch {
        Write-Warning "Unable to query ngrok inspector requests."
    }
} else {
    Write-Warning "LINE_CHANNEL_ACCESS_TOKEN not set. Update LINE webhook URL to $publicUrl/webhooks/line."
}

"server_pid=$serverPid" | Set-Content -LiteralPath $PidFile
Add-Content -LiteralPath $PidFile ("ngrok_pid={0}" -f $ngrokPid)
Add-Content -LiteralPath $PidFile ("server_stdout={0}" -f $ServerOut)
Add-Content -LiteralPath $PidFile ("server_stderr={0}" -f $ServerErr)
Add-Content -LiteralPath $PidFile ("ngrok_stdout={0}" -f $NgrokOut)
Add-Content -LiteralPath $PidFile ("ngrok_stderr={0}" -f $NgrokErr)

Write-Host "Runtime info saved to $PidFile"
Write-Host "LINE webhook is reachable via ngrok."

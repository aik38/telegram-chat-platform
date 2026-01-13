param(
    [string]$DotenvFile = ".env.gemini"
)

$ErrorActionPreference = "Stop"

$RepoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
Set-Location $RepoRoot

function Resolve-DotenvPath {
    param(
        [string]$DotenvFile
    )
    if ([System.IO.Path]::IsPathRooted($DotenvFile)) {
        return [System.IO.Path]::GetFullPath($DotenvFile)
    }
    return [System.IO.Path]::GetFullPath((Join-Path $RepoRoot $DotenvFile))
}

function Import-DotenvFile {
    param(
        [string]$Path
    )
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
        [string]$Path
    )
    if (Test-Path -LiteralPath $Path) {
        Write-Host "---- $Label log tail ($Path) ----"
        Get-Content -LiteralPath $Path -Tail 200
    } else {
        Write-Host "---- $Label log not found ($Path) ----"
    }
}

function Fail-WithLogs {
    param(
        [string]$Message,
        [string]$ServerLog,
        [string]$NgrokLog
    )
    Write-Error $Message
    if ($ServerLog) {
        Show-LogTail -Label "server" -Path $ServerLog
    }
    if ($NgrokLog) {
        Show-LogTail -Label "ngrok" -Path $NgrokLog
    }
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

$DotenvPath = Resolve-DotenvPath -DotenvFile $DotenvFile
Import-DotenvFile -Path $DotenvPath
$env:DOTENV_FILE = $DotenvPath
Write-Host "Loaded dotenv: $DotenvPath"

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

$LogDir = Join-Path $RepoRoot "40_logs"
if (-not (Test-Path -LiteralPath $LogDir)) {
    New-Item -ItemType Directory -Path $LogDir | Out-Null
}
$Timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$ServerLog = Join-Path $LogDir "line_api_$Timestamp.log"
$NgrokLog = Join-Path $LogDir "ngrok_$Timestamp.log"

$PsExe = if (Get-Command pwsh -ErrorAction SilentlyContinue) { "pwsh" } else { "powershell" }
$RunLinePath = Join-Path $RepoRoot "scripts\\run_line.ps1"
$NgrokPath = Join-Path $RepoRoot "tools\\run_ngrok.ps1"

if (-not (Wait-ForEndpoint -Url "http://127.0.0.1:$Port/api/health" -TimeoutSec 5)) {
    Write-Host "Starting LINE API server..."
    Start-Process -FilePath $PsExe `
        -ArgumentList @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", $RunLinePath, "-DotenvFile", $DotenvPath) `
        -RedirectStandardOutput $ServerLog `
        -RedirectStandardError $ServerLog | Out-Null
}

if (-not (Wait-ForEndpoint -Url "http://127.0.0.1:$Port/api/health" -TimeoutSec 60)) {
    Fail-WithLogs -Message "LINE API server did not become healthy." -ServerLog $ServerLog -NgrokLog $NgrokLog
}

$ngrokRunning = @(Get-Process ngrok -ErrorAction SilentlyContinue).Count -gt 0
if (-not $ngrokRunning) {
    Write-Host "Starting ngrok..."
    Start-Process -FilePath $PsExe `
        -ArgumentList @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", $NgrokPath, "-Port", $Port) `
        -RedirectStandardOutput $NgrokLog `
        -RedirectStandardError $NgrokLog | Out-Null
}

if (-not (Wait-ForEndpoint -Url "http://127.0.0.1:4040/api/tunnels" -TimeoutSec 30)) {
    Fail-WithLogs -Message "ngrok API did not become available." -ServerLog $ServerLog -NgrokLog $NgrokLog
}

try {
    $tunnels = Invoke-RestMethod -Method Get -Uri "http://127.0.0.1:4040/api/tunnels" -TimeoutSec 5 -ErrorAction Stop
} catch {
    Fail-WithLogs -Message "Failed to fetch ngrok tunnels." -ServerLog $ServerLog -NgrokLog $NgrokLog
}

$publicUrl = $null
foreach ($tunnel in $tunnels.tunnels) {
    if ($tunnel.public_url -like "https://*") {
        $publicUrl = $tunnel.public_url
        break
    }
}
if (-not $publicUrl) {
    Fail-WithLogs -Message "No https public_url found from ngrok." -ServerLog $ServerLog -NgrokLog $NgrokLog
}

$token = $env:LINE_CHANNEL_ACCESS_TOKEN
if (-not $token) {
    Fail-WithLogs -Message "LINE_CHANNEL_ACCESS_TOKEN is missing." -ServerLog $ServerLog -NgrokLog $NgrokLog
}

$webhookUrl = "$publicUrl/webhooks/line"
$headers = @{
    Authorization = "Bearer $token"
    "Content-Type" = "application/json"
}
$body = @{ endpoint = $webhookUrl } | ConvertTo-Json -Compress

Write-Host "Updating LINE webhook endpoint to $webhookUrl"
try {
    Invoke-RestMethod -Method Put -Uri "https://api.line.me/v2/bot/channel/webhook/endpoint" -Headers $headers -Body $body -ErrorAction Stop | Out-Null
} catch {
    Fail-WithLogs -Message "Failed to update LINE webhook endpoint." -ServerLog $ServerLog -NgrokLog $NgrokLog
}

Write-Host "Testing LINE webhook..."
try {
    $testResponse = Invoke-RestMethod -Method Post -Uri "https://api.line.me/v2/bot/channel/webhook/test" -Headers $headers -ErrorAction Stop
} catch {
    Fail-WithLogs -Message "Failed to call LINE webhook test." -ServerLog $ServerLog -NgrokLog $NgrokLog
}

Write-Host "Webhook test response: $($testResponse | ConvertTo-Json -Compress)"
if (-not $testResponse.success) {
    Fail-WithLogs -Message "LINE webhook test did not return success:true." -ServerLog $ServerLog -NgrokLog $NgrokLog
}

Write-Host "LINE webhook updated and verified."

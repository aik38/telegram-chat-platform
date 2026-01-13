Param(
    [string]$DotenvFile,
    [int]$ApiPort = 8000,
    [int]$NgrokPort = 4040,
    [ValidateSet("Preflight", "Runtime")]
    [string]$Mode = "Runtime",
    [switch]$CheckPorts
)

$ErrorActionPreference = "Stop"

$RepoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
Set-Location $RepoRoot

function Get-ProcessInfoMap {
    $map = @{}
    Get-CimInstance Win32_Process | ForEach-Object {
        $map[$_.ProcessId] = $_
    }
    return $map
}

function Get-DotenvFileFromCommandLine {
    param(
        [string]$CommandLine
    )
    if (-not $CommandLine) {
        return $null
    }
    $dotenvMatch = [regex]::Match($CommandLine, 'DOTENV_FILE=("[^"]+"|\S+)')
    if ($dotenvMatch.Success) {
        return $dotenvMatch.Groups[1].Value.Trim('"')
    }
    $argMatch = [regex]::Match($CommandLine, '-DotenvFile\s+("[^"]+"|\S+)')
    if ($argMatch.Success) {
        return $argMatch.Groups[1].Value.Trim('"')
    }
    return $null
}

function Test-CommandLineForDotenv {
    param(
        [string]$CommandLine
    )
    if (-not $CommandLine) {
        return $false
    }
    if ($CommandLine -match 'DOTENV_FILE=("[^"]+"|\S+)') {
        return $true
    }
    if ($CommandLine -match '-DotenvFile\s+("[^"]+"|\S+)') {
        return $true
    }
    return $false
}

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

function Get-DotenvValue {
    param(
        [string]$FilePath,
        [string]$Key
    )
    if (-not (Test-Path $FilePath)) {
        return $null
    }
    $lines = Get-Content $FilePath -ErrorAction SilentlyContinue
    foreach ($line in $lines) {
        $trimmed = $line.Trim()
        if (-not $trimmed -or $trimmed.StartsWith("#")) {
            continue
        }
        $match = [regex]::Match($trimmed, "^\s*$Key\s*=\s*(.+)\s*$")
        if ($match.Success) {
            $value = $match.Groups[1].Value.Trim()
            if (($value.StartsWith('"') -and $value.EndsWith('"')) -or ($value.StartsWith("'") -and $value.EndsWith("'"))) {
                $value = $value.Substring(1, $value.Length - 2)
            }
            return $value
        }
    }
    return $null
}

function Mask-Token {
    param(
        [string]$Token
    )
    if (-not $Token) {
        return $null
    }
    if ($Token.Length -le 8) {
        return ($Token.Substring(0, 2) + "..." + $Token.Substring($Token.Length - 2))
    }
    return ($Token.Substring(0, 4) + "..." + $Token.Substring($Token.Length - 4))
}

function Test-HttpEndpoint {
    param(
        [string]$Url,
        [int]$TimeoutSec = 3
    )
    try {
        $response = Invoke-WebRequest -Uri $Url -UseBasicParsing -TimeoutSec $TimeoutSec -ErrorAction Stop
        return ($response.StatusCode -ge 200 -and $response.StatusCode -lt 400)
    } catch {
        return $false
    }
}

$processInfo = Get-ProcessInfoMap

$Ports = @($ApiPort, $NgrokPort)
$listeners = @()
try {
    $listeners = Get-NetTCPConnection -State Listen -LocalPort $Ports -ErrorAction SilentlyContinue
} catch {
    $listeners = @()
}

Write-Host "Doctor: repo root $RepoRoot"
Write-Host ("Mode: {0}" -f $Mode)
Write-Host ""
Write-Host ("Listening ports ({0}):" -f ($Ports -join ", "))

foreach ($port in $Ports) {
    $entries = $listeners | Where-Object { $_.LocalPort -eq $port }
    if (-not $entries) {
        Write-Host "  Port ${port}: (no listeners)"
        continue
    }
    foreach ($entry in $entries) {
        $procId = $entry.OwningProcess
        $procInfo = $processInfo[$procId]
        $procName = if ($procInfo) { $procInfo.Name } else { "unknown" }
        $cmdLine = if ($procInfo -and $procInfo.CommandLine) { $procInfo.CommandLine } else { "(no command line)" }
        Write-Host "  Port ${port}: PID $procId | $procName | $cmdLine"
    }
}

$trackedProcesses = @()

$processInfo.Values | ForEach-Object {
    $cmdLine = $_.CommandLine
    if (-not $cmdLine) {
        return
    }
    if ($_.Name -notmatch '(?i)^(python|pythonw|ngrok)(\.exe)?$') {
        return
    }
    if (-not (Test-CommandLineForDotenv -CommandLine $cmdLine)) {
        return
    }
    $trackedProcesses += $_
}

Write-Host ""
Write-Host "Python/ngrok processes with DOTENV_FILE:"

if (-not $trackedProcesses) {
    Write-Host "  (none)"
} else {
    foreach ($proc in $trackedProcesses) {
        $dotenvRaw = Get-DotenvFileFromCommandLine -CommandLine $proc.CommandLine
        $dotenvPath = Resolve-DotenvPath -DotenvFile $dotenvRaw
        $token = $null
        if ($dotenvPath) {
            $token = Get-DotenvValue -FilePath $dotenvPath -Key "TELEGRAM_BOT_TOKEN"
        }
        $tokenMasked = if ($token) { Mask-Token -Token $token } else { "(not found)" }
        $dotenvDisplay = if ($dotenvPath) { $dotenvPath } else { "(not set)" }
        Write-Host "  PID $($proc.ProcessId) | $($proc.Name) | DOTENV_FILE=$dotenvDisplay | TELEGRAM_BOT_TOKEN=$tokenMasked"
        Write-Host "    $($proc.CommandLine)"
    }
}

$exitCode = 0

$requestedDotenvPath = $null
$requestedToken = $null
if ($DotenvFile) {
    $requestedDotenvPath = Resolve-DotenvPath -DotenvFile $DotenvFile
    if (-not (Test-Path $requestedDotenvPath)) {
        Write-Error "Dotenv file not found: $requestedDotenvPath"
        exit 1
    }
    $requestedToken = Get-DotenvValue -FilePath $requestedDotenvPath -Key "TELEGRAM_BOT_TOKEN"
    if ($requestedToken) {
        Write-Host ""
        Write-Host ("Requested DOTENV_FILE: {0}" -f $requestedDotenvPath)
        Write-Host ("Requested TELEGRAM_BOT_TOKEN: {0}" -f (Mask-Token -Token $requestedToken))
    } else {
        Write-Host ""
        Write-Warning ("Requested DOTENV_FILE has no TELEGRAM_BOT_TOKEN: {0}" -f $requestedDotenvPath)
    }
}

$tokenOwners = @{}
foreach ($proc in $trackedProcesses) {
    $dotenvRaw = Get-DotenvFileFromCommandLine -CommandLine $proc.CommandLine
    $dotenvPath = Resolve-DotenvPath -DotenvFile $dotenvRaw
    if (-not $dotenvPath) {
        continue
    }
    $token = Get-DotenvValue -FilePath $dotenvPath -Key "TELEGRAM_BOT_TOKEN"
    if (-not $token) {
        continue
    }
    if (-not $tokenOwners.ContainsKey($token)) {
        $tokenOwners[$token] = @()
    }
    $tokenOwners[$token] += $proc.ProcessId
}

$requestedTokenOwners = @()
if ($requestedToken) {
    foreach ($entry in $tokenOwners.GetEnumerator()) {
        if ($entry.Key -eq $requestedToken) {
            $requestedTokenOwners = $entry.Value
        }
    }
    if ($requestedTokenOwners.Count -gt 0) {
        Write-Host ""
        Write-Error "同一TELEGRAM_BOT_TOKENのため同時起動できない。別Botトークンを用意して .env.arisa_* に設定してください"
        Write-Error ("  Token {0} is already used by PID(s): {1}" -f (Mask-Token -Token $requestedToken), (($requestedTokenOwners | Sort-Object) -join ", "))
        $exitCode = 1
    }
}

$duplicateTokens = $tokenOwners.GetEnumerator() | Where-Object { $_.Value.Count -gt 1 }
if ($duplicateTokens) {
    Write-Host ""
    Write-Warning "Duplicate TELEGRAM_BOT_TOKEN detected in running processes:"
    foreach ($entry in $duplicateTokens) {
        $masked = Mask-Token -Token $entry.Key
        $pids = ($entry.Value | Sort-Object) -join ", "
        Write-Warning "  Token $masked is used by PID(s): $pids"
    }
    $exitCode = 1
}

if ($CheckPorts) {
    $portConflicts = $listeners | Group-Object -Property LocalPort
    if ($portConflicts) {
        Write-Host ""
        Write-Warning "Requested ports already in use:"
        foreach ($group in $portConflicts) {
            $owners = $group.Group | ForEach-Object { $_.OwningProcess } | Sort-Object -Unique
            Write-Warning ("  Port {0}: PID(s) {1}" -f $group.Name, ($owners -join ", "))
        }
        $exitCode = 1
    }
}

if ($Mode -eq "Runtime") {
    Write-Host ""
    Write-Host "Runtime checks:"

    $apiListeners = $listeners | Where-Object { $_.LocalPort -eq $ApiPort }
    if (-not $apiListeners) {
        Write-Error "API port $ApiPort is not listening."
        $exitCode = 1
    } else {
        $apiUrl = "http://127.0.0.1:$ApiPort/api/health"
        if (-not (Test-HttpEndpoint -Url $apiUrl)) {
            Write-Error "API health check failed: $apiUrl"
            $exitCode = 1
        } else {
            Write-Host "  API health OK: $apiUrl"
        }
    }

    $ngrokListeners = $listeners | Where-Object { $_.LocalPort -eq $NgrokPort }
    if (-not $ngrokListeners) {
        Write-Error "ngrok inspector port $NgrokPort is not listening."
        $exitCode = 1
    } else {
        $ngrokUrl = "http://127.0.0.1:$NgrokPort/api/tunnels"
        if (-not (Test-HttpEndpoint -Url $ngrokUrl)) {
            Write-Error "ngrok API check failed: $ngrokUrl"
            $exitCode = 1
        } else {
            Write-Host "  ngrok API OK: $ngrokUrl"
        }
    }
}

if ($exitCode -eq 0) {
    Write-Host ""
    Write-Host "Doctor checks passed."
} else {
    Write-Host ""
    Write-Warning "Doctor checks failed. Resolve the issues above and retry."
}

exit $exitCode

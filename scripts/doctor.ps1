$ErrorActionPreference = "Stop"

$RepoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")

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

$processInfo = Get-ProcessInfoMap

$ports = @(8000, 8001, 4040)
$listeners = @()
try {
    $listeners = Get-NetTCPConnection -State Listen -LocalPort $ports -ErrorAction SilentlyContinue
} catch {
    $listeners = @()
}

Write-Host "Doctor: repo root $RepoRoot"
Write-Host ""
Write-Host "Listening ports (8000, 8001, 4040):"

foreach ($port in $ports) {
    $entries = $listeners | Where-Object { $_.LocalPort -eq $port }
    if (-not $entries) {
        Write-Host "  Port ${port}: (no listeners)"
        continue
    }
    foreach ($entry in $entries) {
        $pid = $entry.OwningProcess
        $procInfo = $processInfo[$pid]
        $procName = if ($procInfo) { $procInfo.Name } else { "unknown" }
        $cmdLine = if ($procInfo -and $procInfo.CommandLine) { $procInfo.CommandLine } else { "(no command line)" }
        Write-Host "  Port ${port}: PID $pid | $procName | $cmdLine"
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

if ($exitCode -eq 0) {
    Write-Host ""
    Write-Host "Doctor checks passed."
} else {
    Write-Host ""
    Write-Warning "Doctor checks failed. Resolve the issues above and retry."
}

exit $exitCode

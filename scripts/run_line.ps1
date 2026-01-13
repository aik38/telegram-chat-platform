Param(
    [string]$DotenvFile,
    [ValidateSet("gemini", "openai")]
    [string]$Provider = "gemini",
    [int]$Port,
    [int]$TimeoutSec = 90
)

$ErrorActionPreference = "Stop"

$RepoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
Set-Location $RepoRoot

$LauncherPath = Join-Path $RepoRoot "tools\launcher.ps1"
if (-not (Test-Path -LiteralPath $LauncherPath)) {
    throw "Launcher not found: $LauncherPath"
}

if ($PSBoundParameters.ContainsKey("TimeoutSec")) {
    $env:LINE_TIMEOUT_SEC = $TimeoutSec
}

$args = @(
    "-NoProfile",
    "-ExecutionPolicy", "Bypass",
    "-File", $LauncherPath,
    "-App", "line",
    "-Provider", $Provider
)

if ($DotenvFile) {
    $args += @("-DotenvFile", $DotenvFile)
}
if ($PSBoundParameters.ContainsKey("Port")) {
    $args += @("-Port", $Port)
}

$PsExe = if (Get-Command pwsh -ErrorAction SilentlyContinue) { "pwsh" } else { "powershell" }
Write-Host "Forwarding to launcher.ps1 for LINE (provider=$Provider)"
& $PsExe @args
exit $LASTEXITCODE

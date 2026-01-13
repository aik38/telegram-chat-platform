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

$RunLinePath = Join-Path $RepoRoot "scripts\\run_line.ps1"
$PsExe = if (Get-Command pwsh -ErrorAction SilentlyContinue) { "pwsh" } else { "powershell" }

$args = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", $RunLinePath, "-TimeoutSec", $TimeoutSec)
if ($DotenvFile) {
    $args += @("-DotenvFile", $DotenvFile)
}
if ($PSBoundParameters.ContainsKey("Port")) {
    $args += @("-Port", $Port)
}

Write-Host "LINE runtime launcher (provider=$Provider) -> scripts/run_line.ps1"
& $PsExe @args
exit $LASTEXITCODE

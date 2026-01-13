<<<<<<< Updated upstream
Param(
    [string]$DotenvFile,
    [ValidateSet("gemini", "openai")]
    [string]$Provider = "gemini",
    [int]$Port,
    [int]$TimeoutSec = 90
=======
param(
  [string]$DotenvFile = $env:DOTENV_FILE,
  [string]$Provider = "",
  [int]$Port = 8000
>>>>>>> Stashed changes
)

$repo = Split-Path -Parent $PSScriptRoot

<<<<<<< Updated upstream
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
=======
if (-not $DotenvFile -or -not (Test-Path $DotenvFile)) {
  foreach($cand in @(
    (Join-Path $repo ".env.openai"),
    (Join-Path $repo ".env.gemini"),
    (Join-Path $repo ".env")
  )) {
    if (Test-Path $cand) { $DotenvFile = $cand; break }
  }
}

if (-not $Provider) {
  if ($DotenvFile -match "\.env\.gemini$") { $Provider = "gemini" }
  elseif ($DotenvFile -match "\.env\.openai$") { $Provider = "openai" }
  elseif ($DotenvFile -match "\.env\.deepseek$") { $Provider = "deepseek" }
  else { $Provider = "openai" }
}

pwsh -NoProfile -ExecutionPolicy Bypass -File (Join-Path $repo "tools\launcher.ps1") `
  -App line -Provider $Provider -DotenvFile $DotenvFile -Port $Port
>>>>>>> Stashed changes

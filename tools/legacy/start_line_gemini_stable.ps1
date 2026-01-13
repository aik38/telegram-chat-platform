param(
    [string]$DotenvFile = ".env.gemini",
    [int]$Port = 8000
)

Write-Warning "Deprecated: use tools/launcher.ps1 instead."

$launcherRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
$script = Join-Path $launcherRoot "launcher.ps1"
$args = @("-App", "line", "-Provider", "gemini", "-Port", $Port, "-AutoStart")
if ($DotenvFile) {
    $args += @("-DotenvFile", $DotenvFile)
}

& $script @args
exit $LASTEXITCODE

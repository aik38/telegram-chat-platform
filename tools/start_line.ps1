param(
    [string]$DotenvFile,
    [ValidateSet("gemini", "openai")]
    [string]$Provider = "gemini",
    [int]$Port = 8000
)

Write-Warning "Deprecated: use tools/launcher.ps1 instead."

$script = Join-Path $PSScriptRoot "launcher.ps1"
$args = @("-App", "line", "-Provider", $Provider, "-Port", $Port, "-AutoStart")
if ($DotenvFile) {
    $args += @("-DotenvFile", $DotenvFile)
}

& $script @args
exit $LASTEXITCODE

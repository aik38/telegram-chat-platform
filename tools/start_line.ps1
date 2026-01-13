param(
    [string]$DotenvFile,
    [ValidateSet("gemini", "openai")]
    [string]$Provider = "gemini",
    [int]$Port = 8000
)

Write-Warning "Deprecated: use tools/start_line_stable.ps1 instead."

$script = Join-Path $PSScriptRoot "start_line_stable.ps1"
$args = @("-Provider", $Provider, "-Port", $Port)
if ($DotenvFile) {
    $args += @("-DotenvFile", $DotenvFile)
}

& $script @args
exit $LASTEXITCODE

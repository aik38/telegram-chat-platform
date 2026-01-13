param(
    [string]$DotenvFile = ".env.gemini",
    [int]$Port = 8000
)

Write-Warning "Deprecated: use tools/start_line_stable.ps1 -Provider gemini instead."

$script = Join-Path $PSScriptRoot "start_line_stable.ps1"
$args = @("-Provider", "gemini", "-Port", $Port)
if ($DotenvFile) {
    $args += @("-DotenvFile", $DotenvFile)
}

& $script @args
exit $LASTEXITCODE

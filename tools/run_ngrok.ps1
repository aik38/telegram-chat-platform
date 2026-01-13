param (
    [Parameter(Mandatory = $true)]
    [int]$Port
)

$ErrorActionPreference = "Stop"

$ngrokCmd = Get-Command ngrok -ErrorAction SilentlyContinue
if (-not $ngrokCmd) {
    Write-Error "ngrok command not found. Install ngrok and ensure it is on PATH."
    exit 1
}

Write-Output "Starting ngrok for port $Port (http://localhost:$Port)..."

& $ngrokCmd.Source http $Port
if ($LASTEXITCODE -ne 0) {
    Write-Error "ngrok exited with code $LASTEXITCODE."
    exit $LASTEXITCODE
}

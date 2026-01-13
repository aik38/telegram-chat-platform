param(
    [ValidateSet("tarot", "arisa", "line", "doctor")]
    [string]$App = "tarot",
    [ValidateSet("gemini", "openai")]
    [string]$Provider = "gemini",
    [string]$DotenvFile,
    [int]$Port = 8000,
    [ValidateSet("Preflight", "Runtime")]
    [string]$DoctorMode = "Runtime",
    [switch]$AutoStart
)

$ErrorActionPreference = "Stop"

$RepoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
Set-Location $RepoRoot

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

function Get-DefaultDotenv {
    param(
        [string]$App,
        [string]$Provider
    )
    switch ($App) {
        "tarot" { return ".env.$Provider" }
        "arisa" { return ".env.arisa.$Provider" }
        "line" { return ".env.$Provider" }
        default { return $null }
    }
}

$ResolvedDotenv = $null
if ($DotenvFile) {
    $ResolvedDotenv = Resolve-DotenvPath -DotenvFile $DotenvFile
} else {
    $defaultDotenv = Get-DefaultDotenv -App $App -Provider $Provider
    if ($defaultDotenv) {
        $defaultPath = Resolve-DotenvPath -DotenvFile $defaultDotenv
        if (Test-Path -LiteralPath $defaultPath) {
            $ResolvedDotenv = $defaultPath
        } elseif ($App -eq "tarot" -or $App -eq "line") {
            $fallbackPath = Resolve-DotenvPath -DotenvFile ".env"
            if (Test-Path -LiteralPath $fallbackPath) {
                Write-Warning "Default dotenv not found ($defaultPath). Falling back to $fallbackPath."
                $ResolvedDotenv = $fallbackPath
            }
        }
    }
}

if ($ResolvedDotenv -and (-not (Test-Path -LiteralPath $ResolvedDotenv))) {
    Write-Error "Dotenv file not found: $ResolvedDotenv"
    exit 1
}

switch ($App) {
    "tarot" {
        $targetScript = Join-Path $RepoRoot "scripts\\run_tarot.ps1"
        $args = @()
        if ($ResolvedDotenv) {
            $args += @("-DotenvFile", $ResolvedDotenv)
        }
    }
    "arisa" {
        $targetScript = Join-Path $RepoRoot "scripts\\run_arisa.ps1"
        $args = @()
        if ($ResolvedDotenv) {
            $args += @("-DotenvFile", $ResolvedDotenv)
        }
    }
    "line" {
        $targetScript = Join-Path $RepoRoot "tools\\line_runtime.ps1"
        $args = @("-Provider", $Provider, "-Port", $Port)
        if ($ResolvedDotenv) {
            $args += @("-DotenvFile", $ResolvedDotenv)
        }
    }
    "doctor" {
        $targetScript = Join-Path $RepoRoot "scripts\\doctor.ps1"
        $args = @("-Mode", $DoctorMode)
        if ($ResolvedDotenv) {
            $args += @("-DotenvFile", $ResolvedDotenv)
        }
    }
}

$PsExe = if (Get-Command pwsh -ErrorAction SilentlyContinue) { "pwsh" } else { "powershell" }
Write-Host "Launcher: $App ($Provider)"
if ($App -eq "line") {
    try {
        & $PsExe -NoProfile -ExecutionPolicy Bypass -File $targetScript @args
    } catch {
        Write-Error $_.Exception.Message
        Read-Host "LINE launcher failed. Press Enter to exit"
        exit 1
    }
    exit $LASTEXITCODE
}

& $PsExe -NoProfile -ExecutionPolicy Bypass -File $targetScript @args
exit $LASTEXITCODE

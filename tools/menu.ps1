$ErrorActionPreference = "Stop"

$RepoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
$LauncherPath = Join-Path $RepoRoot "tools\launcher.ps1"
if (-not (Test-Path $LauncherPath)) {
    throw "Launcher not found: $LauncherPath"
}

function Read-Choice {
    param(
        [string]$Title,
        [string]$Prompt,
        [string[]]$Options,
        [int]$DefaultIndex = 0
    )

    $choices = $Options | ForEach-Object {
        New-Object System.Management.Automation.Host.ChoiceDescription "&$_", $_
    }

    return $host.ui.PromptForChoice($Title, $Prompt, $choices, $DefaultIndex)
}

try {
    $apps = @("tarot", "arisa", "line")
    $providers = @("gemini", "openai")

    $appIndex = Read-Choice -Title "Bot" -Prompt "Select a bot" -Options $apps -DefaultIndex 0
    $providerIndex = Read-Choice -Title "LLM" -Prompt "Select a provider" -Options $providers -DefaultIndex 0

    $selectedApp = $apps[$appIndex]
    $selectedProvider = $providers[$providerIndex]

    & $LauncherPath -App $selectedApp -Provider $selectedProvider -DoctorMode Runtime -AutoStart
    exit $LASTEXITCODE
} catch {
    Write-Error $_
    Read-Host "Press Enter to close"
    exit 1
}

Param()

$ErrorActionPreference = "Stop"

$RepoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
Set-Location $RepoRoot

function Read-Choice {
    param(
        [string]$Prompt,
        [hashtable]$Options
    )
    while ($true) {
        Write-Host ""
        Write-Host $Prompt
        foreach ($key in ($Options.Keys | Sort-Object)) {
            Write-Host "[$key] $($Options[$key])"
        }
        $choice = (Read-Host "Select").Trim()
        if ($Options.ContainsKey($choice)) {
            return $Options[$choice]
        }
        Write-Host "Invalid selection. Try again."
    }
}

$app = Read-Choice -Prompt "Select app" -Options @{
    "1" = "tarot"
    "2" = "line"
    "3" = "arisa"
}

$provider = Read-Choice -Prompt "Select LLM" -Options @{
    "1" = "openai"
    "2" = "gemini"
}

switch ($app) {
    "arisa" { $dotenvFile = ".env.arisa.$provider" }
    "line" { $dotenvFile = ".env.$provider" }
    "tarot" { $dotenvFile = ".env.$provider" }
}

$env:DOTENV_FILE = $dotenvFile
Write-Host "DOTENV_FILE=$dotenvFile"

$scriptPath = Join-Path $PSScriptRoot ("run_{0}.ps1" -f $app)
& $scriptPath -DotenvFile $dotenvFile

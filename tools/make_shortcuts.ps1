param(
  [switch]$NoIcon,
  [int]$IconIndex = 1,
  [switch]$IncludeQuickLaunch
)

$ErrorActionPreference = "Stop"

$repo = Split-Path -Parent $PSScriptRoot
$userProfile = $env:USERPROFILE
if (-not $userProfile) {
  throw "USERPROFILE not found."
}
$targetFolder = Join-Path $userProfile "OneDrive\デスクトップ\telegram-chat-platform 起動"

New-Item -ItemType Directory -Path $targetFolder -Force | Out-Null

$psCommand = Get-Command pwsh -ErrorAction SilentlyContinue
$psExe = if ($psCommand) { $psCommand.Source } else { (Get-Command powershell).Source }
$launcherPath = Join-Path $repo "tools\launcher.ps1"
if (-not (Test-Path $launcherPath)) {
  throw "Launcher not found: $launcherPath"
}

$shortcuts = @(
  @{
    Name = "Launcher"
    Arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$launcherPath`""
  }
)

if ($IncludeQuickLaunch) {
  $shortcuts += @(
    @{ Name = "Tarot_Gemini"; Arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$launcherPath`" -App tarot -Provider gemini -AutoStart" },
    @{ Name = "Tarot_OpenAI"; Arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$launcherPath`" -App tarot -Provider openai -AutoStart" },
    @{ Name = "Arisa_Gemini"; Arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$launcherPath`" -App arisa -Provider gemini -AutoStart" },
    @{ Name = "Arisa_OpenAI"; Arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$launcherPath`" -App arisa -Provider openai -AutoStart" },
    @{ Name = "LINE_Gemini"; Arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$launcherPath`" -App line -Provider gemini -Port 8000 -AutoStart" },
    @{ Name = "LINE_OpenAI"; Arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$launcherPath`" -App line -Provider openai -Port 8000 -AutoStart" }
  )
}

$wsh = New-Object -ComObject WScript.Shell
$iconPath = Join-Path $env:SystemRoot "System32\shell32.dll"
$useIcon = -not $NoIcon -and (Test-Path $iconPath)
$created = @()

foreach ($item in $shortcuts) {
  $shortcutPath = Join-Path $targetFolder ("{0}.lnk" -f $item.Name)
  if (Test-Path $shortcutPath) {
    Remove-Item -Path $shortcutPath -Force
  }
  $shortcut = $wsh.CreateShortcut($shortcutPath)
  $shortcut.TargetPath = $psExe
  $shortcut.Arguments = $item.Arguments
  $shortcut.WorkingDirectory = $repo
  if ($useIcon) {
    $shortcut.IconLocation = "$iconPath,$IconIndex"
  }
  $shortcut.Save()
  $created += $shortcutPath
}

Write-Host "Shortcuts created in: $targetFolder"
foreach ($path in $created) {
  Write-Host (" - {0}" -f $path)
}

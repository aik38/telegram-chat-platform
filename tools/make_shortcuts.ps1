param(
  [switch]$NoIcon,
  [int]$IconIndex = 1
)

$ErrorActionPreference = "Stop"

$repo = Split-Path -Parent $PSScriptRoot
$desktop = [Environment]::GetFolderPath("Desktop")
$targetFolder = Join-Path $desktop "telegram-chat-platform 起動"
if (-not $desktop) {
  throw "Desktop folder not found."
}

New-Item -ItemType Directory -Path $targetFolder -Force | Out-Null

$shortcuts = @(
  @{ Name = "start_gemini"; Target = "start_gemini.cmd" },
  @{ Name = "start_openai"; Target = "start_openai.cmd" },
  @{ Name = "start_line_gemini"; Target = "start_line_gemini.cmd" },
  @{ Name = "start_line_openai"; Target = "start_line_openai.cmd" },
  @{ Name = "start_arisa_gemini"; Target = "start_arisa_gemini.cmd" },
  @{ Name = "start_arisa_openai"; Target = "start_arisa_openai.cmd" }
)

$wsh = New-Object -ComObject WScript.Shell
$iconPath = Join-Path $env:SystemRoot "System32\shell32.dll"
$useIcon = -not $NoIcon -and (Test-Path $iconPath)
$created = @()

foreach ($item in $shortcuts) {
  $targetPath = Join-Path $repo $item.Target
  if (-not (Test-Path $targetPath)) {
    throw "Missing target file: $targetPath"
  }

  $shortcutPath = Join-Path $targetFolder ("{0}.lnk" -f $item.Name)
  if (Test-Path $shortcutPath) {
    Remove-Item -Path $shortcutPath -Force
  }
  $shortcut = $wsh.CreateShortcut($shortcutPath)
  $shortcut.TargetPath = $targetPath
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

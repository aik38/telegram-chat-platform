param(
  [switch]$NoIcon,
  [int]$IconIndex = 1
)

$ErrorActionPreference = "Stop"

$repo = Split-Path -Parent $PSScriptRoot
$desktopPath = [Environment]::GetFolderPath("Desktop")
if (-not $desktopPath) {
  throw "Desktop path not found."
}

$psCommand = Get-Command pwsh -ErrorAction SilentlyContinue
if (-not $psCommand) {
  throw "pwsh.exe not found."
}
$psExe = $psCommand.Source
$menuPath = Join-Path $repo "tools\menu.ps1"
if (-not (Test-Path $menuPath)) {
  throw "Menu entrypoint not found: $menuPath"
}

$shortcuts = @(
  @{
    Name = "Launcher"
    Arguments = "-NoLogo -NoProfile -ExecutionPolicy Bypass -File `"$menuPath`""
  }
)

$wsh = New-Object -ComObject WScript.Shell
$iconPath = Join-Path $env:SystemRoot "System32\shell32.dll"
$useIcon = -not $NoIcon -and (Test-Path $iconPath)
$created = @()

foreach ($item in $shortcuts) {
  $shortcutPath = Join-Path $desktopPath ("{0}.lnk" -f $item.Name)
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

Write-Host "Shortcut created: $desktopPath"
foreach ($path in $created) {
  Write-Host (" - {0}" -f $path)
}

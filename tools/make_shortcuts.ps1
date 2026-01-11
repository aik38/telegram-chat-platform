$ErrorActionPreference = "Stop"

$repo = Split-Path -Parent $PSScriptRoot
$desktop = [Environment]::GetFolderPath("Desktop")
$targetFolder = Join-Path $desktop "telegram-chat-platform 起動"

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

foreach ($item in $shortcuts) {
  $targetPath = Join-Path $repo $item.Target
  if (-not (Test-Path $targetPath)) {
    throw "Missing target file: $targetPath"
  }

  $shortcutPath = Join-Path $targetFolder ("{0}.lnk" -f $item.Name)
  $shortcut = $wsh.CreateShortcut($shortcutPath)
  $shortcut.TargetPath = $targetPath
  $shortcut.WorkingDirectory = $repo
  $shortcut.Save()
}

Write-Host "Shortcuts created in: $targetFolder"

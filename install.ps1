# install.ps1 - installs claude-statusline-win for the current user
#
#   1. copies statusline.ps1 to ~/.claude/statusline.ps1
#   2. points the statusLine setting in ~/.claude/settings.json at it
#
# Existing files are backed up next to the originals as *.bak-<timestamp>.
# Usage: powershell -NoProfile -ExecutionPolicy Bypass -File install.ps1

$ErrorActionPreference = 'Stop'

$claudeDir = Join-Path $HOME '.claude'
$source = Join-Path $PSScriptRoot 'statusline.ps1'
$target = Join-Path $claudeDir 'statusline.ps1'
$settingsPath = Join-Path $claudeDir 'settings.json'
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'

if (-not (Test-Path $source)) { throw "statusline.ps1 not found next to install.ps1" }
if (-not (Test-Path $claudeDir)) { New-Item -ItemType Directory -Path $claudeDir | Out-Null }

# --- script ------------------------------------------------------------------

if (Test-Path $target) {
    Copy-Item $target "$target.bak-$stamp"
    Write-Host "Backed up existing script to statusline.ps1.bak-$stamp"
}
Copy-Item $source $target -Force
Write-Host "Installed $target"

# --- settings.json -------------------------------------------------------------

$command = 'powershell -NoProfile -ExecutionPolicy Bypass -File "' + ($target -replace '\\', '/') + '"'
$statusLine = [pscustomobject]@{ type = 'command'; command = $command }

if (Test-Path $settingsPath) {
    $raw = [IO.File]::ReadAllText($settingsPath)
    try { $settings = $raw | ConvertFrom-Json } catch { throw "settings.json is not valid JSON; fix it and run again" }
    if ($settings.statusLine.command -eq $command) {
        Write-Host "settings.json already points at the script"
        Write-Host "Done. The status line refreshes on your next message."
        exit 0
    }
    Copy-Item $settingsPath "$settingsPath.bak-$stamp"
    Write-Host "Backed up settings.json to settings.json.bak-$stamp"
    if ($null -eq $settings) { $settings = [pscustomobject]@{} }
    $settings | Add-Member -NotePropertyName statusLine -NotePropertyValue $statusLine -Force
} else {
    $settings = [pscustomobject]@{ statusLine = $statusLine }
}

# UTF-8 without BOM, which is what Claude Code expects
[IO.File]::WriteAllText($settingsPath, ($settings | ConvertTo-Json -Depth 32), (New-Object Text.UTF8Encoding $false))
Write-Host "Updated $settingsPath"
Write-Host "Done. The status line refreshes on your next message."

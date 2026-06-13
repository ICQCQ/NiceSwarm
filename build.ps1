# Builds a distributable Windows release of NiceSwarm into build\
# Requires Godot 4.6 on PATH and the matching export templates installed
# (run install_export_templates.ps1 once if "no export template found").
$ErrorActionPreference = "Stop"
$root = $PSScriptRoot
New-Item -ItemType Directory -Force "$root\build" | Out-Null

Write-Host "Importing project..."
godot --headless --path $root --import 2>&1 | Out-Null

Write-Host "Exporting Windows release..."
godot --headless --path $root --export-release "Windows Desktop" "$root\build\NiceSwarm.exe"

if (Test-Path "$root\build\NiceSwarm.exe") {
    $size = [math]::Round((Get-Item "$root\build\NiceSwarm.exe").Length / 1MB, 1)
    Write-Host "Done -> build\NiceSwarm.exe ($size MB)"
    Write-Host "Ship the whole build\ folder (the .exe has the game embedded)."
} else {
    Write-Error "Export failed - is the export template installed? See install_export_templates.ps1"
}

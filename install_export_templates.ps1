# One-time: installs the Godot 4.6.3 export templates so build.ps1 can produce
# a Windows .exe. Downloads ~700 MB from the official GitHub release.
$ErrorActionPreference = "Stop"
$ver = "4.6.3.stable"
$tag = "4.6.3-stable"
$dest = "$env:APPDATA\Godot\export_templates\$ver"

if (Test-Path "$dest\windows_release_x86_64.exe") {
    Write-Host "Export templates already installed at $dest"
    return
}

$url = "https://github.com/godotengine/godot/releases/download/$tag/Godot_v${tag}_export_templates.tpz"
$tpz = "$env:TEMP\godot_templates_$ver.tpz"
Write-Host "Downloading export templates ($tag)..."
$ProgressPreference = 'SilentlyContinue'
Invoke-WebRequest -Uri $url -OutFile $tpz -UseBasicParsing

# A .tpz is a zip whose files live under templates/. Extract and flatten into $dest.
$tmp = "$env:TEMP\godot_tpl_extract_$ver"
Remove-Item -Recurse -Force $tmp -ErrorAction SilentlyContinue
Expand-Archive -Path $tpz -DestinationPath $tmp -Force
New-Item -ItemType Directory -Force $dest | Out-Null
Copy-Item "$tmp\templates\*" $dest -Recurse -Force
Write-Host "Installed export templates -> $dest"

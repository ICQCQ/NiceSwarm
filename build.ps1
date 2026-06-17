# Builds a distributable Windows release of NiceSwarm into build\
# Requires Godot 4.6 on PATH and the matching export templates installed
# (run install_export_templates.ps1 once if "no export template found").
$ErrorActionPreference = "Stop"
$root = $PSScriptRoot
New-Item -ItemType Directory -Force "$root\build" | Out-Null

# Embed the build identity INTO the build at build time: overwrite the BuildVersion
# BRANCH/COMMIT/COUNT consts before export so they are compiled into the .exe (no runtime
# git/file lookup), then restore the committed "dev" placeholders afterward. COMMIT is the
# short SHA (not `git describe`, which would surface v* release tags instead of a bare
# commit id); `-dirty` marks a build made from a modified *tracked* working tree
# (--untracked-files=no, matching describe --dirty semantics) so a local build is
# distinguishable from a clean HEAD build. BRANCH+COUNT drive the headline version string
# ("Publish v. 220") via BuildVersion.label().
$commit = (git -C $root rev-parse --short HEAD 2>$null)
if (-not $commit) { $commit = "unknown" }
elseif (git -C $root status --porcelain --untracked-files=no) { $commit = "$commit-dirty" }
$branch = (git -C $root rev-parse --abbrev-ref HEAD 2>$null)
if (-not $branch) { $branch = "dev" }
$count = (git -C $root rev-list --count HEAD 2>$null)
if (-not $count) { $count = "0" }
$bvFile = "$root\scripts\config\build_version.gd"
$bvOrig = Get-Content $bvFile -Raw   # restored verbatim after export (works even if uncommitted)
# Replace only the const lines so the rest of the file (label()/full_label()) is preserved.
($bvOrig -replace 'const COMMIT := "[^"]*"', "const COMMIT := `"$commit`"" `
        -replace 'const BRANCH := "[^"]*"', "const BRANCH := `"$branch`"" `
        -replace 'const COUNT := "[^"]*"', "const COUNT := `"$count`"") |
    Set-Content -Path $bvFile -NoNewline -Encoding ascii
Write-Host "Build version: $branch v. $count ($commit)"

try {
    Write-Host "Importing project..."
    godot --headless --path $root --import 2>&1 | Out-Null

    Write-Host "Exporting Windows release..."
    godot --headless --path $root --export-release "Windows Desktop" "$root\build\NiceSwarm.exe"
} finally {
    # Always restore the original placeholder so the working tree stays clean.
    Set-Content -Path $bvFile -Value $bvOrig -NoNewline -Encoding ascii
}

if (Test-Path "$root\build\NiceSwarm.exe") {
    $size = [math]::Round((Get-Item "$root\build\NiceSwarm.exe").Length / 1MB, 1)
    Write-Host "Done -> build\NiceSwarm.exe ($size MB)"
    Write-Host "Ship the whole build\ folder (the .exe has the game embedded)."
} else {
    Write-Error "Export failed - is the export template installed? See install_export_templates.ps1"
}

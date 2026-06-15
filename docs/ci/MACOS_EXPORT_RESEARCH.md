# CI: per-arch macOS + Windows-arm64 export — research & ready-to-apply plan

Research for extending the GitHub Actions release pipeline (today: Windows x86_64 only,
`.github/workflows/build-windows.yml`) to ship **separate per-architecture builds**:

| Platform | x86_64 | arm64 |
|----------|--------|-------|
| Windows  | `NiceSwarm.exe` *(existing)* | **`NiceSwarm-arm64.exe`** *(new)* |
| macOS    | **`NiceSwarm-x86_64.zip`** *(new)* | **`NiceSwarm-arm64.zip`** *(new)* |

Decision (from the requester): **two separate per-arch zips for macOS** (not a single
universal binary), and **add Windows arm64** alongside the existing Windows x86_64 build.
Status: **research complete, not yet applied** — apply the artifacts below as one PR.

Sources: [Godot — Exporting for macOS](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_macos.html),
[Godot — Running on macOS](https://github.com/godotengine/godot-docs/blob/master/tutorials/export/running_on_macos.rst),
[Godot — Feature tags](https://docs.godotengine.org/en/stable/tutorials/export/feature_tags.html),
[Godot 4.3 release notes (Windows-on-ARM + templates)](https://godotengine.org/releases/4.3/),
[setup-godot action](https://github.com/marketplace/actions/setup-godot-action).

---

## TL;DR recommendation

- **macOS:** one `export-macos` job on `macos-latest`, doing **two exports** from **two
  presets** (`macOS x86_64` → `NiceSwarm-x86_64.zip`, `macOS arm64` → `NiceSwarm-arm64.zip`),
  each **ad-hoc signed** (free) so the arm64 slice runs on Apple Silicon at all.
- **Windows arm64:** add a **second preset** (`Windows Desktop arm64`, `architecture="arm64"`)
  and a parallel export step in the existing Windows job → `NiceSwarm-arm64.exe`. The
  x86_64 host on `windows-latest` cross-packages arm64 fine (templates are just bundled).
  Official Windows-arm64 templates ship since **Godot 4.3**, so 4.6.3 is covered.
- **Per-arch sidecars + arch-aware update check:** each artifact gets its own `.sha256`;
  `update_check.gd` selects the asset by **platform AND arch** (`OS.has_feature("arm64")`).
- Keep the existing Windows x86_64 asset names (`NiceSwarm.exe`/`-debug.exe`) unchanged so
  already-shipped builds' update URLs don't break. New arch gets the `-arm64` suffix.
- Mac users still clear Gatekeeper quarantine once (right-click → Open / `xattr -dr`).
  Clean double-click needs paid Developer ID + notarization — out of scope.

---

## Key facts (verified against current docs)

### 1. macOS per-arch needs TWO presets (CLI exports by preset name)
`godot --export-release "<preset>" <out>` selects a *named preset*, and a preset pins one
`binary_format/architecture`. So separate x86_64/arm64 zips = **two macOS presets**, one per
arch, each with its own `export_path`. (A single "universal" preset would cover both in one
binary, but the requester wants them split.)

### 2. The mac job is *simpler* than the Windows job — no Start-Process dance
The Windows job wraps every `godot` call in `Start-Process -Wait ... -RedirectStandardOutput`
because setup-godot symlinks `godot` to the **GUI-subsystem** `Godot_*_win64.exe`, which
detaches from PowerShell and returns immediately (the export races silently). That's a
**Windows-only workaround.** On `macos-latest`, `godot --headless ... --export-release` runs
in the foreground and blocks, so the mac steps are plain `run:` with the exit code checked
directly. **Do not port the Windows plumbing into the mac job.**

### 3. macOS format: `.zip` per arch (not `.dmg`/`.app`)
`.dmg` is macOS-host-only with extra tooling; a loose `.app` is a directory bundle that loses
its executable bit when uploaded. **`.zip` is the correct CI artifact** — preserves the
bundle + exec flag. One zip per arch.

### 4. Signing — two *separate* gates, do not conflate them
- **(a) Code-signature validity (required to execute on Apple Silicon).** The kernel refuses
  an *entirely unsigned* arm64 binary. Docs' user-side fix for a fully unsigned app on Apple
  Silicon is `codesign -s - --force --deep "App.app"` (ad-hoc). We avoid pushing that on users
  by exporting **ad-hoc-signed from CI** (`codesign/codesign=1`, "Built-in (ad-hoc only)").
  Free, no certificate. Applies to **both** mac presets (the x86_64 zip also runs on Apple
  Silicon via Rosetta 2, so ad-hoc-sign it too).
- **(b) Gatekeeper quarantine (downloaded-from-internet flag).** Separate gate; ad-hoc does
  **not** clear it. User does it once: right-click (Control-click) → **Open** → confirm, or
  `xattr -dr com.apple.quarantine "NiceSwarm.app"`. Auto-clearing for double-click needs paid
  Developer ID + notarization — out of scope. Put the one-liner in the Release notes.

### 5. Bundle identifier is mandatory (both mac presets)
A macOS export needs "a valid and unique Bundle identifier"; empty/default = **silent**
headless export failure. Use the same reverse-DNS id for both arch presets (e.g.
`com.niceswarm.game`).

### 6. Windows arm64 is supported and cross-packages from an x86_64 runner
Official Windows-on-ARM export templates landed in **Godot 4.3**, so 4.6.3 has them via
`include-templates: true`. Packaging an arm64 exe does **not** require an arm64 host —
`windows-latest` (x86_64) bundles the arm64 template fine. Add a preset with
`binary_format/architecture="arm64"`.

### 7. `update_check.gd` ripple — now a platform×arch matrix, and a hash-order trap
- **Runtime arch:** `OS.has_feature("arm64")` vs `OS.has_feature("x86_64")` (feature tags).
- **macOS exe path trap:** at runtime `OS.get_executable_path()` returns the **inner Mach-O**
  (`NiceSwarm.app/Contents/MacOS/NiceSwarm`), not the `.zip`/`.app`. `_self_hash()` hashes that
  inner binary, so the CI sidecar must `shasum -a 256` the **same inner binary** — and **after**
  ad-hoc signing (signing mutates bytes). Order: **export → (ad-hoc sign, by export) → hash
  inner binary → zip.** Hashing the `.zip` never matches.
- The current `SHA_URL_*` consts are x86_64-`.exe`-only; replace with a computed asset name
  keyed on platform + arch + debug (Artifact 4).

### 8. Cost & release-race (minor)
- `macos-latest`/`windows-latest` minutes are **free on public repos**; private bills macOS at
  10×, Windows at 2×. `ICQCQ/NiceSwarm` is referenced by public Release URLs → non-issue if public.
- Multiple jobs pushing to the same `latest` tag can race creating the release.
  `softprops/action-gh-release` **appends** assets, so make `export-macos` run
  **`needs: export-windows`** (serialize), and let only the Windows job carry
  `generate_release_notes: true`.

---

## Artifact 1 — `export_presets.cfg`: add Windows-arm64 + two macOS presets

Keep existing `[preset.0]` ("Windows Desktop", x86_64) unchanged. Add three presets.

**`[preset.1]` — Windows Desktop arm64.** Copy the full `[preset.0]` + `[preset.0.options]`
blocks verbatim, then change only:

```ini
[preset.1]
name="Windows Desktop arm64"
export_path="build/NiceSwarm-arm64.exe"
# ...all other [preset.0] keys identical...

[preset.1.options]
binary_format/architecture="arm64"
# ...all other [preset.0.options] keys identical (rcedit metadata, embed_pck, etc.)...
```

**`[preset.2]` — macOS x86_64** and **`[preset.3]` — macOS arm64.** Same option block, differing
only in `name`, `export_path`, and `binary_format/architecture`:

```ini
[preset.2]

name="macOS x86_64"
platform="macOS"
runnable=true
dedicated_server=false
custom_features=""
export_filter="all_resources"
include_filter=""
exclude_filter=""
export_path="build/NiceSwarm-x86_64.zip"
patches=PackedStringArray()
encryption_include_filters=""
encryption_exclude_filters=""
seed=0
encrypt_pck=false
encrypt_directory=false
script_export_mode=2

[preset.2.options]

export/distribution_type=1
binary_format/architecture="x86_64"
custom_template/debug=""
custom_template/release=""
debug/export_console_wrapper=1
application/icon=""
application/icon_interpolation=4
application/bundle_identifier="com.niceswarm.game"
application/signature=""
application/app_category="Games"
application/short_version="0.9.0"
application/version="0.9.0"
application/copyright="(c) 2026"
application/copyright_localized={}
application/min_macos_version_x86_64="10.12"
application/min_macos_version_arm64="11.00"
application/export_angle=0
display/high_res=true
xr/shaders=false
codesign/codesign=1
codesign/installer_identity=""
codesign/apple_team_id=""
codesign/identity=""
codesign/certificate_file=""
codesign/certificate_password=""
codesign/provisioning_profile=""
codesign/entitlements/custom_file=""
codesign/entitlements/allow_jit_code_execution=false
codesign/entitlements/allow_unsigned_executable_memory=false
codesign/entitlements/allow_dyld_environment_variables=false
codesign/entitlements/disable_library_validation=true
codesign/custom_options=PackedStringArray()
notarization/notarization=0
privacy/microphone_usage_description=""
privacy/camera_usage_description=""
privacy/location_usage_description=""
privacy/address_book_usage_description=""
privacy/calendar_usage_description=""
privacy/photos_library_usage_description=""
privacy/desktop_folder_usage_description=""
privacy/documents_folder_usage_description=""
privacy/downloads_folder_usage_description=""
privacy/network_volumes_usage_description=""
privacy/removable_volumes_usage_description=""
ssh_remote_deploy/enabled=false
```

`[preset.3]` is identical to `[preset.2]` except:
```ini
[preset.3]
name="macOS arm64"
export_path="build/NiceSwarm-arm64.zip"
[preset.3.options]
binary_format/architecture="arm64"
```

> `codesign/codesign=1` with no identity = **ad-hoc**. **Highest-priority apply step:** add all
> three presets via the editor (Project → Export) once and **diff** the generated file against
> the above — 4.6.3 option-key spelling is the likeliest source of a silent no-op export, and a
> typo'd key is ignored, not errored. Blocks above are the documented default shape, not a
> guaranteed byte-match.

## Artifact 2 — add a Windows arm64 export to the existing Windows job

Insert after the existing "Export Windows release" / verify / sha256 steps in
`export-windows`, reusing the same `Start-Process` pattern (the GUI-subsystem workaround still
applies). Release: `--export-release "Windows Desktop arm64" "build/NiceSwarm-arm64.exe"`.

```yaml
      - name: Export Windows arm64 release
        shell: pwsh
        run: |
          $p = Start-Process -FilePath godot -ArgumentList '--headless --path . --export-release "Windows Desktop arm64" "build/NiceSwarm-arm64.exe"' -NoNewWindow -Wait -PassThru -RedirectStandardOutput godot-export-arm-out.txt -RedirectStandardError godot-export-arm-err.txt
          Get-Content godot-export-arm-out.txt, godot-export-arm-err.txt -ErrorAction SilentlyContinue
          if ($p.ExitCode -ne 0) { throw "arm64 export failed ($($p.ExitCode))" }
          if (-not (Test-Path "build/NiceSwarm-arm64.exe")) { throw "no arm64 exe produced" }
          $hash = (Get-FileHash "build/NiceSwarm-arm64.exe" -Algorithm SHA256).Hash.ToLower()
          "$hash  NiceSwarm-arm64.exe" | Out-File -Encoding ascii -NoNewline "build/NiceSwarm-arm64.exe.sha256"
```

Then add `build/NiceSwarm-arm64.exe` + `.sha256` to the `upload-artifact` and both
`action-gh-release` `files:` lists. (Optionally mirror a `--export-debug ...
NiceSwarm-arm64-debug.exe` step for F1-panel parity, like the existing x86_64 debug build.)

## Artifact 3 — `export-macos` job (two per-arch exports)

```yaml
  export-macos:
    runs-on: macos-latest
    needs: export-windows # serialize Release creation; avoid racing the `latest` tag
    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Stamp build commit into BuildVersion
        run: |
          commit=$(git rev-parse --short HEAD)
          sed -i '' -E "s/const COMMIT := \"[^\"]*\"/const COMMIT := \"$commit\"/" \
            scripts/config/build_version.gd
          echo "Build commit: $commit"; cat scripts/config/build_version.gd

      - name: Set up Godot 4.6
        uses: chickensoft-games/setup-godot@v2
        with:
          version: 4.6.3
          use-dotnet: false
          include-templates: true

      - name: Import project
        run: godot --headless --path . --import || true

      # One export per arch + per-arch sidecar over the inner Mach-O (post ad-hoc sign).
      - name: Export macOS per-arch (.zip, ad-hoc signed)
        run: |
          mkdir -p build
          for arch in x86_64 arm64; do
            preset="macOS $arch"
            out="build/NiceSwarm-$arch.zip"
            godot --headless --path . --export-release "$preset" "$out"
            test -f "$out" || { echo "no zip for $arch"; exit 1; }
            rm -rf "build/_u_$arch" && unzip -q "$out" -d "build/_u_$arch"
            app=$(find "build/_u_$arch" -maxdepth 1 -name '*.app' | head -n1)
            bin="$app/Contents/MacOS/$(basename "$app" .app)"
            hash=$(shasum -a 256 "$bin" | awk '{print $1}')
            printf '%s  NiceSwarm-%s.zip' "$hash" "$arch" > "$out.sha256"
            echo "macOS $arch inner-binary sha256: $hash"
          done

      - name: Upload build artifact
        uses: actions/upload-artifact@v4
        with:
          name: NiceSwarm-macos
          path: |
            build/NiceSwarm-x86_64.zip
            build/NiceSwarm-x86_64.zip.sha256
            build/NiceSwarm-arm64.zip
            build/NiceSwarm-arm64.zip.sha256
          if-no-files-found: error

      - name: Publish versioned Release (on v* tags)
        if: startsWith(github.ref, 'refs/tags/')
        uses: softprops/action-gh-release@v2
        with:
          files: |
            build/NiceSwarm-x86_64.zip
            build/NiceSwarm-x86_64.zip.sha256
            build/NiceSwarm-arm64.zip
            build/NiceSwarm-arm64.zip.sha256

      - name: Publish rolling 'latest' prerelease (on publish branch)
        if: github.ref == 'refs/heads/publish'
        uses: softprops/action-gh-release@v2
        with:
          tag_name: latest
          files: |
            build/NiceSwarm-x86_64.zip
            build/NiceSwarm-x86_64.zip.sha256
            build/NiceSwarm-arm64.zip
            build/NiceSwarm-arm64.zip.sha256
```

## Artifact 4 — `update_check.gd`: compute the asset by platform + arch + debug

Replace the three hardcoded `SHA_URL_*` consts with a base URL + a computed filename. This
keeps Windows x86_64 names legacy-stable (`NiceSwarm.exe` / `NiceSwarm-debug.exe`) and adds
the new arch/platform variants.

```gdscript
const REL_BASE := "https://github.com/ICQCQ/NiceSwarm/releases/download/latest/"

## "<asset>.sha256" for the running platform+arch+build. Windows x86_64 keeps its legacy
## bare names so already-shipped builds keep matching; everything else gets an -arch suffix.
func _sidecar_url() -> String:
    var arch := "arm64" if OS.has_feature("arm64") else "x86_64"
    if OS.get_name() == "macOS":
        return REL_BASE + "NiceSwarm-%s.zip.sha256" % arch  # mac: release only (no debug build)
    var name := "NiceSwarm"
    if arch == "arm64":
        name += "-arm64"          # x86_64 stays bare (legacy)
    if OS.is_debug_build():
        name += "-debug"
    return REL_BASE + name + ".exe.sha256"
```

Then in `check()`:
```gdscript
var sha_url := _sidecar_url()
if _http.request(sha_url) != OK:
    ...
```

`_self_hash()` is unchanged — it hashes `OS.get_executable_path()` (the inner Mach-O on macOS),
which is exactly the byte sequence the CI sidecar hashes (Artifact 3). `_parse_hash()` is
filename-agnostic (leading 64-hex token only), so it needs no change despite the new filenames.

> If you add macOS debug builds later, extend `_sidecar_url()` with a `-debug` mac variant and
> add the matching CI export — mirror the Windows scheme.

---

## Open items to confirm when applying (don't treat this doc as byte-exact)

1. **Add all four presets via the editor once and diff** against Artifact 1 — option-key
   spelling for 4.6.3 is the top silent-failure risk. (Highest priority.)
2. **Sanity-check the Windows arm64 export actually produces a binary in CI** — official
   4.3+ templates exist, but confirm `include-templates` for 4.6.3 pulls the arm64 Windows
   template (watch the first run's export log). Fall back: drop Windows-arm64 if the template
   is absent, keep macOS per-arch.
3. Confirm `softprops/action-gh-release@v2` **appends** (not replaces) assets to `latest`
   across the serialized jobs — the `needs:` ordering assumes append.
4. Decide on **debug** parity for the new arches (Windows-arm64-debug, macOS-debug).
5. Update `CLAUDE.md` (CI/Running sections) and `PLAN.md` once applied — they currently
   describe a Windows-x86_64-only pipeline.
6. One-line Release-notes addition: mac quarantine step (right-click → Open /
   `xattr -dr com.apple.quarantine NiceSwarm.app`), and which download is which arch.

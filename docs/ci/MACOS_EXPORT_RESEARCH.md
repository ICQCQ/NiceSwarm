# CI: macOS export — research & ready-to-apply plan

Research for adding a macOS executable to the GitHub Actions release pipeline that
today only builds Windows (`.github/workflows/build-windows.yml`). Status: **research
complete, not yet applied**. This doc ends in concrete artifacts (a preset block, a CI
job, and the `update_check.gd` change) — apply them as one PR.

Sources: [Godot — Exporting for macOS](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_macos.html),
[Godot — Running on macOS](https://github.com/godotengine/godot-docs/blob/master/tutorials/export/running_on_macos.rst),
[chickensoft-games/setup-godot](https://github.com/marketplace/actions/setup-godot-action).

---

## TL;DR recommendation

- Add a **second job** `export-macos` on `runs-on: macos-latest` — *not* a build matrix.
  The Windows job is full of pwsh-specific `Start-Process` plumbing that does not port.
- Export a **`.zip`** (containing a Universal 2 `.app`), not `.dmg`/`.app`.
- Export with **ad-hoc signing** (`codesign/codesign=1`, "Built-in (ad-hoc only)") so the
  arm64 slice runs on Apple Silicon at all. This is free (no Apple Developer account).
- Set a **bundle identifier** in the preset — macOS export needs a valid unique one.
- Ship a macOS sidecar hash computed over the **inner Mach-O binary, after signing,
  before zipping**, and teach `update_check.gd` a `macOS` URL variant.
- Users still clear Gatekeeper quarantine once (right-click → Open, or `xattr -dr`).
  A clean double-click requires paid Developer ID + notarization — out of scope here.

---

## Key facts (verified against current docs)

### 1. The macOS job is *simpler* than Windows — drop the Start-Process dance
The Windows job wraps every `godot` call in `Start-Process -Wait ... -RedirectStandardOutput`
because setup-godot symlinks `godot` to the **GUI-subsystem** `Godot_*_win64.exe`, which
detaches from PowerShell and returns immediately (the export races silently). That is a
**Windows-only workaround.** On `macos-latest`, `godot --headless ... --export-release`
runs in the foreground and blocks normally, so the mac job is plain `run:` steps with the
exit code checked directly. **Do not cargo-cult the Windows plumbing into the mac job.**

### 2. Export format: `.zip`, not `.dmg`/`.app`
Godot can emit `.app`, `.zip`, or `.dmg`. `.dmg` is **macOS-host-only** and needs extra
tooling — no benefit for an artifact download. `.app` is a *directory bundle*; uploading it
loose to a Release flattens/loses the executable bit. **`.zip` is the only sane CI artifact**
— it preserves the bundle and the executable flag. (Exporting macOS from a Windows host even
*requires* `.zip`, because a Windows-exported `.app` loses its exec flag — moot here since we
run on a real mac, but it's why `.zip` is the documented CI default.)

### 3. Architecture: Universal 2 (x86_64 + arm64) for free
`include-templates: true` already pulls both slices. The preset's
`binary_format/architecture="universal"` produces one binary that runs on Intel **and**
Apple Silicon. No extra cost.

### 4. Signing — two *separate* gates, do not conflate them
- **(a) Code-signature validity (required to execute on Apple Silicon).** The kernel refuses
  to run an *entirely unsigned* arm64 binary. The docs' user-side fix for a fully unsigned app
  on Apple Silicon is `codesign -s - --force --deep "Unsigned Game.app"` (ad-hoc). We avoid
  pushing that onto users by exporting **ad-hoc-signed from CI** (Godot's "Built-in (ad-hoc
  only)" codesign mode). Free, no certificate.
- **(b) Gatekeeper quarantine (downloaded-from-internet flag).** Separate gate. Ad-hoc signing
  does **not** clear it. The user still does it once:
  - Right-click (Control-click) the app → **Open** → confirm, **or**
  - `xattr -dr com.apple.quarantine "NiceSwarm.app"`
  - Clearing this automatically for double-click users needs **Developer ID + notarization**
    (paid, $99/yr Apple Developer) — explicitly out of scope. Document the manual step in the
    Release notes instead.

### 5. Bundle identifier is mandatory
A macOS export needs "a valid and unique Bundle identifier" in the Application section. With
the default/empty value, a **headless** export fails silently in CI. Set a reverse-DNS id
(e.g. `com.niceswarm.game`) in the preset.

### 6. `update_check.gd` ripple — the hash-order trap
At runtime on macOS, `OS.get_executable_path()` returns the **inner Mach-O**
(`NiceSwarm.app/Contents/MacOS/NiceSwarm`), *not* the `.zip` and *not* the `.app` dir.
`_self_hash()` therefore hashes that inner binary. So the CI sidecar must `shasum -a 256`
the **same inner binary** — and **after ad-hoc signing**, because signing mutates the bytes.
Correct ordering: **export → (ad-hoc sign, done by export) → hash inner binary → zip.**
Hashing the `.zip` would never match the running build. The current `SHA_URL_*` consts are
`.exe`-only and branch solely release/debug; macOS needs a third URL keyed on `OS.get_name()`.

### 7. Cost & release-race (minor)
- `macos-latest` minutes are **free on public repos**; on private they bill at **10×**.
  `ICQCQ/NiceSwarm` is referenced by public Release URLs, so this is a non-issue if public.
- Two jobs publishing to the same `latest` tag can race creating the release.
  `softprops/action-gh-release` **appends** assets to an existing release, so the safe fix is
  to make `export-macos` run **`needs: export-windows`** (serialize), and let only the
  Windows job carry `generate_release_notes: true`.

---

## Artifact 1 — add a macOS preset to `export_presets.cfg`

Append as `[preset.1]`. (Bump `application/short_version`/`version` in lockstep with the
`0.9.0` version trio when the project version changes.)

```ini
[preset.1]

name="macOS"
platform="macOS"
runnable=true
dedicated_server=false
custom_features=""
export_filter="all_resources"
include_filter=""
exclude_filter=""
export_path="build/NiceSwarm.zip"
patches=PackedStringArray()
encryption_include_filters=""
encryption_exclude_filters=""
seed=0
encrypt_pck=false
encrypt_directory=false
script_export_mode=2

[preset.1.options]

export/distribution_type=1
binary_format/architecture="universal"
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

> `codesign/codesign=1` with no identity = **ad-hoc** ("Built-in (ad-hoc only)"). Verify the
> exact integer/option keys by adding the preset once in the editor (Project → Export) and
> diffing — Godot is picky about option key spelling, and a typo'd key is silently ignored
> rather than erroring. The block above is the documented default shape, not a guaranteed
> byte-match for 4.6.3.

## Artifact 2 — `export-macos` job for `build-windows.yml`

Append under `jobs:`. Mirrors the Windows job's stamp + release wiring but uses plain
foreground `run:` steps.

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

      - name: Export macOS release (.zip, ad-hoc signed)
        run: |
          mkdir -p build
          godot --headless --path . --export-release "macOS" "build/NiceSwarm.zip"
          test -f build/NiceSwarm.zip || { echo "no zip produced"; exit 1; }

      # The game hashes its OWN inner Mach-O at runtime (OS.get_executable_path()),
      # so the sidecar must hash that exact file — already ad-hoc-signed by the export.
      - name: Compute macOS SHA256 sidecar (inner binary)
        run: |
          rm -rf build/_unzip && unzip -q build/NiceSwarm.zip -d build/_unzip
          app=$(find build/_unzip -maxdepth 1 -name '*.app' | head -n1)
          bin="$app/Contents/MacOS/$(basename "$app" .app)"
          hash=$(shasum -a 256 "$bin" | awk '{print $1}')
          printf '%s  NiceSwarm.app' "$hash" > build/NiceSwarm.zip.sha256
          echo "macOS inner-binary sha256: $hash"

      - name: Upload build artifact
        uses: actions/upload-artifact@v4
        with:
          name: NiceSwarm-macos
          path: |
            build/NiceSwarm.zip
            build/NiceSwarm.zip.sha256
          if-no-files-found: error

      - name: Publish versioned Release (on v* tags)
        if: startsWith(github.ref, 'refs/tags/')
        uses: softprops/action-gh-release@v2
        with:
          files: |
            build/NiceSwarm.zip
            build/NiceSwarm.zip.sha256

      - name: Publish rolling 'latest' prerelease (on publish branch)
        if: github.ref == 'refs/heads/publish'
        uses: softprops/action-gh-release@v2
        with:
          tag_name: latest
          files: |
            build/NiceSwarm.zip
            build/NiceSwarm.zip.sha256
```

> A macOS debug export is optional — Windows ships one for the F1 panel. Mirror the
> `--export-debug "macOS" build/NiceSwarm-debug.zip` step + its own sidecar if macOS
> playtesters need it; otherwise skip to keep the job lean.

## Artifact 3 — `update_check.gd` change (macOS URL variant)

The constants are `.exe`-only. Add a macOS pair and select on platform:

```gdscript
const SHA_URL_RELEASE := "https://github.com/ICQCQ/NiceSwarm/releases/download/latest/NiceSwarm.exe.sha256"
const SHA_URL_DEBUG := "https://github.com/ICQCQ/NiceSwarm/releases/download/latest/NiceSwarm-debug.exe.sha256"
const SHA_URL_MACOS := "https://github.com/ICQCQ/NiceSwarm/releases/download/latest/NiceSwarm.zip.sha256"
```

In `check()`, pick the URL by OS first, then debug/release:

```gdscript
var sha_url: String
if OS.get_name() == "macOS":
    sha_url = SHA_URL_MACOS # (add a *-debug.zip.sha256 variant if you ship a mac debug build)
else:
    sha_url = SHA_URL_DEBUG if OS.is_debug_build() else SHA_URL_RELEASE
```

`_self_hash()` already hashes `OS.get_executable_path()` (the inner Mach-O on macOS) — it
needs **no change**, which is exactly why the CI sidecar must hash that same inner binary
post-signing (Artifact 2). `_parse_hash()` is filename-agnostic (it only reads the leading
64-hex token), so it works unchanged.

---

## Open items to confirm when applying (don't take this doc as byte-exact)

1. **Add the preset via the editor once and diff** the generated `[preset.1]` against
   Artifact 1 — option key spelling for 4.6.3 is the single most likely source of a silent
   no-op export. (Highest priority.)
2. Confirm `softprops/action-gh-release@v2` appends (not replaces) assets on the existing
   `latest` release when the mac job runs after the Windows job — the `needs:` serialization
   assumes append.
3. Decide whether a macOS **debug** build is wanted (F1 panel parity).
4. Update `CLAUDE.md` (the CI/Running sections) and `PLAN.md` once applied — they currently
   describe a Windows-only pipeline.
5. One-line Release-notes addition telling mac users the quarantine step (right-click → Open
   or `xattr -dr com.apple.quarantine NiceSwarm.app`).

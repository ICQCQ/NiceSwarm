# NiceSwarm — Session Log

> Historical development log, moved out of PLAN.md (which keeps current status +
> milestones). Append new session entries at the bottom; newest work last.

### 2026-06-17 — Session 12: amalgam tooltip + turret-fusion keeps its gun
- **Amalgam hover tooltip:** hovering a fused weapon now lists every weapon inside it
  (`game_hud._fusion_parts_block`) — each component's name, level, per-hit DMG (base parts),
  and live DPS/total. Reuses the universal `WeaponBase.dps`/`damage_dealt`.
- **Turret fusions keep the normal gun:** turret-fusion modes whose effect is NOT a fired
  bullet — deploys (mines/gravity/venom) and AoE/chain (nova/lightning/flame) — now also fire
  the normal turret bolt on an independent `gun_cd` timer (`turret_node.GUN_RETAINING_MODES` +
  extracted `_fire_bolt()`). So e.g. a Mine Layer plants mines AND shoots like a normal turret.
  Bullet modes (missile/frost/glaive + plain bolt) and continuous beam/orbit are unchanged.
- **Verify:** `[tests] 1103 passed`; boots clean. (Tooltip render + turret behavior best confirmed in-game.)

### 2026-06-17 — Session 11: fusion damage — fresh-fusion boost + amalgam per-level scaling
- **Two requests, one mechanism.** Added `WeaponBase.fuse_pow`/`born_dmg` (both default 1.0 →
  no effect on base/standalone weapons) and 4 `fuse_*()` stat accessors; replaced all 424
  `player.{damage,area,duration,rate}_mult` reads in `weapon_fusions.gd` with them (identity at
  the defaults, so standalone fusions are unchanged).
- **#1 fresh fusion not weak:** a signature fusion is born with `born_dmg = GameConfig.FUSION_BORN_DMG`
  (×1.5 damage) so it isn't a downgrade from the two maxed weapons it consumed. (Flat multiplier, a
  tunable approximation of "≥ the 2 combined" — an exact per-fusion floor would need editing each of
  the 78 damage constants.)
- **#2 amalgam scaling:** `WeaponFused` leveling now buffs ALL its components' stats by
  `GameConfig.AMALGAM_STAT_PER_LEVEL` (5%) per level via `fuse_pow`, instead of bumping each
  component's level. Components are maxed (Lv7) at merge, so base/counts are already capped.
- **Verify:** `[tests] 1103 passed` (incl. new `test_merge` asserts for born_dmg + amalgam fuse_pow);
  `NICESWARM_TEST=all_fusions` smoke runs all 78 fusions clean. Made `test_config` MAX_GEMS a
  positivity check (was a brittle exact 500) since it's a tunable knob.

### 2026-06-17 — Session 10: slow buff + visual/balance tweaks
- **Slow buff ("really slow enemy"):** every slow source funnels through `Enemy.apply_slow`,
  so the buff is one central change there. New `GameConfig.SLOW_POTENCY` (1.6) deepens the
  incoming speed factor and `SLOW_FLOOR_MULT` (0.2) clamps it — the 0.5 base frost slow now
  lands at 0.2 speed (an 80% slow, "slow to 0.8"). Bosses/tier-3 included (still slowable);
  only `cc_immune` enemies stay exempt. Test added in `test_enemies.gd` (potency + floor + cc).
- **XP gem size −:** normal gems 5/8 → 3.5/5.5 px (`xp_gem.gd`) — less field clutter (condensed gold orbs unchanged).
- **Gravity "veil" size −:** base Gravity Well radius `160 + 15/lv` → `120 + 10/lv` (`weapon_gravity.gd`); fusions unchanged.
- **Venom trail opacity −:** fill `0.22→0.12`, spots `0.30→0.16` (`venom_puddle.gd`) — stops washing out everything underneath.
- **Mine cap was global, now per-weapon (bug):** all mine-spawners shared one `get_nodes_in_group("mines")`
  count, so multiple mine weapons (esp. one-per-player in co-op) split a single cap. Added `owner_weapon_id`
  to `MineNode` + reusable `WeaponBase.owned_in_group()`; base Mines, ClusterBomb, NapalmMine, and the turret
  mines-mode now cap per deploying weapon (mirrors how turrets already filter by owner). Turret caps were
  verified already per-weapon (not the bug). Regression test: `tests/test_merge.gd` (deep-fusion structure).
- **Unblocked the unit suite:** fixed pre-existing drift in `test_config.gd` + `test_spawner.gd`
  (`DIFF_WARMUP_SECS`→`DIFF_WARMUP_PROGRESS`, `MID_GAME_TIME`→`MID_GAME_PROGRESS`,
  `BOUNCER_UNLOCK`→`BOUNCER_UNLOCK_PROGRESS`, removed `sp.pace`, mock `run_progress` from elapsed).
- **Verify:** `[tests] 1082 passed, 0 failed`; solo headless smoke boots clean.

### 2026-06-17 — Session 9: fusions born at Lv1 (gate amalgam behind leveling) + icon fix
- **Goal (2 reported issues, one root cause):** (1) only a maxed-out fusion should be
  amalgamable; (2) a freshly-fused weapon's HUD badge always showed Lv⁷.
- **Root cause:** `player.merge_weapons` stamped a signature fusion `sig.level = maxi(a.level, b.level)`
  (= Lv7) — born maxed, so its badge read ⁷ *and* it was instantly eligible for the `[MERGE]` pool
  (which gates on `level >= MAX_WEAPON_LEVEL`). Both symptoms, one line.
- **Fix:** drop that line — a signature fusion is now born at the `WeaponBase` default Lv1, levels
  up 1→7 like a base weapon, and only becomes amalgamable once maxed. Badge now shows ¹.
  This **reverses the Session-7 born-at-Lv7 DPS-cliff fix** (above): per product decision the
  cliff is **accepted** — a fresh fusion is weaker and rewards leveling it back up.
- **Verify:** `NICESWARM_TEST=merge` smoke → `merged -> Plasma Burst … weapons=1`, `pool ok, options=22`
  (the Lv1 fusion now appears in the `[Lv]` pool, not `[MERGE]`). Docs: WEAPON_CODEX.md updated.
- **Note (pre-existing, unrelated):** `tests/run_tests.gd` is currently red at `test_config.gd` —
  it references `GameConfig.DIFF_WARMUP_SECS` / `MID_GAME_TIME` / `BOUNCER_UNLOCK` which were
  removed/renamed (`BOUNCER_UNLOCK` → `BOUNCER_UNLOCK_PROGRESS`). Not touched this session; flag for a fix.

### 2026-06-16 — Session 8: settings menu (audio / display / accessibility)
- **Goal:** implement the long-stubbed settings menu (the in-game hub's "O settings"
  showed only "coming soon").
- **`GameSettings` (`scripts/core/settings.gd`, new `class_name`):** client-local prefs —
  **master volume** (10% cycler), **mute**, **fullscreen**, **screen shake** — persisted to
  `user://settings.cfg` via `store_var` (mirrors the profile save/load). `apply_audio()`
  drives Master bus 0 (mutes the bus when muted **or** volume 0, since `linear_to_db(0)` is
  `-INF`); `apply_window()` toggles `DisplayServer` fullscreen (no-op under headless);
  `apply_all()` runs both. Deliberately **NOT net-synced** — every player keeps their own.
- **Wiring:** `main._ready` creates + loads + applies settings before the UI builds. The hub
  "O" key now opens a real settings tab (`gameui._show_settings`, treated as another
  `codex_view` so ESC backs out via `_close_codex`; codex/settings share the hub body slot).
  Added a **Settings button + overlay on the main menu** too (own dim + Back button — menus
  are mouse-driven, no ESC perturbation) so audio/display can be set before a run. Both panels
  share one `GameSettings`; each is relabeled on show (`_relabel`) so a change in one isn't
  stale in the other. **Screen-shake gate** is the single apply point in `player._update_cam`
  (shake still decays; only the `cam.offset` write is suppressed when disabled).
- **GDScript trap avoided:** the relabel row dicts use keys `btn`/`fn`, not `b`/`get` —
  `dict.get` resolves to `Dictionary.get()`, not the key.
- **Verified:** `--import` clean (new class_name); unit suite **1078 passed, 0 failed** (+10:
  new `tests/test_settings.gd` covers `next_volume` cycling + a save/load round-trip through a
  **temp** `user://settings_test.cfg`, never the real file — `save`/`load_from_disk` gained an
  optional path arg for this); 300-frame boot smoke + 600-frame solo run both error-free.
  **Not** verified interactively (no display here): live volume/mute audibility, the actual
  fullscreen switch, and the on-screen panel layout need a real window — call those out.
- **Next:** real in-game check of the settings panels (layout + that volume/fullscreen/shake
  actually take effect); consider a VSync toggle and per-bus (SFX vs music) volume if music lands.

### 2026-06-16 — Session 7: weapon codex + full hover stat tooltip (branch `feat/weapon-codex`, worktree)
- **Goal:** write down a weapon/skill codex + all fusions, and make the in-game weapon-icon
  hover tooltip always show **all** weapon stats, including for fusion weapons.
- **Codex:** new [WEAPON_CODEX.md](WEAPON_CODEX.md) — the player-facing catalogue: per-weapon
  base stat table (dmg/growth/cd/type + behavior, pulled from `WeaponConfig.BASE` +
  `WEAPON_INFO`), run rules (5 slots, Lv7 cap, fusion tiers), the 4-stat axis summary, and all
  **78 fusions** (name + behavior, generated from `Fusions.INFO` so it can't drift). Linked it
  from WEAPON_DESIGN.md (which stays the *design contract*; the codex is the catalogue).
- **Hover tooltip (`scripts/ui/game_hud.gd:_weapon_tip_text`):** was DMG+cadence for base
  weapons and only "scales with your stats" (no numbers) for fusions. Now every weapon — base
  **and** fusion — shows: name + Lv + fusion-tier badge (◆T1/◆T2/◆T3); per-hit DMG + cadence
  for base weapons (fusions have no `BASE` row); universal live **DPS + total damage** (reuses
  the fusion-aware `_weapon_dps`/`_weapon_dmg` aggregation — sums components for `WeaponFused`,
  reads `damage_dealt`/`dps` for monolithic signature fusions); the four build-wide axes
  (Pwr/Spd/Area/Dur, labeled "Your build" since they're global); and a behavior line (WEAPON_INFO
  for base, `Fusions.INFO` desc for signature fusions, component list for generic `WeaponFused`).
  Added helper `_fusion_desc(w)`.
- **Verified:** fresh-worktree `--import` clean; 300-frame headless smoke clean; unit suite
  **1068 passed, 0 failed**. The hover path isn't reachable from headless smoke, so wrote a
  throwaway `--script` harness (since deleted) that load()s Player/HUD/Fusions at runtime
  (static refs fail to compile — `Sfx` is autoload-only, not a `class_name`) and actually
  called `_weapon_tip_text` for all three branches: base (Bolt → `DMG 3.0 / every 0.69s`),
  signature fusion (Pulsar ◆T1 + its INFO desc), and `WeaponFused` (Pulsar + Glacial Edge ◆T2 +
  component list) — all rendered correctly, no empties/errors. **Not** visually hovered (no
  display in this environment); verified by-construction + runtime string output.
- **Overflow guard:** the new lines are longer than the tooltip ever showed (the "Your build"
  line ~56 chars + fusion descs up to ~105, e.g. Beam Battery), and `weapon_tip` was
  `AUTOWRAP_OFF` → long lines would run off-screen and hide stats. Flipped it to
  `AUTOWRAP_WORD_SMART` so they wrap inside the fixed 584px box (`game_ui.gd`). Pointer to the
  codex added to CLAUDE.md.
- **Next:** real in-game hover check to confirm the wrapped layout looks right; consider a
  fusion `[FUSE]` pick showing the same stat block. (Stale-but-out-of-scope: `SUP` const + its
  "max level 3" comment predate `MAX_WEAPON_LEVEL = 7`; the badge clamps so Lv7 shows "³".)

### 2026-06-16 — Session 6: auto-updating launcher (branch `feat/launcher`, worktree)
- **Goal:** a small, cross-platform launcher that checks for updates and downloads the
  game automatically, then launches it. Design + rationale in [LAUNCHER.md](LAUNCHER.md).
- **Architecture:** the launcher is the primary distributable; the ~100 MB game binary is
  managed in a per-user data dir (`%LOCALAPPDATA%\NiceSwarm` on Windows, `~/Library/
  Application Support/NiceSwarm` on macOS). Because the game isn't running during a
  download, the Windows locked-exe problem never arises. **Reuses the existing `.sha256`
  sidecar contract** — asset resolution mirrors `update_check.gd:_sidecar_url()` exactly
  (Windows x86_64 bare / arm64 `-arch` / `-debug`; macOS one universal zip whose sidecar
  hashes the inner Mach-O, not the zip).
- **Built in Go** (`launcher/`, zero external deps, ~6 MB binary). Packages: `release`
  (asset/URL resolution), `download` (HTTP + redirect-follow + SHA256 verify + progress),
  `install` (data dir, atomic replace on Win / `.app` swap + `xattr` quarantine clear on
  mac, launch), `config` (persists `--debug`). `--debug` selects the debug game build
  (Windows x86_64 only; macOS/arm64 downgrade to release). **Installed Go via scoop** (was
  absent on this machine; run `go` as `~\scoop\shims\go.exe` from agent tools).
- **CI:** new `.github/workflows/build-launcher.yml` publishes `NiceSwarm-Launcher*.{exe,zip}`
  to a **separate `launcher` rolling tag** (+ `launcher-v*`), path-filtered to `launcher/**`
  so game commits don't republish it. One Linux job cross-compiles both Windows arches; a
  macOS job builds a universal `.app` (ad-hoc signed).
- **Verified empirically (Windows):** `go build`/`go vet`/`go test ./...` green; live sidecar
  fetch against the real `latest` release returned a valid 64-hex hash; all 4 cross-compile
  targets build; **full run downloaded 106 MB → SHA256-verified → installed to LOCALAPPDATA
  → launched the game** (exit 0); 2nd run printed "already up to date" (no re-download).
  macOS path is implemented but **untested** (no mac host here) — Phase 2.
- **Next:** Phase 2 real macOS test (`.app` swap, quarantine, the no-terminal progress UX);
  Phase 3 launcher self-update (it becomes the locked exe — rename-self-to-`.old` trick) +
  Windows arm64-debug asset. A native Windows progress window (vs console) is optional polish.

### 2026-06-16 — Session 5: early-game XP catch-up (branch `feat/early-xp-bonus`, worktree)
- **Goal:** snappier opening — a 2× XP bonus for the first 5 levels, and make the very first
  level-up (1 → 2) cost only 2 XP.
- **Implemented (all in the pure, unit-tested config layer):**
  - `GameConfig.EARLY_XP_BONUS_LEVELS = 5` / `EARLY_XP_BONUS_MULT = 2` + new pure helper
    `GameConfig.xp_gain(value, lvl)` (2× while `lvl <= 5`, raw after). `main._on_gem_collected`
    now credits `xp_gain(value, level)` to both the shared XP pool and the scoreboard XP
    (host-authoritative — puppet gems never emit `collected`).
  - `GameConfig.XP_FIRST_LEVEL = 2`: `xp_for_level` returns a flat 2 at `lvl <= 1` (ignores
    `cfg_xp_rate`), so the 1 → 2 level-up is near-instant; level 2+ keeps the geometric curve.
- **Fixed a pre-existing test-harness bug found en route:** `test_xp.gd:35` called `t.lt`, which
  the Tester doesn't define (`ok/eq/ne/gt/ge/approx` only) — it threw a SCRIPT ERROR that silently
  aborted the xp suite before its last assertions (a script-abort counts as neither pass nor fail).
  Rewrote it as `t.gt(...)` with reversed args; the suite now runs to completion.
- **Verified:** unit suite **1068 passed, 0 failed**; headless 300-frame smoke clean. Same-seed
  god-sim (`god=1,ff=4`) comparison — **publish: L2 @ min 1; this branch: L5 @ min 1**, with
  `xp_need=2` at level 1 (was 10); the real `_on_gem_collected` path ran with zero errors.
- **Tuning knobs:** `EARLY_XP_BONUS_LEVELS` / `EARLY_XP_BONUS_MULT` / `XP_FIRST_LEVEL` in
  `game_config.gd`. Docs: GAME_DESIGN.md §5 "Snappy opening".
- **Next:** real playtest of the opening feel; if too fast, dial the bonus window/mult down.

### 2026-06-16 — Session 4: enemy soft-separation (no stacking) (branch `publish`)
- **Goal:** enemies should not pile up on a single point / overlap each other.
- **Approach:** kept `collision_mask = 0` (physics collision between 220 bodies is the
  documented O(n²) cliff). Added a boids-style **soft separation** steering force in
  `Enemy._separation()` (host-only): query the shared per-frame `EnemyGrid.near(pos, radius)`,
  sum a unit-capped push away from overlapping neighbors (linear falloff, 0 at first touch →
  1 at full overlap), and add `_separation() * spd * SEPARATION_STRENGTH (0.7)` to velocity
  before `move_and_slide`. Skipped for manual movers (bounce/straight shards phase through)
  and immovable enemies (`knockback_immune`/`cc_immune`, incl. bosses) — they still part the
  swarm around them since they appear in others' queries. Puppets are unaffected (early-return).
- **Verified:** headless smoke + `zoo` (all enemy types) clean; unit suite 1059 passed, 0 failed;
  god lethality probe (`god=1,ff=4`) ran a full 10:00 → `result=WIN`, 0 errors, physics peaked
  ~11–13ms at the 220-enemy swarm (within budget). Updated CLAUDE.md collision note.
- **Tuning:** `SEPARATION_STRENGTH` in `enemy.gd` — raise for firmer spacing, lower if the
  swarm feels too "pushy" / jittery.

### 2026-06-15 — Session 3: balance overhaul + docs + unit tests (branch `balance/curve-waves`)
- Rebased the balance branch onto the post-`sync-from-master` `publish`, re-grounding the
  plan against the refactored code (spawning now in `scripts/core/spawner.gd`; two-track
  `pace`/`difficulty` + heat/heat-spike/bosses/bouncers already exist). Revised
  [docs/balance/BALANCE_PLAN.md](docs/balance/BALANCE_PLAN.md) accordingly (waves → spawner,
  walls dropped in favor of the boss system, FF reuses `player.debug_god`).
- **Docs:** wrote [GAME_DESIGN.md](GAME_DESIGN.md) (holistic design, incl. the new difficulty
  model) + [README.md](README.md).
- **Implemented the 4-system overhaul:**
  1. *Gem cap* — 500-gem ceiling; excess XP condenses into the farthest gem, rendered as a
     growing red orb (perf). Client value-sync updated each tick.
  2. *`NICESWARM_FF=<mult>`* fast-forward hook — scales `Engine.time_scale` +
     `max_physics_steps_per_frame`, immortal players (`debug_god`), auto-picks level-ups,
     prints level/gems per game-minute. Fixed a pre-existing bomb-pickup freed-instance crash
     it surfaced.
  3. *Three-band XP curve* — `GameConfig.xp_for_level` (pure/static/tested); fast early →
     earned late.
  4. *Time-based waves* — per-minute intensity/pop in `spawner.run_spawning`, layered over the
     existing engine; bosses remain the DPS-checkpoints.
- **Unit tests:** new zero-dependency headless harness `tests/run_tests.gd` + 7 modules,
  **925 assertions** (config, weapons, enemies, all 78 fusions, spawner math, XP curve, waves,
  gems). Run: `godot --headless --path . --script res://tests/run_tests.gd`.
- **Calibrated via FF:** shipped curve+waves land the 10-min win at ~L45–48 (target 40–50).
  Verified: 925 unit tests + solo/zoo/all_weapons/merge/bomber + co-op host/join all clean.
- **Next:** real playtest of the new curve/waves/gem-cap; tune wave feel; the XP/wave numbers
  are calibrated to the *aggressive* FF case, so real play lands a bit lower.

### 2026-06-14 — Session 2: late-game O(n²) perf fix (branch `perf/game-loop-on2`)
- User reported late-game crash to <1 fps + attacks "passing through" enemies. Investigated
  and wrote [PERFORMANCE.md](PERFORMANCE.md): **two independent O(n²) costs**, and the
  missed-hits are a *symptom* of the frame collapse (Godot time-dilation past
  `max_physics_steps_per_frame`), not tunneling (bolt 520 px/s = 8.7 px/step < 17 px radius).
- **Cost A (engine):** 220 enemies (`CharacterBody2D`) all had `collision_mask = 2` → mutual
  `move_and_slide()` contact solving. Set enemy `collision_mask = 0` (overlap freely, VS-style).
- **Cost B (script):** ~70 `get_tree().get_nodes_in_group("enemies")` calls/tick, each
  allocating a fresh ≤220 array. Added `Main`'s shared per-tick enemy index (`class_name Main`
  + `static instance`, built once in `_physics_process` before children): `all_enemies()`,
  `enemies_in_radius()` (uniform 128px grid, O(local)), `nearest_enemy_to()`. Routed
  `player.nearest_enemy` + orbit + gravity_well through the grid; swapped the rest to the
  shared cached list. Helpers return `Array[Node]` to preserve call-site inference.
- Verified headless (a same-version Godot binary; user's `godot` wasn't on the automation
  PATH): import clean + solo/all_weapons/zoo/merge/bomber/co-op all error-free.
- **Next:** measure the real fps gain in a playtest (the doc's bisect); optionally do the
  follow-ups (throttle continuous scanners, migrate nova/laser/flame/spawned to the radius
  query, `queue_redraw` cleanup). Pushed to fork for a PR to the original repo.

### 2026-06-13 — Session 1
- Chose concept (action roguelike) + stack (Godot 4) with user; installed Godot 4.6.3 via Scoop.
- Built entire first playable (M0–M5): all scripts under `scripts/`, one minimal `scenes/main.tscn`.
- Fixed: class_name cache needs `--import` after adding new `class_name` scripts; UI must build before world (player emits health signal in `_ready`).
- Headless smoke test passes clean.
- **Next session:** get user playtest feedback, then M6 balance pass. Known untested: real input feel, upgrade button clicks, win-at-10:00 path (only code-reviewed, not played).

### 2026-06-13 — Session 1 (continued): variety update
- User playtest verdict: "too straightforward, nothing engaging" → built M6 variety update.
- Added: dash (SPACE/SHIFT, i-frames, HUD indicator), weapon system as player child nodes
  (`weapon_bolt/orbit/nova.gd`, levels 1–5), dynamic upgrade pool (learn/level weapons + 6 stats),
  elites dropping chests (free upgrade picks, queued via `pending_chests`), brute pickup drops
  (heart/bomb/magnet), damage numbers (`float_text.gd`), ring FX (`ring_fx.gd`), knockback, screen shake.
- Player stats refactored: `damage_mult`/`rate_mult` multipliers instead of per-weapon stats.
- Headless smoke test clean. **Untested in real play:** orbit/nova feel, dash feel, chest flow, bomb.
- **Next session:** playtest round 2 → balance pass (M7). If it still feels flat, consider: faster
  early ramp (first minute is quiet), starting weapon choice, or more aggressive elite cadence.

### 2026-06-13 — Session 1 (continued): arsenal expansion
- User asked for ~10 more attack options with distinct styles → added 10 weapons (13 total):
  glaive (out-and-back pierce), lightning (chain zap), flame (facing cone DoT), mines (placed traps),
  missiles (homing + splash), laser (rotating beam), frost (piercing slow volley), gravity (pull vortex),
  turret (deployable), venom (trail puddles). Each is a self-processing player child node, levels 1–5.
- Supporting: enemy `apply_slow()`, damage-number throttling for tick weapons, ground FX z-ordering
  (background z=-10, puddles/mines/wells z=-1), 5-weapon run cap, owned-weapons HUD (top right).
- Smoke-test hook: env `NICESWARM_TEST=all_weapons` grants every weapon at start; 900-frame
  headless run with all 13 active is clean.
- **Untested in real play:** all 10 new weapons' feel and balance; expect damage outliers (M7).

### 2026-06-13 — Session 1 (continued): end-game scoreboard
- Per-player stats (host): `_score[pid] = {damage, xp, revives, deaths}`. Accrual — **deaths** in
  `_on_player_downed`; **revives** credit the adjacent helper in `_run_revives`; **xp** to the
  nearest player at gem-collect; **damage** via a new `source_pid` param on `enemy.take_hit` (credits
  `min(amount, hp)` so overkill doesn't inflate). Threaded `source_pid` through every spawned node
  (projectile/missile/mine/well/venom/frost/glaive/turret, incl. turret's sub-spawns) and every
  direct `take_hit` in the 13 weapons + 43 fusions (weapons pass `player.peer_id`, nodes carry it).
- End screen shows a ranked scoreboard (`scoreboard_box`, colored per player). Synced via the end
  RPC: `send_end(...scores: PackedFloat32Array)` packs `[color_idx, dmg, xp, rev, deaths]×N`.
- Test: `NICESWARM_TEST=score` (force-ends at 4 s, prints rows). Fixed a stray invalid `level // 2`
  (no Python int-div in GDScript) in weapon_turret while here.
- Verified headless: score, all_weapons, all_fusions (43), zoo (27), host+client — clean.

### 2026-06-13 — Session 1 (continued): script restructure + config files
- **Restructure:** moved 35 scripts into folders — `core/` (net/player/sfx), `weapons/`,
  `spawned/` (projectiles/nodes/fx weapons emit), `enemies/`, `world/`, `config/`; `main.gd` stays at
  root (scene ref). All `class_name`, so code refs unaffected; only updated project.godot's Sfx
  autoload path. Deleting `.godot/` cleared a stale autoload-path cache after the move.
- **Config files (`scripts/config/`):** `GameConfig` (run + difficulty + spawn knobs; main aliases its
  consts via `const X := GameConfig.X`; net reads `NET_PORT`), `EnemyConfig.CLASSES` (the enemy table,
  lifted out of main → `ENEMY_CLASSES`), `WeaponConfig.BASE` (per-weapon dmg/growth/cd; each
  `weapon_*.gd` reads `WeaponConfig.BASE[weapon_id]`).
- **Test-timing note:** headless runs the loop uncapped, so a co-op host with too few `--quit-after`
  frames can exit before the client connects — looks like a netcode break but isn't. Give the host a
  big frame budget (6000+) and start the client immediately. Verified: join ok → peer connected →
  synced; all solo hooks (all_weapons/merge/all_fusions 43/zoo 27/bomber/heat) clean after the move.

### 2026-06-13 — Session 1 (continued): back-to-menu + 6 creative fusions (43)
- **Quit to menu:** `_to_menu()` leaves the run (net.leave + clear world + show menu). Host ESC pauses
  then **M** = menu; client ESC = leave directly; game-over screen offers **M** (+ R restart on host).
  Updated pause/end/HUD hint text.
- **+6 creative fusions (43):** Absolute Zero (frost+nova, freezing nova), Thermal Shock (flame+frost,
  burn+slow cone), Event Horizon (gravity+orbit, holds enemies in the blade ring via pull-to-ring),
  Vortex Blade (glaive+gravity, glaives + a well), Thunderclap (lightning+nova, blast that forks
  lightning from each hit), Mine Halo (mines+orbit, orbiting blades that fling mines).
- Heredoc-append broke on shell quoting → wrote classes via a temp .gd file + `cat >>`.
- Verified headless: all_fusions (43), zoo (27), host+client zoo — clean. Rebuild exe to ship.

### 2026-06-13 — Session 1 (continued): slow revive decay, spawn-mix tweak, all turret fusions
- **Revive:** when no ally is adjacent, `revive_progress` now decays at `delta·0.07` (was `delta`) —
  nearly retained, so a helper doesn't have to hover the whole 3 s.
- **Spawn mix:** disruptors stay rare; added two extra `bouncer` weights past 5:00 so bouncers
  become common late.
- **All turret fusions:** `TurretNode.mode` extended to bolt/missile/frost/beam/glaive/lightning/
  nova/flame/mines/gravity/venom/orbit (emit dispatch in `_emit`, plus `_run_orbit`/`_run_beam`).
  Added the 9 remaining turret pairs (Gun/Halo/Pulse/Glaive/Tesla/Flame/Mine Layer/Singularity/
  Toxic Turret) as thin `_Sentry` subclasses → **37 signature fusions** (turret now pairs with all
  12 other base weapons). Gotcha: `var x := dict.get(...)` infers Variant (warning-as-error) — typed it.
- Verified headless: all_fusions (37), zoo (27), host+client zoo — clean. Rebuild exe before shipping.

### 2026-06-13 — Session 1 (continued): version display + double-click build
- Turret Lv1 bug fixed (`int(level/2)`==0) + calmer early population (target 18→6+diff·3).
- **Versioning:** `VERSION = "0.9.0"` const shown on the menu subtitle; `config/version` in
  project.godot; `application/file_version`/`product_version` (0.9.0.0) + product/company/description
  in export_presets.cfg → the built exe carries Windows version metadata (verified via VersionInfo).
- **Double-click build:** `build.cmd` wraps `build.ps1` (`powershell -ExecutionPolicy Bypass`, pauses
  at the end) so the .exe can be produced without a terminal. Rebuilt build/NiceSwarm.exe.
- Bump version in all three spots together (see CLAUDE.md).

### 2026-06-13 — Session 1 (continued): all planned fusions + 3 new, softer difficulty
- User: implement the planned fusions + add new ones; difficulty still ramps fast; scale down the
  level-up contribution.
- **Difficulty:** DIFF_BASE 1/34→1/48, DIFF_HEAT 2.0→1.8, DIFF_LEVEL 0.06→0.02, and the direct
  per-level-up step DIFF_LEVEL_STEP **0.9→0.3** (the main ask). Gentler overall + much less from leveling.
- **Turret modes:** `TurretNode.mode` = bolt / missile / frost (slowing shards) / beam (a sweeping
  laser, host-damaged along a rotating line). Drives the 3 planned sentry fusions.
- **+6 fusions (28):** Missile Battery (missiles+turret), Beam Sentry (laser+turret), Cryo Sentry
  (frost+turret) via a shared `_Sentry` inner base; Nova Beam (laser+nova), Barrage (bolt+missiles,
  bolts + periodic rocket salvo), Toxic Nova (nova+venom, blast + poison pool). All designed turret
  fusions are now implemented.
- Verified headless: all_fusions (28), zoo (27), host+client zoo — clean.
- **Next session:** confirm the softer curve doesn't let enemies fall behind late; M7.

### 2026-06-13 — Session 1 (continued): NiceSwarm rename, early-game brake, tier spread, +3 fusions
- User: more fusions; rename to **NiceSwarm**; early difficulty grows too fast (tone down only early);
  at high difficulty shift spawn proportion toward higher ranks but keep low ranks; when the player
  is overwhelmed (can't clear, too many enemies) the heat should tone down.
- **Rename:** Nightswarm→NiceSwarm across project name, menu title, exe, docs, and the test env vars
  (`NICESWARM_NET`/`NICESWARM_TEST`). Rebuilt `build/NiceSwarm.exe`.
- **Early brake:** `_warmup() = clamp(0.25 + elapsed/80, 0.25, 1)`; multiplies the difficulty climb
  AND the per-level-up step, so the opening ~80 s ramps gently to full speed.
- **Tier distribution:** `_class_tier` now sets a ceiling `int(diff/3)` then steps *down* with 40%
  prob per rank — higher tiers become common as difficulty rises while lower tiers keep appearing
  (was a hard pick of the top tier).
- **Overwhelmed relief:** if `alive > desired_pop*1.4` and `clear_ema < spawn_rate*0.7`, force heat
  target to 0 and decay it fast (0.35/s) — eases the difficulty acceleration when struggling.
- **+3 fusions (22):** Tesla Halo (lightning+orbit), Plasma Storm (flame+lightning), Cyclone (glaive+nova).
- Verified headless: all_fusions (22), zoo (27), heat samples, host+client zoo; rebuilt exe runs.
- **Next session:** playtest the gentler opening + tier spread + relief; M7.

### 2026-06-13 — Session 1 (continued): difficulty/spawn tuning, indestructible shards, Windows build
- User: enemies can't keep up at 5 min; heat dissipates too fast; level-ups should add to difficulty;
  refill spawns when the field is thin; Bomber/Disruptor need more jitter; shards must be undestroyable;
  produce a Windows build.
- **Scaling:** DIFF_BASE 1/55→1/34, DIFF_HEAT 1.6→2.0; level-up adds `DIFF_LEVEL_STEP` (0.9) straight to
  `difficulty`; heat decay 0.12→0.05/s (lingers). Spawn interval shrinks (×0.3) while
  `enemies_by_id.size() < 18 + difficulty·2.5` so a fast-clearing player gets the field refilled.
- **Casters:** pattern-0 cast now has a chaos *floor* (0.35) + bigger jitter (≥30 px) and always fires a
  2nd scattered strike past chaos 0.4 — applies to Bomber AND Disruptor/Hexer (effect 1), so debuffs
  are harder to pre-dodge.
- **Shards:** new `bullet` flag — not in the "enemies" group, collision_layer/mask 0, `take_hit` no-op,
  so weapons can't target or destroy them; they only deal contact damage (distance check) and expire.
  Set on the `shard` tier.
- **Windows build:** `export_presets.cfg` (Windows Desktop, x86_64, embed_pck, `build/NiceSwarm.exe`),
  `build.ps1`, `install_export_templates.ps1`. Gotcha: Scoop's Godot is self-contained → templates must
  live in `scoop/apps/godot/current/editor_data/export_templates/4.6.3.stable/`, not %APPDATA%. Built &
  launch-tested a 99.8 MB single-file exe. `build/` is gitignored.
- Verified headless: zoo (27), all_fusions (19), host+client zoo — clean; exe runs.
- **Next session:** re-balance the steeper curve from playtest; M7.

### 2026-06-13 — Session 1 (continued): movement variety, shapes, Bouncer, Burster bullets
- User: too many pure-chasers → some move random; make classes look distinct; add a bouncer that
  phases + can't be interrupted; rework Splitter into an exploder that spits bullets on death; more fusions.
- **Movement:** enemy `move_mode` 0 chase / 1 wander (random heading) / 2 bounce (straight, reflects
  off arena walls) / 3 straight+`life`. `phase` (collision_mask 0), `cc_immune` (no slow/knockback),
  `life` (despawn). Wisps now wander; new **Bouncer** class (ricochet, phase, cc-immune, pull-immune).
- **Distinct looks:** `shape` per class (circle/triangle/square/diamond/hex/star) drawn via
  `_draw_body`; directional shapes point along `heading`.
- **Burster (was Splitter):** on death spits a radial ring of **shard** enemy-bullets (new `shard`
  class: move=straight, phase, cc-immune, life 2.2 s, 1 hp, contact dmg, 0 xp). `_spawn_burst`
  (deferred). Shards give no kill credit / gem / drop (`xp_value<=0` early-return in `_on_enemy_killed`).
- **+3 fusions (19):** Pulsar (nova+orbit), Frost Lance (bolt+frost), Plague Arc (lightning+venom).
- Verified headless: zoo (27 types), all_fusions (19), host+client zoo — all clean.
- **Next session:** playtest the movement variety + bouncer/burster; M7.

### 2026-06-13 — Session 1 (continued): master Difficulty number, gravity pull-resist, Defiler
- User: dynamic option-select keys (not capped); gravity warp too strong → gradual pull + pull-resist
  after; heat decays too fast → gradual; show a Difficulty number/bar that drives spawn-type/dmg/hp
  and is accelerated by heat + level; a ground-effect debuff enemy; Bomber more unpredictable over time.
- **Picks:** MAX_CHOICES 4→6, CHOICES_OPTS adds 5/6; number-key handler is now dynamic (`KEY_1..KEY_1+MAX_CHOICES`).
- **Gravity:** reverted the one-time warp to a gradual `pull * factor * delta` drag; per-enemy
  `pull_factor` decays 1→0 over ~1.7 s, so enemies are drawn in then released. `pull_immune` unaffected.
- **Difficulty system:** new master `difficulty` (host, synced via HUD as `net_difficulty`). Grows at
  `DIFF_BASE·(1 + heat·DIFF_HEAT + (level-1)·DIFF_LEVEL)`. `_make_enemy` scales hp/speed from it (was
  elapsed-minutes) and adds `+1 dmg / 12 diff`; `_class_tier` = `diff/2.8`. Removed the old per-enemy
  heat hp bonus (no double-dip). HUD shows `DIFFICULTY x.x ▮▮▮▯…` with `▲/▲▲` heat accelerator.
- **Heat decay:** `heat_cur` smoothed — rises at 0.6/s, falls at 0.12/s (gradual). `_heat()` returns it.
- **Defiler enemy:** TelegraphZone `effect=2` (EFFECT_FIELD) — after the warn it lingers ~3 s as a
  ground hazard disrupting players inside (`apply_disrupt(0.4)` refresh). New `defiler` class
  (Warlock/Defiler) casts these. Effect packed in the synced telegraph radius float (0/1/2).
- **Bomber chaos:** pattern-0 cast scales jitter + variable lead with `main_ref.difficulty`, plus a
  2nd scattered strike past chaos 0.5. (Type-inference gotcha: `var lead: Vector2 =` since target is Node2D.)
- Verified headless: zoo (24 types), all_fusions (16), heat samples, host+client zoo — all clean.
- **Next session:** tune the difficulty curve + new mechanics; M7.

### 2026-06-13 — Session 1 (continued): clear-rate heat, immunities, disruptor/sentinel/wisp
- User: gravity well too strong (pull once); some enemies immune to pull / a damage type; heat
  negligible → measure clear rate instead; add a self-protecting enemy + a disruptor; more fusions.
- **Gravity well:** pulls each enemy in exactly once (member `pulled` set), then only grinds; `pull`
  is now a one-time distance. `pull_immune` enemies (tank/warden/sentinel/elite) ignore it.
- **Damage types:** `Enemy.DMG_PHYS/FIRE/ICE/ENERGY`; `take_hit(amount, from_pos, dtype)`;
  `immune_type` → zero damage of that type. Tagged nova/lightning/laser/gravity=ENERGY, flame+burn=FIRE,
  frost=ICE. Wisp class immune to ENERGY.
- **Heat = clear rate:** `_clear_ema` (kills/sec EMA) vs `_spawn_rate`; `_heat()` =
  clamp((clear−spawn)/(spawn·2+1),0,1). Verified: 1/1→0, 3/1→0.67, 5/1→1.0, 6/2→0.80. Host-only
  compute, synced to clients via the HUD-state RPC (`net_heat`).
- **New classes:** Sentinel (phasing invuln shield via `shield_cycle`/`shield_time`, checked in
  `take_hit`), Wisp (energy-immune, fast), Disruptor (caster `cast_effect=1` → TelegraphZone
  `effect=DISRUPT` → `player.apply_disrupt`: slows + dash-lock 2.5 s; purple zone; dashing through
  ignores it). Telegraph effect packed into the synced radius float (radius + effect·10000).
- **+3 fusions (16):** Cluster Warhead (missiles+nova), Black Bog (gravity+venom), Toxic Halo (orbit+venom).
- Preserved live user edits (lightning `dmgDrop` falloff, etc.); used Python for edits while the
  files were being modified.
- Verified headless: zoo (22 types), all_fusions (16), heat formula samples, host+client zoo — all clean.
- **Next session:** playtest immunities, disruptor/sentinel, gravity nerf, clear-rate ramp; M7 balance.

### 2026-06-13 — Session 1 (continued): enemy catalogue, threatening Bomber, more variety
- User: add an enemy-design MD; Bomber feels unthreatening; too few variety.
- **ENEMY_DESIGN.md:** catalogues the class/tier system, stat fields, telegraph patterns, the full
  roster, designed-not-built ideas, and an add-a-class checklist.
- **Bomber threat:** now *leads* the target (`pos + velocity*0.9`) so straight-line running gets hit;
  faster, data-driven cadence (`cdt` per caster tier: Bomber 2.0s / Diviner 2.6 / Oracle 3.0 via
  `enemy.cast_cooldown`); radius 95→115; slightly faster, +contact. Oracle damage 1→2.
- **More variety:** 2 new classes — **Warden** (Shieldling/Bulwark, `resist` 0.4/0.55 applied in
  `enemy.take_hit`, steel-ring draw) and **Splitter** (Spore/Brood, `splits` → host spawns N weak
  grunts at the death site in `_on_enemy_killed`, inner-cell draw). Woven into `_run_spawning`'s
  weighted pick (warden from 2:00, splitter from 3:00). Pickup drops are tank-only.
- Cleaned up an in-progress edit in enemy.gd (stray unused var, hardcoded cadence) — note the file
  was being edited live; used Python for robust replacements.
- Verified headless: `NICESWARM_TEST=zoo` (16 types spawn/run incl. splits+resist+casts), heat,
  all_fusions, and a host+client zoo (client rebuilds all 16 typed enemies) — all clean.
- **Next session:** playtest Bomber lead + Warden/Splitter; M7 balance.

### 2026-06-13 — Session 1 (continued): enemy class/tier system + heat fix
- User: Diviner is just an upgraded Bomber — make an enemy *class* system where classes have tiers
  that are direct upgrades; categorize all enemies; the upgrade should vary its attack pattern.
  Also: the threat/heat meter seemed not to work.
- **Class system:** `ENEMY_CLASSES` (brawler/rusher/tank/caster/elite), each an ordered list of tier
  stat-dicts. `_build_type_registry` (in `_ready`) flattens them to stable network ids; `_make_enemy`
  takes (cls, tier); `_class_tier` picks the tier from elapsed/170 + heat + level·0.05 so harder
  variants appear over time and faster when ahead. `_spawn_enemy(cls, tier=-1)`. Sync now packs
  `type_id` (+1000 = slowed) instead of kind_idx (+10); client rebuilds via `_make_enemy_by_type`.
  Bomber=caster t0, Diviner=caster t1 (predictive line), **Oracle**=caster t2 (new ring pattern,
  `cast_pattern==2`). Removed the separate diviner timer — the caster timer escalates by tier.
- **Heat fix:** old par=1+t/20, /5 + a Threat label overlapping the timer → looked dead. Now
  par=1+t/24, /4 (verified via `NICESWARM_TEST=heat`: t60/lv5→0.38, t120/lv9→0.75, t180/lv16→1.0,
  t300/lv14→0.13) and the label moved to (540,58). Tanks-only pickup drops (casters no longer flood).
- Verified headless: heat samples, caster-tier spawn, all_fusions, host+client (client rebuilds 6
  typed enemies) — all clean.
- **Next session:** playtest tiers + heat ramp; M7 balance.

### 2026-06-13 — Session 1 (continued): run config, fusion bias, Diviner enemy
- User asks: bias fusion options to appear when eligible; menu config for options-per-levelup / XP
  rate / enemy scale; a 2nd premonition enemy that's more common at higher level.
- **Fusion bias:** `_roll_choices` now splits the pool into merges vs rest; if any merge exists it
  guarantees one in the slate, then fills the rest randomly (up to `cfg_choices`).
- **Run config:** `cfg_choices`/`cfg_xp_rate`/`cfg_enemy_scale` set by menu cyclers (`_make_cycler`
  helper); `_apply_menu_config` on Solo/Host; host broadcasts via `net.send_config` →
  `rpc_run_config` (NOTE: `rpc_config` is a **reserved native Node method** — must use another name)
  → `apply_config`. Applied: choices → buttons built to `MAX_CHOICES`=4, sliced to `cfg_choices`,
  keys 1–4; XP → `_xp_needed` divided by rate; enemy scale → hp ×scale, speed partial, in `_make_enemy`.
- **Diviner:** enemy kind "diviner" (caster, `cast_pattern=1`) hovers at 340px and paints a line of
  3 telegraphs ahead of the target's velocity (premonition of your path). Spawns from level ≥ 8,
  interval `clamp(50 - level*1.5, 12, 50)` so it's more frequent the higher you climb. Reuses the
  circle telegraph + `STATE_TELEGRAPHS` channel (no netcode change).
- Other format gotcha: GDScript `%` has no `%g` — used `str(value)` for the cycler labels.
- Verified headless: bomber+diviner (solo), merge, all_fusions (13), host+client with casters
  (client gets 6 enemies + telegraph channel; config broadcast clean) — all error-free.
- **Next session:** playtest config presets + the Diviner dodge; M7 balance.

### 2026-06-13 — Session 1 (continued): dynamic difficulty + 6 more fusions
- User asks: ramp difficulty when the player is ahead (more elites/special enemies); add more fusions.
- **Dynamic difficulty (`_heat()`):** par = 1 + elapsed/20; heat = clamp((level - par)/5, 0, 1).
  Used in `_run_spawning` (elite interval 75→32s, bomber 20→11s, ~22%×heat chance to upgrade a
  normal spawn to brute/bomber) and `_make_enemy` (hp ×(1+0.35·heat), speed ×(1+0.1·heat)). HUD
  "Threat ▮▮▮▯" meter (calm/rising/HIGH). heat uses synced level+elapsed so clients match.
- **6 new fusions** (→13): Railgun (bolt+lightning, line damage via LightningFx beam), Supernova
  (flame+nova, big blast + fiery puddle), Frost Halo (frost+orbit, slowing blades), Glacier
  (frost+gravity, freezing well via `GravityWell.freeze`), Storm Disc (glaive+lightning, glaives
  that arc via `GlaiveProj.arc_damage`), Napalm Mine (flame+mines, mine leaves fire pool via
  `MineNode.fire_*`). Added those small fields to the spawned nodes.
- Verified headless: all_fusions (13 active), bomber, host+client pair — all clean.
- **Next session:** playtest the rubber-band ramp (tune par curve) and the new fusions; M7 balance.

### 2026-06-13 — Session 1 (continued): starter pick, pick colors, FUSE/AMALGAM, Bombardier
- User asks: color upgrade options by type; two merge keywords (combine→amalgam, new-weapon→fuse);
  pick 1-of-3 starter weapon at run start; a new enemy with a telegraphed attack you must react to.
- **Pick colors:** `CAT_COLORS` map; each pool entry tags a `cat` ("new/level/fuse/amalgam/stat/
  starter"); `_roll_choices` tints button font per category.
- **Keywords:** signature merge → `[FUSE]` (gold, "NEW WEAPON"); generic combine → `[AMALGAM]`
  (orange). Pool builds the right label/cat from `Fusions.info`.
- **Starter pick:** `_grant_starters()` — interactive play opens a starter pick (free + `picks_starter`
  flag → pool is 3 random `learn_` options, title "CHOOSE YOUR STARTING WEAPON"); headless/test runs
  keep the fixed bolt+test loadout (no input). `open_picks`/`send_open_picks`/`rpc_open_picks` gained
  a `starter` param. Reuses the wait-for-all flow, so co-op each picks their own.
- **Bombardier:** new enemy kind "bomber" (caster) that hovers at ~300px and every 3s calls
  `main.cast_telegraph(pos,r,dmg)`; `telegraph.gd` (`TelegraphZone`) fills a red circle over
  TELEGRAPH_WARN (1.3s) then detonates on host, hitting players still inside. Synced via a NEW 4th
  world-state channel `STATE_TELEGRAPHS` (telegraphs_by_id, last_tick key 3); clients show the
  warning as a puppet and the removal-diff plays the detonation. Spawns from 2:30, every 20s.
- Verified headless: bomber (solo: spawn→cast→detonate), all_weapons, and host+client with bombers
  (client receives channel kind=3) — all clean. Test hook `NICESWARM_TEST=bomber`.
- **Next session:** playtest starter choice, the dodge enemy, pick colors; M7 balance.

### 2026-06-13 — Session 1 (continued): universal stats, distinct fusions, design guide
- User principle: every weapon must benefit from every stat; if a stat only touches some weapons,
  the stat isn't general enough or the weapon design is wrong. Also: fusions should be NEW weapons,
  not the same two; and write a design guide so this holds going forward.
- **Universal stats:** added enemy `apply_burn(dps,dur)` + host-side burn tick + orange tint;
  `WeaponBase.ignite()` applies a burn whose length scales with Duration and dps with Power — the
  universal Duration hook for instant weapons (nova/orbit/laser/lightning/flame/glaive). Wired the
  remaining gaps: Area → turret targeting range, mine trigger radius, projectile size (added
  `Projectile.radius`); Haste → orbit/laser spin speed + per-enemy re-hit cadence; frost slow
  duration now scales with Duration. Audited all 13 — each honors Power/Haste/Area/Duration.
- **Distinct fusions:** `scripts/weapon_fusions.gd` — `Fusions.INFO` recipe table + `Fusions.make()`
  returning new WeaponBase inner classes (PlasmaBurst, Cryoshock, ToxicPyre, Singularity,
  ClusterBomb, PrismHalo, GlacialEdge). `player.merge_weapons` prefers a signature recipe, else the
  generic combined WeaponFused (deep merges / uncovered pairs). `[MERGE]` pick shows the resulting
  weapon name + "NEW WEAPON". Added small additive hooks to spawned nodes: Projectile explode,
  VenomPuddle burn/fiery, GravityWell detonate, MineNode spawn_missiles/life, GlaiveProj slow_factor.
- **Guide:** `WEAPON_DESIGN.md` — the 4-stat contract, a new-weapon checklist, and the fusion recipe
  list (7 implemented + 10 designed). CLAUDE.md points to it.
- Verified headless: all_weapons, merge (→ Plasma Burst), all_fusions (7 active, no errors — only a
  benign "leaked at exit" under that stress hook), and host+client pair — all clean.
- **Known gap:** burn/slow tint + burn damage are host-side; clients don't visually show burn ticks
  (state stream only syncs position + slow flag). Note for M7.5 co-op hardening.
- **Next session:** playtest the universal stats + 7 fusions; M7 balance.

### 2026-06-13 — Session 1 (continued): generalized stats, level cap 3, pause arsenal
- User asks: generalize stats so each affects weapons via a mechanic (not just raw damage); list
  weapons in pause menu; shorten weapon level grind (cap 3 instead of 5).
- **Stats:** added `area_mult` + `duration_mult` to player (alongside `damage_mult`/`rate_mult`).
  Every weapon now multiplies its spatial dims by `area_mult` (radii, reach, beam length, orbit r,
  puddle r, projectile/shard/glaive hit radius, lightning jump range) and its lifetimes by
  `duration_mult` (turret/venom/well/projectile life). Stat pool is Power/Haste/Area/Duration +
  Swift/Vitality/Magnet/Slipstream; `st_damage`→`st_power`, added `st_area`/`st_duration` (capped
  at 2.5×). Projectile got a `radius` field so bolt/Area scales its size.
- **Level cap:** `MAX_WEAPON_LEVEL = 3` in main, referenced by `[Lv]`/`[MERGE]` gates and merge test
  hook. Per-level damage factors doubled (0.15→0.30 etc.) so L3 ≈ old L5 ceiling. Rescaled:
  glaive +glaive at Lv2/Lv3, laser 2nd beam Lv3, turret 2nd turret Lv3. WEAPON_INFO text updated.
- **Pause arsenal:** `_refresh_pause_roster()` on pause shows loadout (fusion names + levels) and a
  2-per-line list of all 13 base weapons with `Lv n` / `fused` / `—` status. Used `rpad` (GDScript
  `%-16s` width flag is unreliable).
- Verified headless: solo, all_weapons, merge (fuses at Lv3 now), host+client pair — all clean.
- **Next session:** playtest the new stat axes + faster fusion + the doubled growth (likely needs
  M7 tuning), then SFX mix.

### 2026-06-13 — Session 1 (continued): fusion, audio, custom port
- User asked for: host port selection, weapon fusion of level-5 attacks (merge 2 → 1 new slot for
  more build layers), and unique per-attack SFX.
- **Fusion:** new `weapon_base.gd` (shared base: id/level/display_name + player resolution by
  walking up the tree so nested weapons still find the player) and `weapon_fused.gd` (container
  holding component weapons as children; `level_up()` bumps every component; merging a fusion
  flattens its parts into the new one). All 13 weapons refactored from `extends Node2D` +
  `@onready get_parent()` to `extends WeaponBase` + `_init()` sets id/name. `merge_weapons()` on
  player re-parents components (no re-create, so levels/state survive). Upgrade pool now offers up
  to 2 `[MERGE]` options when ≥2 weapons are maxed, and `[Lv]` on a fusion routes to `level_up()`.
- **Audio:** `scripts/sfx.gd` autoloaded as `Sfx`. Synthesizes ~25 sounds at startup into
  AudioStreamWAV (pitch-sweep + noise-mix + envelope), pools AudioStreamPlayer2D/flat, per-name
  throttle so tick weapons (flame/laser/orbit) don't stack. Each weapon plays its voice on fire;
  also dash/hurt/kill/gem/chest/levelup/merge/revive/click. Clients hear their local weapons + get
  kill/gem/chest cues from removal-diff in `_apply_state`.
- **Custom port:** `Net.host_game/join_game` take an optional port; menu has a Port field
  (validated, defaults to 24565).
- Test hooks: `NICESWARM_TEST=merge` force-maxes bolt+nova and fuses them at start.
- Verified headless: solo, all_weapons, merge (`fused_bolt_nova`, 1 slot), and host+client pair all clean.
- **Next session:** real playtest of fusion feel + SFX mix, then M7 balance.

### 2026-06-13 — Session 1 (continued): online co-op v1
- Built host-authoritative ENet co-op (user chose online over couch co-op), up to 4 players, port 24565.
- New: `scripts/net.gd` (all RPCs; Net node child of Main for stable RPC paths), main menu/lobby,
  shared-XP party leveling with wait-for-all upgrade picks, downed/revive (3 s, half HP),
  chests reward every player, ally HP lines + off-screen ally arrows, party-size difficulty scaling.
- Sync model: host simulates everything; clients send pos/facing/dash at 20 Hz and upgrade picks;
  host broadcasts chunked full-snapshot state (enemies 12 Hz, items 8 Hz, HUD 4 Hz, ≤80 entities
  per packet); clients run weapons cosmetically (damage host-only via `take_hit` puppet guard),
  removal-by-diff drives death pops. Solo uses the identical code path with no peer.
- Restart (host R) rebuilds the world in place without dropping connections.
- Verified headless: solo run clean; host+client pair over localhost connects, starts with both
  peers, client materializes enemy puppets from host stream — both logs error-free.
  Test hooks: env `NICESWARM_NET=solo|host|join` (auto-menu), gated `[test]` prints.
- **Known v1 limits (queued in M7.5):** client cosmetic mines/missiles drift from host truth,
  ally flame/laser angles approximate, no mid-game join, no latency smoothing beyond lerp.
- **Next session:** real-input co-op playtest (two windows on one PC works), then M7 balance.
- Post-playtest hotfix: collected gems/pickups were never erased from the host sync dicts →
  thousands of "previously freed instance" errors (typed assignment raises *before* any
  `is_instance_valid` check can run). Now erased at collection; all sync-dict reads untyped
  with validity checks first. Re-verified: solo + host/client pair logs clean.

### 2026-06-14 — Session 2: fusion coverage matrix complete (78/78)
- Filled in every remaining cell of the fusion coverage matrix in `WEAPON_DESIGN.md`,
  bringing signature fusions from 43 → 78 (all pairs). New recipes live in
  `scripts/weapons/weapon_fusions.gd`.
- Gravity row (GRV): Cinder Vortex (flame), Accretion Beam (laser, rotating energy
  spokes added to `GravityWell`), Storm Vortex (lightning, chain-arc field added to
  `GravityWell`), Implosion Mine (mines), Implosion Salvo (missiles) — each spawns/hosts
  the paired weapon's effect inside the vortex's own radius.
- Mines row (MIN): Shrapnel Mine (glaive), Beam Mine (laser), Tesla Mine (lightning),
  Nova Mine (nova), Toxic Mine (venom) — share a new `_MineFusion` base class; the
  mine's own blast uses normal `(level-1)` growth, the bonus payload it spawns on
  detonation uses `(level)` growth (one level stronger than the mine). New optional
  fields added to `MineNode` (`shrapnel_*`, `beam_*`, `chain_*`, `nova_*`, `venom_*`).
- Final 14 pairs (flame/glaive/laser/missiles/orbit/venom/lightning cross-combinations):
  Inferno Blade, Solar Lance, Phoenix Rocket, Blaze Halo, Photon Disc, Rotor Missile,
  Blade Tempest, Plague Blade, Ion Storm, Beam Battery, Acid Ray, EMP Missile, Rocket
  Halo, Plague Rocket. `MissileProj` gained optional `fire_*`/`venom_*`/`shrapnel_*`/
  `chain_*` payload fields (mirrors `MineNode`'s pattern) for the rocket-based ones.
- `main.gd`'s `NICESWARM_TEST=all_fusions` regression list extended to all 78 pairs.
- Verified headless: `all_fusions` (300 & 1800 frames) and `all_weapons` (600 frames)
  all clean, zero errors.
- **Next session:** real playtest of the new fusions for balance/feel, then M7 balance pass.

### 2026-06-14 — Session 2 (continued): burn stacking rework, gravity tone-down, EnemySpawner extraction
- **Burn rework (user correction):** reverted the 5-stack burn array to a single
  `burn_dps`/`burn_timer` pair (`enemy.gd`). `apply_burn` now stacks additively on
  re-ignite — both `burn_dps` and `burn_timer` add onto the active burn instead of a
  capped array of independent burns. `WeaponBase.ignite()` base duration back to
  `1.2 * player.duration_mult`.
- **Gravity well tone-down:** base well `damage` now lands exactly **once per enemy per
  well lifetime** via a new `_hit_enemies` tracking dict in `gravity_well.gd`. Fusion
  "pair" damage fields (`beam_dmg` for Accretion Beam, `chain_dmg` for Storm Vortex)
  still tick every 0.35s as before; one-shot/separate-node fusion effects (Singularity
  detonate, Cinder Vortex puddle, Implosion Mine/Salvo) untouched.
- **EnemySpawner extraction:** pulled all enemy-spawn pacing + dynamic-difficulty/heat
  state out of `main.gd` into a new `scripts/core/spawner.gd` (`class_name EnemySpawner`,
  child of Main like `Net`, `spawner.main = self`). Owns the type registry
  (`build_type_registry`/`types`/`type_id`), difficulty/heat (`difficulty`,
  `net_difficulty`, `heat_cur`, `net_heat`, `heat()`, `diff()`, `warmup()`,
  `update_difficulty`, `add_kill`, `add_level_difficulty`), and spawning
  (`run_spawning`, `class_tier`, `make_enemy`, `make_enemy_by_type`, `spawn_enemy`,
  `spawn_burst`). Spawn weights/timings are now data-driven: `EnemyConfig.SPAWN_POOL`
  (weighted, time-gated regular spawns) and `EnemyConfig.SPAWN_SPECIALS` (periodic
  tank/elite/caster spawns with heat-lerped intervals) — tuning what spawns when is now
  a table edit. `enemy.gd`'s Bomber/Disruptor chaos calc reads `main_ref.spawner.difficulty`.
- Gotcha: fields computed from `main.<dict>.size()`/`main.peer_ids.size()` (where `main`
  is typed `Node`) need an explicit type annotation (`var x: float = ...`/`var x: bool =
  ...`) — `:=` can't infer through a `Variant`-typed property access.
- Verified headless: import (new `class_name EnemySpawner` resolves), plain 300-frame
  run, `zoo`/`bomber` (300), `all_weapons` (900), `all_fusions` (1800), host+join pair —
  all clean, zero errors.
- **Next session:** real playtest of the new burn-stacking feel, gravity tone-down, and
  use the new `SPAWN_POOL`/`SPAWN_SPECIALS` tables for more granular spawn tuning; M7.

### 2026-06-14 — Session 2 (continued): split pace vs. difficulty
- User: separate the single `difficulty` number into two — one controls enemy
  *variety* + *desired population* and must progress with time only (never
  accelerate); the other controls how hard enemies are to *clear* and should
  accelerate when the player is doing well.
- `EnemySpawner` now tracks both, growing from the same base rate (`DIFF_BASE *
  warmup()`) each tick:
  - **`pace`** (new, host-only) — flat time-based climb, no heat/level
    multiplier. `class_tier` (variety ceiling) and `desired_pop` (spawn-refill
    target) now read `pace` instead of `difficulty`.
  - **`difficulty`** (unchanged name/sync) — same base rate but multiplied by
    `(1 + heat*DIFF_HEAT + (level-1)*DIFF_LEVEL)`, plus the level-up step
    (`add_level_difficulty`). Still drives `make_enemy`'s hp/speed/dmg scaling
    and the HUD difficulty bar; still synced to clients via `net_difficulty`.
  - Net effect: `difficulty >= pace` always; the gap is exactly the
    "ahead-of-par" bonus that makes monsters tougher without also escalating
    variety/population.
- Updated `ENEMY_DESIGN.md`'s difficulty/heat section (also fixed stale
  `_class_tier`/`_make_enemy`/`ENEMY_CLASSES`-style references left over from
  the EnemySpawner extraction).
- Verified headless: import, 300/900/1800-frame weapon/fusion runs, zoo, bomber,
  and a 4000-frame solo run (covers most of a 9-min run) — all clean.
- **Next session:** playtest whether pace's variety/population schedule still
  feels right now that it's decoupled from heat; M7.

### 2026-06-14 — Session 2 (continued): heat exponential spike + boss class
- User: when the player nearly clears the map (mid-game+), heat should spike
  exponentially; add a hard "boss" enemy class spawned after X kills, with
  multiple variations, each hard to kill via a mechanic (not just hp), with
  map-wide/pattern attacks.
- **Heat spike** (`EnemySpawner.heat_spike`, host-only): once `elapsed >=
  MID_GAME_TIME` (5:00), if live enemy count < `HEAT_SPIKE_POP_FRAC` (20%) of
  `desired_pop`, `heat_spike` compounds exponentially
  (`(heat_spike+dt)*(1+HEAT_SPIKE_GROWTH*dt)`, capped `HEAT_SPIKE_MAX=5`) and
  feeds an extra `+ heat_spike * DIFF_SPIKE` term into the `difficulty` climb;
  decays linearly (`HEAT_SPIKE_DECAY`) once the population recovers. New
  consts in `GameConfig`.
- **Boss class** (`EnemyConfig.CLASSES.boss`, 3 tiers): `EnemySpawner.add_kill`
  tracks `total_kills`; at `BOSS_KILL_BASE` (60) and then every
  `BOSS_KILL_INTERVAL` (90) kills, `spawn_boss()` spawns one, tier = boss count
  so far (capped). Each tier is hard to kill via a distinct mechanic, not just
  hp: Juggernaut (`shield_cycle`/`shield_time` + `cc_imm`), Harbinger
  (`immune_cycle`/`immune_pool` rotates elemental immunity), Eclipse
  (`enrage_resist` ramps armor as hp drops + `summon_cls`/`summon_count`/
  `summon_cooldown` calls in adds). All `elite`+`pull_imm`, drawn with an extra
  crimson ring.
- New `Enemy.slam_pattern`/`slam_radius`/`slam_damage`/`slam_cooldown` —
  independent of `caster`, so bosses chase normally while periodically firing
  a map-wide/pattern attack via `cast_telegraph` in `_do_slam()`: pattern 3
  (checkerboard grid centered on self) and pattern 4 (rotating sweep radiating
  from the target, advancing 60°/cast).
- Updated `ENEMY_DESIGN.md` with a new "Bosses" section + heat-spike
  description + tier-field table additions.
- Verified headless: import, plain 300-frame run, zoo (300 and 1800, spawns
  all 3 boss tiers via `spawner.types`), bomber, host+join pair — all clean.
- **Next session:** playtest boss encounters live (kill-count pacing, slam
  telegraph fairness/readability, heat-spike feel near map-clears); M7.

### 2026-06-14 — Session 2 (continued): caster uniform tier + bouncer special population
- User: caster-type enemies should always pick their spawn tier uniformly
  (not skewed toward the ceiling); make bouncer a special population — once
  unlocked it's excluded from the normal pool and gets its own cap that keeps
  growing with game progress.
- `EnemySpawner.class_tier`: classes whose tier-0 dict sets `uniform_tier:
  true` now pick `randi() % (ceiling + 1)` — every unlocked tier equally
  likely — instead of the geometric step-down that heavily favors the
  ceiling. Marked `"caster"` (Bomber/Diviner/Oracle) in `EnemyConfig.CLASSES`.
- Bouncer removed from `EnemyConfig.SPAWN_POOL` entirely. New
  `EnemySpawner.bouncer_live`/`bouncer_accum`: once `elapsed >=
  BOUNCER_UNLOCK` (2:45), `run_spawning` tops bouncers up to
  `BOUNCER_CAP_BASE + pace * BOUNCER_CAP_PER_PACE` (grows with pace, never
  shrinks/accelerates) every `BOUNCER_SPAWN_INTERVAL` (2s).
  `spawn_enemy`/`_on_enemy_killed` track `bouncer_live`; new
  `_pool_count() = enemies_by_id.size() - bouncer_live` is used everywhere
  `desired_pop`/`overwhelmed`/heat-spike previously read the raw live count,
  so the bouncer population never crowds out or distorts the normal pool's
  pacing. New `GameConfig.BOUNCER_*` consts.
- Updated `ENEMY_DESIGN.md`: spawn-cadence section notes `uniform_tier` and the
  bouncer exclusion; new "Bouncer: a separate population" section.
- Verified headless: import, plain 300-frame run, zoo, bomber, a 10000-frame
  solo run (crosses BOUNCER_UNLOCK and the first boss kill-threshold), and a
  host+join pair — all clean.

### 2026-06-14 — Session 3: sync master with publish, merge origin/publish perf work
- User: squash the full dev history (`master`, 33 commits) onto a branch off
  `publish`, since `master` and `origin/publish` had completely diverged (no
  common ancestor). Chose "master's tree only, parent = publish HEAD": new
  branch `sync-from-master` off `publish` (b68e835), single commit `2a114ea`
  whose tree is identical to master's.
- User: then merge `origin/publish` (a8c649c — perf/CI work unique to that
  branch: shared `EnemyGrid` spatial index in `main.gd`/`Main.instance`,
  "safe spawn radius" + newborn-enemy ease-in, no enemy-enemy collision,
  `SPAWN_RING_MIN/MAX`/`SPAWN_SAFE_RADIUS` consts, GH Actions build workflow,
  PERFORMANCE.md) into `sync-from-master`. Resolved 19 conflicts across 10
  files, consistently preferring master's existing equivalents where one
  existed (master's own `EnemyGrid` spatial index in `scripts/enemies/
  enemy_grid.gd` for projectile/mine/turret/fusion queries, event-driven mine
  arming, per-blade Pulsar fusion design) while keeping origin/publish's
  unique additions that auto-merged cleanly (ease-in, safe-spawn ported into
  `EnemySpawner._enemy_spawn_pos`, the `Main.instance` grid API still used by
  ~25 weapon/player call sites, CI workflow, docs). Both spatial-index systems
  now coexist (redundant but correct) — left as-is rather than unifying.
- Fixed a resulting GDScript type-inference compile error in
  `EnemySpawner._enemy_spawn_pos` (needed explicit `Node2D`/`Vector2`
  annotations since `main` is typed `Node`).
- **Gotcha discovered**: headless smoke tests run via `/mnt/c/.../godot.exe`
  from WSL bash don't see `NICESWARM_NET`/`NICESWARM_TEST` unless `WSLENV`
  lists them (e.g. `WSLENV=NICESWARM_NET:NICESWARM_TEST NICESWARM_TEST=...
  godot.exe ...`) — otherwise the run silently falls back to plain
  menu-idle (still "banner only, zero errors", so it looks like a pass).
  All smoke-test commands in this file/CLAUDE.md need this prefix on this
  machine.
- Re-verified with `WSLENV` fix: import, plain/all_weapons/zoo/bomber/merge
  all print their `[test]` lines and exit clean; host+join pair prints
  `start_game` on both sides + `first enemy puppet` on the client. Noted a
  flaky (pre-existing, ~1/3 runs, present on master too) "ObjectDB instances
  leaked at exit" warning on `all_weapons`/`bomber` — harmless `--quit-after`
  timing artifact, not a regression.
- Merge committed as `b29836a` on `sync-from-master`.

### 2026-06-15 — Session 4: CI now builds & publishes a debug exe
- User: add a debug executable to CI and release it. Worked in worktree
  `ci-debug-exe` (branch `worktree-ci-debug-exe`).
- `.github/workflows/build-windows.yml`: added an `--export-debug` pass that
  produces `NiceSwarm-debug.exe` + a `NiceSwarm-debug.exe.sha256` sidecar,
  using the same `Start-Process -Wait -RedirectStandard*` pattern as the
  release export (a bare `godot ...` detaches/races silently — see the
  workflow comments). The debug exe + sidecar are attached to the upload
  artifact, the rolling `latest` prerelease, and `v*` releases.
- Why a debug exe: it ships verbose error reporting + stack traces and
  `OS.is_debug_build()` is already the gate for the in-game F1 debug panel,
  so playtesters running it get actionable diagnostics.
- Bug avoided: `update_check.gd` hashed the running exe against the hardcoded
  release `NiceSwarm.exe.sha256`, so a debug exe would forever mismatch and
  nag about a non-existent update. Split into `SHA_URL_RELEASE`/`SHA_URL_DEBUG`
  and pick by `OS.is_debug_build()` inside `check()` (reached only after the
  `has_feature("template")` guard, so the flag reliably means debug template).
- `main.gd` menu subtitle appends ` · debug` when
  `OS.has_feature("template") and OS.is_debug_build()` (template-gated so the
  editor isn't tagged) — so bug reports name the right build.
- Verified locally: `--export-debug` produces a 102 MB `NiceSwarm-debug.exe`
  (debug template present); `[tests] 966 passed, 0 failed`; headless smoke =
  banner only. Updated CLAUDE.md "Running" with the CI dual-exe note.
- **Next:** merge `worktree-ci-debug-exe` → `publish` to trigger the release
  (push to `publish` is what publishes the rolling `latest` build).

### 2026-06-16 — Session 5: weapon progression revamp + fusion depth cap (worktree `revamp-weapon-progression`)
- User: "revamp weapon level progression and fusion weapon capped." Clarified to two
  changes (worktree off `publish`):
  1. **Party-level weapon scaling (augment).** Every weapon's base damage now scales
     with the shared party level, *on top of* its own Lv1→3 growth and Power picks.
     Implemented with zero weapon edits: `player.gd` keeps the pick-driven factor in a
     new `power_stat`, and `_physics_process` derives `damage_mult = power_stat *
     (1 + GameConfig.WEAPON_LEVEL_POWER*(Main.instance.level-1))` at the top (before any
     early-return, so bots/puppets stay current; parent-before-children tree order means
     weapon kids read the fresh value the same frame). `st_power` pick now mutates
     `power_stat`; debug reset resets it. New const `WEAPON_LEVEL_POWER := 0.04`.
  2. **Fusion depth cap (T1→T2 final, no T3).** New `WeaponBase.tier` (base=0); merging
     tiers a,b yields `max(a,b)+1`, allowed only while ≤ `GameConfig.MAX_FUSION_TIER` (=2).
     Single source of truth `Fusions.can_merge`/`merged_tier`, enforced in BOTH the pick
     pool (`main._build_choice_pool` skips over-cap pairs) and the model
     (`player.merge_weapons` refuses + stamps the result's tier). So base+base→T1,
     T1+T1→T2 (final), and a T2 fusion is never offered/allowed to merge again.
- **Tests:** +2 config asserts (`MAX_FUSION_TIER`, `WEAPON_LEVEL_POWER`) and +9
  `Fusions.can_merge`/`merged_tier` asserts → `[tests] 1025 passed, 0 failed`.
- **Verified headless** (Scoop godot 4.6.3): import clean; unit suite 1025/0; solo / merge
  (→ Plasma Burst T1, pool builds) / all_weapons / all_fusions all clean (only the
  pre-existing benign "ObjectDB leaked at exit" --quit-after artifact). **Balance:** FF
  (immortal) wins at 10:00 with difficulty climbing smoothly 0.1→~14.8 (no heat/difficulty
  runaway); a same-machine baseline worktree off `publish` showed the identical difficulty
  trajectory (peak 14.4) and SIM bots DEAD at L1 on BOTH branches — confirming the change is
  a no-op at L1 and balance-neutral in these harnesses (the SIM L1 deaths are a pre-existing
  harness artifact, not a regression).
- **Next:** real playtest to tune `WEAPON_LEVEL_POWER` (0.04 is FF-calibrated, not
  hand-played) and confirm the T2 cap feels right; then merge → `publish`.

### 2026-06-16 — Session 5 (continued): hard-difficulty pass + FF lethality probe (target win <10%)
- User: the game is too easy (esp. after the weapon revamp); recalibrate toward a
  **skilled-player win rate <10%**; look back at the old, harder enemy design. Then
  steered specific knobs live (spawn rate, half XP, cap 300, ×5 spawn, spawn ring).
- **Key diagnosis (new instrument):** the kiting **bot sweep is saturated** — every build
  dies in the mid-game (~3-4 min, L9), so it's blind to the level-20-45 late game where a
  skilled human lives. Built a **lethality probe**: `NICESWARM_SIM=...,god=1` runs the bot
  **immortal** to 10:00 and `player.lethal_taken` tallies the would-be (i-frame-respected)
  damage; per-minute `[ff] lethal/min` is the incoming-DPS-to-a-5HP-player curve. It showed
  the real "too easy": **late-game incoming damage was 0** — once a build comes online the
  player out-runs/out-DPSes the capped swarm (a free snowball). Count/XP levers alone can't
  reach it (more enemies → more XP → more DPS → untouchable again).
- **Changes (GameConfig unless noted):** density — `ENEMY_CAP` 220→300, spawn interval ×5
  (`SPAWN_INTERVAL_START/_END` →0.2/0.024) **ramped over `DIFF_WARMUP_SECS` 80→130** so the
  opening is survivable, `SPAWN_DESIRED_*` up, `SPAWN_RING_MIN/_MAX` 300/1200,
  `SPAWN_SAFE_RADIUS` 500→250. Late-game lethality — `DIFF_BASE` 1/62→1/45, new
  `ENEMY_SPEED_DIFF_SCALE` 0.025 + `ENEMY_HP_DIFF_SCALE` 0.04 in `spawner.make_enemy` (late
  enemies catch + survive a kiter), contact dmg `diff/12→diff/7`, `MAX_TELEGRAPHS` 6→9.
  Player power-curve — `XP_GAIN_MULT` 0.5 (half leveling, applied at `_xp_needed`),
  `WEAPON_LEVEL_POWER` 0.04→0.025.
- **Result:** lethality curve went from `…6:149 7:0 8:0 9:0` (free late snowball) to a
  sustained `2:191 3:1038 4:1214 5:661 6:214 7:139 8:145 9:103` — brutal mid wall, **no free
  late game**. Mortal-bot win 3%→0% (dies in the min3-4 wall). The 130s warmup was the fix
  for an instant-death overshoot (×5 flood on a L1 player → die at 40s).
- **Verified:** `[tests] 1026 passed, 0 failed`; solo/merge/all_weapons smoke clean. Doc:
  new "Hard-difficulty pass" section in [docs/balance/SOLO_BALANCE_SIM.md].
- **Caveat / next:** no automated proxy measures a *skilled* player's win rate — the final
  <10% is a **playtest call**. The probe over-counts dodgeable AoE, so trust relative change.
  Knobs to tune live are listed in the balance doc. Late-game perf at 300 enemies wants a
  real check. Open as PR off `revamp-weapon-progression`.

### 2026-06-16 — Session 6: DPS-responsive boss HP + level-scaled enemy HP + CC-immune tough enemies (branch `feat/boss-dps-hp`)
- User (live-steered, off `publish`): boss HP should scale by party level, player count, and
  the **last-15s average DPS**; base enemy HP should also scale by player level; bosses + tier-3
  enemies should be immune to pushback (knockback) and suck-in (gravity).
- **DPS-responsive boss HP:** new pure `GameConfig.boss_hp(tier_floor, recent_dps, level, players)
  = max(hp0, recent_dps·BOSS_FIGHT_SECONDS) · (1+BOSS_HP_PER_LEVEL·(lvl-1)) · (1+BOSS_HP_PER_PLAYER·
  (N-1))`. Host tracks party DPS in `spawner` as a 15×1s ring (`add_damage_sample` from
  `main.add_damage`, advanced in `update_difficulty`); `make_enemy` sizes bosses from it. Floor is
  the **static** `hp0` (not the difficulty curve) so the three named factors actually drive it.
  Verified (god-bot sim): boss hp tracks rdps — rises 1397→5633 as rdps 146→413 and *drops* when
  DPS dips, with `hp0` floor protecting low-DPS spawns. `[boss]` log prints under sim/FF.
- **Base enemy HP per level:** `ENEMY_HP_PER_LEVEL=0.02` → base enemies ×(1+0.02·(lvl-1)) on top of
  party-size + difficulty scaling (≈×1.9 by L48).
- **CC-immune tough enemies:** new `Enemy.knockback_immune` (pushback only — still slowable, unlike
  `cc_immune`); `make_enemy` sets `knockback_immune`+`pull_immune` for bosses and tier ≥
  `CC_IMMUNE_TIER` (=2, the 3rd tier). `apply_push` now also checks it.
- **Verified:** `[tests] 1034 passed, 0 failed` (+8 boss_hp/const asserts); zoo (34 types incl
  tier-3 + bosses) + god-bot sim clean, no errors. Host-authoritative (enemy hp isn't synced, so
  client boss bars stay cosmetic — same as all enemies). All knobs tunable in `GameConfig`.
- **Caveat:** `ENEMY_HP_PER_LEVEL` stacks on the already-hard pass — may need easing after playtest.

### 2026-06-16 — Session 6 (continued): big live-tuned balance + co-op + HUD + netcode pass (PR #26)
On `feat/boss-dps-hp` the boss-HP work grew into a 16-commit pass (all on PR #26):
- **Balance (live-tuned):** exponential XP curve (`XP_BASE·XP_GROWTH^(L-1)`, `XP_GROWTH=1.12`,
  replaced the 3-band model); `DIFF_HEAT` 2.4→3.12; `ENEMY_HP_PER_LEVEL` settled at 0.05;
  `ENEMY_CAP` 220; `MAX_TELEGRAPHS` 6, `TELEGRAPH_WARN` 1.5.
- **Progression:** weapon level cap 3→7 before fusion; fusion depth cap 2→3 (T2+T2→T3 final,
  cap-relative test).
- **Enemies/UI:** bombardier telegraph circle no longer lingers on clients after detonation;
  boss/elite banner moved below the difficulty readout.
- **Co-op:** ESC now pauses the whole run for **every** player (host-authoritative
  `set_menu_open`/`menu_open_pids`; resumes with an `alert` cue, no countdown); **same-name
  rejoin** so a brand-new game instance reclaims a ghosted slot by player name
  (`_disconnected_pid_by_name`→`_take_over_slot`, with old-peer-id→name fallback).
- **HUD:** end-game scoreboard + ally list + floating name tags now show real names, the
  character glyph, and the player's colour (ally list is a RichTextLabel); **in-game ping (ms)**
  (host measures ENet RTT → `net_pings`, broadcast 4Hz); a pulsing "grow" ring around each
  player glyph + `z_index=100` so glyph/effect/name always render on top.
- **Netcode:** world-state quantized to a **10-byte record** (`u32 id | s16 x×16 | s16 y×16 |
  u16 f`, was 16-byte 4×f32). Positions ×16 fixed-point (1/16 px, lossless to the eye; clients
  lerp puppets). Client enemy bandwidth for a full 220-field ~361→~235 kbps; max enemies under
  300 kbps ~180→~287. `_put_entity`/`StreamPeerBuffer` encode/decode; verified co-op round-trips
  to exact ×16 positions.
- **Verified:** `[tests] 1052 passed, 0 failed`; solo/zoo/bomber/merge/all_weapons/score +
  co-op host/join smoke all clean. **Docs updated** (GAME_DESIGN §9/§10/§11/controls, CLAUDE.md
  multiplayer model). Design docs reflect the wire format, pause/rejoin model, and HUD.
- **Next:** **2-PC playtest** the co-op menu/pause UX, same-name rejoin reclaim, and HUD
  names/colours/ping/glyph (headless can't render the HUD or orchestrate disconnects). Then
  merge PR #26 → `publish`.

### 2026-06-16 — Session 7: fusion DPS cliff + above-Lv3 fairness pass (on `publish`)
Two reported balance bugs, both rooted in the 3→7 weapon-cap rise not being followed through:
- **Fusion DPS cliff (FIXED):** `player.merge_weapons` created a **signature** fusion via
  `Fusions.make()` but never set its `level` — it was born at the `WeaponBase` default `1`, so its
  `BASE × dm × (1 + growth×(level−1))` growth term collapsed to ×1.0. Fusing two Lv7 weapons
  (~3–4× base each) yielded one ~1× weapon → the "dps decreases significantly, can't keep up"
  cliff. Fix: `sig.level = maxi(a.level, b.level)` → born at Lv7, ~a maxed weapon's damage **plus**
  the fusion's richer multi-hit/AoE. **Signature-path only** — the generic `WeaponFused`/Amalgam
  path stays level 1 on purpose (its shell level drives `level_up()` which grows the retained
  components past 7). Side effect (intended): signature fusions are now **merge-only** (the
  `[LEVEL]` pool gates at `< MAX_WEAPON_LEVEL`), i.e. instantly maxed → fuse again.
- **Above-Lv3 fairness (FIXED 5 weapons):** the cap rise feeds `count_level()` to 7, so weapons
  using it (bolt/orbit/glaive/lightning/mines/missiles/frost/turret) auto-scale counts to Lv7 —
  but five weapons stalled above Lv3 (only flat damage+size). Per user's picks: **Laser** — beams
  were dead-computed (`count_level()` beams all offset by `PI*b` → collapse onto 2 opposite lines);
  now **1→4 evenly-spread beams** (`TAU*b/beams`). **Nova** — echo shockwaves at Lv5/6/7 (1/2/3
  extra pulses). **Gravity** — +1 simultaneous well at Lv4 & Lv6 (up to 3, on distinct foes).
  **Flame** — cone half-angle widens past Lv3. **Venom** — wider toxic carpet (2nd puddle Lv3, 3rd
  Lv6, spread perpendicular to travel). All honor the 4-stat contract.
- **Turret deploy never filled its cap (FIXED):** base turret's `max_turrets` (`count_level()-1`)
  and the fused `_Sentry`'s `_deploy_cap()` (`count_level()+2`) allowed many turrets, but the flat
  deploy cooldown (`base.cd`≈6.5s) ≈ a turret's life, so each expired right as the next deployed —
  **only ~1 alive even at Lv3+** (user report). Fix: deploy cooldown now `cd / cap`, so the field
  fills within one turret lifetime. Verified: forced Lv7 fills **6/6** (was ~1). Same fix on
  `_Sentry`. ⚠ `_Sentry` cap is `count_level()+2` (=9 at a Lv7 fusion) — now reachable; may want a
  lower cap after playtest.
- **75% rule (target met structurally; wells are the margin):** user wants a fused weapon ≥75% of
  its two materials' combined DPS. Born-at-Lv7 makes multi-hit archetypes (bursts/halos/mines/
  sentries/chains/glaive-fans/cones) land comfortably above; the single-instance **well** fusions
  (Singularity/Glacier/BlackBog) sit ~at the margin in the swarm-throughput model. **Proposed
  (not yet applied):** a ~15–20% base-damage bump on those 3, or a sustained-crowd measurement
  harness for exact per-fusion ratios.
- **Stale-doc cleanup:** `weapon_base.count_level()` comment said "Lv3" (now MAX_WEAPON_LEVEL=7);
  glaive docstring "Lv3/Lv5" (grows every level). WEAPON_CODEX.md: new behaviors + signature-vs-
  Amalgam fusion birth-level section.
- **Verified:** `[tests] 1068 passed, 0 failed`; all_weapons at **forced Lv7** (temp scaffold,
  reverted) ran 900 frames exercising every kicker branch with zero errors; merge + plain smoke
  clean.
- **Next:** decide on the well-fusion 75% bump (or measurement harness); playtest the Lv4–7 feel
  of laser/nova/gravity/flame/venom and the born-at-max fusion power.

### 2026-06-17 — Session 13: fusion source split + PLAN refactor (orchestrated)
- **Fusion files:** split the 3288-line `scripts/weapons/weapon_fusions.gd` into one file per fusion
  weapon under `scripts/weapons/fusions/` (80 files: 78 fusions + shared `FusSentryBase`/`FusMineBase`).
  `weapon_fusions.gd` now keeps only the public API (`INFO`/`key`/`info`/`merged_tier`/`can_merge`) and a
  `make()` rewired to the new `class_name Fus*` classes. Done deterministically (no hand-edits).
  Verified: 1103/1103 unit tests (incl. `test_fusions` 78-pair check), clean `--import` (no class_name
  collisions), plain/all_weapons/merge smoke all green.
- **PLAN refactor:** moved the historical session log out of PLAN.md into this file; reconciled the PLAN
  head to live code (level cap 3→7, 78 fusions split into files, fusion depth cap, DPS-responsive bosses,
  UX/tooling milestones M6.22–M6.27, status to v0.9.0).
- **Working mode:** documented the orchestrator + 3-Sonnet-sub-agent model (`ORCHESTRATION.md`, CLAUDE.md),
  with per-agent git-worktree isolation.

### 2026-06-18 — Session 14: branch+count build version, version on launcher, Force Update
- **Build version scheme:** `BuildVersion` (`scripts/config/build_version.gd`) gained `BRANCH` + `COUNT`
  consts alongside `COMMIT`; `commit_label()` replaced by `label()` → `"Publish v. 220"` (branch + commit
  count) and `full_label()` → `"Publish v. 220 (9da5762)"` (sha + `*` dirty marker). The menu footer
  (`game_ui.gd`) now shows `full_label()` only (the 0.9.0 semver is dropped from the in-game display but
  stays in `project.godot`/`export_presets.cfg`/`main.gd VERSION` for exe metadata). Title-casing is
  first-char-only (NOT `String.capitalize()`) so it matches the launcher.
- **Stamping:** `build.ps1` and both CI jobs in `build-windows.yml` now stamp all three consts
  (`rev-parse --short HEAD` / `GITHUB_REF_NAME` / `rev-list --count HEAD`). **Critical:** added
  `fetch-depth: 0` to every CI checkout (all four, across build-windows + build-launcher) — a shallow
  clone makes `rev-list --count` return 1, which would have shipped "Publish v. 1".
- **Launcher (Go):** shows BOTH its own build version (stamped via `-ldflags -X main.verBranch/verCount`
  in `build-launcher.yml`; `version.go`) under the title AND the published game version, fetched from a
  new plain-text `VERSION.txt` asset CI publishes next to the binaries (`release.GameVersionURL()` +
  `download.FetchText()`). Added a **Force Update** button: `checkAndUpdate(debug, force)` skips the
  "already current" short-circuit to re-download + reinstall the latest build.
- **Verified:** `[tests] 1112 passed, 0 failed` (incl. new `test_build_version.gd`); 300-frame smoke
  clean; stamp simulation confirmed end-to-end `LABEL=Publish v. 220` / `FULL=Publish v. 220 (9da5762)`;
  launcher `go vet`/`go test ./internal/...`/`go build` all green (new `FetchText` + `GameVersionURL`
  tests). build_version.gd restored to `dev` defaults after the probe.
- **Next:** push to `publish` so CI publishes the first `VERSION.txt` (launcher game-version line stays
  blank until then); manually dispatch `build-launcher.yml` to ship a version-stamped launcher.

### 2026-06-18 — Session 15: async level-up UX, config refactor, Noray NAT lobby
- **Async level-up UX** (commit `ab22a6a`): non-modal bottom-right panel that auto-opens while a player has
  banked upgrade credits, instead of a screen-blocking centered dialog; fixed the chest pickup pausing/opening
  the dialog for all players (now host-authoritative credit banking). Plus config tweaks (MAX_WEAPONS 5→4,
  STAT_CAP_DURATION 2.5→2.0, MAX_TELEGRAPHS 7→5) + a `NICESWARM_DMGTABLE` per-weapon damage/min sim hook.
- **Config refactor** (commit `3f0105a`): moved all 13 base-weapon tuning literals into `WeaponConfig.BASE`
  (spatial/lifetime params alongside dmg/growth/cd); each `weapon_*.gd` now reads `cfg.*`. Fusion params were
  already config-driven. cfg-derived locals need explicit `: float`/`: int` (cfg is Variant, breaks `:=`).
- **Noray NAT lobby** (commit `2c0f2d4`, milestone **M7.6**): online co-op without port-forwarding. Vendored the
  proven `netfox.noray` client (`addons/netfox.noray/` — `noray.gd`/`packet-handshake.gd`/`protocol-handler.gd`
  + a `NetfoxLogger` stub so no netfox rollback core is needed; autoloads `Noray`+`PacketHandshake`). All async
  flow in one file `scripts/core/noray_lobby.gd` (`NorayLobby`): bootstrap → host (ENet server bound to
  `Noray.local_port`, punch on incoming connect) / client (handshake over local_port → `create_client` reusing
  it). `net.gd` got thin `host_via_noray`/`join_via_noray` delegators (direct IP/Port untouched as fallback);
  `main.gd`/`game_ui.gd` got an OID-join-code menu + `NICESWARM_NET=noray_host`/`noray_join` headless hooks.
  Full plan + the CGNAT inbound blocker in [docs/NORAY.md](NORAY.md).
- **Verified:** 1112 unit tests pass; headless import/boot clean. **Live rendezvous PASS** — ran
  `ghcr.io/foxssake/noray:main` (throwaway `--rm`) on docker-server `192.168.1.36`; two headless instances
  connected by OID through the relay (`start_game peers=[1, <id>]` both sides, joiner received world-state +
  enemy puppets), proving the ENet socket-reuse handoff. Throwaway container removed.
- **Known follow-up (pre-existing, not Noray):** a peer that leaves mid-run lingers in `peer_ids` but drops from
  `multiplayer.get_peers()`, so `_refresh_pings()` → `get_peer(ghosted_id)` logs `!peers.has(p_id)` (cosmetic
  ping HUD). Cheap fix: intersect before `get_peer`. Affects direct-IP co-op too.
- **Next:** persistent Noray server deploy (compose + `.env` + healthcheck) on docker-server; resolve the public
  inbound/CGNAT question (read the home router WAN IP → bridge ONT vs. public VPS) before `ns.javis.coffee` can
  serve real internet players; wire the OID join code into the launcher / add copy-to-clipboard in the lobby UI.

### 2026-06-18 — Session 13: Noray server deployed, security-reviewed, swapped to hardened fork
- **Persistent deploy:** Noray now runs as a standing stack on docker-server (`~/noray/`, LAN, healthy), not a
  throwaway `--rm`. Game reaches it via `NICESWARM_NORAY_HOST=192.168.1.36`.
- **Security review** (blackbox + whitebox; report in infra repo `network/noray-security-review.md`): **no RCE**.
  Found a process-killing crash (any relay crossing a bandwidth/lifetime/traffic cap threw uncaught → the whole
  server exited, dropping all sessions — reproduced live), a dynamic-relay pool-exhaustion crash, unbounded
  `register-host`, and metrics exposed on `0.0.0.0:8891`.
- **Hardened private fork** ([github.com/chawasit/noray](https://github.com/chawasit/noray), `upstream` =
  foxssake/noray): relay drops instead of crashing (DoS-1, proven live on the built image), dynamic-relay
  exhaustion guard + per-connection host cap & command rate limit (DoS-2/3), metrics bound to container loopback
  + `8891` un-published (IL-2). Published to **private GHCR** `ghcr.io/chawasit/noray:trirat`; live `~/noray/`
  compose pulls it (self-healing). Relay caps tuned generous for co-op (1mb/s · 24hr · 64gb). 147/147 unit tests
  (added DoS-1 + limits regression tests); relay forwarding re-proven end-to-end on the fork image.
- **Client compat:** game side is wire-compatible (fork is server-only hardening); our ~2-cmd/1-host handshake is
  far under the new limits. See `docs/NORAY.md` for the contract + the fork's `FORK.md`.
- **Still open (owner):** raise `NORAY_OID_LENGTH` from 6 before any internet exposure (rate-limit ≠ anti-enumeration);
  public-inbound CGNAT decision; e2e suite + full Godot rendezvous not re-run against the fork (named residual).
- **Next:** OID length decision; CGNAT bridge-vs-VPS; wire OID join code into launcher + copy-to-clipboard.

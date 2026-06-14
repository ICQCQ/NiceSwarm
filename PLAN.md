# NiceSwarm — Project Plan & Progress Tracker

> **This file is the source of truth for project status.** Read it at the start of
> every session; update the checkboxes and Session Log before ending one.

## Vision

A top-down 2D arena survival roguelike (Vampire Survivors-like) built in **Godot 4**
(pure GDScript, code-built scenes, drawn shapes — no art assets required).
You move; your weapon fires itself at the nearest enemy. Swarms grow relentlessly.
Collect XP, level up, pick 1 of 3 upgrades, and survive **10 minutes** to win.

## Design summary

- **Controls:** WASD/arrows move · SPACE/SHIFT dash · ESC pause (host) / leave to menu (client) · 1–6 pick upgrades · **M main menu** (from pause/game-over) · R restart (game-over, host)
- **Run config (menu):** host sets **options per level-up** (2/3/4), **XP rate** (0.5–2×), and
  **enemy scale** (0.75–1.5×) before starting; broadcast to all peers.
- **Start of run:** each player picks **1 of 3** random starting weapons.
- **Fusion bias:** whenever a merge is available it is *guaranteed* a slot in your choices.
- **Upgrade picks are color-coded by type:** green `[NEW]` · blue `[Lv]` · gold `[FUSE]` (new
  weapon) · orange `[AMALGAM]` (combined) · pale `[STAT]`.
- **Enemy classes & tiers** (full catalogue in [ENEMY_DESIGN.md](ENEMY_DESIGN.md)): archetype
  *classes*, each with tiers that are direct upgrades. Higher tiers spawn over time and faster when ahead of par.
  - *Brawler*: Grunt → Bruiser → Reaver · *Rusher*: Runner → Sprinter · *Tank*: Brute → Behemoth
  - *Caster* (telegraphed, synced so co-op can dodge): **Bomber** (leads you) → **Diviner** (line ahead
    of your path) → **Oracle** (ring around you)
  - *Warden*: Shieldling → Bulwark — armored, shrugs off 40–55% of every hit, pull-immune
  - *Splitter*: Spore → Brood — bursts into a cluster of grunts on death
  - *Sentinel*: Sentinel → Aegis — phases an invulnerable shield on/off; strike between phases
  - *Wisp*: Mote → Wisp — fast, **immune to ENERGY** damage (counters energy builds)
  - *Disruptor*: Hexer → Nullifier — telegraphs zones that don't hurt but **slow + dash-lock** you
  - *Elite* (always drops a chest): Elite → Champion
  - Add a class or tier in `EnemyConfig.CLASSES`; network ids are assigned automatically.
- **Damage types** (PHYS/FIRE/ICE/ENERGY): weapons tag hits; immune enemies take zero of their type.
- **Dynamic difficulty from clear rate:** `EnemySpawner.heat()` = how fast you clear vs spawn pressure
  — clear fast and the game escalates faster (more elites, higher tiers, +HP/speed). Synced to clients.
- **Player:** 5 HP, brief invulnerability after a hit, starts with the Bolt weapon
- **Upgrade picks are categorized:** `[NEW]` learn a weapon · `[Lv n]` level an owned one ·
  `[MERGE]` fuse two maxed weapons · `[STAT]` passive boost
- **Generalized stats (VS-style axes — EVERY weapon honors ALL four; see [WEAPON_DESIGN.md](WEAPON_DESIGN.md)):**
  Power (+25% damage) · Haste (+14% cadence — cooldowns, ticks, spin/sweep, re-hit) · Area (+20%
  every spatial dim — radii, reach, beams, orbit, projectile size, targeting range, chain jump) ·
  Duration (+25% lifetime; instant weapons gain a lingering **burn** via `ignite()` whose length
  scales with Duration). Enemy now supports `apply_burn` alongside `apply_slow`. Plus Swift Boots /
  Vitality / Magnet / Slipstream (player stats). Weapons read the multipliers live, so fused parts scale too.
- **Fusions are distinct new weapons** (not the two running together) — **78 signature recipes
  (every weapon-pair combination)**. Recipes in `weapon_fusions.gd`; full list and coverage
  matrix in [WEAPON_DESIGN.md](WEAPON_DESIGN.md).
- **Dynamic difficulty:** a `heat()` value rises as the party level outpaces par-for-time. When
  ahead, elites and bombardiers spawn more often, normal spawns can upgrade to special enemies, and
  all enemies get a mild HP/speed bonus. A HUD "Threat ▮▮▮▮" meter shows the current pressure.
- **Weapon level cap is 3** (was 5) so fusion is reached fast; per-level damage growth ~doubled to
  keep the ceiling. Thresholds rescaled: glaive extra glaives at Lv2/3, laser 2nd beam at Lv3,
  turret 2nd turret at Lv3.
- **Pause menu shows the arsenal:** your current loadout (incl. fusion names + levels) and all 13
  base weapons with owned-level / `fused` / `—` status.
- **Weapon fusion:** any two level-5 attacks can merge into ONE slot (removes 2, adds 1 — frees a
  slot). The fused weapon's parts keep firing and **level together** (`[Lv n]` on a fusion bumps
  every component); fusions are themselves level-5-mergeable, so deeper layers stack. `WeaponBase`
  + `WeaponFused` container; components are re-parented, not re-created.
- **Weapons** (each levels 1→5; level-ups offer learning new ones or leveling owned ones; **max 5 per run** so picks form a build):
  - *Bolt*: auto-fires at nearest enemy; level = projectile count
  - *Orbit Blades*: blades circle the player; level = blade count − 1
  - *Nova Pulse*: periodic AoE blast; level = radius + damage
  - *Boomerang Glaive*: pierces out and returns; extra glaives at Lv3/5
  - *Chain Lightning*: instant zap arcing to 2+level enemies
  - *Flame Cone*: rapid-tick cone in facing direction
  - *Proximity Mines*: up to 3+level armed mines, AoE blast
  - *Homing Missiles*: 1+level seeking rockets with splash
  - *Sweep Laser*: rotating beam; 2nd beam at Lv4
  - *Frost Shards*: 2+level piercing shards that slow 50% for 1.5 s
  - *Gravity Well*: vortex pulls the swarm together + tick damage
  - *Sentry Turret*: deployed shooter, 2 at once from Lv3
  - *Venom Trail*: toxic puddles dropped while moving
- **Enemies:** spawn in a ring off-screen, scale with elapsed time
  - *Grunt* (red): baseline chaser
  - *Runner* (orange, from 1:00): fast, fragile
  - *Brute* (purple, every 45 s after 1:30): big, slow, 2 contact damage, 70% pickup drop
  - *Elite* (gold-ringed, every 75 s after 2:00): tanky mini-boss, always drops a chest
- **Pickups:** heart (heal 2) · bomb (blast everything on screen) · magnet (vacuum all gems) · chest (free upgrade pick)
- **Stat upgrades:** +25% damage · 12% faster firing · +12% speed · Vitality (+1 max HP, heal 2) · +50% pickup range · −20% dash cooldown
- **Juice:** damage numbers, knockback, kill pops, screen shake on hit/bomb
- **Audio:** every weapon, pickup, dash, hit, level-up, and merge has a distinct procedurally
  synthesized sound (`scripts/sfx.gd`, `Sfx` autoload — no asset files; positional 2D + throttled).
- **Co-op (online/LAN, up to 4):** host-authoritative. Host menu sets a custom **port**. Shared XP & party level; level-up pauses
  for everyone and waits until *all* players pick (each their own upgrade, separate HP/builds).
  Downed at 0 HP → ally stands close 3 s to revive at half HP; run ends when all are down.
  Elite chests give *every* player a free pick. Enemies scale with party size and target the
  nearest living player. Ally HP/downed on HUD + off-screen ally arrows + name tags/colors.
- **Win:** survive 10:00 · **Lose:** whole party downed · **end-game scoreboard** (per player:
  damage / XP / revives / deaths, ranked by damage) + restart (host)

## Milestones

- [x] **M0 — Project setup**: Godot 4.6 installed (via Scoop), project scaffold, git repo, plan docs
- [x] **M1 — Core movement**: player moves, camera follows, arena bounds, grid background
- [x] **M2 — Enemies**: time-scaled spawner, chase AI, contact damage, player HP + i-frames, death
- [x] **M3 — Combat**: auto-targeting weapon, projectiles, enemy HP/death, hit flash
- [x] **M4 — Progression**: XP gems with magnet, level curve, pause-and-pick upgrade UI (6 upgrades)
- [x] **M5 — First playable**: HUD (HP/XP/timer/level/kills), pause, win at 10:00, game over, restart
- [x] **M6 — Variety & engagement** (was: playtest & balance): playtest verdict was "too straightforward, not engaging" → added dash, weapon system (Bolt/Orbit/Nova ×5 levels), elites + chests, pickups (heart/bomb/magnet), damage numbers, knockback, kill pops, screen shake
- [x] **M6.5 — Arsenal expansion**: 10 new weapons with distinct mechanics (glaive, lightning, flame, mines, missiles, laser, frost, gravity, turret, venom), 5-weapon run cap, enemy slow support, owned-weapons HUD, `NICESWARM_TEST=all_weapons` smoke-test hook
- [x] **M6.7 — Online co-op v1**: main menu (Solo/Host/Join), ENet host-authoritative sync (chunked enemy/gem/pickup snapshots, player state at 20 Hz), shared XP + wait-for-all picks, downed/revive, team chests, ally HUD + off-screen arrows, party-scaled difficulty, in-place restart that keeps the connection
- [x] **M6.8 — Fusion, audio & custom port**: `WeaponBase`/`WeaponFused` so two level-5 attacks merge into one slot (parts keep firing + level together, fusions re-mergeable for deeper layers); categorized upgrade picks (`[NEW]/[Lv]/[MERGE]/[STAT]`); full procedural SFX (`sfx.gd`, `Sfx` autoload — distinct sound per weapon/pickup/dash/hit/levelup/merge, no assets); host menu custom port field
- [x] **M6.9 — Generalized stats, level cap 3, pause arsenal**: replaced single damage stat with Power/Haste/Area/Duration axes (added `area_mult`/`duration_mult`, every weapon reads them); weapon max level 5→3 with doubled per-level damage growth + rescaled thresholds; pause menu lists full 13-weapon arsenal + loadout
- [x] **M6.10 — Universal stats + distinct fusions + design guide**: every weapon now honors all 4 stats (added burn DoT `ignite()`/`apply_burn` as the universal Duration hook for instant weapons; wired Area into turret range/mine trigger/etc., Haste into orbit/laser spin & re-hit); 7 signature fusion weapons that are genuinely new (`weapon_fusions.gd`); wrote [WEAPON_DESIGN.md](WEAPON_DESIGN.md) codifying the contract + full recipe list
- [x] **M6.11 — Starter pick, color-coded picks, FUSE/AMALGAM split, Bombardier**: pick 1-of-3 starting weapons (host-broadcast, wait-for-all); option buttons tinted by category; signature fusion `[FUSE]` vs generic `[AMALGAM]` keywords/colors; new Bombardier enemy with a synced telegraphed AoE you must dodge (4th world-state channel `STATE_TELEGRAPHS`, `telegraph.gd`)
- [x] **M6.12 — Dynamic difficulty + 6 more fusions**: `_heat()` rubber-banding (ahead-of-par → faster elites/bombers, special-enemy upgrades, +HP/speed, Threat HUD meter); 6 new signature fusions (Railgun, Supernova, Frost Halo, Glacier, Storm Disc, Napalm Mine) → 13 total
- [x] **M6.13 — Run config, fusion bias, Diviner**: menu sets options/level-up + XP rate + enemy scale (broadcast); merge options are guaranteed a slot when available; new Diviner enemy paints a predictive line of telegraphs ahead of the player, spawning more as level rises
- [x] **M6.14 — Enemy class/tier system + heat fix**: enemies refactored into archetype classes with upgrade tiers (`ENEMY_CLASSES`, auto-assigned network ids); Bomber/Diviner are Caster tier 0/1, added tier 2 Oracle (ring attack); tier rises with time/level/heat; recalibrated `_heat()` (par=1+t/24, /4) so being ahead registers, moved the Threat HUD off the timer
- [x] **M6.15 — Enemy catalogue, threatening Bomber, more variety**: wrote [ENEMY_DESIGN.md](ENEMY_DESIGN.md); Bomber now leads your movement + faster data-driven cadence (`cdt`) + bigger radius; 2 new classes (Warden = armored `resist`, Splitter = death-burst) and Oracle damage bump
- [x] **M6.16 — Clear-rate heat, damage immunities, disruptor/sentinel/wisp, gravity nerf, +3 fusions**: gravity well pulls each enemy once (+`pull_imm`); damage types (PHYS/FIRE/ICE/ENERGY) + per-enemy immunity; heat now measures clear rate (synced); new classes Sentinel (phasing shield), Wisp (energy-immune), Disruptor (slows+dash-locks); 16 fusions total (Cluster Warhead, Black Bog, Toxic Halo)
- [x] **M6.17 — Master Difficulty number, gravity pull-resist, gradual heat, Defiler, dynamic picks**: up to 6 upgrade options (dynamic 1–6 keys); gravity restored to gradual pull with per-enemy resistance that builds up; **Difficulty** master scalar (HUD number+bar) drives enemy tier/HP/damage, accelerated by heat *and* level; heat now decays gradually; new Defiler enemy (lingering ground disrupt fields); Bomber unpredictability scales with difficulty
- [x] **M6.18 — Movement variety, distinct shapes, Bouncer, Burster→bullets, +3 fusions**: enemy `move` modes (chase/wander/bounce/straight) so not everything chases — Wisps wander, new Bouncer ricochets/phases/can't-be-interrupted; per-class silhouettes (`shape`); Splitter reworked into Burster that spits shard bullets on death (new Shard type); 19 fusions (Pulsar, Frost Lance, Plague Arc)
- [x] **M6.19 — Difficulty/spawn tuning, indestructible shards, Windows build**: faster difficulty climb + level-ups add to it directly + low-population spawn ramp (enemies keep pace late); heat decays slower; Bomber/Disruptor casts always jittered (+2nd strike); Burster shards now indestructible (dodge-only); **Windows export build** (`build.ps1` → `build/NiceSwarm.exe`)
- [x] **M6.20 — Renamed to NiceSwarm, early-game brake, tier distribution, overwhelmed relief, +3 fusions**: full rename (incl. `NICESWARM_*` test env); difficulty climb + level-step scaled by an early-game `_warmup` (gentle opening); `_class_tier` now samples below a difficulty ceiling so higher ranks get common but low ranks still spawn; heat bleeds off fast when overwhelmed (relief); 22 fusions (Tesla Halo, Plasma Storm, Cyclone); rebuilt `build/NiceSwarm.exe`
- [x] **M6.21 — All planned fusions + 3 new, softer difficulty/level scaling**: implemented the turret sentries (Missile Battery / Beam Sentry / Cryo Sentry via TurretNode `mode`) + Nova Beam / Barrage / Toxic Nova → **28 fusions**; toned down difficulty (DIFF_BASE 1/34→1/48, level rate 0.06→0.02, **level-up step 0.9→0.3**)
- [ ] **M7 — Playtest round 2 & balance** ← *NEXT*: re-check the now-gentler curve (make sure enemies still keep up late), tier spread, relief; balance 28 fusions; default config; SFX mix; web/itch build
- [ ] **M7.5 — Co-op hardening**: real 2-PC playtest; smooth interpolation under latency; sync flame/laser visuals of allies more exactly; reconcile client-side cosmetic objects (mines/missiles ghost slightly vs. host); mid-game join?; port forwarding docs
- [ ] **M8 — Sound & polish**: sound effects, music loop, better death/hit animations
- [ ] **M9 — Content depth**: a boss at 5:00, elite modifiers, weapon evolutions, more stat picks
- [ ] **M10 — Meta**: title screen, run-end stats screen, persistent high scores (save file)
- [ ] **M11 — Ship**: export presets (Windows/web), itch.io-ready build

*Status: variety update done — pending playtest round 2.*

## Backlog / ideas (unordered)

- Weapon evolution at max level, pickup drops (heal, bomb, freeze)
- Multiple characters with different starting stats
- Endless mode after the 10:00 win

## How to run

```powershell
godot --path \path\to\folder           # play
godot -e --path \path\to\folder       # open editor
godot --headless --path \path\to\folder --quit-after 300   # smoke test (should print no errors)
```

## Session log

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

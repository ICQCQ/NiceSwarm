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
  (every weapon-pair combination)**. The `Fusions.INFO`/`make()` table lives in `weapon_fusions.gd`;
  each fusion class is its own file under `scripts/weapons/fusions/`. Full list + coverage matrix in
  [WEAPON_DESIGN.md](WEAPON_DESIGN.md); player-facing catalogue in [WEAPON_CODEX.md](WEAPON_CODEX.md).
- **Dynamic difficulty:** a `heat()` value rises as the party level outpaces par-for-time. When
  ahead, elites and bombardiers spawn more often, normal spawns can upgrade to special enemies, and
  all enemies get a mild HP/speed bonus. A HUD "Threat ▮▮▮▮" meter shows the current pressure.
- **Weapon level cap is 7** (`MAX_WEAPON_LEVEL`; mergeable at Lv7) — a longer grind to fusion. Spawn
  COUNTS freeze at the cap (`weapon_base.count_level()`) while damage/area/cadence keep scaling with
  the real level; party level also scales every weapon's base power (`WEAPON_LEVEL_POWER`).
- **Pause menu shows the arsenal:** your current loadout (incl. fusion names + levels) and all 13
  base weapons with owned-level / `fused` / `—` status.
- **Weapon fusion:** any two **maxed** (Lv7) attacks merge into ONE slot (removes 2, adds 1 — frees a
  slot). The fused weapon's parts keep firing and **level together** (`[Lv n]` on a fusion bumps every
  component); merges are **same-kind only** — base+base→signature fusion (T1), signature+signature→amalgam
  (T2, terminal). `WeaponBase` + `WeaponFused` container; components are re-parented, not re-created.
- **Weapons** (each levels 1→7; level-ups offer learning new ones or leveling owned ones; **max 5 per run** so picks form a build):
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
- **Enemies:** spawn in a ring off-screen and scale with a master `difficulty` value (time/level/heat).
  Full archetype-class & tier catalogue is the **Enemy classes & tiers** list above + [ENEMY_DESIGN.md](ENEMY_DESIGN.md).
  Bosses have **DPS-responsive HP** (scaled to the party's recent damage); high-tier enemies are CC-immune.
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
- [x] **M6.22 — Full fusion matrix + tests/docs**: all **78/78** signature fusions; burn-stacking rework, gravity tone-down, `EnemySpawner` extraction; split pace vs. difficulty; heat exponential spike + boss class; balance overhaul + headless unit-test suite (`tests/`) + balance/design docs
- [x] **M6.23 — Weapon progression revamp + fusion depth cap**: weapon level cap 3→**7** (counts freeze at cap, damage keeps scaling) + party-level power scaling (`WEAPON_LEVEL_POWER`); fusion depth capped at `MAX_FUSION_TIER` 3 (base→T1→T2→final T3); fusions born at Lv1
- [x] **M6.24 — Difficulty hardening + responsive bosses**: hard-difficulty pass + FF/god lethality probe (incoming-DPS curve); **DPS-responsive boss HP** + level-scaled enemy HP + CC-immune tough enemies; enemy soft-separation (no O(n²) stacking)
- [x] **M6.25 — UX & tooling**: settings menu (audio/display/accessibility); **weapon codex** ([WEAPON_CODEX.md](WEAPON_CODEX.md)) + full hover stat tooltip + amalgam parts tooltip; auto-updating **launcher**; CI builds Windows x86_64/arm64 + macOS universal + debug exe
- [x] **M6.26 — Balance tuning passes**: fresh-fusion damage boost + amalgam per-level all-stat scaling; slow buff + per-weapon mine cap; early-game XP catch-up; live-tuned co-op/HUD/netcode pass + live damage-ranking panel
- [x] **M6.27 — Fusion source split + orchestration**: `weapon_fusions.gd` (3288→197 lines) split into one file per fusion under `scripts/weapons/fusions/`; documented the orchestrator + sub-agent working mode ([ORCHESTRATION.md](ORCHESTRATION.md))
- [ ] **M7 — Balance & playtest** ← *ongoing*: headless playstyle-sim + bot harness landed (solo + multiplayer + god lethality probe); continuing live balance of the 78 fusions / difficulty curve; default config + SFX mix; web/itch build
- [ ] **M7.5 — Co-op hardening**: real 2-PC playtest; smooth interpolation under latency; sync flame/laser visuals of allies more exactly; reconcile client-side cosmetic objects (mines/missiles ghost slightly vs. host); mid-game join?; port forwarding docs
- [x] **M7.6 — Noray NAT lobby (game side)**: online co-op without port-forwarding — vendored `netfox.noray` client + `NorayLobby` (`scripts/core/noray_lobby.gd`); host advertises an **OID join code**, joiner connects through the Noray relay; direct IP/Port kept as fallback. Live-verified end-to-end (rendezvous + ENet socket-reuse). See [docs/NORAY.md](docs/NORAY.md).
- [x] **M7.6b — Noray server deployed + hardened (2026-06-18)**: persistent stack on docker-server (`~/noray/`, LAN, healthy). Security-reviewed → swapped from `ghcr.io/foxssake/noray:main` to a **private hardened fork** ([github.com/chawasit/noray](https://github.com/chawasit/noray), image `ghcr.io/chawasit/noray:trirat`, self-healing pull). Fixes: relay no longer crashes the whole server on a bandwidth/lifetime/traffic cap (DoS-1, proven live), dynamic-relay exhaustion guard + per-conn caps (DoS-2/3), metrics loopback-only (IL-2). See [docs/NORAY.md](docs/NORAY.md) + the fork's `FORK.md`. **Remaining:** public-inbound CGNAT decision (infra) + raise `NORAY_OID_LENGTH` from 6 before any internet exposure.
- [ ] **M8 — Sound & polish**: sound effects, music loop, better death/hit animations
- [ ] **M9 — Content depth**: a boss at 5:00, elite modifiers, weapon evolutions, more stat picks
- [ ] **M10 — Meta**: title screen, run-end stats screen, persistent high scores (save file)
- [ ] **M11 — Ship**: export presets (Windows/web), itch.io-ready build

*Status: feature-complete sandbox (v0.9.0) — ongoing balance + co-op hardening. Full dev log in [docs/SESSION_LOG.md](docs/SESSION_LOG.md).*

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

Full historical dev log moved to **[docs/SESSION_LOG.md](docs/SESSION_LOG.md)**.
Append new session entries there (newest at the bottom); keep this file's
status + milestones current.

# NiceSwarm (Godot 4 arena survival roguelike, online co-op)

**Start every session by reading [PLAN.md](PLAN.md)** — it holds current status and the
milestone checklist (the full historical dev log lives in [docs/SESSION_LOG.md](docs/SESSION_LOG.md)).
Before ending a session: update the checkboxes, append a session-log entry to
docs/SESSION_LOG.md with what changed and what's next, and commit.

**Working mode:** this repo runs the orchestrator + sub-agent model — see
[ORCHESTRATION.md](ORCHESTRATION.md). Act as orchestrator with up to 3 concurrent Sonnet
sub-agents (each may use Opus as advisor); route every fix/feature through the task queue
and keep it updated with sub-agent progress.

## Running

- Play: `godot --path .` (Godot 4.6 installed via Scoop, on PATH)
- Build a distributable Windows .exe: **double-click `build.cmd`** (or run `./build.ps1`) → `build/NiceSwarm.exe` (single self-contained file, PCK embedded, with version metadata). One-time setup if it errors "no export template": `./install_export_templates.ps1`, then copy that folder into Scoop's self-contained path `scoop/apps/godot/current/editor_data/export_templates/<version>/` (Scoop Godot looks there, not %APPDATA%). Preset is `export_presets.cfg` ("Windows Desktop", x86_64, embed_pck).
- **CI release** (`.github/workflows/build-windows.yml`, "Build desktop binaries"): on push to `publish` (rolling `latest` prerelease) and `v*` tags, two jobs export four desktop binaries. **`export-windows`** (windows-latest): Windows x86_64 release exe (`NiceSwarm.exe`) + **debug exe** (`NiceSwarm-debug.exe`, ships verbose errors/stack traces + the F1 debug panel via `OS.is_debug_build()`) + Windows **arm64** release exe (`NiceSwarm-arm64.exe`, cross-packaged — official Windows-arm64 templates ship since Godot 4.3). **`export-macos`** (macos-latest, `needs: export-windows` to avoid racing the `latest` tag): one **universal** `.zip` (`NiceSwarm-macos.zip`), **ad-hoc signed** so it runs on Apple Silicon; users still clear Gatekeeper quarantine once (right-click → Open / `xattr -dr com.apple.quarantine`). macOS is universal-only because the stock Godot template ships a single `godot_macos_release.universal` binary — a per-arch preset (`architecture="x86_64"`/`"arm64"`) makes Godot look for `godot_macos_release.<arch>`, which doesn't exist (→ "Requested template binary not found"); the universal binary runs native on both Intel and Apple Silicon anyway. The universal export **requires** `rendering/textures/vram_compression/import_etc2_astc=true` in `project.godot` (the arm64 slice) plus the default `import_s3tc_bptc` (the x86_64 slice). Each binary gets its own `<name>.sha256` sidecar; `update_check.gd` (`_sidecar_url`) picks the matching asset by platform + arch (`OS.has_feature("arm64")`) + `OS.is_debug_build()` — Windows x86_64 keeps legacy bare names, Windows arm64 is `-arch`-suffixed, macOS is the single `NiceSwarm-macos.zip`; the macOS sidecar hashes the **inner Mach-O** (`Contents/MacOS/NiceSwarm`) after signing, before zipping. `build.ps1` (local) builds only the Windows x86_64 release exe.
- **Version** lives in three places that must stay in sync when bumped: `VERSION` const in `main.gd` (shown on the menu), `config/version` in `project.godot`, and `application/file_version`+`product_version` in `export_presets.cfg` (the Windows exe metadata). Currently `0.9.0`.
- Smoke test: `godot --headless --path . --quit-after 300` — must print nothing but the engine banner.
- Unit tests: `godot --headless --path . --script res://tests/run_tests.gd` — zero-dependency headless suite over the config/data/formula/fusion layers; prints `[tests] N passed, M failed`, exits non-zero on failure. See [tests/README.md](tests/README.md).
- Full-arsenal smoke test: set env `NICESWARM_TEST=all_weapons` first — grants all 13 weapons at start so every weapon's code path runs headless.
- Co-op smoke test: run two headless instances — first with `NICESWARM_NET=host` (background, ~1500 frames), then `NICESWARM_NET=join` (~800 frames). Expect `[test] start_game peers=[1, ...]` and `[test] first enemy puppet` in the client log, zero errors in both. `NICESWARM_NET=solo` skips the menu for solo runs.
- Bombardier/telegraph smoke test: `NICESWARM_TEST=bomber` spawns 4 bombers at start (works solo or as host) so the telegraph attack + the `STATE_TELEGRAPHS` sync channel run headless.
- Headless/test runs bypass the interactive 1-of-3 starter-weapon pick (no input) and grant bolt + any `NICESWARM_TEST` loadout directly.
- Fusion smoke test: `NICESWARM_TEST=merge` force-maxes bolt+nova and fuses them at start; log should print `[test] merged -> ... weapons=1`.
- **Late-game lethality probe** (balance): `NICESWARM_SIM="style=greedy,players=1,seed=1,god=1,ff=4"` runs the kiting bot **immortal** so it reaches 10:00; `player.lethal_taken` tallies the would-be (i-frame/dash-respected) damage and the per-minute `[ff] lethal/min` line is the incoming-DPS-to-a-5HP-player curve. This is the only signal that sees the late game (the mortal `NICESWARM_SIM` sweep is saturated — bots die mid-game). Keep `ff<=6` (higher time-dilates the headless host → false losses). See [docs/balance/SOLO_BALANCE_SIM.md].
- After adding a **new** `class_name` script, run `godot --headless --path . --import` once,
  or other scripts won't resolve the class (global class cache).

## Architecture

Everything is built in code; the only scene file is `scenes/main.tscn` (root node +
`main.gd`). No art assets — entities draw themselves via `_draw()`.

**Script layout:** `scripts/main.gd` (root, referenced by the scene) plus folders:
`core/` (net, player, sfx), `config/` (game/enemy/weapon tuning), `weapons/` (weapon_*),
`spawned/` (projectile, *_proj, *_node, *_well, *_puddle, *_fx that weapons emit),
`enemies/` (enemy, telegraph), `world/` (pickup, xp_gem, ring_fx, float_text, background).
All scripts use `class_name`, so moving a file never breaks references — but rerun `--import`
(and delete `.godot/` if a stale autoload/uid path lingers).

**Tuning lives in `scripts/config/`:** `GameConfig` (run/difficulty/spawn knobs — main.gd aliases
its consts, net.gd reads `NET_PORT`), `EnemyConfig.CLASSES` (the enemy table → `ENEMY_CLASSES`),
`WeaponConfig.BASE` (per-weapon dmg/growth/cd, read by each `weapon_*.gd`).

**Multiplayer model (host-authoritative):** the host simulates everything (enemy AI,
damage, XP, pickups, revives). Clients send their player pos/facing/dash (20 Hz) and
upgrade picks; the host broadcasts chunked full-snapshot world state (enemies 24 Hz,
gems/pickups/telegraphs 8 Hz, HUD + pings 4 Hz; ≤80 entities/packet, removal by diff).
Each entity is a compact **10-byte `PackedByteArray` record** — `u32 id | s16 x·POS_SCALE |
s16 y·POS_SCALE | u16 f` (positions ×16 fixed-point; `f` is the per-channel extra: enemy
type+slow / gem value / pickup kind / telegraph radius+effect). `_put_entity` encodes,
`_apply_state` decodes via `StreamPeerBuffer`. Entities
have a `puppet` flag on clients: no AI, position lerp, `take_hit` is cosmetic (flash +
number only). Clients still run all weapons locally for visuals — real damage is host-only.
Solo play is the same code path with no ENet peer (`Net.active == false`). World-state
channels: `STATE_ENEMIES`/`GEMS`/`PICKUPS`/`TELEGRAPHS` (0–3); to add one, extend `last_tick`,
the dict array in `_apply_state`, and add a `_send_state`/`_apply_state` case (encode via
`_put_entity`). **Co-op pause** is host-authoritative: any player's in-game menu pauses the
whole run (`set_menu_open`/`menu_open_pids`); **rejoin** is by saved peer-id or player NAME
(`_disconnected_pid_by_name` → `_take_over_slot`). Host measures per-peer ENet RTT into
`net_pings` for the HUD.

- `scripts/net.gd` — ENet host/join + every RPC (transport only, calls back into main). Node lives at `Main/Net` so RPC paths match on all peers. Port 24565. **Gotcha:** RPC method names can't collide with native `Node` methods — `rpc_config` is reserved, so the run-config RPC is `rpc_run_config`.

- `scripts/main.gd` — game controller: menu/lobby (+ run config: options-per-levelup / XP rate / enemy scale via `_make_cycler`, broadcast with `send_config`), host simulation (spawning, `_heat()` dynamic difficulty, XP, pickups, downed/revive, `cast_telegraph`), wait-for-all upgrade flow (merges guaranteed a slot when available), world-state send/apply, all UI. Runs `PROCESS_MODE_ALWAYS`; the `World` child node is `PAUSABLE`. Balance knobs: `_heat()`, `cfg_*` defaults, `_xp_needed`, `_run_spawning`, `_make_enemy`.
- `scripts/player.gd` — local (input, camera, dash) vs puppet (net lerp) modes; HP/downed/revive state; stat multipliers `damage_mult` (Power), `rate_mult` (Haste), `area_mult` (Area — sizes/reach), `duration_mult` (Duration — lifetimes). Weapons read these live each frame. `damage_mult` is **derived each frame** in `_physics_process` (before any early-return, so bots/puppets stay current) as `power_stat × (1 + GameConfig.WEAPON_LEVEL_POWER·(Main.instance.level − 1))` — Power picks mutate `power_stat`; party level scales weapon base power on top, so reading `damage_mult` folds in both with zero weapon edits. Child nodes in `player.weapons`; all weapons check `player.downed`. `MAX_WEAPON_LEVEL` is 7 (a weapon is mergeable at Lv7); `weapon_base.count_level()` freezes spawn COUNTS at that cap while damage/area/cadence keep scaling with the real `level`.
- `scripts/weapon_base.gd` (`WeaponBase`) — base for all weapons: `weapon_id`, `level`, `display_name`, and `player` resolved by walking up the tree (so weapons nested in a fusion still find the player). Subclasses set id/name in `_init()`, not `@onready`.
- `scripts/weapon_*.gd` (13: bolt, orbit, nova, glaive, lightning, flame, mines, missiles, laser, frost, gravity, turret, venom) — `extends WeaponBase`, self-processing (level 1–5); each reads player multipliers (`damage_mult`, `rate_mult`) and plays its `Sfx` voice on fire. New weapons: add script + `WEAPON_INFO` entry in main + `add_weapon` match in player + a sound in `sfx.gd`. Runs are capped at `MAX_WEAPONS` (5).
- **Weapon design contract:** every weapon must honor all 4 stats — see [WEAPON_DESIGN.md](WEAPON_DESIGN.md). Power=`damage_mult`, Haste=`rate_mult` (cadence), Area=`area_mult` (all spatial dims), Duration=`duration_mult` (lifetimes; instant weapons call `WeaponBase.ignite()` for a burn). Read it before adding/changing a weapon. The player-facing catalogue (per-weapon base stats + all 78 fusions, generated from `WeaponConfig.BASE`/`WEAPON_INFO`/`Fusions.INFO`) is [WEAPON_CODEX.md](WEAPON_CODEX.md).
- `scripts/weapon_fusions.gd` (`Fusions`) — fusion recipes: `INFO` table (name/desc per sorted id-pair) + `make(a,b)` returning a DISTINCT new weapon (inner `WeaponBase` classes: PlasmaBurst, Cryoshock, ToxicPyre, Singularity, ClusterBomb, PrismHalo, GlacialEdge). Uncovered pairs / deep merges fall back to `WeaponFused`.
- `scripts/weapon_fused.gd` (`WeaponFused`) — generic fallback fusion: holds component weapons as children; `setup()` re-parents, `level_up()` bumps each. `player.merge_weapons()` tries `Fusions.make()` first, else builds this. Upgrade pool offers `[MERGE]`; `apply_choice` routes merge/level/learn/stat by id prefix. **Merges are same-kind only**: each weapon has a `tier` (base=0, signature fusion=1, amalgam=2+); `Fusions.can_merge(a,b)` returns true only when `a==b and tier<=1` — so **base+base→signature fusion (T1)** and **signature+signature→amalgam (T2)**, while an **amalgam is terminal** (no base+fusion mixing, no amalgam re-merge). Two of the SAME weapon merge via `player._second_weapon`, and leveling a duplicate uses `player.lowest_weapon` (levels the lowest copy so each reaches max) — `get_weapon` alone returns the first instance twice. Gated in both the pool and `merge_weapons`.
- `scripts/enemy.gd` status effects (host-authoritative): `apply_slow(mult,dur)`, `apply_burn(dps,dur)`.
- `scripts/sfx.gd` (`Sfx` autoload) — procedural audio: synthesizes all sounds at startup (no asset files), positional 2D + flat pools, per-name throttle. Call `Sfx.play(name, pos_or_null, vol_db)`.
- `scripts/core/settings.gd` (`GameSettings`) — client-local prefs (master volume / mute / fullscreen / screen-shake), `store_var` at `user://settings.cfg`. Owned by Main as `main.settings`, created+applied in `_ready` before the UI builds; deliberately **not** net-synced. `apply_audio()` drives Master bus 0 (mutes when muted or volume 0 — `linear_to_db(0)` is −INF), `apply_window()` toggles fullscreen (no-op headless). UI: the in-game hub "O settings" tab + a main-menu Settings overlay (both share the one instance; `game_ui` relabels on show). Screen shake is gated at the single apply point in `player._update_cam`. Add a setting: a field + a cycler row in `game_ui._build_settings_rows` (+ `_adv_*`).
- Weapon-spawned nodes: `glaive_proj.gd`, `missile_proj.gd`, `frost_shard.gd` (slows via `enemy.apply_slow`), `mine_node.gd`, `gravity_well.gd`, `turret_node.gd`, `venom_puddle.gd`, `lightning_fx.gd`. Ground objects use `z_index = -1` (background is -10).
- `scripts/enemy.gd` — chase + contact damage + knockback; stats assigned by `main.gd` **before** `add_child`. `take_hit(amount, from_pos, dtype)` honors `resist`, `immune_type` (DMG_PHYS/FIRE/ICE/ENERGY), and `shielded`. `caster` enemies call `main.cast_telegraph(pos,r,dmg,effect)` with a `cast_pattern` (0 single-lead / 1 line / 2 ring) and `cast_effect` (0 damage / 1 disrupt). Also `pull_immune` (gravity suck-in), `knockback_immune` (pushback only — still slowable, unlike `cc_immune` which blocks both), `split_count`, Sentinel `shield_cycle`/`shield_time`. Status: `apply_slow`/`apply_burn` (host-authoritative). **Boss HP is DPS-responsive** (`spawner.make_enemy` → `GameConfig.boss_hp`): `max(hp0 floor, recent_dps·BOSS_FIGHT_SECONDS) × level × player-count`, where `recent_dps` is the party's damage over the last `BOSS_DPS_WINDOW`s (host tracks it via `spawner.add_damage_sample` from `main.add_damage`). Bosses + tier-`CC_IMMUNE_TIER`+ enemies are knockback/pull immune. Sim/FF runs print `[boss] … hp=… (rdps=… lvl=… N=…)` for tuning.
- **Enemy classes:** defined in `main.gd` `ENEMY_CLASSES` — archetype classes (brawler/rusher/tank/caster/warden/splitter/elite), each an ordered list of tier stat-dicts (a higher tier is a direct upgrade). `_build_type_registry` flattens them into stable network ids; `_class_tier` chooses which tier spawns (rises with time/level/heat). Behaviors: `move` (chase/wander/bounce/straight), `phase`/`cc_imm`/`life`, `shape` (silhouette), `resist` (Warden armor), `immune` (damage type), `burst` (Burster spits `shard` bullets via `_spawn_burst`), `caster`+`pattern`/`effect` (telegraph). **Full catalogue + add-a-class checklist: [ENEMY_DESIGN.md](ENEMY_DESIGN.md).** Difficulty: a master `difficulty` value (`_diff()`) drives all enemy scaling in `_make_enemy`/`_class_tier`; it climbs at `DIFF_BASE·(1 + heat·DIFF_HEAT + level·DIFF_LEVEL)`. `_heat()` is the clear-rate accelerator (kills/sec EMA vs `_spawn_rate`, rises fast / decays slow). Both host-computed and synced via HUD state (`net_difficulty`/`net_heat`), surfaced to the player as the named `THREAT` readout (CALM→NIGHTMARE tiers from `THREAT_TIERS`, color-coded, with a `▲ rising`/`▲▲ SURGING` heat note — display-only, see `_update_hud`). Smoke-test all types with `NICESWARM_TEST=zoo`.
- `scripts/telegraph.gd` (`TelegraphZone`) — a synced, telegraphed AoE strike; host detonates and damages players inside after `warn`; clients show it as a puppet (channel `STATE_TELEGRAPHS`).
- `scripts/pickup.gd` — heart/bomb/magnet/chest; effects applied in `main._on_pickup_taken`.
- `scripts/projectile.gd`, `scripts/xp_gem.gd`, `scripts/ring_fx.gd`, `scripts/float_text.gd`, `scripts/background.gd` — small, self-contained.

Collision layers: 1 = player, 2 = enemies (enemy `collision_layer = 2`). Projectiles are Area2D with mask 2; gems/pickups use distance checks, no physics. Groups: `"enemies"`, `"gems"`. **Enemies have no physics collision with each other** (`collision_mask = 0`) — 220 mutually-colliding bodies was an O(n²) cliff. Instead, overlap is avoided with a cheap boids-style **soft separation** steering force (`Enemy._separation`, host-only): each enemy queries the shared per-frame `EnemyGrid` for neighbors within its body radius and adds a unit-capped push away from them (`SEPARATION_STRENGTH` × speed) before `move_and_slide`. O(local), reuses the index weapons already rebuild — the swarm spreads out instead of stacking on one point without reintroducing the contact-solver cost. Immovable enemies (bosses / `knockback_immune` / `cc_immune`) don't get shoved but still part the swarm around them.

**Finding enemies (perf — do NOT call `get_tree().get_nodes_in_group("enemies")` in per-frame code):** `Main` builds a shared enemy spatial index once per physics tick (`_rebuild_enemy_grid`, runs before any child processes). Query it instead: `Main.instance.enemies_in_radius(pos, r)` (O(local) uniform-grid query — keep your own precise `dist <= reach + e.radius` check), `Main.instance.nearest_enemy_to(pos, range)` (or `player.nearest_enemy(range)` which delegates to it), or `Main.instance.all_enemies()` (cached `Array[Node]`, no alloc) when you genuinely need every enemy. Helpers return `Array[Node]` so loop-var inference matches the old group scans. Rationale + remaining follow-ups in [PERFORMANCE.md](PERFORMANCE.md).

## Conventions

- GDScript 4 syntax, tabs, typed where cheap (`:=`).
- Keep the build-in-code approach — don't introduce .tscn files for entities.
- Tune balance numbers in `main.gd` (`_run_spawning`, `_spawn_enemy`, `_xp_needed`, stat pool in `_build_choice_pool`, `MAX_WEAPON_LEVEL`) and per-weapon scaling in each `weapon_*.gd` (damage uses `damage_mult`, spatial dims use `area_mult`, lifetimes use `duration_mult`).

<!-- code-review-graph MCP tools -->
## MCP Tools: code-review-graph

**IMPORTANT: This project has a knowledge graph. ALWAYS use the
code-review-graph MCP tools BEFORE using Grep/Glob/Read to explore
the codebase.** The graph is faster, cheaper (fewer tokens), and gives
you structural context (callers, dependents, test coverage) that file
scanning cannot.

### When to use graph tools FIRST

- **Exploring code**: `semantic_search_nodes` or `query_graph` instead of Grep
- **Understanding impact**: `get_impact_radius` instead of manually tracing imports
- **Code review**: `detect_changes` + `get_review_context` instead of reading entire files
- **Finding relationships**: `query_graph` with callers_of/callees_of/imports_of/tests_for
- **Architecture questions**: `get_architecture_overview` + `list_communities`

Fall back to Grep/Glob/Read **only** when the graph doesn't cover what you need.

### Key Tools

| Tool | Use when |
| ------ | ---------- |
| `detect_changes` | Reviewing code changes — gives risk-scored analysis |
| `get_review_context` | Need source snippets for review — token-efficient |
| `get_impact_radius` | Understanding blast radius of a change |
| `get_affected_flows` | Finding which execution paths are impacted |
| `query_graph` | Tracing callers, callees, imports, tests, dependencies |
| `semantic_search_nodes` | Finding functions/classes by name or keyword |
| `get_architecture_overview` | Understanding high-level codebase structure |
| `refactor_tool` | Planning renames, finding dead code |

### Workflow

1. The graph auto-updates on file changes (via hooks).
2. Use `detect_changes` for code review.
3. Use `get_affected_flows` to understand impact.
4. Use `query_graph` pattern="tests_for" to check coverage.

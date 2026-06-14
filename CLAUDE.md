# NiceSwarm (Godot 4 arena survival roguelike, online co-op)

**Start every session by reading [PLAN.md](PLAN.md)** — it holds current status, the
milestone checklist, and the session log. Before ending a session: update the
checkboxes, append a session-log entry with what changed and what's next, and commit.

## Running

- Play: `godot --path .` (Godot 4.6 installed via Scoop, on PATH)
- Build a distributable Windows .exe: **double-click `build.cmd`** (or run `./build.ps1`) → `build/NiceSwarm.exe` (single self-contained file, PCK embedded, with version metadata). One-time setup if it errors "no export template": `./install_export_templates.ps1`, then copy that folder into Scoop's self-contained path `scoop/apps/godot/current/editor_data/export_templates/<version>/` (Scoop Godot looks there, not %APPDATA%). Preset is `export_presets.cfg` ("Windows Desktop", x86_64, embed_pck).
- **Version** lives in three places that must stay in sync when bumped: `VERSION` const in `main.gd` (shown on the menu), `config/version` in `project.godot`, and `application/file_version`+`product_version` in `export_presets.cfg` (the Windows exe metadata). Currently `0.9.0`.
- Smoke test: `godot --headless --path . --quit-after 300` — must print nothing but the engine banner.
- Unit tests: `godot --headless --path . --script res://tests/run_tests.gd` — zero-dependency headless suite over the config/data/formula/fusion layers; prints `[tests] N passed, M failed`, exits non-zero on failure. See [tests/README.md](tests/README.md).
- Full-arsenal smoke test: set env `NICESWARM_TEST=all_weapons` first — grants all 13 weapons at start so every weapon's code path runs headless.
- Co-op smoke test: run two headless instances — first with `NICESWARM_NET=host` (background, ~1500 frames), then `NICESWARM_NET=join` (~800 frames). Expect `[test] start_game peers=[1, ...]` and `[test] first enemy puppet` in the client log, zero errors in both. `NICESWARM_NET=solo` skips the menu for solo runs.
- Bombardier/telegraph smoke test: `NICESWARM_TEST=bomber` spawns 4 bombers at start (works solo or as host) so the telegraph attack + the `STATE_TELEGRAPHS` sync channel run headless.
- Headless/test runs bypass the interactive 1-of-3 starter-weapon pick (no input) and grant bolt + any `NICESWARM_TEST` loadout directly.
- Fusion smoke test: `NICESWARM_TEST=merge` force-maxes bolt+nova and fuses them at start; log should print `[test] merged -> ... weapons=1`.
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
upgrade picks; the host broadcasts chunked full-snapshot world state (enemies 12 Hz,
gems/pickups/telegraphs 8 Hz, HUD 4 Hz; ≤80 entities/packet, removal by diff). Entities
have a `puppet` flag on clients: no AI, position lerp, `take_hit` is cosmetic (flash +
number only). Clients still run all weapons locally for visuals — real damage is host-only.
Solo play is the same code path with no ENet peer (`Net.active == false`). World-state
channels: `STATE_ENEMIES`/`GEMS`/`PICKUPS`/`TELEGRAPHS` (0–3); to add one, extend `last_tick`,
the dict array in `_apply_state`, and add a `_send_state`/`_apply_state` case.

- `scripts/net.gd` — ENet host/join + every RPC (transport only, calls back into main). Node lives at `Main/Net` so RPC paths match on all peers. Port 24565. **Gotcha:** RPC method names can't collide with native `Node` methods — `rpc_config` is reserved, so the run-config RPC is `rpc_run_config`.

- `scripts/main.gd` — game controller: menu/lobby (+ run config: options-per-levelup / XP rate / enemy scale via `_make_cycler`, broadcast with `send_config`), host simulation (spawning, `_heat()` dynamic difficulty, XP, pickups, downed/revive, `cast_telegraph`), wait-for-all upgrade flow (merges guaranteed a slot when available), world-state send/apply, all UI. Runs `PROCESS_MODE_ALWAYS`; the `World` child node is `PAUSABLE`. Balance knobs: `_heat()`, `cfg_*` defaults, `_xp_needed`, `_run_spawning`, `_make_enemy`.
- `scripts/player.gd` — local (input, camera, dash) vs puppet (net lerp) modes; HP/downed/revive state; stat multipliers `damage_mult` (Power), `rate_mult` (Haste), `area_mult` (Area — sizes/reach), `duration_mult` (Duration — lifetimes). Weapons read these live each frame. Child nodes in `player.weapons`; all weapons check `player.downed`. `MAX_WEAPON_LEVEL` is 3 (in main.gd); per-level damage growth factors are doubled to compensate.
- `scripts/weapon_base.gd` (`WeaponBase`) — base for all weapons: `weapon_id`, `level`, `display_name`, and `player` resolved by walking up the tree (so weapons nested in a fusion still find the player). Subclasses set id/name in `_init()`, not `@onready`.
- `scripts/weapon_*.gd` (13: bolt, orbit, nova, glaive, lightning, flame, mines, missiles, laser, frost, gravity, turret, venom) — `extends WeaponBase`, self-processing (level 1–5); each reads player multipliers (`damage_mult`, `rate_mult`) and plays its `Sfx` voice on fire. New weapons: add script + `WEAPON_INFO` entry in main + `add_weapon` match in player + a sound in `sfx.gd`. Runs are capped at `MAX_WEAPONS` (5).
- **Weapon design contract:** every weapon must honor all 4 stats — see [WEAPON_DESIGN.md](WEAPON_DESIGN.md). Power=`damage_mult`, Haste=`rate_mult` (cadence), Area=`area_mult` (all spatial dims), Duration=`duration_mult` (lifetimes; instant weapons call `WeaponBase.ignite()` for a burn). Read it before adding/changing a weapon.
- `scripts/weapon_fusions.gd` (`Fusions`) — fusion recipes: `INFO` table (name/desc per sorted id-pair) + `make(a,b)` returning a DISTINCT new weapon (inner `WeaponBase` classes: PlasmaBurst, Cryoshock, ToxicPyre, Singularity, ClusterBomb, PrismHalo, GlacialEdge). Uncovered pairs / deep merges fall back to `WeaponFused`.
- `scripts/weapon_fused.gd` (`WeaponFused`) — generic fallback fusion: holds component weapons as children; `setup()` re-parents, `level_up()` bumps each. `player.merge_weapons()` tries `Fusions.make()` first, else builds this. Upgrade pool offers `[MERGE]`; `apply_choice` routes merge/level/learn/stat by id prefix.
- `scripts/enemy.gd` status effects (host-authoritative): `apply_slow(mult,dur)`, `apply_burn(dps,dur)`.
- `scripts/sfx.gd` (`Sfx` autoload) — procedural audio: synthesizes all sounds at startup (no asset files), positional 2D + flat pools, per-name throttle. Call `Sfx.play(name, pos_or_null, vol_db)`.
- Weapon-spawned nodes: `glaive_proj.gd`, `missile_proj.gd`, `frost_shard.gd` (slows via `enemy.apply_slow`), `mine_node.gd`, `gravity_well.gd`, `turret_node.gd`, `venom_puddle.gd`, `lightning_fx.gd`. Ground objects use `z_index = -1` (background is -10).
- `scripts/enemy.gd` — chase + contact damage + knockback; stats assigned by `main.gd` **before** `add_child`. `take_hit(amount, from_pos, dtype)` honors `resist`, `immune_type` (DMG_PHYS/FIRE/ICE/ENERGY), and `shielded`. `caster` enemies call `main.cast_telegraph(pos,r,dmg,effect)` with a `cast_pattern` (0 single-lead / 1 line / 2 ring) and `cast_effect` (0 damage / 1 disrupt). Also `pull_immune`, `split_count`, Sentinel `shield_cycle`/`shield_time`. Status: `apply_slow`/`apply_burn` (host-authoritative).
- **Enemy classes:** defined in `main.gd` `ENEMY_CLASSES` — archetype classes (brawler/rusher/tank/caster/warden/splitter/elite), each an ordered list of tier stat-dicts (a higher tier is a direct upgrade). `_build_type_registry` flattens them into stable network ids; `_class_tier` chooses which tier spawns (rises with time/level/heat). Behaviors: `move` (chase/wander/bounce/straight), `phase`/`cc_imm`/`life`, `shape` (silhouette), `resist` (Warden armor), `immune` (damage type), `burst` (Burster spits `shard` bullets via `_spawn_burst`), `caster`+`pattern`/`effect` (telegraph). **Full catalogue + add-a-class checklist: [ENEMY_DESIGN.md](ENEMY_DESIGN.md).** Difficulty: a master `difficulty` value (`_diff()`) drives all enemy scaling in `_make_enemy`/`_class_tier`; it climbs at `DIFF_BASE·(1 + heat·DIFF_HEAT + level·DIFF_LEVEL)`. `_heat()` is the clear-rate accelerator (kills/sec EMA vs `_spawn_rate`, rises fast / decays slow). Both host-computed and synced via HUD state (`net_difficulty`/`net_heat`), shown as the `DIFFICULTY` HUD readout. Smoke-test all types with `NICESWARM_TEST=zoo`.
- `scripts/telegraph.gd` (`TelegraphZone`) — a synced, telegraphed AoE strike; host detonates and damages players inside after `warn`; clients show it as a puppet (channel `STATE_TELEGRAPHS`).
- `scripts/pickup.gd` — heart/bomb/magnet/chest; effects applied in `main._on_pickup_taken`.
- `scripts/projectile.gd`, `scripts/xp_gem.gd`, `scripts/ring_fx.gd`, `scripts/float_text.gd`, `scripts/background.gd` — small, self-contained.

Collision layers: 1 = player, 2 = enemies (enemy `collision_layer = 2`). Projectiles are Area2D with mask 2; gems/pickups use distance checks, no physics. Groups: `"enemies"`, `"gems"`. **Enemies do NOT collide with each other** (`collision_mask = 0`) — 220 mutually-colliding bodies was an O(n²) cliff; they overlap freely, VS-style.

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

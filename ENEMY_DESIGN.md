# NiceSwarm — Enemy Design Guide

Companion to [WEAPON_DESIGN.md](WEAPON_DESIGN.md). Enemies are organized into
**classes**; each class is an ordered list of **tiers** where a higher tier is a
*direct upgrade* of the one before. Which tier spawns rises with **pace** — elapsed
time only (`EnemySpawner.class_tier`) — so the same class supplies easy and hard
variants on a fixed schedule, regardless of how well the party is doing.

All enemy data lives in one place: `EnemyConfig.CLASSES` in `scripts/config/enemy_config.gd`.
Add a class or a tier there and the network type-id is assigned automatically
(`EnemySpawner.build_type_registry`); no other wiring is needed. Spawn cadence/weights
live in `EnemyConfig.SPAWN_POOL` and `EnemyConfig.SPAWN_SPECIALS` in the same file.

## Tier stat fields

Each tier is a dictionary:

| Field | Meaning |
|-------|---------|
| `name` | display name |
| `hp0`, `hpk` | health = `(hp0 + minute*hpk) * party`, then ×heat & ×enemy-scale |
| `spd`, `spdk` | speed = `spd + minute*spdk`, then ×heat & ×enemy-scale |
| `r` | radius (also the collision/contact size) |
| `dmg` | contact damage to the player |
| `xp` | XP gem value dropped |
| `col` | body color |
| `elite` | always drops a chest (free team upgrade) |
| `resist` | Warden armor — fraction of every hit ignored (0..1) |
| `immune` | `Enemy.DMG_*` — takes **zero** damage of that type (PHYS/FIRE/ICE/ENERGY) |
| `pull_imm` | ignores gravity-well pull |
| `shield_cycle`+`shield_time` | Sentinel — phases an invulnerable shield on/off |
| `move` | 0 chase (default) / 1 wander (random) / 2 bounce (straight, reflects off walls) / 3 straight+`life` |
| `phase` | passes through all bodies (no collision) |
| `cc_imm` | can't be slowed or knocked back (interrupt-immune) |
| `life` | despawns after N seconds (shards) |
| `burst` | Burster — enemy "shard" bullets sprayed radially on death |
| `shape` | silhouette: circle/triangle/square/diamond/hex/star (polygons point along travel) |
| `caster` + `pattern`/`effect`/`cr`/`cd`/`cdt`/`keep` | ranged telegraph attacker (see below) |
| `boss` + `slam_pattern`/`slam_radius`/`slam_damage`/`slam_cooldown` | boss map-wide/pattern slam attack (see Bosses) |
| `enrage_resist` | extra `resist` that ramps up to this value as hp drops toward 0 |
| `immune_cycle`+`immune_pool` | rotates `immune` through this list of `DMG_*` every `immune_cycle` seconds |
| `summon_cls`+`summon_count`+`summon_cooldown` | periodically calls in `summon_count` enemies of `summon_cls` |

## Damage types

Weapons tag their hits with a `DMG_*` type (defaults to PHYS). Enemies with `immune`
take zero damage of that type — a counter to mono-element builds. Current tags: ENERGY =
nova / lightning / laser / gravity-well; FIRE = flame + all burns (`ignite`); ICE = frost;
everything else PHYS. The gravity **well pulls each enemy in only once** (then it just
grinds), and `pull_imm` enemies ignore the pull entirely.

## Telegraph (caster) attacks

`caster` enemies keep their distance (`keep` px) and every `cdt` seconds call
`main.cast_telegraph(pos, cr, cd)` — a red danger zone that detonates after
`TELEGRAPH_WARN` (1.3 s) and damages players still inside. Synced to clients so co-op
players see and dodge it. `pattern` selects the shape:

- **0 — single, leads the target.** Casts ahead of the player's velocity, so running in a
  straight line walks you into it; you must turn or stop. (Bomber)
- **1 — random line.** Three strikes laid out along a random angle from your position —
  unpredictable, so you can't out-read it, only react and reposition. (Diviner)
- **2 — ring.** Six strikes encircling you; leave through the gap. (Oracle)

`effect` selects what the strike does: **0 damage** (normal); **1 disrupt** (Disruptor — instant,
no damage, but standing in it **slows you and locks your dash** for ~2.5 s); **2 field** (Defiler
— after the warn it becomes a **lingering ground hazard** for ~3 s, disrupting anyone inside).
Dashing through any disrupt zone shrugs it off. Disrupt/field zones are purple instead of red.
Pattern-0 casters (Bomber etc.) grow **more unpredictable as difficulty climbs** — variable lead +
jitter, and a second scattered strike late game.

## Current roster

| Class | Tier 0 | Tier 1 | Tier 2 | Role |
|-------|--------|--------|--------|------|
| **brawler** | Grunt | Bruiser | Reaver | baseline chaser, the staple spawn |
| **rusher** | Runner | Sprinter | — | fast, fragile, flanks you |
| **tank** | Brute | Behemoth | — | big, slow, heavy contact; drops pickups |
| **caster** | Bomber | Diviner | Oracle | ranged telegraphed strikes (lead → line → ring) |
| **warden** | Shieldling | Bulwark | — | armored (40–55% resist), pull-immune; focus-fire to break |
| **burster** | Spore | Brood | — | follows, then **spits a ring of shard bullets on death** — dodge the burst |
| **shard** | Shard | — | — | the enemy bullet: flies straight, phases, expires, dies in one hit |
| **bouncer** | Caroms | Pinball | — | **ricochets off walls, phases through everything, can't be interrupted** (no chase) |
| **sentinel** | Sentinel | Aegis | — | phases an **invulnerable shield** on/off; strike between phases |
| **wisp** | Mote | Wisp | — | **drifts randomly** (no chase); **immune to ENERGY** (counters energy builds) |
| **disruptor** | Hexer | Nullifier | — | telegraphs instant **disrupt** zones — no damage, but slows + dash-locks you |
| **defiler** | Warlock | Defiler | — | lays **lingering disrupt fields on the ground** (effect 2) — area denial, walk out or dash through |
| **elite** | Elite | Champion | — | tanky mini-boss, always drops a chest |
| **boss** | Juggernaut | Harbinger | Eclipse | rare, very tough — see Bosses below |

### Spawn cadence (host, `EnemySpawner.run_spawning`)
- Steady stream: weighted pick from `EnemyConfig.SPAWN_POOL` — brawler (staple) / rusher (0:45) /
  wisp (1:30) / warden (2:00) / sentinel (2:30) / burster (3:00) / disruptor (3:30) /
  defiler (5:00). Shards only spawn from a Burster's death.
- Periodic specials from `EnemyConfig.SPAWN_SPECIALS`: tank every 45 s after 1:30 ·
  elite every 75→32 s (faster with heat) after 2:00 · caster (Bomber/Diviner/Oracle by
  tier) every 20→11 s after 2:30.
- `EnemySpawner.class_tier` pushes every class toward higher tiers as **pace** climbs —
  *except* classes marked `uniform_tier: true` (on tier 0), which instead pick
  uniformly at random among every tier unlocked so far (currently **caster**: Bomber/
  Diviner/Oracle stay evenly mixed instead of Oracle dominating once pace is high).
- **Bouncer is not in `SPAWN_POOL`** — see "Bouncer: a separate population" below.

### Pace, difficulty & heat
Spawning is driven by **two independent numbers** (`EnemySpawner`), both host-computed
and only ever rising:

- **Pace** — enemy *variety* and *population*. Climbs at a flat, time-only rate
  (`DIFF_BASE · warmup`) — it **never accelerates**, so a skilled/fast party doesn't get
  buried under more enemy types or a bigger swarm than the run "should" have yet.
  `class_tier` spawns a higher tier every ~3 pace; `desired_pop` (the spawn-refill
  target) grows with pace.
- **Difficulty** — how tough each enemy is to *clear*. `make_enemy` uses it in place of
  elapsed-minutes for HP/speed, and adds `+1 contact damage per 12 difficulty`. It
  climbs at the *same base rate as pace*, but accelerated by heat, a heat *spike*, and
  party level: `DIFF_BASE · warmup · (1 + heat·2.4 + heat_spike·1.0 + (level−1)·0.05)`
  — so **clearing fast and leveling up both push difficulty ahead of pace** (tougher
  monsters, same variety/pop). Shown on the HUD as `DIFFICULTY x.x` + a bar, synced to
  clients.

**Heat** (`EnemySpawner.heat()`, 0..1) is the clear-rate accelerator feeding difficulty:
`clamp((kills/sec EMA − spawns/sec) / (spawns/sec·2 + 1), 0, 1)` — clear at the spawn
rate → 0, ~3× → 0.67, ≥5× → 1. It rises fast and **decays gradually** (so a brief lull
doesn't reset pressure). The HUD shows `▲`/`▲▲` when heat is feeding the climb.

**Heat spike** (`EnemySpawner.heat_spike`, host-only) punishes *nearly clearing the
map*: once `elapsed ≥ MID_GAME_TIME` (5:00), if the live enemy count drops below
`HEAT_SPIKE_POP_FRAC` (20%) of `desired_pop`, `heat_spike` grows **exponentially**
(`(heat_spike + dt) · (1 + HEAT_SPIKE_GROWTH·dt)`, capped at `HEAT_SPIKE_MAX = 5`) —
each tick that the arena stays empty compounds the surge. The moment the population
recovers, it decays linearly back to 0 (`HEAT_SPIKE_DECAY`). Unlike `heat()`, this can
push the difficulty multiplier well past 2×, so a party that's steamrolling mid/late
game gets hit with a sudden, escalating wall of tougher enemies.

### Bouncer: a separate population

Bouncer (Caroms/Pinball) is excluded from `SPAWN_POOL` entirely. Once
`elapsed >= BOUNCER_UNLOCK` (2:45), `run_spawning` instead tops up a dedicated
`bouncer_live` count toward its own cap, `BOUNCER_CAP_BASE + pace ·
BOUNCER_CAP_PER_PACE` — a cap that **keeps growing with pace** (never shrinks,
never accelerates) independent of everything else. This population is also
excluded from `desired_pop`/`overwhelmed`/heat-spike accounting (`_pool_count()`
= total live − `bouncer_live`), so a growing swarm of ricochet bouncers never
crowds out the normal pool's spawns or falsely signals "overwhelmed"/"map
cleared". Tier still escalates with pace via the normal `class_tier`.

## Bosses

After `EnemySpawner.total_kills` reaches `BOSS_KILL_BASE` (60), and again every
`BOSS_KILL_INTERVAL` (90) kills thereafter, `add_kill()` spawns one `boss`-class enemy
(`EnemyConfig.CLASSES.boss`), tier = number of bosses spawned so far (capped at the
roster size — later spawns repeat the toughest tier). Bosses chase normally like any
other enemy (no `caster` keep-distance behavior), are `elite` (drop a chest) and
`pull_imm`, and draw an extra crimson ring. Each is hard to kill via a *mechanic*, not
just raw hp, and periodically fires a `slam_pattern` attack via `cast_telegraph` —
independent of the normal AI, so it interrupts chasing/casting on its own cooldown:

- **3 — checkerboard grid**, centered on the boss: a 5×5 grid of strikes spaced
  `slam_radius·1.6` apart in a checkerboard (half the cells), covering a large area
  around it — find the gaps.
- **4 — rotating sweep**: 4 strikes radiating outward from the target along an angle
  that advances 60° every cast (`slam_rot`) — a full rotation every 6 casts, forcing
  continuous repositioning.

| Tier | Name | Hard-to-kill mechanic | Slam |
|------|------|------------------------|------|
| 0 | Juggernaut | `shield_cycle`/`shield_time` (2.5 s shielded / 1.5 s open) + `cc_imm` (can't be slowed/knocked back) | 3 — grid |
| 1 | Harbinger | `immune_cycle` (4 s) rotates `immune_type` through PHYS→FIRE→ICE→ENERGY — match your damage type | 4 — sweep |
| 2 | Eclipse | `enrage_resist` (0.5) — armor ramps up to +50% as hp drops toward 0 + `summon_cls`/`summon_count`/`summon_cooldown` calls in 2 brawlers every 9 s | 3 — grid |

## Designed, not yet implemented

| Class / tier | Idea |
|--------------|------|
| **charger** | telegraphs a line then dashes along it (movement telegraph, not a zone) |
| **healer** | hangs back and heals nearby enemies — kill it first |
| **warper** | blinks toward the player every few seconds, ignoring spacing |
| caster tier 3 "Seraph" | combines line + ring in one cast |
| tank tier 2 "Colossus" | on death, a shockwave telegraph |
| warden tier 2 "Aegis" | projects resist onto nearby enemies |

## Adding a class — checklist
1. Add an entry to `ENEMY_CLASSES` with its tier list (stat dicts above).
2. If it needs new behavior (new `pattern`, on-death effect, etc.), add the field and handle
   it host-side (`enemy.gd` for AI/attacks, `main._on_enemy_killed` for death effects).
3. Add it to the spawn weighting in `_run_spawning` (or a dedicated timer).
4. Keep damage/effects **host-authoritative**; clients only render puppets. The network packs
   the type-id (+1000 = slowed) — nothing else per enemy, so behavior must be reconstructable
   from the type alone.
5. Smoke-test with `NICESWARM_TEST=zoo` (spawns one of every type) headless and in co-op.

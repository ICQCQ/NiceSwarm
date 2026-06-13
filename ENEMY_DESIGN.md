# NiceSwarm — Enemy Design Guide

Companion to [WEAPON_DESIGN.md](WEAPON_DESIGN.md). Enemies are organized into
**classes**; each class is an ordered list of **tiers** where a higher tier is a
*direct upgrade* of the one before. Which tier spawns rises with elapsed time, party
level, and dynamic-difficulty heat (`_class_tier`), so the same class supplies easy and
hard variants as the run escalates.

All enemy data lives in one place: `ENEMY_CLASSES` in `scripts/main.gd`. Add a class or a
tier there and the network type-id is assigned automatically (`_build_type_registry`); no
other wiring is needed.

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
- **1 — predictive line.** Three strikes laid out ahead of where you're moving. (Diviner)
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

### Spawn cadence (host, `_run_spawning`)
- Steady stream: weighted pick — brawler (staple) / rusher (0:45) / wisp (1:30) / warden (2:00) /
  sentinel (2:30) / bouncer (2:45) / burster (3:00) / disruptor (3:30) / defiler (4:00). Shards only spawn from a Burster's death.
- Tank every 45 s after 1:30 · Elite every 75→32 s (faster with heat) after 2:00 ·
  Caster (Bomber/Diviner/Oracle by tier) every 20→11 s after 2:30.
- `_class_tier` pushes every class toward higher tiers over time and with **heat**.

### Difficulty & heat
**Difficulty** is the master number every enemy stat scales from — `_make_enemy` uses it in
place of elapsed-minutes for HP/speed, adds `+1 contact damage per 12 difficulty`, and
`_class_tier` spawns a higher tier every ~2.8 difficulty. It only ever rises. It's shown on the
HUD as `DIFFICULTY x.x` + a bar.

**Heat** (`_heat()`, 0..1) is the clear-rate accelerator: `clamp((kills/sec EMA − spawns/sec) /
(spawns/sec·2 + 1), 0, 1)` — clear at the spawn rate → 0, ~3× → 0.67, ≥5× → 1. It rises fast and
**decays gradually** (so a brief lull doesn't reset pressure). Difficulty climbs at
`DIFF_BASE · (1 + heat·1.6 + (level−1)·0.05)` — so **clearing fast and leveling up both make
difficulty accelerate**. The HUD shows `▲`/`▲▲` when heat is feeding the climb. Host-computed;
difficulty + heat are synced to clients.

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

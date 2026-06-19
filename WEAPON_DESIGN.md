# NiceSwarm — Weapon Design Guide

> For the player-facing catalogue (per-weapon base stats + all 78 fusions in one table),
> see [WEAPON_CODEX.md](WEAPON_CODEX.md). This file is the *design contract* behind it.

This is the contract every weapon (base **and** fusion) must follow. It exists so the
stat system stays *general*: a player who invests in any stat should feel it on **every**
weapon they own. If a stat does nothing for a weapon, the weapon is wrong — fix the
weapon, don't shrink the stat.

## The 4-stat contract

Player carries four weapon-facing multipliers (`scripts/player.gd`):

| Stat | Field | Every weapon must… |
|------|-------|--------------------|
| **Power** | `damage_mult` | scale damage-per-hit by `damage_mult` — the player derives it each frame as `power_stat × (1 + WEAPON_LEVEL_POWER·(party_level−1))`, so simply reading `damage_mult` folds in both Power picks **and** party-level scaling; no extra weapon code needed |
| **Haste** | `rate_mult` (lower = faster) | scale how often it acts — cooldown, tick interval, spin speed, or per-target re-hit cadence — by `rate_mult` |
| **Area** | `area_mult` | scale **every** spatial dimension by `area_mult` — projectile/hit radius, blast/AoE radius, beam length, cone reach, orbit radius, targeting range, chain-jump distance |
| **Duration** | `duration_mult` | scale how long its effect persists by `duration_mult` — projectile/summon/field lifetime; for instant weapons, the length of a lingering **burn** (`ignite()`) or **slow** |

### Damage types
A hit may be tagged `e.take_hit(amount, from_pos, Enemy.DMG_*)` — `PHYS` (default), `FIRE`,
`ICE`, or `ENERGY`. Enemies with an `immune` type take zero of it (see ENEMY_DESIGN.md), so
tag elemental weapons honestly: fire weapons FIRE, ice weapons ICE, energy/lightning ENERGY.
`ignite()` burns are FIRE. Physical weapons can leave the default.

### How "instant" weapons satisfy Duration
Hitscan/contact weapons (nova, orbit, laser, lightning, flame, glaive) have no lifetime,
so they call `WeaponBase.ignite(enemy, dmg)` on hit. That applies a burn DoT whose length
scales with `duration_mult` and whose dps scales with the hit damage (i.e. Power). This is
the universal Duration hook — reach for it before inventing a bespoke one.
`ignite(enemy, dmg, stack_mult)` takes an optional stack multiplier (default 1.0) for
sources that should pile burn stacks on faster — Flame Cone's signature (`BURN_STACK_MULT`
in `weapon_flame.gd`) is the only user so far.

`Enemy` supports five status effects, all host-authoritative:
- `apply_slow(mult, duration)` — frost/ice weapons; deepened by `SLOW_POTENCY` and floored
  at `SLOW_FLOOR_MULT` (never fully stops the enemy — see `apply_freeze` for that)
- `apply_freeze(duration)` — complete movement halt (speed → 0, no floor); currently only
  Glacial Mine (frost+mines); freeze duration scales with Duration, not damage. Bosses are
  exempt outright (a full stop would trivialize boss fights) on top of the `cc_immune` check
- `apply_burn(dps, duration)` — fire/energy weapons, via `ignite()`
- `apply_push(from_pos, strength)` — knockback impulse away from `from_pos`, capped at 280 px/s;
  nova-family blasts call `WeaponBase.push(e, from_pos)` for a mild extra "shockwave" shove on
  top of `take_hit`'s normal hit knockback (skipped for `cc_immune` enemies, scales with Area)
- `apply_blast_push(from_pos, distance)` — a heavy forced shove that covers `distance` px at a
  fixed speed (`BLAST_PUSH_SPEED`), bypassing `apply_push`'s 280 px/s cap so a "heavy push"
  effect (Cluster Warhead) actually reads as heavy; `distance` is the stat-scaled knob (Duration)

Both `apply_slow` and `apply_freeze` are no-ops on `cc_immune` enemies; `apply_push` and
`apply_blast_push` are no-ops on `cc_immune` or `knockback_immune` enemies. Every enemy's
final position is clamped to the arena bounds every tick (in `Enemy._physics_process`, after
movement + any push/pull), so no push or pull effect — including these — can shove or drag an
enemy outside the map.

## Checklist for a NEW base weapon

1. `extends WeaponBase`; set `weapon_id` + `display_name` in `_init()` (never `@onready`).
2. Damage = `BASE * player.damage_mult * (1.0 + GROWTH * (level - 1))`. With
   `MAX_WEAPON_LEVEL == 7`, GROWTH ≈ 0.3–0.5 so per-level damage keeps climbing to a high Lv7 ceiling.
3. Cadence (cooldown / tick / spin) multiplied by `player.rate_mult`.
4. **Every** distance literal multiplied by `player.area_mult`. If a value lives on a
   spawned node (projectile/field), add a field there and set it from the weapon.
5. Lifetime multiplied by `player.duration_mult`; if there is no lifetime, `ignite()` on hit.
6. Guard with `if player == null or player.downed: return`.
7. Play a distinct `Sfx.play(...)` voice (add one in `scripts/sfx.gd`).
8. Register: `WEAPON_INFO` entry in `main.gd`, `add_weapon` match in `player.gd`.

## Fusion weapons

Merging two **maxed** weapons produces a **distinct new weapon**, not the two running
together. Recipes live in `scripts/weapon_fusions.gd`:
- `Fusions.INFO[key]` — name + description for the `[MERGE]` pick (key = the two base
  `weapon_id`s sorted, joined with `|`).
- `Fusions.make(a, b)` — returns the new `WeaponBase`; each fusion class lives in its own file under `scripts/weapons/fusions/`.
- Pairs without a signature recipe fall back to a generic `WeaponFused` (both run together).

A fusion weapon follows the **same 4-stat contract**. Build it from existing spawned nodes
where possible (they already carry Area/Duration fields).

**Merges are same-kind only.** Every weapon carries a `tier`: base weapons are 0, a base+base
**signature fusion** is 1, and a **signature+signature amalgam** is 2. `Fusions.can_merge(a,b)`
allows a merge only when `a == b and tier <= 1` — so **base+base → signature fusion** and
**signature+signature → amalgam**, while an **amalgam is terminal** (you cannot merge a base with
a fusion, nor merge an amalgam with anything). Single source of truth, enforced in both the pick
pool (`main._build_choice_pool`) and the model (`player.merge_weapons`).

### Fusion recipe list

**Implemented (signature) — 78 (all pairs):**

| Pair | Fusion | Behavior |
|------|--------|----------|
| bolt + nova | **Plasma Burst** | slugs that erupt into an AoE blast on impact |
| frost + lightning | **Cryoshock** | a chain that freezes (slow) and burns every link |
| flame + venom | **Purgatory** | an eerie field that burns and marks foes inside it -- marked enemies take extra damage, slow harder, and can't burn out |
| gravity + nova | **Singularity** | a vortex that yanks enemies inward every second, then collapses into a detonation that hits harder the more enemies it caught |
| mines + missiles | **Cluster Bomb** | mines that spray homing rockets on blast |
| laser + orbit | **Prism Halo** | prisms drop around you, linked to you and each other by damage beams |
| frost + glaive | **Glacial Edge** | boomerangs that freeze and bleed |
| bolt + lightning | **Railgun** | a piercing rail-line that electrifies everything along it |
| flame + nova | **Supernova** | a huge blast that leaves a burning field |
| frost + orbit | **Frost Halo** | orbiting blades that freeze on contact |
| frost + gravity | **Glacier** | a slow, huge vortex that freezes everything inside |
| glaive + lightning | **Storm Disc** | boomerangs that arc lightning to nearby foes |
| flame + mines | **Napalm Mine** | mines that leave a burning pool on blast |
| missiles + nova | **Cluster Warhead** | straight-flying (non-homing) warheads that explode into a heavy shockwave, shoving everything in the blast outward (push distance scales with Duration) |
| gravity + venom | **Black Bog** | a vortex that leaves a toxic pool where it forms |
| orbit + venom | **Toxic Halo** | orbiting blades that poison on contact and paint a rotating ring of toxic ground |
| nova + orbit | **Pulsar** | orbiting balls that periodically swarm a random foe — spreading into a ring around it before every ball rushes the center and detonates (target-find range + blast radius scale with Area, ring distance + both the dive and the blast's damage scale with Duration, the wait between attacks shortens with Haste) |
| bolt + frost | **Frost Lance** | a piercing volley of chilling lances; a lance that strikes an already-frozen foe shatters into an icy burst |
| lightning + venom | **Ground Current** | drops a crackling field on a random foe within the player's screen (Duration stretches that leash); every enemy caught inside it becomes its own lightning source and chains out to nearby foes, re-zapping on an interval for as long as the field lasts (hop count scales with level + every Duration power-up picked) |
| lightning + orbit | **Tesla Halo** | orbiting blades that zap nearby foes |
| flame + lightning | **Plasma Storm** | emits a red cloud that drifts in a straight line (aimed at whatever's nearest when it spawns, then locked) until it covers its max travel distance, continuously burning anything it touches and periodically arcing lightning to nearby foes (max travel distance + lifespan scale with Duration, cloud size with Area) |
| glaive + nova | **Cyclone** | whirling glaives around a pulsing core |
| turret + missiles | **Missile Battery** | a deployed launcher firing homing salvos |
| turret + laser | **Beam Sentry** | a deployed turret that sweeps a beam |
| turret + frost | **Cryo Sentry** | a deployed turret firing slowing shots |
| laser + nova | **Plasma Pulse** | drops a ring of light where it's emitted and grows outward — slow at first, then a fast burst past the halfway point; hits harder the farther out it catches a foe (2x base damage at the base max range, more if Area pushes it past that), and re-hits foes who linger in it (pulse rate + re-hit cadence scale with Haste, growth time with Duration, max range + thickness with Area) |
| bolt + missiles | **Flak Battery** | rapid-fire homing flak shells that curve toward foes and burst into shrapnel |
| nova + venom | **Toxic Nova** | a blast that leaves a poison pool |
| turret + orbit/nova/glaive/lightning/flame/mines/gravity/venom | **Halo / Pulse / Glaive / Tesla / Flame / Mine Layer / Singularity / Toxic Turret** | a deployed sentry firing that weapon (TurretNode `mode`) |
| turret + bolt | **Gatling Nest** | a swarm of short-lived, rapid-redeploy mini-turrets that constantly carpet the field |
| frost + nova | **Absolute Zero** | a freezing blast that chills everything caught |
| flame + frost | **Thermal Shock** | a cone that burns and freezes at once |
| gravity + orbit | **Event Horizon** | blades that hold enemies in a crushing ring |
| glaive + gravity | **Vortex Blade** | glaives that drop a small pulling vortex on every hit |
| lightning + nova | **Thunderclap** | a blast that forks lightning out of every hit |
| mines + orbit | **Bouncy Grenade** | a barrage of grenades that bounce between enemies, exploding hardest on the final hop |
| bolt + flame | **Incendiary Rounds** | bolts that ignite the ground on impact, leaving a burning field |
| bolt + orbit | **Scatter Shot** | a ring of bolts fired in all directions |
| bolt + glaive | **Ricochet** | bolts that arc to the next enemy on every hit |
| bolt + gravity | **Gravity Round** | bolts that form a gravity vortex on impact |
| bolt + laser | **Chaingun** | a blazing rapid-fire bolt stream |
| bolt + mines | **Sapper Round** | bolts that arm a proximity mine on impact |
| bolt + venom | **Corrosive Round** | bolts that shatter into a corrosive splash on hit |
| frost + laser | **Cryo Beam** | rotating ice beams that chill everything they sweep (slow scales with dmg) |
| frost + mines | **Glacial Mine** | mines that detonate into a total freeze, completely halting enemies in the blast (freeze duration scales with Duration) |
| frost + missiles | **Cryo Missile** | homing missiles that slow all targets in the blast (slow scales with dmg) |
| frost + venom | **Frostbite** | a pool that chills and poisons everything inside (slow scales with dmg) |
| flame + gravity | **Cinder Vortex** | a vortex that drags enemies into a burning pool at its core |
| gravity + laser | **Accretion Beam** | a vortex ringed by rotating energy beams |
| gravity + lightning | **Storm Vortex** | a vortex that arcs lightning between everything it traps |
| gravity + mines | **Implosion Mine** | a vortex that seeds mines around its collapsing core |
| gravity + missiles | **Carpet Bombing** | marks a random foe's spot with a target zone, then calls in a missile barrage on random points inside it (wave rate scales with Haste, missiles per wave scale with level) |
| glaive + mines | **Shrapnel Mine** | mines that burst into a spray of glaive shrapnel that shuttles back and forth until it fades |
| laser + mines | **Beam Mine** | mines that link sustained laser beams to each other; enemy contact arms a long fuse, still beaming, before it detonates |
| lightning + mines | **Tesla Mine** | mines that chain lightning outward from the blast |
| mines + nova | **Nova Mine** | mines that pulse a second energy blast on detonation |
| mines + venom | **Toxic Mine** | mines that leave a toxic pool on blast |
| flame + glaive | **Inferno Blade** | boomerangs that ignite foes and leave fire pools where they strike |
| flame + laser | **Solar Lance** | a continuous beam of searing light |
| flame + missiles | **Phoenix Rocket** | homing rockets that leave a burning crater on impact |
| flame + orbit | **Blaze Halo** | orbiting blades that ignite on contact and pulse a ring of fire |
| glaive + laser | **Photon Disc** | boomerangs that fire a piercing beam from every hit |
| glaive + missiles | **Rotor Missile** | homing rockets that burst into glaive shrapnel |
| glaive + orbit | **Halo Comet** | orbiting balls that periodically spurt outward like a comet's tail, hitting harder while extended |
| glaive + venom | **Plague Blade** | boomerangs that poison foes and leave toxic pools where they strike |
| laser + lightning | **Ion Storm** | rotating beams that arc lightning to nearby foes |
| laser + missiles | **Beam Battery** | harmless rotating beams paint targets; on cooldown a homing missile volley strikes every painted enemy |
| laser + venom | **Acid Ray** | rotating beams that corrode foes and seed toxic pools |
| lightning + missiles | **EMP Missile** | homing rockets that chain lightning on impact |
| missiles + orbit | **Concorde** | a paper-plane missile, small at first and growing to full size over 3s, that flies a dead-straight line and warps to a random *other* side of the arena (re-aimed at the player) instead of dying at the border — pierces, never stops for a hit, and both its damage and speed climb the whole time it's airborne. Very long cooldown, no population cap; lifetime scales hugely with Duration, max size with Area |
| missiles + venom | **Plague Rocket** | homing rockets that burst into a toxic cloud |

The five mine fusions above all share one pattern (`_MineFusion` in
`weapon_fusions.gd`): the mine's own blast uses normal `(level - 1)` growth,
while the bonus payload it spawns on detonation (shrapnel/beam/chain/nova/pool)
is computed at `(level)` growth — i.e. one level stronger than the mine itself.

### Fusion coverage matrix

✓ = signature fusion implemented (see table above). All 78 pairs covered.

|     | BOL | FLA | FRO | GLA | GRV | LAS | LIG | MIN | MIS | NOV | ORB | TUR | VEN |
|-----|-----|-----|-----|-----|-----|-----|-----|-----|-----|-----|-----|-----|-----|
| BOL |  —  |  ✓  |  ✓  |  ✓  |  ✓  |  ✓  |  ✓  |  ✓  |  ✓  |  ✓  |  ✓  |  ✓  |  ✓  |
| FLA |  ✓  |  —  |  ✓  |  ✓  |  ✓  |  ✓  |  ✓  |  ✓  |  ✓  |  ✓  |  ✓  |  ✓  |  ✓  |
| FRO |  ✓  |  ✓  |  —  |  ✓  |  ✓  |  ✓  |  ✓  |  ✓  |  ✓  |  ✓  |  ✓  |  ✓  |  ✓  |
| GLA |  ✓  |  ✓  |  ✓  |  —  |  ✓  |  ✓  |  ✓  |  ✓  |  ✓  |  ✓  |  ✓  |  ✓  |  ✓  |
| GRV |  ✓  |  ✓  |  ✓  |  ✓  |  —  |  ✓  |  ✓  |  ✓  |  ✓  |  ✓  |  ✓  |  ✓  |  ✓  |
| LAS |  ✓  |  ✓  |  ✓  |  ✓  |  ✓  |  —  |  ✓  |  ✓  |  ✓  |  ✓  |  ✓  |  ✓  |  ✓  |
| LIG |  ✓  |  ✓  |  ✓  |  ✓  |  ✓  |  ✓  |  —  |  ✓  |  ✓  |  ✓  |  ✓  |  ✓  |  ✓  |
| MIN |  ✓  |  ✓  |  ✓  |  ✓  |  ✓  |  ✓  |  ✓  |  —  |  ✓  |  ✓  |  ✓  |  ✓  |  ✓  |
| MIS |  ✓  |  ✓  |  ✓  |  ✓  |  ✓  |  ✓  |  ✓  |  ✓  |  —  |  ✓  |  ✓  |  ✓  |  ✓  |
| NOV |  ✓  |  ✓  |  ✓  |  ✓  |  ✓  |  ✓  |  ✓  |  ✓  |  ✓  |  —  |  ✓  |  ✓  |  ✓  |
| ORB |  ✓  |  ✓  |  ✓  |  ✓  |  ✓  |  ✓  |  ✓  |  ✓  |  ✓  |  ✓  |  —  |  ✓  |  ✓  |
| TUR |  ✓  |  ✓  |  ✓  |  ✓  |  ✓  |  ✓  |  ✓  |  ✓  |  ✓  |  ✓  |  ✓  |  —  |  ✓  |
| VEN |  ✓  |  ✓  |  ✓  |  ✓  |  ✓  |  ✓  |  ✓  |  ✓  |  ✓  |  ✓  |  ✓  |  ✓  |  —  |

BOL bolt · FLA flame · FRO frost · GLA glaive · GRV gravity · LAS laser · LIG lightning ·
MIN mines · MIS missiles · NOV nova · ORB orbit · TUR turret · VEN venom

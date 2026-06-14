# NiceSwarm — Weapon Design Guide

This is the contract every weapon (base **and** fusion) must follow. It exists so the
stat system stays *general*: a player who invests in any stat should feel it on **every**
weapon they own. If a stat does nothing for a weapon, the weapon is wrong — fix the
weapon, don't shrink the stat.

## The 4-stat contract

Player carries four weapon-facing multipliers (`scripts/player.gd`):

| Stat | Field | Every weapon must… |
|------|-------|--------------------|
| **Power** | `damage_mult` | scale damage-per-hit by `damage_mult` |
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

`Enemy` supports two status effects, both host-authoritative:
- `apply_slow(mult, duration)` — frost/ice weapons
- `apply_burn(dps, duration)` — fire/energy weapons, via `ignite()`

## Checklist for a NEW base weapon

1. `extends WeaponBase`; set `weapon_id` + `display_name` in `_init()` (never `@onready`).
2. Damage = `BASE * player.damage_mult * (1.0 + GROWTH * (level - 1))`. With
   `MAX_WEAPON_LEVEL == 3`, GROWTH ≈ 0.3–0.5 so level 3 ≈ a meaningful ceiling.
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
- `Fusions.make(a, b)` — returns the new `WeaponBase` (an inner class in that file).
- Pairs without a signature recipe fall back to a generic `WeaponFused` (both run together).

A fusion weapon follows the **same 4-stat contract**. Build it from existing spawned nodes
where possible (they already carry Area/Duration fields).

### Fusion recipe list

**Implemented (signature) — 78 (all pairs):**

| Pair | Fusion | Behavior |
|------|--------|----------|
| bolt + nova | **Plasma Burst** | slugs that erupt into an AoE blast on impact |
| frost + lightning | **Cryoshock** | a chain that freezes (slow) and burns every link |
| flame + venom | **Toxic Pyre** | a trail of burning toxic pools |
| gravity + nova | **Singularity** | a vortex that collapses into a detonation |
| mines + missiles | **Cluster Bomb** | mines that spray homing rockets on blast |
| laser + orbit | **Prism Halo** | rotating beam-spokes orbiting you |
| frost + glaive | **Glacial Edge** | boomerangs that freeze and bleed |
| bolt + lightning | **Railgun** | a piercing rail-line that electrifies everything along it |
| flame + nova | **Supernova** | a huge blast that leaves a burning field |
| frost + orbit | **Frost Halo** | orbiting blades that freeze on contact |
| frost + gravity | **Glacier** | a slow, huge vortex that freezes everything inside |
| glaive + lightning | **Storm Disc** | boomerangs that arc lightning to nearby foes |
| flame + mines | **Napalm Mine** | mines that leave a burning pool on blast |
| missiles + nova | **Cluster Warhead** | rockets whose splash is a mini-nova |
| gravity + venom | **Black Bog** | a vortex that leaves a toxic pool where it forms |
| orbit + venom | **Toxic Halo** | orbiting blades that poison on contact and paint a rotating ring of toxic ground |
| nova + orbit | **Pulsar** | orbiting blades that each breathe — independently pulsing their own mini-nova as they spin |
| bolt + frost | **Frost Lance** | a piercing volley of chilling lances; a lance that strikes an already-frozen foe shatters into an icy burst |
| lightning + venom | **Plague Arc** | a chain that poisons every link |
| lightning + orbit | **Tesla Halo** | orbiting blades that zap nearby foes |
| flame + lightning | **Plasma Storm** | a searing cone that crackles with chained bolts |
| glaive + nova | **Cyclone** | whirling glaives around a pulsing core |
| turret + missiles | **Missile Battery** | a deployed launcher firing homing salvos |
| turret + laser | **Beam Sentry** | a deployed turret that sweeps a beam |
| turret + frost | **Cryo Sentry** | a deployed turret firing slowing shots |
| laser + nova | **Nova Beam** | sweeping beams that pulse a nova |
| bolt + missiles | **Flak Battery** | rapid-fire homing flak shells that curve toward foes and burst into shrapnel |
| nova + venom | **Toxic Nova** | a blast that leaves a poison pool |
| turret + orbit/nova/glaive/lightning/flame/mines/gravity/venom | **Halo / Pulse / Glaive / Tesla / Flame / Mine Layer / Singularity / Toxic Turret** | a deployed sentry firing that weapon (TurretNode `mode`) |
| turret + bolt | **Gatling Nest** | a swarm of short-lived, rapid-redeploy mini-turrets that constantly carpet the field |
| frost + nova | **Absolute Zero** | a freezing blast that chills everything caught |
| flame + frost | **Thermal Shock** | a cone that burns and freezes at once |
| gravity + orbit | **Event Horizon** | blades that hold enemies in a crushing ring |
| glaive + gravity | **Vortex Blade** | glaives that drop a small pulling vortex on every hit |
| lightning + nova | **Thunderclap** | a blast that forks lightning out of every hit |
| mines + orbit | **Mine Halo** | orbiting blades that fling proximity mines |
| bolt + flame | **Incendiary Rounds** | bolts that ignite the ground on impact, leaving a burning field |
| bolt + orbit | **Scatter Shot** | a ring of bolts fired in all directions |
| bolt + glaive | **Ricochet** | bolts that arc to the next enemy on every hit |
| bolt + gravity | **Gravity Round** | bolts that form a gravity vortex on impact |
| bolt + laser | **Chaingun** | a blazing rapid-fire bolt stream |
| bolt + mines | **Sapper Round** | bolts that arm a proximity mine on impact |
| bolt + venom | **Corrosive Round** | bolts that shatter into a corrosive splash on hit |
| frost + laser | **Cryo Beam** | rotating ice beams that chill everything they sweep (slow scales with dmg) |
| frost + mines | **Glacial Mine** | mines that detonate into a freezing blast (slow scales with dmg) |
| frost + missiles | **Cryo Missile** | homing missiles that slow all targets in the blast (slow scales with dmg) |
| frost + venom | **Frostbite** | a pool that chills and poisons everything inside (slow scales with dmg) |
| flame + gravity | **Cinder Vortex** | a vortex that drags enemies into a burning pool at its core |
| gravity + laser | **Accretion Beam** | a vortex ringed by rotating energy beams |
| gravity + lightning | **Storm Vortex** | a vortex that arcs lightning between everything it traps |
| gravity + mines | **Implosion Mine** | a vortex that seeds mines around its collapsing core |
| gravity + missiles | **Implosion Salvo** | a vortex that launches a salvo of homing missiles |
| glaive + mines | **Shrapnel Mine** | mines that burst into glaive shrapnel on blast |
| laser + mines | **Beam Mine** | mines that pulse laser spokes outward on blast |
| lightning + mines | **Tesla Mine** | mines that chain lightning outward from the blast |
| mines + nova | **Nova Mine** | mines that pulse a second energy blast on detonation |
| mines + venom | **Toxic Mine** | mines that leave a toxic pool on blast |
| flame + glaive | **Inferno Blade** | boomerangs that ignite foes and leave fire pools where they strike |
| flame + laser | **Solar Lance** | a continuous beam of searing light |
| flame + missiles | **Phoenix Rocket** | homing rockets that leave a burning crater on impact |
| flame + orbit | **Blaze Halo** | orbiting blades that ignite on contact and pulse a ring of fire |
| glaive + laser | **Photon Disc** | boomerangs that fire a piercing beam from every hit |
| glaive + missiles | **Rotor Missile** | homing rockets that burst into glaive shrapnel |
| glaive + orbit | **Blade Tempest** | a ring of orbiting blades where one periodically breaks formation, flies out as a glaive, and rejoins the ring on return |
| glaive + venom | **Plague Blade** | boomerangs that poison foes and leave toxic pools where they strike |
| laser + lightning | **Ion Storm** | rotating beams that arc lightning to nearby foes |
| laser + missiles | **Beam Battery** | rotating beams backed by homing rocket fire |
| laser + venom | **Acid Ray** | rotating beams that corrode foes and seed toxic pools |
| lightning + missiles | **EMP Missile** | homing rockets that chain lightning on impact |
| missiles + orbit | **Rocket Halo** | orbiting blades that tag whatever they strike, then a homing missile locks onto the marked target |
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

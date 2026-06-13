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

**Implemented (signature) — 43:**

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
| orbit + venom | **Toxic Halo** | orbiting blades that poison on contact |
| nova + orbit | **Pulsar** | orbiting blades that pulse a nova |
| bolt + frost | **Frost Lance** | a piercing volley of chilling lances |
| lightning + venom | **Plague Arc** | a chain that poisons every link |
| lightning + orbit | **Tesla Halo** | orbiting blades that zap nearby foes |
| flame + lightning | **Plasma Storm** | a searing cone that crackles with chained bolts |
| glaive + nova | **Cyclone** | whirling glaives around a pulsing core |
| turret + missiles | **Missile Battery** | a deployed launcher firing homing salvos |
| turret + laser | **Beam Sentry** | a deployed turret that sweeps a beam |
| turret + frost | **Cryo Sentry** | a deployed turret firing slowing shots |
| laser + nova | **Nova Beam** | sweeping beams that pulse a nova |
| bolt + missiles | **Barrage** | a hail of bolts laced with rocket salvos |
| nova + venom | **Toxic Nova** | a blast that leaves a poison pool |
| turret + bolt/orbit/nova/glaive/lightning/flame/mines/gravity/venom | **Gun / Halo / Pulse / Glaive / Tesla / Flame / Mine Layer / Singularity / Toxic Turret** | a deployed sentry firing that weapon (TurretNode `mode`) |
| frost + nova | **Absolute Zero** | a freezing blast that chills everything caught |
| flame + frost | **Thermal Shock** | a cone that burns and freezes at once |
| gravity + orbit | **Event Horizon** | blades that hold enemies in a crushing ring |
| glaive + gravity | **Vortex Blade** | glaives that drop a pulling vortex on the target |
| lightning + nova | **Thunderclap** | a blast that forks lightning out of every hit |
| mines + orbit | **Mine Halo** | orbiting blades that fling proximity mines |

**Designed, not yet implemented** — none outstanding; ~50 of 78 base pairs now have signature
recipes. Uncovered pairs (and deep/fusion merges) use the generic combined fallback.

For any pair not in the table, the generic fallback keeps the game working; converting a
fallback into a signature is always a safe, self-contained addition.

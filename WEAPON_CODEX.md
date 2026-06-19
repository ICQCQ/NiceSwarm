# NiceSwarm — Weapon Codex

A player-facing reference for every weapon (skill) and every fusion. This is the
**stat & catalogue** view; for the *design contract* (why every weapon must honor all
four stat axes, the new-weapon checklist) see [WEAPON_DESIGN.md](WEAPON_DESIGN.md).

**Source of truth in code:** base numbers live in `scripts/config/weapon_config.gd`
(`WeaponConfig.BASE`), the player-facing blurbs in `scripts/main.gd` (`WEAPON_INFO`), and
the fusion recipes in `scripts/weapons/weapon_fusions.gd` (`Fusions.INFO`). If those change,
this file should be regenerated — don't trust it over the code.

## Run rules

- **5 weapon slots** per run (`MAX_WEAPONS`). Once full, new picks are levels, stats, or merges.
- **Weapon level cap 7** (`MAX_WEAPON_LEVEL`). A weapon at Lv7 becomes **mergeable**.
- **Spawn counts freeze at Lv7** (`count_level()`) — extra projectiles/blades/turrets stop, but
  damage / area / cadence keep scaling with the real level past 7. A fresh **fusion** is born with
  `count_level()` already near max (`FUSION_BORN_COUNT_FLOOR`), so it fires near-max counts at once.
- **Same-kind merges only** (`Fusions.can_merge`): base+base → **signature fusion (T1)**, then
  T1+T1 → **amalgam (T2)**, which is **terminal** — an amalgam never merges again (no base+fusion,
  no amalgam+anything). Both inputs must be the **same tier** and maxed (Lv7).

## Stat upgrades

Every level-up offers a slate of choices. Beyond `[NEW]`/`[LEVEL]`/`[FUSE]` weapon picks,
the pool always salts in `[STAT]` upgrades — global modifiers that touch your whole build.
They split into **four weapon axes** (scale every weapon's math) and **four utility stats**
(scale *you*). Source: `_build_choice_pool` / `apply_choice` in `scripts/main.gd`, caps in
`scripts/config/game_config.gd`.

### How a stat pick stacks

**Every pick multiplies, it does not add.** "+25% Power" means your Power multiplier is
multiplied by `×1.25` — so picks **compound**: pick 1 → ×1.25, pick 2 → ×1.5625, pick 3 →
×1.95… The "+N%" in the upgrade card is the size of *that one* step, not a running total.

Each axis has a **hard cap**. A `[STAT]` only appears in the pool while you're still below
(for Haste, above) its cap, so each axis offers a **finite** number of picks before it stops
being offered. The "picks to cap" column below is how many it takes to bottom/top out.

### The four weapon axes (every weapon honors all four)

| Axis | Player field | Per pick | Cap | Picks to cap | What it scales on every weapon |
|------|--------------|----------|-----|--------------|--------------------------------|
| **Power** | `damage_mult` | `×1.25` (+25% damage) | `6.0` | ~9 | damage per hit on **everything** |
| **Haste** | `rate_mult` | `×0.88` (≈+14% attack speed) | `0.5` (2× faster) | ~6 | cooldown, tick interval, spin speed, per-target re-hit cadence (lower field = faster) |
| **Area** | `area_mult` | `×1.2` (+20% size & reach) | `2.0` | ~4 | **every** spatial dimension — projectile/blast radius, beam length, cone reach, orbit radius, targeting & chain-jump range |
| **Duration** | `duration_mult` | `×1.25` (+25% effect time) | `2.5` | ~5 | lifetimes — projectiles, summons (turrets), trails, fields. Instant weapons instead gain a lingering **burn** (`ignite()`) whose duration scales here |

**Power is special — it folds in two things.** A Power *pick* raises `power_stat` (the field
the cap clamps). But the number weapons actually read, `damage_mult`, is **re-derived every
frame** as:

```
damage_mult = power_stat × (1 + WEAPON_LEVEL_POWER × (party_level − 1))
```

`WEAPON_LEVEL_POWER` is `0.025`, so each **party level** quietly adds +2.5% damage to every
weapon *on top of* your Power picks — no weapon code needed, and bots/puppets stay current
because it's recomputed before any early-return. The `power_stat` cap of `6.0` bounds the
**pick** contribution only; party level keeps scaling past it.

### The four utility stats (scale you, not weapons)

| Stat | Card | Player field | Per pick | Cap | Picks to cap |
|------|------|--------------|----------|-----|--------------|
| **Swift Boots** | +12% move speed | `move_speed` | `×1.12` | `396` (1.8× base 220) | ~6 |
| **Vitality** | +1 max HP and heal 2 | `max_hp` / `hp` | `+1 max, heal 2` | `15` (from base 5) | 10 |
| **Magnet** | +50% pickup range | `pickup_range` | `×1.5` | `270` (3× base 90) | ~3 |
| **Slipstream** | −20% dash cooldown | `dash_cooldown` | `×0.8` | `1.2 s` floor (from base 2.5) | ~4 |

Vitality is the only additive utility stat (flat +1 HP, +2 heal); the other three compound
multiplicatively like the weapon axes. Picks are tracked per-id in `player.stat_levels` and
surfaced as the stacking stat icons on the HUD.

Hover any weapon slot in-game to see its **live DMG, DPS, total damage dealt**, and your
current build's Power/Haste/Area/Duration multipliers — for base weapons *and* fusions.

## Base weapons (13)

`dmg` = damage at Lv1 · `growth` = per-level bonus, so damage = `dmg × (1 + growth×(lvl−1)) × Power` ·
`cd` = recurring cooldown / tick / re-hit interval in seconds (`× Haste` at runtime).

| Weapon | id | dmg | growth | cd | Type | Behavior · level scaling |
|--------|----|-----|--------|----|------|--------------------------|
| **Bolt** | `bolt` | 2.0 | 0.345 | 0.8 | Phys | auto-fires at the nearest enemy · +1 projectile, more damage |
| **Orbit Blades** | `orbit` | 2.0 | 0.46 | 0.45ʳ | Phys | blades circle you, shredding nearby foes · +1 blade, more damage |
| **Nova Pulse** | `nova` | 3.0 | 0.575 | 3.5 | Energy | periodic blast hits everything around you · bigger radius, more damage; **echo pulses at Lv5+** (1/2/3 extra shockwaves at Lv5/6/7) |
| **Boomerang Glaive** | `glaive` | 2.5 | 0.345 | 1.6 | Phys | piercing glaive flies out and returns · extra glaive at Lv2/3, more damage |
| **Chain Lightning** | `lightning` | 2.0 | 0.46 | 2.2 | Energy | zaps a foe, arcs to nearby enemies · +1 chain, more damage |
| **Flame Cone** | `flame` | 0.6 | 0.46 | 0.15ᵗ | Fire | torches everything in front of you · longer, hotter flames; **cone widens past Lv3** |
| **Proximity Mines** | `mines` | 6.0 | 0.575 | 2.0 | Phys | drops mines that blast nearby enemies · +1 mine, bigger blasts |
| **Homing Missiles** | `missiles` | 3.0 | 0.345 | 2.4 | Phys | seeking rockets with splash damage · +1 missile, more damage |
| **Sweep Laser** | `laser` | 1.2 | 0.46 | 0.3ʳ | Energy | beams sweep around you · **1→4 evenly-spread beams** (2 at Lv3, 3 at Lv5, 4 at Lv7), longer beam |
| **Frost Shards** | `frost` | 1.5 | 0.345 | 1.8 | Ice | piercing shards that chill enemies · +1 shard, more damage |
| **Gravity Well** | `gravity` | 1.0 | 0.575 | 6.0 | Energy | vortex drags the swarm together · wider, stronger pull; **+1 simultaneous well at Lv4 & Lv6** (up to 3) |
| **Sentry Turret** | `turret` | 1.5 | 0.46 | 6.5 | Phys | deployable turret fights for you · longer uptime; 2nd turret at Lv3 |
| **Venom Trail** | `venom` | 1.2 | 0.46 | 0.5ᵈ | Phys | leave toxic puddles as you move · bigger, deadlier puddles; **wider carpet past Lv3** (2nd puddle Lv3, 3rd Lv6) |

ʳ `cd` = per-enemy re-hit interval · ᵗ `cd` = tick interval · ᵈ `cd` = puddle-drop interval.

**Deployed-fusion base** — `sentry` (dmg 2.16, growth 0.46, cd 4.5): the shared base for the
turret-family fusions below (a Lv1 sentry already matches a Lv3 base turret, so fusing isn't a
downgrade).

## Fusions (78 — every weapon pair)

Merging two **Lv7** weapons consumes both and produces **one distinct new weapon** in a single
slot (freeing a slot). Every fusion honors the same four stat axes. Pairs are listed
alphabetically by result name; the same data backs the `[FUSE]` upgrade pick text in-game.

**A signature fusion is born at the combined power of its two Lv7 components — never a downgrade.**
Its Lv1 is *designed* from the two maxed weapons it consumed: it fires near-max **counts**
(`FUSION_BORN_COUNT_FLOOR`), opens at near-max **area** (ring/beam/blast sizes), and each
sub-action hits at its source weapon's **Lv7 damage** (a nova-fusion's ring ≈ maxed Nova, a
lightning-fusion's chains ≈ maxed Chain Lightning, etc.). From there it grows **gently** with
level (`GameConfig.FUSION_LEVEL_GROWTH`, ~×1.5 by Lv7 — not a base weapon's ~×3.4), since it's
already full-power at birth. Tuning knobs all live in `GameConfig` (`FUSION_LEVEL_GROWTH`,
`FUSION_BORN_DMG`, `FUSION_BORN_COUNT_FLOOR`). See [docs/balance/FUSION_REDESIGN.md].

Integer level still climbs 1..Lv7, which **gates the next merge**: the `[MERGE]` pool only offers
**maxed** weapons, so a signature fusion must be leveled to `MAX_WEAPON_LEVEL` before it can be
amalgamated — only a maxed-out fusion fuses on.

The generic **Amalgam** (deeper merges / uncovered pairs) keeps **both component weapons running**
as one slot. Leveling the amalgam buffs **all of its components' stats** by
`GameConfig.AMALGAM_STAT_PER_LEVEL` (+5%) per level (the components were maxed when merged, so this
flat all-stat boost is its scaling axis rather than re-leveling each part).

| Pair | Fusion | Behavior |
|------|--------|----------|
| frost + nova | **Absolute Zero** | a freezing blast that chills everything caught |
| gravity + laser | **Accretion Beam** | a vortex ringed by rotating energy beams |
| laser + venom | **Acid Ray** | rotating beams that corrode foes and seed toxic pools |
| laser + missiles | **Beam Battery** | harmless rotating beams paint targets; on cooldown, every painted enemy takes a homing, fire-bursting missile |
| laser + mines | **Beam Mine** | mines that link sustained laser beams to each other; enemy contact arms a long fuse, still beaming, before it detonates |
| laser + turret | **Beam Sentry** | a deployed turret that sweeps a beam |
| gravity + venom | **Black Bog** | a vortex that leaves a toxic pool where it forms |
| glaive + orbit | **Halo Comet** | orbiting balls that periodically spurt outward like a comet's tail, hitting harder while extended |
| flame + orbit | **Blaze Halo** | orbiting blades that ignite on contact and pulse a ring of fire |
| bolt + laser | **Charge Round** | charges up a heavy piercing round that punches through every enemy in its path; charge time shortens with Haste, range and bullet size scale with Duration and Area |
| flame + gravity | **Cinder Vortex** | a vortex that drags enemies into a burning pool |
| mines + missiles | **Cluster Bomb** | mines that spray homing rockets on blast |
| missiles + nova | **Cluster Warhead** | straight-flying warheads that erupt into a heavy shockwave, shoving everything in the blast outward |
| bolt + venom | **Corrosive Round** | bolts that shatter into a corrosive splash on hit |
| frost + laser | **Cryo Beam** | rotating ice beams that chill everything they sweep |
| frost + missiles | **Cryo Missile** | homing missiles that slow all targets in the blast |
| frost + turret | **Cryo Sentry** | a deployed turret firing slowing shots |
| frost + lightning | **Cryoshock** | a chain that freezes and burns every link |
| glaive + nova | **Cyclone** | whirling glaives around a pulsing core |
| lightning + missiles | **EMP Missile** | homing rockets that chain lightning on impact |
| gravity + orbit | **Event Horizon** | blades that hold enemies in a crushing ring |
| bolt + missiles | **Flak Battery** | rapid homing flak shells that curve toward foes and burst into shrapnel |
| flame + turret | **Flame Turret** | a deployed turret breathing a fire cone |
| frost + orbit | **Frost Halo** | orbiting blades that freeze on contact |
| bolt + frost | **Frost Lance** | a piercing volley of chilling lances that shatter already-frozen foes |
| frost + venom | **Frostbite** | a pool that chills and poisons everything inside |
| bolt + turret | **Gatling Nest** | a swarm of short-lived, rapid-redeploy mini-turrets carpeting the field |
| frost + glaive | **Glacial Edge** | boomerangs that freeze and bleed |
| frost + mines | **Glacial Mine** | mines that detonate into a total freeze, completely halting enemies in the blast |
| frost + gravity | **Glacier** | a slow, huge vortex that freezes everything inside |
| glaive + turret | **Glaive Turret** | a deployed turret hurling boomerang glaives |
| bolt + gravity | **Gravity Round** | bolts that form a gravity vortex on impact |
| orbit + turret | **Halo Turret** | a deployed turret ringed with whirling blades |
| gravity + mines | **Implosion Mine** | a vortex that seeds mines around its collapsing core |
| gravity + missiles | **Carpet Bombing** | marks a random foe's spot with a target zone, then calls in a missile barrage on random points inside it (missiles per wave scale with level) |
| bolt + flame | **Incendiary Rounds** | bolts that ignite the ground on impact, leaving a burning field |
| flame + glaive | **Inferno Blade** | boomerangs that ignite foes and leave fire pools where they strike |
| laser + lightning | **Ion Storm** | rotating beams that arc lightning to nearby foes |
| mines + orbit | **Bouncy Grenade** | a barrage of grenades that bounce between enemies, exploding hardest on the final hop |
| mines + turret | **Mine Layer** | a deployed turret seeding proximity mines |
| missiles + turret | **Missile Battery** | a deployed launcher firing homing salvos |
| flame + mines | **Napalm Mine** | mines that leave a burning pool on blast |
| laser + nova | **Plasma Pulse** | drops a ring of light that grows outward slowly at first then in a fast burst, hitting harder the farther out it catches a foe — re-hits foes who linger in it |
| mines + nova | **Nova Mine** | mines that pulse a second energy blast on detonation |
| flame + missiles | **Phoenix Rocket** | homing rockets that leave a burning crater on impact |
| glaive + laser | **Photon Disc** | boomerangs that fire a piercing beam from every hit |
| lightning + venom | **Ground Current** | a crackling field where every enemy caught inside becomes its own lightning source, chaining to nearby foes |
| glaive + venom | **Plague Blade** | boomerangs that poison foes and leave toxic pools where they strike |
| missiles + venom | **Plague Rocket** | homing rockets that burst into a toxic cloud |
| bolt + nova | **Plasma Burst** | slugs that erupt into a blast on impact |
| flame + lightning | **Plasma Storm** | a drifting red cloud that burns on contact and arcs lightning to nearby foes |
| laser + orbit | **Prism Halo** | prisms drop around you, linked to you and each other by damage beams |
| nova + orbit | **Pulsar** | orbiting balls that periodically swarm a random foe, ring around it, then rush in and detonate |
| nova + turret | **Pulse Turret** | a deployed turret that pulses novas |
| bolt + lightning | **Railgun** | a piercing rail-shot that electrifies its whole line |
| bolt + glaive | **Ricochet** | bolts that arc to the next enemy on every hit |
| missiles + orbit | **Concorde** | a growing paper-plane missile that warps to the far side of the arena instead of dying at the border, flying until a very long lifetime runs out |
| glaive + missiles | **Rotor Missile** | homing rockets that burst into glaive shrapnel |
| bolt + mines | **Sapper Round** | bolts that arm a proximity mine on impact |
| bolt + orbit | **Scatter Shot** | a ring of bolts fired in all directions |
| glaive + mines | **Shrapnel Mine** | mines that burst into a spray of glaive shrapnel that shuttles back and forth until it fades |
| gravity + nova | **Singularity** | a vortex that yanks enemies inward every second, then collapses into a detonation that hits harder the more enemies it caught |
| gravity + turret | **Singularity Turret** | a deployed turret dropping gravity wells |
| flame + laser | **Solar Lance** | a continuous beam of searing light |
| glaive + lightning | **Storm Disc** | boomerangs that arc lightning to nearby foes |
| gravity + lightning | **Storm Vortex** | a vortex that arcs lightning between everything it traps |
| flame + nova | **Supernova** | a huge blast that leaves a burning field |
| lightning + orbit | **Tesla Halo** | orbiting blades that zap nearby foes |
| lightning + mines | **Tesla Mine** | mines that chain lightning outward from the blast |
| lightning + turret | **Tesla Turret** | a deployed turret that chains lightning |
| flame + frost | **Thermal Shock** | a cone that burns and freezes for thermal stress |
| lightning + nova | **Thunderclap** | a blast that forks lightning out of every hit |
| orbit + venom | **Toxic Halo** | orbiting blades that poison on contact and paint a rotating ring of toxic ground |
| mines + venom | **Toxic Mine** | mines that leave a toxic pool on blast |
| nova + venom | **Toxic Nova** | a blast that leaves a poison pool |
| flame + venom | **Purgatory** | an eerie field that burns and marks foes inside it -- marked enemies take extra damage, slow harder, and can't burn out |
| turret + venom | **Toxic Turret** | a deployed turret pooling venom around it |
| glaive + gravity | **Vortex Blade** | glaives that drop a small pulling vortex on every hit |

Pairs without a signature recipe (none today — all 78 are covered) would fall back to a generic
**Amalgam** that simply runs both component weapons together in one slot.

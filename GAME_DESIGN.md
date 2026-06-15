# NiceSwarm — Game Design Document

A holistic design overview of NiceSwarm as it currently exists in code. For the
deep catalogues see [WEAPON_DESIGN.md](WEAPON_DESIGN.md) (the 4-stat contract + every
fusion) and [ENEMY_DESIGN.md](ENEMY_DESIGN.md) (every enemy class/tier + boss mechanics).
Architecture and build/run commands live in [CLAUDE.md](CLAUDE.md); status + history in
[PLAN.md](PLAN.md); the late-game perf model in [PERFORMANCE.md](PERFORMANCE.md).

> Genre: top-down arena-survival roguelite (Vampire-Survivors-like), online co-op.
> Engine: Godot 4.6, pure GDScript, everything built in code and drawn with `_draw()`
> (no art assets). One scene file (`scenes/main.tscn`); a single 10-minute run.

---

## 1. Design pillars

1. **You move, your weapons fight.** All weapons auto-fire; the player's only verb is
   *movement* (+ a dash). Skill is positioning, dodging telegraphs, and build choices.
2. **A build comes together in 10 minutes.** Short runs, fast dopamine early, a clear
   power fantasy by the end — capped at 5 weapon slots so every pick matters.
3. **Fusion is the payoff.** Two maxed weapons combine into a *distinct new weapon*;
   merge options are biased to always appear once eligible.
4. **The game pushes back when you're winning.** Difficulty is adaptive: clear fast and
   it escalates (heat); crush the map mid-game and it surges (heat-spike); get
   overwhelmed and it eases off.
5. **Co-op is the same game, shared.** Host-authoritative netcode; shared XP/level,
   separate HP/builds, revive-your-ally teamwork.

---

## 2. Core loop

```
move + dodge → weapons auto-kill enemies → enemies drop XP gems → gems pull to you
→ party levels up → everyone picks 1 upgrade (weapon / level / fuse / stat)
→ enemies get tougher & more varied → survive to 10:00 = win
```

A run escalates on two independent axes (see §6): enemy **variety/population** grows on a
fixed schedule, while enemy **toughness** accelerates when the party is doing well.

---

## 3. Controls

| Input | Action |
|-------|--------|
| WASD / arrows | Move |
| SPACE / SHIFT | Dash (brief i-frames; shrugs off disrupt zones) |
| 1–6 | Pick an upgrade (number of options is configurable) |
| ESC | Open the in-game menu — pauses the whole run for **every** player (resume = ESC again) |
| M | Main menu (from pause / game-over) |
| R | Restart (host, at game-over) |

---

## 4. Run structure & objective

- **Win:** survive **`WIN_TIME` = 600 s** (10 minutes).
- **Lose:** the **whole party is downed** at once.
- **Downed/revive:** at 0 HP a player is *downed*, not dead. An ally standing within
  **70 px** revives them over **3 s** (progress decays slowly — ~7%/s — if the helper
  steps away). Revive restores **50% max HP** + 2 s of invulnerability. Run ends only
  when everyone is down simultaneously.
- **Start of run:** each player picks **1 of 3** random starting weapons.

---

## 5. Progression & economy

### Party XP and levels
XP and level are **shared by the whole party** — anyone's gem pickup advances everyone.
The cost AT level `L` to reach `L+1` is **exponential** (`GameConfig.xp_for_level`):

```
xp_needed(L) = max(1, round( XP_BASE * XP_GROWTH^(L-1) / (cfg_xp_rate * XP_GAIN_MULT) ))
```
`XP_BASE = 5`, `XP_GROWTH = 1.12` (each level costs 1.12× the last → gentle early, steep late),
and the effective rate is `cfg_xp_rate` (menu) × `XP_GAIN_MULT` (0.5 base). At the default rate
the shown costs are L1≈10, L20≈86, L30≈267, L45≈1462 — leveling compounds, so high levels are
genuinely earned. On level-up the game pauses
and **every player picks their own** upgrade; the run resumes once all have picked
(banked XP / queued chests chain straight into another pick).

### The upgrade pick (categories, colour-coded)
`_build_choice_pool` offers up to `cfg_choices` (2–6) options drawn from:

| Tag | Colour | Meaning |
|-----|--------|---------|
| `[NEW]` | green | learn a weapon you don't own (while < `MAX_WEAPONS` = 5) |
| `[Lv n]` | blue | level an owned weapon (cap `MAX_WEAPON_LEVEL` = 7) — adds damage + counts |
| `[FUSE]` | gold | combine two maxed weapons into a **signature** new weapon |
| `[AMALGAM]` | orange | combine two maxed weapons with no recipe → generic `WeaponFused` |
| `[STAT]` | pale | a passive stat boost (below) |

**Fusion bias:** whenever any merge is eligible, one merge option is guaranteed a slot.

### Passive stats
Eight passives, multiplicative (so early picks matter most). The four **weapon** stats
are the universal contract every weapon honours (see §7):

Each is **capped** (the pick stops being offered, and the value is clamped, at the cap —
see `GameConfig.STAT_CAP_*`):

| Pick | Effect | Cap |
|------|--------|-----|
| Power (`st_power`) | `power_stat ×1.25` | **×6** |
| Haste (`st_rate`) | `rate_mult ×0.88` (faster cadence) | **1.8× faster** (`rate_mult ≥ 1/1.8`) |
| Area (`st_area`) | `area_mult ×1.2` (all spatial dims) | **×1.75** |
| Duration (`st_duration`) | `duration_mult ×1.25` (lifetimes) | **×1.75** |
| Swift Boots (`st_speed`) | `move_speed ×1.12` | **1.8× (396)** |
| Vitality (`st_hp`) | +1 max HP, heal 2 | **15 max HP** |
| Magnet (`st_magnet`) | `pickup_range ×1.5` | **3× (270)** |
| Slipstream (`st_dash`) | `dash_cooldown ×0.8` | `≥ 1.2 s` |

### Weapon base power scales with party level
Every weapon's base damage is multiplied by `(1 + WEAPON_LEVEL_POWER·(party_level − 1))`
on top of its own Lv1→3 growth and the player's Power picks (see `player._physics_process`,
which derives `damage_mult` from `power_stat` each frame). This keeps weapons you never pour
level-ups into — and the off-build half of a fusion — paying their way as enemy HP scales.
At ~L45 that's ≈2.1× base damage (dialed back from 0.04 to curb the late-game snowball);
a single tunable knob (FF/lethality-probe calibrated).

### Weapon → fusion slot economy
5 slots, level cap 7. Hit Lv7 on two weapons and you can **fuse** them: removes 2, adds 1
(frees a slot). Fusion depth is **capped at `MAX_FUSION_TIER` = 3**: two base weapons fuse to
a tier-1 fusion; two T1s fuse to a T2; two T2s fuse once more into a **final tier-3** fusion that
can never be merged again. Fused weapons still level as a unit. Breadth (many weapons) vs
depth (few, deeply fused) is the central build tension; the cap keeps a single slot's power
bounded. The cap is enforced both in the pick pool and in `player.merge_weapons`
(`Fusions.can_merge`).

### Drops & pickups
- **XP gems** drop from every non-shard kill (value = the enemy's `xp` stat). They pull to
  the nearest player within `pickup_range` (90 px base), accelerating to 760 px/s.
- **Pickups** (tanks drop one ~70%; rarely any enemy drops a heart):
  - **heart** — heal 2 · **bomb** — 30 dmg to everything within 850 px ·
    **magnet** — vacuum all gems · **chest** — a free upgrade pick.
- **Elites/bosses always drop a chest** → in co-op, *every* player gets a free pick.

---

## 6. Difficulty & pacing — the adaptive model

The host runs **two independent difficulty tracks** (`scripts/core/spawner.gd`). Both
climb at the same base rate `DIFF_BASE` (1/48) times an early-game `warmup()` brake
(`clamp(0.25 + elapsed/80, 0.25, 1)` — a gentle first ~80 s):

- **`pace`** — *time only, never accelerated.* Drives enemy **variety** (the `class_tier`
  ceiling) and target **population** (`desired_pop`). A skilled/fast party does **not**
  get buried under more enemy *types or numbers* than the run "should" have yet.
- **`difficulty`** — *accelerated by heat + party level.* Drives how **tough** each enemy
  is to kill: `hp = (hp0 + difficulty·hpk)·party`, `speed = spd + difficulty·spdk`,
  `dmg = dmg + difficulty/12`. Being ahead of the curve means **tougher** monsters, not
  *more/rarer* ones.

```
pace        += dt · DIFF_BASE · warmup
difficulty  += dt · DIFF_BASE · warmup · (1 + heat·2.4 + heat_spike·1.0 + (level-1)·0.02)
```

### Heat (clear-rate accelerator)
`heat = clamp((kills/sec_EMA − spawns/sec) / (spawns/sec·2 + 1), 0, 1)` — 0 when you're
just keeping pace, →1 the faster you clear beyond the spawn rate. It **rises fast (0.7/s)
and decays slowly (0.05/s)** so a brief lull doesn't reset the pressure.

### Heat-spike (mid-game crush reward)
Once past **`MID_GAME_TIME` = 300 s**, if live population drops below **20%** of
`desired_pop` (you're shredding everything), `heat_spike` grows **exponentially**
(rate 1.8/s, capped at 5) and feeds the `difficulty` climb hard — a deliberate spike that
punishes near-clearing the arena late. It decays (2/s) as the map refills.

### Overwhelmed relief
If the field is packed (`> 1.4× desired_pop`) **and** you're barely clearing
(`clear_ema < 0.7× spawn_rate`), heat is forced toward 0 and decays faster (0.35/s) —
the game eases the *acceleration* when you're drowning.

### Spawning
- **Interval** lerps `1.4 → 0.2 s` over the first 9 min, divided by party size, and is
  cut to **40%** while below `desired_pop` (refill). `desired_pop` grows with `pace`,
  clamped to `ENEMY_CAP − 20` (cap = 220 live enemies).
- **Normal pool** (`SPAWN_POOL`): weighted, time-unlocked — brawler (staple) → rusher
  (0:45) → wisp (1:30) → warden (2:00) → sentinel (2:30) → burster (3:00) → disruptor
  (3:30) → defiler (5:00).
- **Specials** (`SPAWN_SPECIALS`): tank every 45 s (from 1:30); elite every **75→32 s**
  and caster every **20→11 s** (intervals tighten with heat) from 2:00/2:30.
- **Bosses:** a `boss`-class enemy spawns after **60 total kills**, then every **+90**
  kills, escalating boss tier (Juggernaut → Harbinger → Eclipse). See ENEMY_DESIGN.md.
- **Bouncers:** a *separate* population from 2:45, with its own growing cap
  (`2 + pace`), topped up every 2 s — never counted toward `desired_pop`/overwhelmed.

### Config knobs (host sets in the menu, broadcast to all)
- **Options/level-up** `cfg_choices` ∈ {2,3,4,5,6} (default 3)
- **XP rate** `cfg_xp_rate` ∈ {0.5,1,1.5,2,3,5}× (divides `xp_needed`)
- **Enemy scale** `cfg_enemy_scale` ∈ {0.75,1,1.25,1.5}× (×hp, partial ×speed)

---

## 7. Combat & weapons

Every weapon auto-fires and **must honour all four stats** (the contract enforced in
[WEAPON_DESIGN.md](WEAPON_DESIGN.md)): **Power** (`damage_mult`), **Haste** (`rate_mult`,
cadence), **Area** (`area_mult`, *every* spatial dimension), **Duration**
(`duration_mult`, lifetimes; instant weapons leave a `ignite()` burn). Damage = `base ×
damage_mult × (1 + growth·(level−1))`.

**13 base weapons:** bolt, orbit, nova, glaive, lightning, flame, mines, missiles, laser,
frost, gravity, turret, venom. **Damage types** PHYS/FIRE/ICE/ENERGY are tagged on hits;
enemies can be immune to one. **Fusions:** every one of the 78 weapon pairs has a
signature recipe (distinct new weapon); deep/uncovered merges fall back to the generic
combined `WeaponFused`. Full weapon + fusion catalogue: **WEAPON_DESIGN.md**.

---

## 8. Enemies

Enemies are organised into **archetype classes**, each an ordered list of **tiers** where a
higher tier is a direct upgrade; which tier spawns rises with `pace`. Behaviours include
chase / wander / bounce / straight movement, armour (`resist`), elemental immunity,
pull/CC immunity, phasing, death-bursts (Bursters spit shard bullets), and **casters** that
telegraph synced AoE strikes (lead / line / ring patterns; damage / disrupt / lingering
field effects). **Bosses** (Juggernaut, Harbinger, Eclipse) add slam patterns, an enrage
resist ramp, cycling elemental immunity, and summons. Full roster, stats, and the
add-a-class checklist: **ENEMY_DESIGN.md**.

---

## 9. Co-op (online / LAN, up to 4)

Host-authoritative: the **host simulates everything** (AI, damage, XP, pickups, revives,
spawns). Clients send their position/facing/dash (20 Hz) and upgrade picks; the host
broadcasts chunked full-snapshot world state (enemies 12 Hz, items/telegraphs 8 Hz, HUD +
pings 4 Hz). Each entity is a compact **10-byte record** — `u32 id | s16 x×16 | s16 y×16 |
u16 f` — positions ×16 fixed-point (1/16 px, lossless to the eye since clients lerp puppets
to the target); ~235 kbps/client for a full 220-enemy field. Sent **unreliable**; removal-
by-diff drives death pops. Clients run weapons **cosmetically** (real damage is host-only)
and show enemies as position-lerped puppets. **Solo is the identical code path** with no
peer. Shared XP/level (level-up waits for *all* to pick), separate HP/builds, party-scaled
enemy hp/spawn-rate, ally HUD + off-screen arrows, team chests. Port 24565 (configurable).

**Pause:** any player opening their in-game menu (ESC) pauses the whole run for everyone
(host-authoritative); it stays paused while *any* player's menu is open, resuming with an
alert cue once the last closes (no countdown). **Rejoin:** a disconnected player is ghosted
for a few seconds; a returning client reclaims its slot by saved peer-id, or — for a
brand-new game instance — by matching its player **name**, recovering the character's
weapons/levels. **Ping:** the host measures each peer's ENet round-trip and broadcasts it
for the HUD.

---

## 10. Presentation

No art assets — every entity draws itself with vector `_draw()`. **Player visibility:**
each player draws a pulsing "grow" ring in their colour and renders above the whole world
(`z_index = 100`) so the glyph, ring, and name tag are never buried in the swarm; ally name
tags show the character glyph + name (in the player's colour) + ping. **HUD:** the ally
list (a RichTextLabel) and the end-game scoreboard show each player's real name prefixed by
their character glyph, in their colour (scoreboard ranks by damage). **Juice:** damage
numbers, knockback, kill pops, screen shake, telegraph flashes. **Audio:** `sfx.gd`
synthesises ~25 sounds at startup (no files); each weapon/pickup/dash/hit/level-up/merge/
resume cue has a distinct positional voice, throttled per-name so tick weapons don't stack.

---

## 11. Key constants (in `scripts/config/`)

| Const | Value | Meaning |
|-------|-------|---------|
| `WIN_TIME` | 600 s | run length |
| `MAX_WEAPONS` / `MAX_WEAPON_LEVEL` | 5 / 7 | slots / level cap before fuse |
| `MAX_FUSION_TIER` | 3 | fusion depth cap: base+base→T1, T1+T1→T2, T2+T2→T3 (final) |
| `WEAPON_LEVEL_POWER` | 0.025 | weapon base damage ×(1 + this·(party_level−1)) |
| `XP_GAIN_MULT` | 0.5 | base XP-gain multiplier (half leveling speed) |
| `ENEMY_CAP` | 220 | hard live-enemy limit |
| `DIFF_BASE` | 1/45 | base difficulty climb rate |
| `ENEMY_SPEED_DIFF_SCALE` / `ENEMY_HP_DIFF_SCALE` | 0.025 / 0.04 | enemy speed/hp ×(1 + diff·this) — break the late-game kite |
| `ENEMY_HP_PER_LEVEL` | 0.05 | base enemy hp ×(1 + this·(party_level−1)) — tankier as the party levels (≈×3.4 by L48) |
| `CC_IMMUNE_TIER` | 2 | tier-index ≥ this (the 3rd tier) + bosses resist knockback & gravity suck-in |
| `BOSS_FIGHT_SECONDS` / `BOSS_DPS_WINDOW` | 8 / 15 s | boss hp ≈ recent_dps·FIGHT (DPS over the last WINDOW s) |
| `BOSS_HP_PER_LEVEL` / `BOSS_HP_PER_PLAYER` | 0.015 / 0.5 | boss hp ×(1+·(level−1))·(1+·(N−1)) on top of the DPS term |
| `SPAWN_INTERVAL_START` / `_END` | 0.2 / 0.024 | spawn cadence (ramped in over `DIFF_WARMUP_SECS`); dense flood late |
| `SPAWN_RING_MIN` / `_MAX` / `SPAWN_SAFE_RADIUS` | 300 / 1200 / 250 | spawn-distance band + closest allowed spawn |
| `POS_SCALE` | 16 | world-state x,y fixed-point scale (1/16 px); 10-byte/entity wire record |
| `DIFF_HEAT` / `DIFF_SPIKE` / `DIFF_LEVEL` | 3.12 / 1.0 / 0.02 | climb accelerators |
| `DIFF_LEVEL_STEP` | 0.05 | flat difficulty added per level-up |
| `MID_GAME_TIME` | 300 s | earliest heat-spike arm time |
| `HEAT_SPIKE_GROWTH` / `_MAX` | 1.8 / 5.0 | exponential spike rate / cap |
| `BOSS_KILL_BASE` / `_INTERVAL` | 60 / 90 | kills to first boss / between bosses |
| `BOUNCER_UNLOCK` | 165 s | when bouncers start |

Tuning lives in `GameConfig` (run/difficulty/spawn), `EnemyConfig` (`CLASSES`,
`SPAWN_POOL`, `SPAWN_SPECIALS`), and `WeaponConfig.BASE` (per-weapon dmg/growth/cd).

---

## 12. Document map

| Doc | Owns |
|-----|------|
| **GAME_DESIGN.md** (this) | holistic design: loop, pacing, progression, economy, co-op |
| [WEAPON_DESIGN.md](WEAPON_DESIGN.md) | the 4-stat contract + all weapons & fusions |
| [ENEMY_DESIGN.md](ENEMY_DESIGN.md) | every enemy class/tier + boss mechanics |
| [CLAUDE.md](CLAUDE.md) | architecture, file map, build/run/test commands |
| [PERFORMANCE.md](PERFORMANCE.md) | late-game perf model (enemy grid, no enemy-enemy collision) |
| [PLAN.md](PLAN.md) | milestone status + session log |
| [docs/balance/BALANCE_PLAN.md](docs/balance/BALANCE_PLAN.md) | the in-progress XP-curve / waves / gem-cap overhaul |

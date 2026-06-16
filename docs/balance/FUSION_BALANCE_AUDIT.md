# Fusion Balance Audit (2026-06-17)

Static source analysis of all **78 fusion weapons** at a Lv1 reference point
(`fuse_damage/rate/area/duration` all = 1.0). Directional — good for *picking
targets*; confirm final magnitudes by sim/playtest before shipping. Produced by 3
parallel analysts; see [SOLO_BALANCE_SIM.md](SOLO_BALANCE_SIM.md) for the live harness.

Yardstick: a healthy tier-1 fusion ≈ **3–6 effective single-target DPS**, or lower
direct DPS if it brings strong AoE/CC/DoT.

## 🔻 NERF — over-tuned

| Weapon | Eff. DPS | Why |
|---|---|---|
| **Turret family** (VERIFIED below) | ~7–21 | Whole family above yardstick; 5 modes stack a free full-damage bolt gun. |
| **Solar Lance** | ~9 | Continuous hitscan line, no cooldown gate. |
| **Photon Disc** | ~7.3 | Fast 1.1s glaives, each fires a piercing beam. |
| **Plasma Storm** | ~6.6 | 160r cone every 0.14s **+** chain bolts. |
| **Pulsar / Rocket Halo** | ~6.3 / ~5.9 | Top of the orbit class, no offsetting weakness. |

## 🔺 BUFF — under-tuned

| Weapon | Eff. DPS | Why |
|---|---|---|
| **Vortex Blade** | **~0.4** | Glaives deal **0 direct damage**; tiny wells do nothing — worst in game. |
| **Glacier** | ~0.2 | Pure freeze; trivial damage, no payoff burst. |
| **Black Bog** | ~0.4 | Weakest gravity fusion — no detonation unlike Singularity. |
| **Glacial Edge** | ~1.8 | **0 direct damage**, burn-DoT only. |
| **Storm Disc** | ~2.25 | **0 direct damage**, relies entirely on the arc. |
| **Absolute Zero** | ~1.0 | Weak 30% slow, low direct. |
| **Ion Storm / Acid Ray** | ~1.3 / ~1.4 | Rotating-beam sweep too slow to re-hit. |
| **Cinder Vortex / Thunderclap** | ~1.1 | Low CC/AoE payoff for the cost. |
| minor: Cryo Beam, Ricochet, Gravity Round, Implosion Salvo, Flak Battery | floor | **[Applied 2026-06-17]** Cryo Beam spin 1.6→2.4 + slow 1.0s; Ricochet cd 1.0→0.8; Gravity Round dmg 2.2→2.8 cd 1.4→1.1; Implosion Salvo dmg 2.6→3.0 cd 5.8→4.5; Flak Battery dmg 1.0→1.2 splash 36→44. |

## Patterns
- **"0-direct-damage" weapons** (Vortex Blade, Glacial Edge, Storm Disc) all
  underperform for the same reason — give each a small direct hit.
  **[Applied 2026-06-17: Glacial Edge & Storm Disc glaives +`dmg×0.6` direct; Vortex Blade glaives +~2.0 direct, well kept.]**
- **Gravity/vortex fusions** (Glacier, Black Bog, Cinder Vortex) trade *all* damage
  for CC and fall below a utility floor — add a detonation/burst payoff or lower cd.
  **[Applied 2026-06-17: Glacier well 1.2→2.5 + cd 6→5; Black Bog well 0.96→1.5, puddle 1.2→1.6/tick, cd 5.5→4.5; Cinder Vortex pool 0.6→0.9/tick, burn 0.7→0.9, cd 5.5→4.5. Also: Absolute Zero slow 30%→50% + cd 3→2.4; Ion Storm spin 1.8→2.8; Acid Ray spin 1.6→2.4 + dmg 1.0→1.3; Thunderclap cd 2.8→2.2.]**
- **Mechanics note (verified):** `VenomPuddle.damage` is **per-tick** (0.4s → ×2.5 DPS); `GravityWell.damage` lands **once per enemy** (CC value is the pull/freeze/zone, not the well hit).


## Turret Family — verified math (2026-06-17)

Deploy cap = `count_level()+2` = **3 turrets at Lv1** (Gatling overrides to `+5` = **6**).
Turret life 6.5s; deploy cd = `sentry.cd(4.5) / cap`. Each turret `damage = dmg_base`.
`GUN_RETAINING_MODES` (mines/gravity/venom/nova/lightning/flame) ALSO fire a full-damage
bolt every `BOLT_CD` 0.45s **on top of** their special — a free second weapon.

| Turret | mode | dmg_base | real ST DPS (×cap) | main driver |
|---|---|---|---|---|
| Pulse | nova + bolt | 2.5 | ~21 | bolt 5.6 + nova 1.6, ×3 |
| Gatling | bolt ×6 | 1.5 | ~20 | 6 × 3.3 |
| Mine Layer | mines + bolt | 3.0 | ~20 | bolt 6.7 ×3 + mine bursts |
| Tesla | lightning + bolt | 2.0 | ~19 | bolt 4.4 + 4-chain, ×3 |
| Flame | flame + bolt | 0.8 | ~19 | cone 4.4 + bolt 1.8, ×3 |
| Halo | orbit ×3 | 2.0 | ~15 | melee orbit 5.0 ×3 |
| Beam | beam ×3 | 1.2 | ~12 | 4.0 ×3 (sweep) |
| Missile Battery | missile ×3 | 3.0 | ~10 | 3.3 ×3 + splash |
| Cryo | frost ×3 | 1.8 | ~9.8 | 3.3 ×3 + slow |
| Singularity | gravity + bolt | 1.2 | ~9.2 | bolt 2.7 ×3 + pull |
| Toxic | venom + bolt | 1.0 | ~9 | bolt 2.2 ×3 + DoT |
| Glaive | glaive ×3 | 2.5 | ~6.8 | 2.3 ×3 + pierce |

**Status — surgical nerf applied 2026-06-17:** retained bolt gun ×0.5 (turret_node `GUN_RETAIN_SCALE`); Flame cone tick 0.18→0.28s; Gatling cap 6→5. Top cluster ~19–21 → ~13–16; honest single-effect turrets untouched.

**Mitigant:** turrets are stationary (480 range, ~6.5s life). For a mobile/kiting player real
uptime-on-target is well below these "always-on-target" figures, so trim the outliers — don't
gut the archetype to the non-turret average.

## Caveats
1. ~~Turret magnitudes uncertain~~ **RESOLVED — verified (see Turret Family section).**
2. **Railgun** flagged #1 nerf (333 zap ≈ 33 eff. DPS) but that is the **intentional**
   buff per spec (commit b6bdc90) — leave unless explicitly revisited.
3. Static Lv1 analysis; not a live sim.

# Fusion Redesign — Lv1 = two max-level base weapons, combined

**Directive (user):** redesign every fusion so its **Lv1 ≈ its two component base weapons at
max level (Lv7), combined**. Fusing consolidates two maxed weapons into one slot at full
combined power — never a downgrade. Leveling the fusion is a gentle top-up + the gate to the
amalgam merge, not a power explosion.

This supersedes the old model (low base coeff × `born_dmg` 1.5, steep ×3.4 level growth, counts
floored only by T16). The old model made fresh fusions cliff: small AoE, low counts, low damage.

## Base weapon reference @ Lv7 (per-hit dmg = `dmg·(1+growth·6)`)

| id | per-hit @L7 | count @L7 | AoE size @L7 | cadence (cd) | type / effect |
|----|------------:|:----------|:-------------|:-------------|:--------------|
| bolt | 6.14 | 7 burst | projectile | 0.8 | PHYS |
| orbit | 7.52 | 8 blades | r75 orbit | 0.45 re-hit | PHYS, persistent |
| nova | 13.35 | 4 pulses | r310 | 3.5 | ENERGY, push |
| glaive | 7.68 | 7 fan | projectile | 1.6 | PHYS, burn |
| lightning | 7.52 | 9 chains | jump 200 | 2.2 | ENERGY, −1/hop |
| flame | 2.26 | cone (all) | r222 cone | 0.15 tick | FIRE, ignite |
| mines | 26.70 | 10 live | r190 blast | 2.0 drop | PHYS, proximity |
| missiles | 9.21 | 8 salvo | r70 splash | 2.4 | PHYS, homing |
| laser | 4.51 | 4 beams | L420 | 0.3 re-hit | ENERGY, persistent |
| frost | 4.61 | 9 shards | projectile | 1.8 | ICE, slow |
| gravity | 4.45 | 3 wells | r180 | 6.0 | PHYS, pull |
| turret | 5.64 | 6 live | range480 | 6.5 deploy | PHYS, sentry |
| venom | 4.51 | 3 puddles | r75 | 0.35 drop | POISON, DoT |

## Derivation rules

A fusion has a **primary** action (component A) and a **secondary** action (component B). Each
sub-action is sized to its **source component at Lv7**:

1. **Damage coeff** of each sub-action = source component's **per-hit @L7** (the table above).
   Per-hit, not total — the count below restores the source's volume.
2. **Count** via `count_level()` (born-floored ~6, cap 7) so a fresh fusion fires ≈ source's
   `count @L7`. Convert every raw-`level` count to `count_level()`.
3. **AoE size** scaled by `count_level()` (NOT raw `level`) so a fresh fusion opens at ≈ source's
   `size @L7`, not a tiny birth circle. (This is the half T16 missed — the "wide area".)
4. **Cadence** ≈ the dominant component's cd, so the fusion's per-sub-action DPS ≈ that component.
5. **Effects** of BOTH components apply (slow+burn, pull+ignite, etc.).
6. **`born_dmg` → 1.0** (`GameConfig.FUSION_BORN_DMG`): the coeff now encodes the maxed value, so
   the old 1.5× premium would double-count. Drop it.
7. **Gentle level growth:** per-hit damage `× (1 + FUSION_LEVEL_GROWTH·(level-1))`, with
   `FUSION_LEVEL_GROWTH ≈ 0.08` (~×1.5 at Lv7) — NOT the base weapons' ~×3.4. Lv1 is already
   "combined maxed"; leveling adds the last count/size step + a modest damage bump and unlocks
   amalgamation.

**Power-curve check:** fusion Lv1 ≈ A@7 + B@7 (slot-efficient, power-neutral vs the two inputs).
Lv7 fusion ≈ ×1.5 that. Amalgam (two maxed fusions) ≈ 2× a maxed fusion. Controlled, not
exponential — consistent with the dialed-back `WEAPON_LEVEL_POWER` snowball work.

## Worked reference: Thunderclap (lightning + nova) — already shipped (f9c9d6f)
- Ring = nova: radius `170+28·(count_level()-1)` → born ~310 (= nova @L7), dmg `12 ≈ 0.9·13.35`.
- Forks = lightning: `3 + count_level()` → born 9 (= lightning @L7 chains), dmg `·0.6 ≈ 7.2 ≈ 7.52`.
- (born_dmg still 1.5 here — to be set to 1.0 in the global pass, with the coeff re-checked.)

## Critical correction — carrier-attached effects conserve TOTAL, not per-hit
Rule 1 ("coeff = source per-hit @L7") holds ONLY when the fusion fires that sub-action the same
number of times per cycle the source did at L7. When component X's effect rides on **each** of
the M instances of the other component's count (Plasma Burst: 7 bolts each explode a nova ring;
Cyclone: each glaive mini-novas; Cluster Warhead: each rocket = nova splash; every mine payload),
use the source's **@L7 TOTAL per cycle ÷ carriers (and ÷ cadence ratio)**:
`X_coeff = (X@7_perhit · X@7_count) / (M · cadence_ratio)`.
Naive per-hit there = M× too strong (7 overlapping r310 nova rings). This is the #1 spec trap.

## Phased rollout (by RISK, not just mechanic)
Balance is NOT verifiable headless — tests/smoke confirm it compiles+runs, not that it feels
right. So it ships iteratively and will need playtest tuning. Therefore:
- **Knobs live in `GameConfig`**, never hardcoded across 77 files: `FUSION_BORN_COUNT_FLOOR`
  (exists), `FUSION_LEVEL_GROWTH` (new, replaces inline `0.4`), `FUSION_BORN_DMG` (→1.0 in P2).
  Post-playtest re-tune touches ONE file.
- **Phase 1 (high-confidence — counts + AoE sizes → `count_level()`):** what the user originally
  asked ("wide area + many pulses"). No damage change. For AoE size, **recompute the base
  constant** so `count_level()==7 → source S7` (don't blind-swap `(level-1)→(count_level()-1)`,
  which lands short of S7). Converts every raw-`level` count + level-scaled size + mine caps.
- **Phase 2 (big swing — damage re-anchor):** set each sub-action coeff per the carrier rule
  above; replace inline growth with `FUSION_LEVEL_GROWTH`; flip `FUSION_BORN_DMG → 1.0` in the
  FINAL wave (global; mid-pass fusions reading 1.5 are "hot but running" — fine, balance isn't
  judged mid-pass).
- **Process:** Opus produces the per-fusion target table; sub-agents do mechanical find-replace.
  Do `FusMineBase`+`FusSentryBase` first (≈20 mine/turret fusions in 2 files). Commit per wave,
  keep repo green each wave.

**Accepted consequence:** Lv1≈maxed + counts only 6→7 makes leveling nearly inert (≈+50% dmg, +1
count). Mitigate by either born floor 5 (visible 5→7 growth) or a felt `FUSION_LEVEL_GROWTH` —
tuning knobs, decide at playtest.

## Execution log
Per-fusion target numbers derived in the companion spec sections as each wave is built.

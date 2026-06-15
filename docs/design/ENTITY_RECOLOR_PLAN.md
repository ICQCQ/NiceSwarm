# Entity Recolor Plan — Enemy-vs-Player Color Psychology

**Status:** implemented — Phase 2 edits applied (player `COLORS`, 15 enemy `col`, condensed
XP gem, burn tint). Verified: headless import clean, `run_tests.gd` 1059 passed / 0 failed.
**Preview:** [`entity_recolor_before_after.png`](entity_recolor_before_after.png) — rendered by
[`render_entity_recolor.py`](render_entity_recolor.py), a faithful PIL replica of every
Godot `_draw()` (silhouettes, `_muted()` HSV, overlay rings, the dark-blue arena backdrop).

Goal: make **danger** instantly legible. The player should always read as the bright,
cool, friendly anchor; every enemy should read as a warm threat; loot should never be
mistaken for either.

---

## The four principles, applied

1. **Color psychology** — enemies = aggressive **red / orange / deep-violet**; player =
   approachable **blue / green / yellow**.
2. **60-30-10** — a dominant body color (60%), a structural secondary (30%), an accent (10%),
   for *both* player and enemies.
3. **No-overlap** — if enemies own red/orange/purple, the player palette must avoid them
   (and vice-versa for the cool band).
4. **Value/silhouette contrast** — every entity is either clearly lighter or clearly darker
   than the arena floor `Color(0.07,0.08,0.12)`; archetype identity rides on **shape**, so
   compressing enemies into a warm hue band costs no readability.

---

## What's wrong today (the audit)

The current palette leaks across the player/enemy boundary in both directions:

| Conflict | Current | Why it confuses |
|---|---|---|
| Player can pick **orange** | `P5 (1.0,0.6,0.3)` | identical family to Rusher enemies |
| Player can pick **purple** | `P4 (0.7,0.55,1.0)` | Tank / Caster / Disruptor are purple |
| **Interceptor** line is **cyan** | `(0.25,0.75,0.85)→(0.4,0.9,1.0)` | cyan is player color `P0` |
| **Bouncer** line is **yellow** | `(0.95,0.85,0.3)` | yellow is player color `P2` |
| **Burster + Shard** are **green** | `(0.4,0.72,0.42)`, `(0.6,0.95,0.6)` | green = player, XP gems, "good" |
| **Warden / Sentinel** are **blue** | `(0.55,0.6,0.72)`, `(0.35,0.55,0.7)` | cool = friendly/safe |
| **Condensed XP gem** is **red** | `(1.0,0.3,0.3)` | high-value loot reads as a threat |

Shape already disambiguates archetypes (circle / triangle / square / diamond / hex / star),
so all of these can move into the warm band without losing per-enemy identity.

---

## Player palette → cool / bright only

`scripts/core/player.gd:14-18` `COLORS`. Keep `P0–P2`, retune `P3–P5` into the cool band.
**60-30-10:** body 60% · dark core `(0.1,0.25,0.4)` + black halo 30% · white facing notch 10%
(already structured this way in `_draw`; we only change the body hues).

| Slot | Before | After | Note |
|---|---|---|---|
| P0 | `(0.45,0.90,1.00)` cyan | *(keep)* | dominant identity |
| P1 | `(0.50,1.00,0.60)` green | `(0.55,1.00,0.55)` | unchanged in spirit |
| P2 | `(1.00,0.85,0.40)` amber | `(1.00,0.85,0.35)` | unchanged in spirit |
| P3 | `(1.00,0.55,0.80)` pink | **`(0.25,0.95,0.80)` aqua** | drop warm pink |
| P4 | `(0.70,0.55,1.00)` purple | **`(0.45,0.62,1.00)` azure** | drop enemy-purple |
| P5 | `(1.00,0.60,0.30)` orange | **`(0.80,1.00,0.45)` chartreuse** | drop enemy-orange |

All six are now high-value cool/green/yellow — none collide with the enemy band.

---

## Enemy palette → warm danger band

`scripts/config/enemy_config.gd` `"col"` field. **60-30-10 for enemies:** body 60% ·
darkened inner detail / silhouette mass 30% (e.g. Burster's `color.darkened(0.3)` cells) ·
status/role accent ring 10% (elite gold, boss crimson, warden steel, caster reticle).
Warm hues spread across red → orange → magenta → deep-violet so tiers still separate.

**Kept (already warm, on-principle):** Brawler reds, Rusher oranges, Tank magenta-purple,
all Casters (Bomber crimson, Diviner/Oracle/Hexer/Nullifier/Warlock/Defiler purples),
Elite pink-reds, all three Bosses.

**Recolored (cool/player-coded → warm):**

| Enemy (line) | Shape | Before | After | Family |
|---|---|---|---|---|
| Shieldling (34) | square | `(0.55,0.60,0.72)` blue-grey | `(0.72,0.50,0.40)` | rust steel |
| Bulwark (35) | square | `(0.62,0.67,0.80)` | `(0.80,0.58,0.45)` | rust steel |
| Spore (38) | star | `(0.40,0.72,0.42)` green | `(0.88,0.62,0.18)` | toxic amber |
| Brood (39) | star | `(0.45,0.82,0.46)` green | `(0.95,0.70,0.20)` | toxic amber |
| Shard (42) | triangle | `(0.60,0.95,0.60)` green | `(1.00,0.50,0.25)` | hot orange-red bullet |
| Sentinel (45) | square | `(0.35,0.55,0.70)` blue | `(0.50,0.30,0.55)` | warm violet |
| Aegis (46) | square | `(0.40,0.62,0.78)` blue | `(0.58,0.36,0.62)` | warm violet |
| Mote (49) | diamond | `(0.80,0.70,1.00)` pastel | `(0.66,0.45,0.95)` | deep violet |
| Wisp (50) | diamond | `(0.86,0.76,1.00)` pastel | `(0.72,0.50,1.00)` | deep violet |
| Caroms (56) | diamond | `(0.95,0.85,0.30)` yellow | `(1.00,0.35,0.50)` | hot magenta |
| Pinball (57) | diamond | `(1.00,0.90,0.35)` yellow | `(1.00,0.40,0.55)` | hot magenta |
| Jammer (69) | hex | `(0.25,0.75,0.85)` cyan | `(0.60,0.15,0.28)` | crimson ramp |
| Scrambler (71) | hex | `(0.30,0.80,0.90)` cyan | `(0.70,0.20,0.32)` | crimson ramp |
| Disperser (73) | hex | `(0.35,0.85,0.95)` cyan | `(0.80,0.25,0.35)` | crimson ramp |
| Overseer (75) | hex | `(0.40,0.90,1.00)` cyan | `(0.90,0.30,0.40)` | crimson ramp |

Note Tank (purple hex) vs Interceptor (now crimson hex) share the hex silhouette but are a
full hue apart; Burster star vs Rusher orange-triangle differ by shape.

---

## Pickups / XP → stay player-coded

`scripts/world/xp_gem.gd`, `scripts/world/pickup.gd`. Loot must not read as a threat.

| Item | Before | After | Rationale |
|---|---|---|---|
| XP gem normal | `(0.45,1.00,0.55)` green | *(keep)* | cool/green = good |
| XP gem condensed | `(1.00,0.30,0.30)` red + pale core | **`(1.00,0.85,0.40)` gold + white core** | high-value, not "danger red" |
| Heart (heal) | `(0.95,0.30,0.40)` red | *(keep — exception)* | universal health convention; white cross sells it |
| Magnet / Chest / Bomb | blue / gold / grey | *(keep)* | already cool/neutral, on-principle |

Player **weapon** projectiles (bolt gold, glaive cyan, frost cyan, missile pale, lightning
blue-white, venom elemental) are already cool/elemental and on-principle — **no changes**.
Gravity-well purple is the one borderline case (a *player* effect in an enemy hue) but it is
a transient field, not a body, so it's left as-is (low priority).

---

## Readability risks introduced by warming the bodies (must verify in-engine)

Pushing bodies warm can collapse the **warm overlays** layered on top. Flagged for Phase 2:

1. **Burn tint** `enemy.gd:466 (1.0,0.45,0.1)` lerp 0.55 — near-invisible on a red/orange
   body. *Mitigation:* shift the burn body-tint toward bright yellow-white
   `~(1.0,0.80,0.30)` so it still pops on warm enemies (embers at `:474` already help).
2. **Caster reticle** `(1.0,0.4,0.3)` on the crimson Bomber body merges slightly — the cross
   lines still read; acceptable, but confirm at gameplay scale.
3. **Boss crimson ring** on the dark-red Juggernaut — relies on being brighter + alpha; reads
   in preview. Eclipse is the deliberate "much darker than bg + bright rim" case.
4. **Slow tint** (blue) and **flash** (white) are cool/neutral — unaffected. **Elite gold**
   ring on pink-red bodies — unaffected.

---

## Phase 2 — edits (applied ✅)

1. ✅ `scripts/core/player.gd` — replaced `P3/P4/P5` in `COLORS` (pink/purple/orange → aqua/azure/chartreuse).
2. ✅ `scripts/config/enemy_config.gd` — 15 `"col"` recolors per the enemy table above.
3. ✅ `scripts/world/xp_gem.gd` — condensed gem → gold body + white core.
4. ✅ `scripts/enemies/enemy.gd` — burn tint → bright yellow-white (risk #1 fix).

### Test plan
- `godot --headless --path . --import` then `--script res://tests/run_tests.gd` (no color
  asserts expected; confirms nothing parse-breaks).
- `NICESWARM_TEST=zoo` — visual smoke of every enemy class in one run.
- Eyeball a dense late-game frame: player pops, no enemy reads cool, no loot reads as threat,
  burn/slow/shield overlays still legible.
- Re-run `render_entity_recolor.py` after edits as the diff artifact for the PR.

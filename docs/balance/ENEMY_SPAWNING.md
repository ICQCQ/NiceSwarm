# How enemies spawn over a run

NiceSwarm has **no discrete levels or stages** — progression is the run *timeline*
(0 → 10:00, `WIN_TIME = 600 s`). "How hard the level is right now" is a function of
**elapsed time**, **how fast you're clearing** (heat), and **party size**. This doc
traces what the spawner does from second 0 to the win, and where every knob lives.

Everything here is **host-authoritative**: only the host runs `EnemySpawner`
(`scripts/core/spawner.gd`); clients receive enemies as puppets over the world-state
sync. Constants live in `scripts/config/game_config.gd` (`GameConfig`) and the enemy
table in `scripts/config/enemy_config.gd` (`EnemyConfig`).

> Heads-up on the word "level": *player level* (from XP) is **not** a spawn stage. It
> only nudges the difficulty climb (`DIFF_LEVEL`) and adds a flat step on each
> level-up (`DIFF_LEVEL_STEP`). There is no "Stage 1/2/3" — read everything below as
> a smooth curve over the clock.

---

## The two climbing tracks

`EnemySpawner` keeps **two** separate numbers that both start at 0 and rise over the
run. Splitting them is deliberate: a skilled party that clears fast should fight
*tougher* enemies without also being buried under more enemy *types* than the run
should have unlocked yet.

| Track | What it controls | How it climbs |
|-------|------------------|---------------|
| **`pace`** | enemy **variety** (tier ceiling) + target **population** (`desired_pop`) | flat, time-only: `pace += dt · DIFF_BASE · warmup`. Never accelerates. |
| **`difficulty`** | how tough each enemy is to **clear** (hp / speed / contact dmg) | `difficulty += dt · DIFF_BASE · warmup · (1 + heat·DIFF_HEAT + spike·DIFF_SPIKE + (level−1)·DIFF_LEVEL)`, plus `DIFF_LEVEL_STEP` flat per level-up |

- `DIFF_BASE = 1/62` — the shared base rate (gentler = slower ramp).
- `warmup()` ramps `0.25 → 1.0` over the first `DIFF_WARMUP_SECS = 80 s` — a gentle opening.
- `heat` is the clear-rate accelerator (next section). `DIFF_HEAT = 2.4`.
- `spike` is a mid-game punisher for near-clearing the map (`DIFF_SPIKE = 1.0`).

`difficulty` (`diff()`) is the single value every enemy stat scales from in
`make_enemy`: `hp = (hp0 + diff·hpk) · party`, `speed = spd + diff·spdk`,
`dmg = dmg + diff/12`.

### Heat — the clear-rate accelerator

`update_difficulty` keeps a smoothed kills/sec EMA (`clear_ema`). When you clear
**faster** than enemies arrive (`clear_ema > spawn_rate`), `heat_cur` rises (fast,
rate 0.7) and feeds the `difficulty` climb; in a lull it decays slowly (0.05) so the
pressure lingers. If you're **overwhelmed** (field > 1.4× target *and* barely
clearing) heat is forced to 0 and bleeds off fast (0.35) — a built-in mercy valve.

**Heat spike** (mid-game+ only, `elapsed ≥ MID_GAME_TIME = 300 s`): if the live
population drops below `HEAT_SPIKE_POP_FRAC = 0.2` of target, an exponential term
(`HEAT_SPIKE_GROWTH = 1.8/s`, capped `HEAT_SPIKE_MAX = 5`) surges the difficulty
climb — the reward for crushing the arena is that it crushes back.

Heat is surfaced to the player as the **THREAT** readout (CALM → NIGHTMARE), with a
`▲ rising` note when it's climbing.

---

## Spawn cadence (`run_spawning`, every physics tick)

The steady spawn loop:

```
interval = lerp(SPAWN_INTERVAL_START 1.4, SPAWN_INTERVAL_END 0.2, elapsed/540)
         / (1 + PARTY_RATE_PER · (N−1))      # co-op density
         / max(wave_intensity, 0.1)          # wave peaks spawn faster
if pool_count < desired_pop: interval *= SPAWN_REFILL_MULT 0.4   # refill burst
```

So spawns start ~1 every 1.4 s and tighten toward 1 every 0.2 s by ~9 min, faster on
wave peaks, faster in co-op, and much faster while the field is below target.

**Target population** (`desired_pop`) — the spawner refills the arena toward this:

```
desired_pop = clamp((SPAWN_DESIRED_BASE 6 + pace · SPAWN_DESIRED_PER_DIFF 2.5)
                    · wave_pop_mult, WAVE_POP_FLOOR 3, ENEMY_CAP−20)
```

Starts at ~6 bodies, grows with `pace` (time), dips in wave valleys. Hard ceiling
`ENEMY_CAP = 220` live enemies (an O(n) safety wall — enemies don't collide with each
other, but everything else is per-enemy work).

### The per-minute wave rhythm (`WAVES`)

Layered on top of everything: a 10-entry `[intensity, pop_mult]` table, one row per
game-minute, **lerped** between adjacent minutes for a smooth peaks-and-valleys feel.
`intensity` divides the spawn interval (>1 = faster); `pop_mult` scales `desired_pop`
(valleys thin the field below the normal floor for a genuine breather).

| Min | intensity | pop_mult | feel |
|----:|:---------:|:--------:|------|
| 0 | 0.8 | 0.8 | intro |
| 1 | 1.0 | 1.0 | build |
| 2 | 1.4 | 1.3 | swarm peak |
| 3 | 0.6 | 0.6 | **valley (breather)** |
| 4 | 1.1 | 1.1 | build + elites |
| 5 | 1.3 | 1.2 | pressure peak |
| 6 | 1.5 | 1.4 | swarm peak |
| 7 | 0.65 | 0.65 | **valley (breather)** |
| 8 | 1.3 | 1.3 | ramp |
| 9 | 1.6 | 1.5 | climax |

Past minute 9 the last row holds.

---

## What spawns, and when it unlocks

Three independent feeds put enemies on the field.

### 1. The main pool (`SPAWN_POOL`) — weighted random, time-gated

Every steady spawn picks a class via weighted random over the rows whose `unlock`
time has passed:

| Class | weight | unlocks at | role |
|-------|:------:|:----------:|------|
| brawler | 3 | 0:00 | baseline chasers |
| rusher | 2 | 0:45 | fast, fragile darters |
| wisp | 1 | 1:30 | ENERGY-immune random drifters |
| warden | 1 | 2:00 | armored (damage `resist`) |
| sentinel | 1 | 2:30 | phases an unbreakable shield |
| burster | 1 | 3:00 | spits a ring of shard bullets on death |
| disruptor | 1 | 3:30 | telegraphs slow/dash-lock zones |
| defiler | 1 | 5:00 | lays lingering ground-deny fields |

Brawlers dominate early (weight 3 of 3); each unlock dilutes the mix with a new threat.

### 2. Scheduled specials (`SPAWN_SPECIALS`) — own cooldown timers

These ignore the weighted pool and fire on their own accumulator once unlocked. The
`interval_hi → interval_lo` ones get **more frequent as heat rises** (party ahead of
the curve):

| Special | unlocks at | interval | note |
|---------|:----------:|----------|------|
| tank | 1:30 | flat 45 s | big, slow, heavy contact; drops pickups |
| elite | 2:00 | 75 s → 32 s by heat | tanky, always drops a chest |
| caster | 2:30 | 20 s → 11 s by heat | telegraphed ranged strikes |

### 3. Bouncer — its own population (`BOUNCER_*`)

From `BOUNCER_UNLOCK = 2:45`, ricocheting bouncers are topped up every 2 s toward
their **own** growing cap (`2 + pace·1`), entirely separate from `desired_pop` —
they're never counted toward "overwhelmed" and never crowd out the normal pool.

### Bosses — kill-count milestones (`add_kill` → `spawn_boss`)

Not on the clock: the first boss spawns at `BOSS_KILL_BASE = 60` total kills, then
every `+BOSS_KILL_INTERVAL = 90` kills, each escalating to the next boss tier
(Juggernaut → Harbinger → …). Bosses own the hard DPS-checks with map-wide slam
telegraphs.

---

## Which tier spawns (`class_tier`)

Most classes have multiple tiers (Grunt → Bruiser → Reaver). The tier that spawns
rises with **`pace` only** (time), so rarer variants arrive on a fixed schedule
rather than flooding in for a fast party:

```
ceiling = clamp(pace / 3, 0, tiers−1)
tier    = ceiling, then ~40% chance to step down each rank
```

So the top tier becomes *more common* over time while lower tiers keep appearing.
Caster-family classes are flagged `uniform_tier` — every unlocked tier is equally
likely, so Bomber/Diviner/Oracle stay evenly mixed instead of Oracle dominating late.

---

## Where enemies appear (`_enemy_spawn_pos`)

- Anchored on the alive player nearest the arena center.
- Placed on a ring `SPAWN_RING_MIN 700 → SPAWN_RING_MAX 900` px out, random angle,
  clamped inside the arena (`ARENA = 2400×2400`).
- **Never** within `SPAWN_SAFE_RADIUS = 500` px of *any* alive player: it retries 8
  angles and, if a player is boxed into a corner, nudges the spawn straight away from
  them so an enemy can't materialise on top of someone.
- Telegraphed strikes are separately capped at `MAX_TELEGRAPHS = 6` simultaneous
  danger zones so the arena can't be blanketed in undodgeable AoE.

---

## Co-op (party) scaling

`N = peer_ids.size()`. Two levers scale per **extra** player (both ×1 at N=1, so solo
is identical to single-player tuning):

| Lever | where | formula |
|-------|-------|---------|
| enemy **hp** | `make_enemy` | `× (1 + PARTY_HP_PER · (N−1))` |
| spawn **density** | `run_spawning` | interval `÷ (1 + PARTY_RATE_PER · (N−1))` |

Enemy **damage and speed do not scale with party size** — only how much there is to
shoot and how much hp it has. Current values: `PARTY_HP_PER = 0.3`,
`PARTY_RATE_PER = 0.4` (see [MULTIPLAYER_BALANCE_SIM.md](MULTIPLAYER_BALANCE_SIM.md)
for how these were chosen).

---

## Quick reference — the whole run at a glance

| Time | What changes |
|------|--------------|
| 0:00 | brawlers only; `warmup` at 0.25; desired_pop ~6; spawns ~1/1.4 s |
| 0:45 | rushers unlock |
| 1:20 | `warmup` reaches full (1.0) at 80 s |
| 1:30 | wisps + tank special unlock |
| 2:00 | wardens + elite special |
| 2:30 | sentinels + caster special |
| 2:45 | bouncers begin |
| 3:00 | bursters |
| 3:30 | disruptors |
| 5:00 | defilers; `MID_GAME_TIME` (heat-spike can now arm) |
| ~60 kills | first boss, then every +90 kills |
| 9:00 | spawn interval near its `0.2 s` floor; climax wave |
| 10:00 | `WIN_TIME` — survive to win |

All numbers above are the live constants in `GameConfig` / `EnemyConfig`; change them
there, not in code.

# Solo balance pass + headless playstyle-sim harness

A data-driven solo difficulty pass, plus the headless **autopilot sim** that drove it. The sim
plays full runs with a kiting bot under different playstyles and reports win/loss, so balance can
be measured instead of guessed.

## The balance changes (solo)

Three enemy-side knobs, each justified by sim data:

| Change | From → To | Why |
|---|---|---|
| `GameConfig.MAX_TELEGRAPHS` (new) | — → **6** | **The core fix.** Death instrumentation showed the player dying in *open space* (0 enemies within 140px) to **up to 21 overlapping, undodgeable telegraph AoEs** — casters/bosses were blanketing the arena. Capping simultaneous danger zones makes them dodgeable again. This alone moved the solo win rate from ~0% to ~40%. |
| `GameConfig.DIFF_BASE` | 1/48 → **1/62** | Slower difficulty climb — lifts the borderline runs (which were dying at 280-340s, just short of the 600s win) into wins. |
| `GameConfig.SPAWN_DESIRED_PER_DIFF` | 3.0 → **2.5** | ~17% thinner steady-state swarm at a given difficulty — eases the mid-game gauntlet. |

`cast_telegraph` enforces the cap (`main.gd`): once `MAX_TELEGRAPHS` zones are live, further casts
are skipped that tick.

### Result
Across **8 playstyles × 4 seeds (32 solo runs)**: **56% win rate** — inside the 50-60% target.
The change also **compressed the style spread**: `prism` 0% → 50% (was a dead style), and the
runaway `supernova`/`warhead` came down from 100% toward the pack.

## The sim harness

Gated entirely behind the `NICESWARM_SIM` env var — **zero cost in normal play** (`sim_mode`
stays false, so every sim branch is skipped).

```
NICESWARM_SIM="style=railgun,players=1,seed=3,ff=4"  (run the project headless)
```
Config keys: `style` (see `SIM_STYLES` in `main.gd`), `players` (1-4 bots), `seed`, `ff` (engine
time-scale). On win (survive `WIN_TIME`) or wipe it prints one line then quits:
```
[sim] style=railgun party=1 seed=3 result=WIN time=600.0 diff=16.0 level=19 kills=304 ttk=2.07
```

**Playstyles** (`SIM_STYLES`): each is a priority-weapon line + the fusion to aim for
(railgun, pulsar, supernova, glacier, prism, toxicpyre, warhead, singular, cluster, storm,
frostbite, greedy). `_sim_pick_for` auto-resolves level-ups toward that build.

**The bot** (`player.gd` `_bot_step`, active only when `bot == true`): comet-tail orbit kite,
vacuums XP gems and hearts, dodges telegraph zones, proactively dashes out of crowds, and revives
downed allies. It's a fixed *"average kiter"* reference — a relative-comparison tool, not a
perfect player.

### Sweep script
`tests/sim_sweep.sh [ff] "seeds"` runs the playstyle × seed × player-count matrix and prints
per-style / per-player-count win-rate aggregates.

## Methodology notes / caveats

- **Run faithfully at `ff <= ~6`.** Higher time-scales time-dilate the headless host and
  under-simulate combat (false losses) — not a step-cap issue. `ff=4` is the safe default.
- **The bot ~= a below-average-to-average kiter.** Tuning the *game* to its 50-60% win is a
  deliberate choice; a skilled human will win more often. Treat absolute win rate as calibrated to
  this proxy, and trust the *relative* signals (style A vs B, player-count trends) more.
- **Outcomes are bimodal** (a run either survives the mid-game and snowballs to a win, or dies in
  it), so per-config win rate needs several seeds; single runs are noisy.

## Multiplayer: NOT yet a trustworthy signal

The 1-4 player path works, but the sim currently shows co-op trending **harder** than solo
(N=4 dies ~185-220s) — the *opposite* of what the mechanics predict (per-capita density drops,
shared leveling is faster, revives exist). The gap is **bot co-op limitations**, not a proven
balance issue: the bots don't focus-fire or hold team formation, and zone-spreading made it worse
(they do better clustered). **Do not tune the party-scaling multipliers on this data.** A clean
co-op verdict needs a team-coordinated bot or a human co-op playtest.

For reference, the only enemy multipliers that scale with player count `N` (`spawner.gd`):
- Enemy **HP** `x (1 + 0.5*(N-1))` -> 1.0/1.5/2.0/2.5 for N=1-4.
- Spawn **density** `x (1 + 0.6*(N-1))` -> 1.0/1.6/2.2/2.8.
- Enemy **damage** and **speed** do **not** scale with N (only with difficulty).

---

## Hard-difficulty pass (target: skilled-player win rate < 10%)

The 50-60% target above was deliberately retired: the game was too easy for a skilled
player. Two problems showed up under measurement and drove this pass.

### The bot sweep can't see the late game
The kiting bot is a *below-average* player and now dies in the **mid-game (~3-4 min,
level ~9)** on every build — the sweep is **saturated near 0% win** and is **blind to the
level-20-45 / minute-4-10 window** where a skilled human actually lives. So the mortal
sweep is only a *relative mid-game* signal here, not the calibration target.

### The lethality probe (the late-game instrument)
`NICESWARM_SIM="...,god=1"` runs the kiting bot **immortal** (`debug_god`) so it reaches
10:00, and `player.take_damage` tallies the damage that *would* have landed (i-frame- and
dash-respected) into `lethal_taken`. The per-minute `[ff] lethal/min` line is then the
**incoming-damage-to-a-5HP-player curve** for the late game. It exposed the real "too easy":
once a build comes online (~min 7) the player out-runs and out-DPSes the capped swarm, so
**late-game incoming damage was 0** — a free snowball. (Caveat: this counts AoE a skilled
player dodges, so trust the *relative* change minute-to-minute, and weight contact/density
over telegraph AoE.)

### The changes (all in `GameConfig` unless noted)
Breaking the snowball needed enemies that can **catch and survive** against a high-DPS kiter,
plus a denser field and slower player power-curve:
- **Density:** `ENEMY_CAP` 220->300, spawn interval 5x faster (`SPAWN_INTERVAL_START/_END`
  1.4/0.2 -> 0.2/0.024) **ramped in over `DIFF_WARMUP_SECS` (80->130 s)** so the opening is
  survivable, not an instant 300-enemy flood; `SPAWN_DESIRED_*` up; `SPAWN_RING_MIN/_MAX`
  300/1200 with `SPAWN_SAFE_RADIUS` 250 (enemies spawn as close as ~300 px).
- **Late-game lethality:** `DIFF_BASE` 1/62->1/45; `ENEMY_SPEED_DIFF_SCALE` 0.025 +
  `ENEMY_HP_DIFF_SCALE` 0.04 in `spawner.make_enemy` (late enemies ~match player speed and
  survive the alpha strike); contact damage `diff/12 -> diff/7`; `MAX_TELEGRAPHS` 6->9.
- **Player power-curve:** XP gain halved (`XP_GAIN_MULT` 0.5); `WEAPON_LEVEL_POWER`
  0.04->0.025 (shrink the DPS snowball at the source).

### Result (lethality probe, immortal supernova bot)
Incoming damage to a 5-HP player per game-minute went from `... 6:149 7:0 8:0 9:0` (free
late snowball) to a **sustained, lethal curve**: `2:191 3:1038 4:1214 5:661 6:214 7:139
8:145 9:103` — a brutal mid-game wall and **no free late game**. Mortal-bot win rate 3% -> 0%
(it dies in the min3-4 wall). **The final <10% number is a skilled-player playtest call** —
no automated proxy measures it; the probe shows the late game is now genuinely lethal.
Knobs to ease/intensify: the `*_DIFF_SCALE` pair, `DIFF_BASE`, `SPAWN_INTERVAL_*`,
`DIFF_WARMUP_SECS`, `XP_GAIN_MULT`, `WEAPON_LEVEL_POWER`.

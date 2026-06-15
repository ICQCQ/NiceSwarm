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

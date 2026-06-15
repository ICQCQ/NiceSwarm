# Multiplayer (co-op) balance — sim report

**TL;DR.** Co-op was over-punished by the party scaling: a 4-player field carried
~2.5× enemy hp and ~2.8× spawn density. This PR **eases both levers** and
parameterizes them into `GameConfig` (`PARTY_HP_PER 0.5 → 0.3`,
`PARTY_RATE_PER 0.6 → 0.4`). Solo is untouched by construction (N=1 ⇒ ×1).

**The headline caveat, up front:** the headless sim **cannot validate** co-op win
rate to a 50-60% target right now. Two independent limits make the co-op number
unreliable: (1) a large run-to-run **noise floor** — identical solo config swung
40% / 66% / 80% across three 15-run sweeps — and (2) the co-op **bot** clumps and
doesn't focus-fire, so sim co-op is a *lower bound* on what coordinated humans hit.
The multiplier ease below is a **conservative, mechanically-justified change for
human playtesting**, not a sim-proven landing.

---

## What changed

`scripts/core/spawner.gd` hard-coded two party multipliers; both are now named
constants in `scripts/config/game_config.gd`:

| Knob | Where it applies | Before | After | Effect |
|------|------------------|:------:|:-----:|--------|
| `PARTY_HP_PER` | `make_enemy`: `hp ×(1 + p·(N−1))` | 0.5 | **0.3** | less hp to chew through per extra gun |
| `PARTY_RATE_PER` | `run_spawning`: interval `÷(1 + p·(N−1))` | 0.6 | **0.4** | thinner swarm per extra player |

Resulting per-party multipliers (N = player count):

| N | enemy hp ×  (before → after) | spawn density ×  (before → after) |
|:-:|:---------------------------:|:--------------------------------:|
| 1 | 1.00 → **1.00** | 1.00 → **1.00** |
| 2 | 1.50 → **1.30** | 1.60 → **1.40** |
| 3 | 2.00 → **1.60** | 2.20 → **1.80** |
| 4 | 2.50 → **1.90** | 2.80 → **2.20** |

Enemy **damage and speed never scaled with party size** and still don't — only the
amount of hp and the number of bodies. See
[ENEMY_SPAWNING.md](ENEMY_SPAWNING.md#co-op-party-scaling).

---

## The sim harness (recap)

Same headless playstyle-sim used for solo balance, gated behind `NICESWARM_SIM` (zero
cost in normal play). `tests/sim_par.sh` runs the matrix in parallel (one godot
process per cell; faithful under contention because `max_physics_steps_per_frame` is
uncapped — a starved run stretches in wall-clock, never under-simulates). Each cell:
one full bot run to win (10:00) or death.

- Matrix: styles {railgun, glacier, supernova, warhead, greedy} × seeds {1,2,3} ×
  players {1,2,3,4} = 60 runs/sweep, `ff=4`, pool 19.
- Reproduce: `for p in 1 2 3 4; do for s in railgun glacier supernova warhead greedy; do for sd in 1 2 3; do echo "$s $p $sd"; done;done;done | bash tests/sim_par.sh 19 4`

---

## Results

### Win rate by party size

| N | Baseline (0.5 / 0.6), n=15 | Eased (0.3 / 0.4), pooled n=30 |
|:-:|:--------------------------:|:------------------------------:|
| 1 (solo) | 40% (6/15) | 73% (22/30) |
| 2 | 27% (4/15) | 33% (10/30) |
| 3 | 33% (5/15) | 50% (15/30) |
| 4 | 27% (4/15) | 53% (16/30) |

Eased = two independent 15-run sweeps pooled (run A: 1=80 2=33 3=46 4=40; run B:
1=66 2=33 3=53 4=66).

### Why these numbers don't prove what they look like they prove

**1. The noise floor is enormous at n=15.** Solo (N=1) is *byte-identical* across
every sweep — the party math is ×1, so nothing in this change touches it. Yet solo
measured **40% → 80% → 66%** across three sweeps of the same code. That ~40-point
spread is the run-to-run variance (bimodal outcomes: snowball-win vs mid-game death).
Binomial SE at p≈0.4 is ±12.6pp for n=15, ±8.9pp for n=30 — and the observed solo
spread exceeds even that, consistent with the bimodal inflation. **The co-op deltas
(e.g. 4p 27% → 53%) are within the same noise envelope as solo's own unchanged
swing.** Some of the apparent co-op lift is just the upward noise that also lifted
solo from 40% to 73% in the very same runs.

**2. The result is non-monotonic across N** — eased pooled is 2p 33% < 3p 50% < 4p
53%, and 2p is *lowest*. Real party-scaling pressure would decline monotonically
(2p > 3p > 4p). It doesn't. This is the signature of a **bot-limited** measurement,
not a scaling-limited one.

**3. The co-op bot is a lower bound.** The bot clumps (all bots orbit a shared
center → overlapping aggro) and does **not** focus-fire (enemies live longer than
under coordinated humans). Both make co-op *harder for the bot than for real
players*. Tuning the multipliers until the **bot** hits 55% would ship a co-op that's
trivial for the humans it's actually for — so we deliberately took **one conservative
pass and stopped**, rather than iterating the sim toward the target.

---

## Decision

- **Ship** the eased multipliers (`0.3 / 0.4`) as the co-op default. They're
  mechanically justified (4p drops from 2.5×hp/2.8×density to 1.9×/2.2×), directionally
  correct, and **leave solo identical**.
- **Do not** claim sim-validation of a 50-60% co-op win rate — the harness can't
  resolve it.
- **Verify with human playtesting.** Coordinated humans focus-fire with more guns on
  the field; expect them well above the bot's sim number.
- **Follow-up (queued):** a co-op-coordinated bot (focus-fire + formation, no shared
  orbit center) is the real prerequisite for trustworthy co-op sim tuning. Until then,
  co-op balance is a playtest question, not a sim question.

## Solo regression check

Solo is unaffected by design (N=1 ⇒ both party terms ×1). The solo target from
[SOLO_BALANCE_SIM.md](SOLO_BALANCE_SIM.md) is ~56%; across the three sweeps here solo
measured 40/80/66% (pooled 62%, n=45) — same code path as the shipped solo balance,
fully inside its own noise band. No solo regression.

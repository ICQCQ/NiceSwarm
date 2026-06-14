# NiceSwarm — Performance Findings: the late-game O(n²) cliff

> **Symptom:** late-game framerate collapses to <1 fps, and attacks visibly "pass
> through" enemies that should be hit.
> **Verdict:** there are **two independent O(n²) cost centers**, plus the missed-hits are a
> *downstream symptom* of the frame collapse — not a separate collision bug.
> Branch: `perf/game-loop-on2`. Investigated 2026-06-14.
>
> **Status (2026-06-14): fix implemented** — cost A (enemy `collision_mask = 0`) + cost B
> (shared per-tick enemy grid: `Main.all_enemies()` / `enemies_in_radius()` /
> `nearest_enemy_to()`, with `player.nearest_enemy`, orbit and gravity_well on the grid and
> all other scans on the shared cached list). Verified error-free headless across
> solo / all_weapons / zoo / merge / bomber / co-op. The real-fps gain still wants the
> measure-first playtest below.
>
> **Update (2026-06-15): step 3 finished for the weapon layer.** Every per-frame weapon
> scanner now uses the radius query instead of looping the full field: the 4 base AoE weapons
> (`flame` / `laser` / `nova` / `lightning`) and **all 37 enemy-scan sites in
> `weapon_fusions.gd`** moved from `all_enemies()` / `get_nodes_in_group("enemies")` to
> `Main.instance.enemies_in_radius(center, reach + 64.0)` (the `+64` margin > the largest enemy
> radius of 38, so no grazing hit is ever dropped; the precise per-site distance/angle check is
> unchanged). The one genuinely unbounded scan (RocketHalo's tag-lock search) stays global but
> now reads the cached `all_enemies()` instead of re-allocating the group. The `spawned/` layer
> was already on `EnemyGrid.near()`. Measured wins (headless micro-benchmark, N=220, see
> **Benchmarks** below): 2.5–5.9× for the base weapons, **5.5–18× for the fusion archetypes**
> (orbit-blade halos gain most — they ran a nested enemy×blade loop every frame).
> **Remaining follow-ups:** throttle continuous scanners to ~10–15 Hz; the `queue_redraw()`
> cleanup (step 4).

`n` = live enemy count, hard-capped at **`ENEMY_CAP = 220`** (`scripts/config/game_config.gd:12`).
The arena is 2400×2400; enemies spawn off-screen in a ring and converge on the player, so
late game most of the 220 are clustered around you at once.

---

## Cost center A — enemy↔enemy physics collision (engine-side)

`Enemy extends CharacterBody2D` with **`collision_layer = 2` and `collision_mask = 2`**
(`scripts/enemies/enemy.gd:72-73`), and every chasing/wandering enemy calls
**`move_and_slide()`** each physics tick (`scripts/enemies/enemy.gd:163`).

That means **every enemy physically collides with every other enemy.** When 150–220
`CharacterBody2D` bodies pile into a tight ring around the player, the engine's broadphase +
contact solver resolves a dense mat of mutual overlaps every step — `O(n · neighbors)`, which
in a converged pile is effectively `O(n²)`. This is **engine-side cost that no script change
touches**, and it matches the reported feel of "entity updates overlapping."

This is the classic Vampire-Survivors-style killer. VS-likes generally do **not** hard-collide
the swarm; they allow overlap or use a cheap separation pass.

- Only `move_mode` 2/3 (bounce/straight) and `phase` enemies skip `move_and_slide()` (the
  `manual` path) and set `collision_mask = 0`. The common chasers (mode 0) do full physics.

## Cost center B — full enemy-group scans every tick (script-side)

`get_tree().get_nodes_in_group("enemies")` is called at **~70 sites** (grep), the majority
inside `_physics_process`. Each call **allocates a fresh array of up to 220** and then
distance-loops it. The worst offenders run the **full scan every tick with no cooldown gate**:

| Site | Cost |
|------|------|
| `scripts/weapons/weapon_orbit.gd:38` | all enemies, every frame |
| `scripts/spawned/gravity_well.gd:33` **and** `:59` | all enemies **twice per instance**, every frame |
| `scripts/core/player.gd:184` (`nearest_enemy`) | all enemies; called by bolt/frost/glaive/gravity/lightning/missiles + many fusions |
| mines (`:32`,`:47`), turret (`:144/150/178/193/214/227`), venom, laser, nova, frost_shard, glaive_proj, missile_proj, ~40 fusion emitters in `weapon_fusions.gd` | all enemies, per tick or per fire |

Late game with a fused 5-weapon build → **40–80 active scanners × 220 × 60 Hz ≈ ~1M distance
checks/sec AND ~1M array allocations/sec.** The allocation churn (GC pressure + cache misses) is
likely hurting more than the float math.

Redundancy compounds it: `gravity_well` scans the group twice, `mine_node` twice, `turret_node`
up to four times — each an independent 220-element allocation.

## The missed hits — a symptom of the collapse, **not** tunneling

Godot runs `_physics_process` at a fixed delta but caps catch-up at
`max_physics_steps_per_frame` (**default 8**). Once a frame can't keep up, the engine
**time-dilates**: the sim runs in slow motion and evaluates far fewer hit-checks per wall-clock
second, so enemies appear to walk through attacks that "should" land.

Genuine projectile tunneling was **ruled out** for the bolt: velocity `520 px/s ÷ 60 =
8.7 px/step` (`scripts/weapons/weapon_bolt.gd:34`) vs ~17 px combined radius (proj 5 + enemy 12),
so it cannot skip an enemy at healthy fps. **Fixing the fps should make the missed hits
disappear.** If any *fast fusion* projectile still misses at healthy fps, check that projectile's
speed individually (only remaining tunneling suspect).

---

## Measure first — a 2-run bisect (≈5 min) so we fix the right cost center

Don't refactor 70 sites on static reasoning alone. Two one-line changes isolate the costs:

| Change | Tells you |
|--------|-----------|
| `ENEMY_CAP = 220 → 40` (`game_config.gd:12`), play to late game | cliff vanishes → confirms `n`-scaling is the cause |
| enemy `collision_mask = 2 → 0` (`enemy.gd:73`), back at 220 | frametime drops a lot → cost center **A** dominates |

Or use the Godot editor's built-in profiler (Debugger → Profiler) to see whether physics or
script time dominates. Either way, measure before refactoring.

---

## Fix plan, ordered by leverage

### 1. Stop enemies hard-colliding (cost A) — biggest win, smallest change
Set enemy `collision_mask = 0` (`enemy.gd:73`). If anti-stacking is still wanted, replace it with
a cheap per-tick **separation nudge against only nearby enemies** (using the grid from step 3),
or simply accept overlap as VS-likes do. Removes the dense contact-solver cost entirely.

### 2. Share one enemy list per tick + throttle the every-tick scanners (cost B) — cheap, no grid
- Build the `"enemies"` array **once per physics tick** in `main.gd` and expose it (plus a
  `nearest_enemy(pos, r)` helper) so the ~70 sites stop each calling `get_nodes_in_group` and
  allocating. Kills the allocation churn.
- Throttle continuous scanners (orbit, gravity_well, laser, venom, turret) to re-scan at
  **~10–15 Hz** instead of 60 — damage cadence already uses per-enemy cooldowns, so target
  re-acquisition doesn't need 60 Hz.
- Dedup the double/quadruple scans (`gravity_well`, `mine_node`, `turret_node`).

### 3. Spatial grid (uniform hash) — only if loops still dominate after step 2
Rebuild a uniform grid of enemies once per tick (cell ≈ max query radius, ~128 px). Replace the
full scans with `enemies_in_radius(pos, r)` that visits only the overlapping cells → O(local)
instead of O(220). This is the **correct generalization** (radius, not viewport): it includes
off-screen-but-in-range enemies and excludes on-screen-but-far ones. This is the performance
ceiling; build it only if measurement shows the loops themselves still cost after step 2.

### 4. Draw-side cleanup — secondary
- Drop the **unconditional `queue_redraw()`** on pure movers (e.g. `enemy.gd:90`). A translating
  CanvasItem doesn't need a redraw to move — its cached `_draw()` follows the node transform.
  Only redraw when the *look* changes (flash, shield phase, directional shape heading).
- Optionally gate `queue_redraw()` on visibility so off-screen entities don't re-record draws.

### Not worth doing: viewport/on-screen culling of simulation
There is **no** viewport filter today, and it's the wrong lever: enemies must keep simulating
off-screen (they spawn off-screen and chase inward — freezing them breaks the swarm), weapons
must hit off-screen-but-in-range enemies, and at the crash moment the swarm has already
converged on-screen so culling saves little. The radius grid (step 3) is strictly better.

---

## Verification after fixes
- `NICESWARM_TEST=zoo` and `=all_weapons` headless runs stay error-free.
- Replay to late game (or `ENEMY_CAP` high + fast spawn) and confirm framerate holds.
- Re-confirm hits register at healthy fps (validates the missed-hits-were-a-symptom theory).
- Co-op smoke test (`NICESWARM_NET=host`/`join`) — keep host damage authoritative.

---

## Benchmarks — weapon enemy-scan cost (step 3)

Headless micro-benchmark `tests/bench_weapon_query.tscn` (run it as a *scene*, not `--script`,
so autoloads load): a real `Main` grid + a fixed seeded field of **N=220** enemies; each weapon's
own `_physics_process` is timed for 4000 calls. Enemies are made immune to the weapon's damage
type so `take_hit` early-returns (no nodes/score), positions are restored each iter (cancel
knockback drift), and spawned FX are freed each iter — so the timer isolates exactly what the
change touches: the candidate-set iteration. Run before/after with
`git stash push -- scripts/weapons/weapon_fusions.gd`.

| Weapon | Archetype | Before (µs/call) | After (µs/call) | Speedup |
|--------|-----------|-----------------:|----------------:|--------:|
| flame | cone | 86.9 | 14.6 | 5.9× |
| laser | sweep beam | 186.0 | 38.5 | 4.8× |
| nova | radial blast | 95.4 | 35.4 | 2.7× |
| lightning | chain (per-hop scan) | 372.8 | 152.1 | 2.5× |
| fus:teslahalo | orbit-blade (enemy×blade) | 497.2 | 27.5 | **18.1×** |
| fus:novabeam | sweep beam + nova | 237.0 | 43.0 | 5.5× |
| fus:plasmastorm | burn cone | 86.9 | 15.7 | 5.5× |

The orbit-blade halos win biggest because the old code ran `for e in all_enemies(): for blade in
n:` — O(n · blades) every frame; the grid cuts the candidate count to the local neighbourhood.
These are headless CPU-µs deltas; real rendered-fps impact still wants the interactive playtest
above, but the per-call cost reduction is unambiguous and the hit set is provably identical.

---

## 2026-06-15 — Visual-optimization session: measure first, then fix

Branch `worktree-visual-optimization`. Reported symptom: "smoother after the last
pass, then lags again past ~8 min (still better than before)."

### Measurement harness (so we fix the real cost center, not a guess)
- `NICESWARM_FF=<mult>` already fast-forwards a headless host to 10:00. Added a
  per-game-minute **census** (`_ff_census` in `main.gd`): walks the live `world`
  subtree, tallies spawned nodes by script file, and prints total node count +
  physics frame time + the player loadout (so deep-fusion state is visible).
- `NICESWARM_TEST=deep` forces the 5 count-scaling weapons past the Lv3 pool cap
  (what unbounded fusion leveling enables) to reproduce the late-game worst case.

### Findings (x80 FF to 10:00)
| min | level | enemies | total nodes | heaviest spawned types |
|-----|-------|---------|-------------|------------------------|
| 3   | 1     | 214     | 439         | (just the 220-cap swarm) |
| 7   | 33    | 228     | 331         | float_text 36, ring_fx 34, missile 26, telegraph 26, frost 23 |
| 9   | 37    | 222     | 315         | telegraph 45, missile 32, frost 24 |

1. **The 220-enemy swarm is the steady backbone** — ~430 nodes; physics time
   tracks *enemy count*, pinned at `ENEMY_CAP` from min 3 on.
2. **The node-count explosion is CONDITIONAL, not automatic.** Even forcing
   weapons to L10, FF's auto-pick merges them into fresh L1 fusions (merging
   resets level), so counts stayed modest (~230–270 peak). The cliff needs a
   player to repeatedly level *one* deep fusion — real, but not guaranteed.
3. **New finding: short-lived FX accumulate** late game — telegraph up to 45,
   ring_fx 39, float_text 36 (caster spam + high kill rate).
4. **Draw cost is invisible to headless** and is the prime suspect for windowed
   8-min lag (220 enemies re-recording `_draw` every frame, no cull).

### Fixes shipped (each its own commit, verified headless)
- **Grid migration** — nova/laser/flame off `all_enemies()` (O(n)) →
  `EnemyGrid.near()`; 15 fusion `get_nodes_in_group("enemies")` allocs →
  frame-cached `EnemyGrid.all()`.
- **Enemy redraw-gate** — `queue_redraw()` only fires when appearance changes
  (flash/slow/burn/shield + a heading bucket for directional shapes); idle circle
  enemies (most of the swarm) now redraw ~once instead of 60×/s.
- **Node-count soft-cap** — `WeaponBase.count_level() = mini(level,
  MAX_WEAPON_LEVEL)` in every count formula (9 base weapons + 52 fusion sites + 2
  turret deploy caps); damage/area keep scaling. Deep census: frost shards ~24→~10.
- **Projectile flush fix** — a chaining `on_hit` re-spawned an Area2D mid-flush
  ("Can't change monitoring state while flushing queries", 4–12/run, pre-existing);
  Projectile now defers monitoring. FF after: 0 errors, kills unchanged.

Also (visual; parse-verified — feel needs in-window review): player z-above-swarm +
halo + facing notch, enemy palette mute, 0.8× player hurtbox, boss/mini-boss spawn
banner, guaranteed owned-weapon upgrade choice each roll.

### Still open
- The draw-cost win is **unmeasured headless** — verify in-window and with the
  editor profiler (Debugger → Profiler).
- Per-node rotation caching for orbit/laser/gravity (the "rotated buffer" idea):
  only ~3 weapon nodes/player vs 220 enemies — low payoff, deferred.

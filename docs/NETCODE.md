# Snapshot netcode — tick rates, channels, interpolation

Plan for the host-authoritative world-state netcode: **how often** each kind of
state is broadcast, **how** clients render it smoothly, and how to scale entity
count without bandwidth blow-up. This is **orthogonal to transport** — it runs
unchanged over direct-IP ENet or the Noray relay (see [`NORAY.md`](./NORAY.md)).

Status: **mostly applied (2026-06-18).** Live: telegraphs promoted to the 20 Hz
tick; cadence gated by physics-frame count (jitter-free); enemies at **12 Hz**
(`% 5`); and **`STATE_ENEMIES` delta compression** (only changed enemies per tick +
explicit removals, full keyframe every ~1 s and on (re)connect). The **only**
remaining item is **time-based snapshot interpolation** — the current puppet lerp is
fixed-weight, so at 12 Hz (83 ms spacing) fast movers can look slightly steppy;
that's a feel change only verifiable over a real relay, so it's deferred. 30 Hz
physics stays off (CPU not proven the bottleneck).

## Current state (as shipped)

All gating lives in `main.gd::_physics_process` (`scripts/main.gd:1635-1665`) as
**time accumulators** (`t_* += delta; if t_* >= 1/rate`), inside the 60 Hz
`_physics_process`:

| Channel | Const | Rate now | Sender | Notes |
| --- | --- | --- | --- | --- |
| Player pos/facing/dash | — | **20 Hz** (`t_player≥0.05`) | `net.send_player_state` | per local player |
| Enemies | `STATE_ENEMIES` (0) | **16 Hz** (`t_enemy≥1/16`) | `_send_state` | chunked snapshot, the heavy one |
| Gems | `STATE_GEMS` (1) | **8 Hz** (`t_items≥1/8`) | `_send_state` | bundled with pickups+telegraphs |
| Pickups | `STATE_PICKUPS` (2) | **8 Hz** | `_send_state` | |
| **Telegraphs** | `STATE_TELEGRAPHS` (3) | **8 Hz** ⚠️ | `_send_state` | **dodge-critical but slowest — see below** |
| HUD / pings / rank | — | 4 Hz (`t_hud≥0.25`) | `send_hud_state`/`send_pings`/`send_rank_state` | fine as-is |

Receiver de-dups per channel with a monotonic `tick` (`main.gd:2552`,
`if tick <= last_tick[kind]: return`). Puppets render via the `net lerp` path in
`player.gd` (and enemy puppets via `STATE_ENEMIES`).

### Two problems with the current setup

1. **Telegraphs are on the slow 8 Hz items bucket.** Casters (Bomber/Diviner/
   Oracle) telegraph AoE that co-op players are *meant to dodge*; at 8 Hz a warn
   can be up to ~125 ms stale before a client even sees it, on top of interp
   delay — unfair deaths. Telegraphs belong on the **fast** channel.
2. **Time-accumulator gating drifts.** At 60 Hz physics, `t_enemy≥1/16` actually
   fires every 3–4 physics frames with jitter (15–20 Hz wobble), and the cadence
   isn't phase-locked to the sim. Frame-count gating removes the jitter and the
   drift for free.

## Target design (60 Hz physics)

Re-tier channels by **latency sensitivity**, and gate by **physics frame count**
so every send phase-locks to the sim with zero drift.

```gdscript
# main.gd::_physics_process, host branch — replace the t_* accumulators
var f := Engine.get_physics_frames()
if f % 3 == 0:                 # 20 Hz — latency-sensitive
    net.send_player_state(...)         # (already 20 Hz; now jitter-free)
    _send_state(STATE_TELEGRAPHS)      # PROMOTED 8 -> 20 Hz
if f % 6 == 0:                 # 10 Hz — interpolated, forgiving
    _send_state(STATE_ENEMIES)         # 16 -> 10 Hz (bandwidth save)
    _send_state(STATE_GEMS)
    _send_state(STATE_PICKUPS)
if f % 15 == 0:                # 4 Hz — HUD/pings/rank (unchanged)
    ...
```

| Channel | Now | Target | Gate (60 Hz) | Why |
| --- | --- | --- | --- | --- |
| Player + **Telegraphs** | 20 / **8** | **20 Hz** | `f % 3` | dodge/revive timing — must be prompt |
| Enemies | 16 | **10 Hz** | `f % 6` | interpolated; biggest bandwidth line |
| Gems / Pickups | 8 | **10 Hz** | `f % 6` | slow-changing; ride the enemy tick |
| HUD / pings / rank | 4 | 4 Hz | `f % 15` | unchanged |

- Use `Engine.get_physics_frames()` as the **`tick` stamp** too — it's already
  monotonic, so the `last_tick[kind]` de-dup keeps working unchanged.
- **Bundling (optional):** `f % 6 == 0` implies `f % 3 == 0`, so the enemy tick
  always coincides with a player/telegraph tick → those can share one datagram
  and save per-packet overhead. Only worth it if packet count shows up in
  profiling.
- If 16→10 Hz enemies reads as too soft once tested, step to **12 Hz** (`f % 5`)
  — still a clean divisor of 60. Don't exceed the old 16 without a measured need.

## Client interpolation (the smoothness lever, not raw Hz)

Low send rates look smooth **if** puppets are interpolated against a time-stamped
snapshot buffer and rendered slightly in the past. Per-channel buffer, because
spacing differs:

- **Player + telegraphs (20 Hz, 50 ms spacing):** render ~**100 ms** behind
  (2 snapshots → survives one dropped packet).
- **Enemies (10 Hz, 100 ms spacing):** render ~**150–200 ms** behind (2
  snapshots). Larger window is fine — enemies are PvE and forgiving.

If the current `net lerp` is a **fixed-weight** lerp (e.g. `pos = lerp(pos, target,
0.3)`), it's rate-dependent and will change feel when the rate changes — migrate
it to **time-based** interpolation (buffer two snapshots, lerp by
`(render_time - t0) / (t1 - t0)`). The **local** player is never interpolated —
it stays locally simulated for 60 Hz feel.

## Scaling lever: delta + quantization (do this before raising any rate)

`STATE_ENEMIES` is the bandwidth driver (entity count ≫ tick rate). To carry more
enemies without bigger packets:

- **Delta:** send only enemies that changed since the last snapshot; full
  **keyframe** every ~1 s and on late-join (the rejoin/late-join history path in
  `net.gd`/`main.gd` already exists — reuse it for the keyframe).
- **Quantize:** pack positions to 16-bit fixed-point (arena-relative), velocities
  optional. Cuts per-entity bytes ~half.

This raises effective fidelity far more cheaply than bumping Hz.

## Physics-rate decision (open)

Everything above assumes **60 Hz physics** (`physics_ticks_per_second = 60`). If
host CPU becomes the proven bottleneck (the O(n²)-ish enemy work at high counts),
dropping to **30 Hz physics** ~halves sim cost — but it **changes the divisors**
and adds prerequisites:

- Net re-tier at 30 Hz: player+telegraphs `f % 2` (**15 Hz**), enemies `f % 3`
  (**10 Hz**).
- **Projectile tunneling** becomes a risk (fast bolts/glaives/missiles travel
  ~33 ms/step). Confirm hits resolve by **raycast/distance sweep** (tick-rate
  independent), not physics-body overlap — fix that first if not.
- Must enable **`physics/common/physics_interpolation = true`** or 30 Hz movement
  renders choppy.

**Default recommendation: stay 60 Hz** (20/10 split) until profiling proves the
host is sim-bound. Revisit 30 Hz only with the two prerequisites handled.

## Tasks

- [x] Promote `STATE_TELEGRAPHS` off the 8 Hz items bucket onto the 20 Hz tick
      (`f % 3`, host-only). **Done 2026-06-18.**
- [x] Replace the `t_*` accumulators in `_physics_process` with
      `Engine.get_physics_frames() % N` gating. **Done 2026-06-18** — player+telegraphs
      `% 3` (20 Hz), world snapshots `% 5` (12 Hz), HUD `% 15` (4 Hz). Kept the
      existing monotonic `tick_counter` as the de-dup stamp (no need to also switch
      the stamp to the frame counter — fewer moving parts).
- [x] Enemies 16→**12 Hz** (`% 5`). **Done 2026-06-18.** Gems/pickups ride the same
      tick. (Feel caveat: best paired with the time-based interpolation below at this
      rate.)
- [ ] Audit `player.gd` puppet lerp: make it time-based snapshot interpolation
      with per-channel buffers (player ~100 ms, enemies ~150–200 ms). **Only remaining
      item** — feel change, needs real-relay A/B.
- [x] Delta + 16-bit quantization for `STATE_ENEMIES`; keyframe every ~1 s + on
      (re)connect. **Done 2026-06-18** — positions were already 16-bit fixed-point;
      added per-tick delta (only changed enemies) + explicit removals + keyframe
      backstop. `_apply_enemy_state`/`_remove_enemy_puppet` decode it.
- [ ] (If/when CPU-bound) evaluate 30 Hz physics — but only after raycast hit
      detection + `physics_interpolation` are confirmed.

## Verification

- **Bandwidth:** log per-channel bytes/s host-side; expect telegraph promotion to
  cost little and enemy 16→10 + delta to net a clear drop.
- **Feel:** the real tests are **dodging a telegraphed Oracle ring** and **landing
  a revive on a moving ally** over a relayed link — both should tighten vs the
  current 8 Hz telegraph / fixed-lerp baseline.
- Headless smoke still via `NICESWARM_NET` hooks (see `NORAY.md`); run host+joiner
  and confirm puppet motion stays smooth at the lower enemy rate.

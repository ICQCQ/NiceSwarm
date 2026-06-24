# Deterministic / lockstep netcode — design & correction

> **Status: PLAN / not committed.** This documents the idea, corrects it for Godot, and lays
> out a recommended path. No code here yet. See [CLAUDE.md](../../CLAUDE.md) for the *current*
> (host-authoritative) model this would replace or augment.

## The idea (as proposed)

> If all players hold the same game state, the only thing we need to send is each user's
> position — because everything is computed from the same origin seed, the result must be the
> same on every machine. (Inspired by Factorio.)

The kernel is correct and is exactly Factorio's model: **same seed + same inputs + a
deterministic simulation ⇒ identical state on every peer**, so you exchange *inputs* instead of
*world state*. Factorio's own description: *"all multiplayer peers calculate the simulation
themselves and only the player input (input actions) is exchanged"*; the server just proxies
inputs and pins each to a tick. Bandwidth then becomes **independent of entity count** — the
prize, because today's bottleneck is exactly the opposite (see below).

## Four corrections that decide whether it works

### 1. You send *inputs/commands*, not "positions"
Position is a *result*, not an input. In lockstep each peer sends its **intent** (move vector,
dash, ability-fired) tick-stamped, and every peer's sim *derives* all positions. We already send
player position at 20 Hz — that is **not** where the win is. The win is **deleting the world-state
snapshots**: today the host chunks full snapshots of ≤80 entities/packet at **12 Hz (enemies) /
8 Hz (gems, pickups) / 8 Hz (telegraphs) / 4 Hz (HUD)** (`STATE_ENEMIES/GEMS/PICKUPS/TELEGRAPHS`
in `main.gd` + `spawner.gd`). Under lockstep those channels vanish — enemies/gems/pickups are
recomputed locally from the seed.

### 2. Determinism is the whole ballgame, and Godot does **not** give it for free
This is the make-or-break correction. Godot's float math and physics engine are **not
deterministic across machines** (CPU/OS/build differences change float rounding → desync). The
ecosystem is unanimous: *"most physics engines aren't deterministic (including Godot's built-in);
Box2D is deterministic only if both run the same binary."* The standard fix is **fixed-point
integer math**, not floats. A faithful port therefore requires:

- **Fixed-point deterministic motion/collision.** Options: [SG Physics 2D](https://www.snopekgames.com/project/sg-physics-2d/)
  (snopek's fixed-point 2D engine, built for this), or hand-rolled fixed-point (viable here —
  see §"Why NiceSwarm is well-positioned").
- **A single lockstep-seeded PRNG**, advanced in identical call-order on every peer. **Today the
  sim uses ~60 global `randf`/`randi` calls across 13 files** (enemy AI, spawner, fusions,
  weapons) — all per-client and unseeded. Every *gameplay-affecting* roll must move to one shared
  `RandomNumberGenerator(seed)`; cosmetic rolls (sfx pitch, camera shake, draw jitter) can stay
  on the global RNG.
- **Deterministic iteration order** everywhere — the enemy spatial grid, `enemies_by_id`,
  any dict/group scan. Godot `Dictionary` keeps insertion order (good); group/node ordering and
  float-keyed sorts must not leak into logic.
- **No wall-clock / `Time` / per-frame `delta`** in the sim. A fixed tick (the game already runs
  fixed-step) drives everything; `Time.get_ticks_*` (used in `sfx.gd`) stays cosmetic-only.

### 3. Lockstep adds input latency
A peer can't simulate tick *N* until **every** peer's tick-*N* input has arrived. Factorio hides
this with an **input-delay buffer** (your actions schedule a few ticks ahead) and accepts the lag
— fine for a builder. **NiceSwarm is twitch bullet-hell**, where that lag lands on *movement
feel*. The alternative — **rollback + prediction** (GGPO; [snopek's godot-rollback-netcode](https://www.snopekgames.com/))
— predicts locally and re-simulates on misprediction, but re-running a 200+ enemy sim several
ticks per frame is expensive. **This tension is the single biggest risk for this genre** and is
why full lockstep is not the default recommendation below.

### 4. You still need desync detection + late-join
- **Desync hashing.** Determinism bugs are inevitable; without a periodic **state-hash/CRC
  heartbeat** comparing peers (Factorio's desync detection) they're undebuggable. Build this
  *first*, before relying on determinism.
- **Late join / drop-in.** A new peer can't replay from tick 0; you snapshot **full** state once
  and ship it, then lockstep. We already have full-state serialization (`_apply_state`) — it just
  gets used rarely instead of every tick.

## Why NiceSwarm is unusually well-positioned (and where it isn't)

**For it:** enemies already avoid real physics (`collision_mask = 0`, distance checks, VS-style
overlap), spawning is already host-driven on a fixed tick, and the "sim" is mostly custom
integer-ish logic. A deterministic rewrite is **far more feasible here** than in a physics-heavy
game — most of the hard part (ripping out the physics engine) is already done.

**Against it:** it's a **model change, not an increment.** Today is host-authoritative — clients
are puppets, weapons are cosmetic, the host owns all damage. Lockstep means **every client runs
the real sim, no puppets, no authority** — a rewrite of `net.gd` and the `_send_state` /
`_apply_state` split. Plus the ~60 RNG sites and all float motion (`move_and_slide`, Area2D
projectiles) must become deterministic.

## Three paths (recommendation: **C**)

| | **A. Interest-managed authoritative** | **C. Deterministic prediction + sparse correction** ⟵ recommended | **B. Full Factorio lockstep** |
|---|---|---|---|
| Idea | Keep host authority; send only entities near each client + quantize + better deltas | Clients deterministically predict enemies from the seed for visuals; host still sends **low-rate** authoritative snapshots that snap drift | Inputs-only on the wire; fixed-point sim; no authority |
| Bandwidth win | High | Very high | Maximum (independent of entity count) |
| Determinism required | None | **Approximate** (drift is corrected, not fatal) | **Bit-exact** |
| Input-lag risk | None | None (keeps local prediction) | Real (movement lag) |
| Eng. cost / risk | Low | Medium | High (fixed-point rewrite + desync hunts) |
| Best when | Quick win, small party | **Action co-op, few players** | Huge entity/player counts |

**Why C for this game:** it captures most of the bandwidth win *without* betting the game on
cross-machine float determinism or eating movement lag. Imperfect determinism only causes visual
drift, which the sparse authoritative corrections fix — so it degrades gracefully instead of
desyncing. Full **B** is the "correct" Factorio answer and is *achievable* here given the
physics-light sim, but it's a multi-week simulation rewrite and changes the feel; pick it only if
the goal becomes very large entity/player counts. **Klotho** (the other Godot determinism lib) is
**.NET-only** — NiceSwarm is GDScript, so the realistic toolkit is SG Physics 2D +
godot-rollback-netcode, or hand-rolled fixed-point.

## Path C — concrete plan for NiceSwarm

The host stays authoritative; clients gain a **local predicted simulation** of the cheap,
seed-driven entities, and the host's existing snapshots drop to a **low correction rate**.

**Phase 0 — instrumentation (do this regardless of path).**
- Add a **state-hash heartbeat**: each peer hashes a canonical subset of state (enemy count +
  quantized positions + RNG cursor) every N ticks; log mismatches. This is the only way to
  measure how deterministic the sim *actually* is and is reusable for A or B.
- Add bandwidth counters per channel so the win is measured, not assumed.

**Phase 1 — single lockstep RNG for spawns.**
- Replace the spawner's global `randf`/`randi` with one seeded `RandomNumberGenerator`; broadcast
  the seed at `start_game`. Enemy *spawn* (type, position, timing) becomes reproducible on every
  peer. Keep host authority for now — just verify via the heartbeat that predicted spawns match.

**Phase 2 — client-side predicted enemy motion.**
- Clients simulate enemy chase/movement locally from the shared seed + known player positions
  (already received) instead of lerping puppets. The host **reduces `STATE_ENEMIES` to a low
  correction tick** (e.g. 2–3 Hz) that snaps any drift. This is where the bandwidth drops sharply.
- Damage stays host-authoritative (clients still don't kill); only *visual position* is predicted.

**Phase 3 — extend prediction to gems/pickups/telegraphs**, dropping those channels to correction-only.

**Phase 4 — (optional) tighten toward B**: if the heartbeat shows the sim is already near-deterministic
and corrections are rarely needed, move damage resolution local and shrink corrections further.

**Stop at the phase where the bandwidth is acceptable** — C is explicitly a dial, not an all-or-nothing rewrite.

## Risks & how C de-risks vs B
- **Float drift** → tolerated (corrected), not fatal. B would desync.
- **RNG order drift** → contained to spawns first (Phase 1), verifiable before expanding.
- **Movement lag** → avoided; local prediction keeps your own avatar responsive.
- **Debuggability** → the Phase-0 heartbeat makes drift visible from day one.

## Interaction with the in-game menu work (PR #10)
Under full **B**, "client auto-safe pause" becomes trivial (just stop feeding that player's
inputs). Under the current model and **C**, the host-side `safe` flag (already added in PR #10)
is the right mechanism. Nothing here blocks PR #10; it adapts cleanly to whichever path is chosen.

## Sources
- [Factorio Wiki — Desynchronization (deterministic lockstep, inputs-only)](https://wiki.factorio.com/Desynchronization)
- [Factorio FFF #302 — The multiplayer megapacket](https://www.factorio.com/blog/post/fff-302)
- [SG Physics 2D — deterministic fixed-point physics for Godot (Snopek)](https://www.snopekgames.com/project/sg-physics-2d/)
- [Getting started with SG Physics 2D & determinism in Godot](https://www.snopekgames.com/tutorial/2021/getting-started-sg-physics-2d-and-deterministic-physics-godot/)
- [Klotho — deterministic multiplayer for Godot (.NET only)](https://godotengine.org/asset-library/asset/5234)

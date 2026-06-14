# NiceSwarm tests

Zero-dependency headless unit tests (no GUT/plugin — matches the project's build-in-code ethos).

## Run

```bash
godot --headless --path . --script res://tests/run_tests.gd
```
Prints `[tests] N passed, M failed` and exits **0** on success, **1** on any failure
(CI-friendly). Run `godot --headless --path . --import` once first after adding a new
test file (global class cache).

## What's covered (unit)

`run_tests.gd` loads each `test_*.gd` (a `RefCounted` with `func run(t)`; `t` is the
`Tester` with `eq/ne/gt/ge/approx/ok`):

| Module | Covers |
|--------|--------|
| `test_config.gd` | every `GameConfig` const (ranges + invariants) |
| `test_weapons.gd` | `WeaponConfig.BASE` integrity, the damage formula, each of the 13 weapons' `_init()` |
| `test_enemies.gd` | `EnemyConfig.CLASSES`/`SPAWN_POOL`/`SPAWN_SPECIALS` validity + the gem red-threshold invariant |
| `test_fusions.gd` | all 78 weapon pairs have an order-independent `Fusions.info`, and `Fusions.make` returns a `WeaponBase` |
| `test_spawner.gd` | `EnemySpawner` pure math (type registry, `warmup`, `class_tier` bounds, `heat`/`diff`, `reset`) via a mock `main` |
| `test_gems.gd` | the `XpGem` value model behind the gem-cap condensation |

## What's covered by integration instead

Scene/network/UI/`_draw`/`_process` functions on `Main` / `Net` / `Player` are not
unit-testable in isolation (they need the scene tree, a live ENet peer, or input). They are
exercised by the **headless smoke hooks** — see [../CLAUDE.md](../CLAUDE.md):

- `NICESWARM_NET=solo|host|join` — full run + co-op host/client sync
- `NICESWARM_TEST=zoo|all_weapons|merge|bomber` — every enemy type / weapon / fusion / telegraph path
- `NICESWARM_FF=<mult>` — fast-forward a full 10-minute run for late-game/balance checks

## Adding a test

1. Create `tests/test_<area>.gd` extending `RefCounted` with `func run(t)`.
2. Add its path to `MODULES` in `run_tests.gd`.
3. `--import`, then run.

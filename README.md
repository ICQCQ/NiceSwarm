# NiceSwarm

![NiceSwarm](niceswarn_banner.png)

A top-down **arena-survival roguelite** (Vampire-Survivors-like) with **online co-op**,
built entirely in **Godot 4 / GDScript** — no art assets, every entity drawn in code.
You move; your weapons fire themselves. Collect XP, level up, pick upgrades, **fuse**
weapons, and survive **10 minutes** against an ever-growing swarm.

## Play

### ▶ Download (recommended)

Grab the **launcher** — it keeps the game current automatically, then launches it:

### **[⬇ Download NiceSwarm-Launcher.exe](https://github.com/ICQCQ/NiceSwarm/releases/download/launcher/NiceSwarm-Launcher.exe)** &nbsp;·&nbsp; Windows x86_64

Run it once: it downloads the latest build into `%LOCALAPPDATA%\NiceSwarm` and starts the
game, and every later run auto-updates first — so you're always on the newest version
without re-downloading by hand. Windows on ARM:
[NiceSwarm-Launcher-arm64.exe](https://github.com/ICQCQ/NiceSwarm/releases/download/launcher/NiceSwarm-Launcher-arm64.exe)
· all launcher builds: [releases/tag/launcher](https://github.com/ICQCQ/NiceSwarm/releases/tag/launcher)
· how it works: [LAUNCHER.md](LAUNCHER.md).

> Prefer a fixed build? Download the game `.exe` straight from the
> [`latest` release](https://github.com/ICQCQ/NiceSwarm/releases/tag/latest) — it just won't
> auto-update.

### From source

```bash
godot --path .            # run (Godot 4.6, on PATH via Scoop)
```
Or double-click **`build.cmd`** → `build/NiceSwarm.exe` (single self-contained file).
One-time export-template setup: see [CLAUDE.md](CLAUDE.md).

**Controls:** WASD/arrows move · SPACE/SHIFT dash · `1–6` pick upgrade · ESC pause ·
`M` menu · `R` restart (on game-over).

## Highlights

- **13 weapons** that all auto-fire and honour 4 universal stats (Power / Haste / Area /
  Duration), plus **78 signature fusions** — merge two maxed weapons into a new one.
- **Adaptive difficulty:** clear fast and the game escalates; crush the map mid-game and it
  surges; get overwhelmed and it eases off. Telegraphed casters, armoured wardens,
  energy-immune wisps, ricocheting bouncers, and **bosses** with slams, enrage, and summons.
- **Online co-op (up to 4):** host-authoritative; shared XP/level, separate HP & builds,
  revive your downed allies, team chests.
- **Procedural audio** synthesised at startup — a distinct sound for every action, no files.

## Docs

| Doc | What |
|-----|------|
| [GAME_DESIGN.md](GAME_DESIGN.md) | the full design: loop, pacing, progression, economy, co-op |
| [WEAPON_DESIGN.md](WEAPON_DESIGN.md) | the 4-stat contract + every weapon & fusion |
| [ENEMY_DESIGN.md](ENEMY_DESIGN.md) | every enemy class/tier + boss mechanics |
| [CLAUDE.md](CLAUDE.md) | architecture, file map, build/run/test commands |
| [PLAN.md](PLAN.md) | milestone status + session log |

Made with Godot 4.6 · GDScript · zero art assets.

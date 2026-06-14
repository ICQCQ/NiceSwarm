#!/usr/bin/env python
"""NiceSwarm balance model — XP curve + income simulation + wave schedule.

Reproducible source for the graphs in BALANCE_PLAN.md. This is a *model* used to
shape the curve before implementation; final numbers are calibrated against a
headless fast-forward run during implementation. Run: `py docs/balance/curve_model.py`
"""
import os
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np

OUT = os.path.dirname(os.path.abspath(__file__))
WIN_TIME = 600.0          # 10-minute run
XP_RATE = 1.0             # default cfg_xp_rate (XP_OPTS[1])

# --- proposed XP curve bands (cost AT level L to reach L+1) -------------------
XP_BASE = 5.0
XP_STEP_EARLY = 3.0       # L1..13  (fast dopamine)
XP_STEP_MID = 9.0         # L14..33 (steepen — the tug-of-war)
XP_STEP_LATE = 18.0       # L34+    (aggressive — earned)
BAND_EARLY = 13
BAND_MID = 33


def xp_cost(L: int) -> float:
    """XP required at level L to advance to L+1 (before cfg_xp_rate)."""
    early = max(min(L, BAND_EARLY) - 1, 0)
    mid = max(min(L, BAND_MID) - BAND_EARLY, 0)
    late = max(L - BAND_MID, 0)
    return XP_BASE + early * XP_STEP_EARLY + mid * XP_STEP_MID + late * XP_STEP_LATE


def xp_needed(L: int) -> int:
    return max(1, round(xp_cost(L) / XP_RATE))


# --- wave schedule (per game-minute, 0..9) -----------------------------------
# intensity = spawn-rate multiplier; pop = desired-population multiplier (so a
# valley actually thins the field instead of being refilled back up).
WAVES = [
    # (label,            intensity, pop_mult, wall)
    ("intro",            0.8,  0.8,  False),  # m0
    ("build",            1.0,  1.0,  False),  # m1
    ("swarm peak",       1.4,  1.3,  False),  # m2
    ("valley",           0.6,  0.6,  False),  # m3 breather — collect gems
    ("build + elites",   1.1,  1.1,  False),  # m4
    ("WALL (DPS check)", 1.2,  1.1,  True),   # m5 wall
    ("swarm peak",       1.5,  1.4,  False),  # m6
    ("valley",           0.65, 0.65, False),  # m7 breather
    ("ramp",             1.3,  1.3,  False),  # m8
    ("WALL + climax",    1.6,  1.5,  True),   # m9 final wall
]

# base spawn interval lerp (matches GameConfig SPAWN_INTERVAL_START/END over 540s)
SPAWN_INTERVAL_START = 1.4
SPAWN_INTERVAL_END = 0.2
AVG_XP_PER_KILL = 1.25    # most enemies xp=1; tanks 5, casters/elites a bit more
# Effective spawn-rate boost over the bare interval: SPAWN_REFILL_MULT makes the
# rate ~2.5x whenever the field is below desired pop (common, since the player
# clears fast), plus periodic tank/elite/bomber/wall spawns. Modeled as a single
# uncertain factor — THE knob that final calibration measures from a real run.
EFFECTIVE_SPAWN_MULT = 1.8


def base_interval(t: float) -> float:
    f = min(t / 540.0, 1.0)
    return SPAWN_INTERVAL_START + (SPAWN_INTERVAL_END - SPAWN_INTERVAL_START) * f


def simulate():
    """Step the run at dt=1s; accumulate kill-XP and level up. Returns time/level
    series and per-minute levels. Assumes the player keeps up with spawns (the
    TTK=1-2-hits design intent), so kills/sec ~= spawn rate * intensity."""
    dt = 1.0
    t = 0.0
    xp = 0.0
    level = 1
    times, levels, rates = [], [], []
    while t < WIN_TIME:
        m = min(int(t // 60), len(WAVES) - 1)
        intensity = WAVES[m][1]
        rate = intensity * EFFECTIVE_SPAWN_MULT / base_interval(t)  # kills/sec
        xp += rate * AVG_XP_PER_KILL * XP_RATE * dt
        while xp >= xp_needed(level):
            xp -= xp_needed(level)
            level += 1
        times.append(t); levels.append(level); rates.append(rate)
        t += dt
    per_min = [levels[min(int(mm * 60), len(levels) - 1)] for mm in range(11)]
    return times, levels, rates, per_min


def plot_xp_curve():
    Ls = list(range(1, 56))
    per = [xp_needed(L) for L in Ls]
    cum = np.cumsum([0] + per)[:-1]  # XP to *reach* level L
    fig, ax1 = plt.subplots(figsize=(9, 5))
    ax1.bar(Ls, per, color="#4ea1ff", alpha=0.85, label="XP for this level")
    ax1.set_xlabel("Player level"); ax1.set_ylabel("XP to next level", color="#1f6fd0")
    for x, c in [(BAND_EARLY, "#2ecc71"), (BAND_MID, "#e67e22")]:
        ax1.axvline(x + 0.5, color=c, ls="--", lw=1.2)
    ax1.text(6, max(per) * 0.92, "EARLY\n+3/lvl", color="#2ecc71", ha="center", fontsize=9)
    ax1.text(23, max(per) * 0.92, "MID\n+9/lvl", color="#e67e22", ha="center", fontsize=9)
    ax1.text(45, max(per) * 0.92, "LATE\n+18/lvl", color="#c0392b", ha="center", fontsize=9)
    ax2 = ax1.twinx()
    ax2.plot(Ls, cum, color="#c0392b", lw=2.2, label="cumulative XP to reach level")
    ax2.set_ylabel("Cumulative XP", color="#c0392b")
    plt.title("NiceSwarm XP curve (10-min run, 1.0x rate)")
    fig.tight_layout(); fig.savefig(os.path.join(OUT, "xp_curve.png"), dpi=110)
    plt.close(fig)
    return per, cum


def plot_waves(times, levels, rates):
    fig, (ax1, ax2) = plt.subplots(2, 1, figsize=(9, 6.5), sharex=True)
    inten = [w[1] for w in WAVES]
    pops = [w[2] for w in WAVES]
    x = list(range(len(WAVES)))
    ax1.step(x + [len(WAVES)], inten + [inten[-1]], where="post", color="#e74c3c", lw=2, label="spawn intensity")
    ax1.step(x + [len(WAVES)], pops + [pops[-1]], where="post", color="#2980b9", lw=2, ls="--", label="desired pop")
    for i, w in enumerate(WAVES):
        if w[3]:
            ax1.axvspan(i, i + 1, color="#c0392b", alpha=0.13)
            ax1.text(i + 0.5, max(inten) * 1.02, "WALL", color="#c0392b", ha="center", fontsize=9, weight="bold")
    ax1.set_ylabel("multiplier"); ax1.set_title("Wave schedule — peaks, valleys, DPS-check walls (per minute)")
    ax1.legend(loc="upper left", fontsize=8); ax1.set_ylim(0, max(inten) * 1.18)
    for i, w in enumerate(WAVES):
        ax1.text(i + 0.5, 0.08, w[0], ha="center", fontsize=7, color="#444")
    ax2.plot([t / 60 for t in times], levels, color="#8e44ad", lw=2)
    ax2.set_xlabel("minute"); ax2.set_ylabel("player level (modeled)")
    ax2.set_title("Modeled level progression (income simulation)")
    ax2.grid(alpha=0.25)
    fig.tight_layout(); fig.savefig(os.path.join(OUT, "wave_schedule.png"), dpi=110)
    plt.close(fig)


if __name__ == "__main__":
    per, cum = plot_xp_curve()
    times, levels, rates, per_min = simulate()
    plot_waves(times, levels, rates)
    print("=== XP curve (level: need / cumulative-to-reach) ===")
    for L in [1, 5, 10, 13, 14, 20, 25, 33, 34, 40, 45, 50]:
        print(f"  L{L:>2}: need {xp_needed(L):>4}   cumulative {int(cum[L-1]):>6}")
    print("\n=== Modeled level @ each minute (income sim, 1.0x) ===")
    for mm, lv in enumerate(per_min):
        print(f"  min {mm:>2}: level {lv}")
    print(f"\nFINAL modeled level at win (10:00): {per_min[10]}")
    print("Graphs written: xp_curve.png, wave_schedule.png")

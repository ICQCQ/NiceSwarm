class_name GameConfig
extends RefCounted
## Central game + difficulty tuning. main.gd aliases these (e.g. `const WIN_TIME :=
## GameConfig.WIN_TIME`), so this is the one place to tweak the knobs below.

# --- core run ---
const ARENA := Rect2(-1200, -1200, 2400, 2400)
const WIN_TIME := 600.0          # survive this long (s) to win
const MAX_WEAPONS := 5           # weapon slots per player per run
const MAX_WEAPON_LEVEL := 3      # per-weapon cap before it can be merged
const MAX_CHOICES := 6           # max upgrade options offered per level-up
const ENEMY_CAP := 220           # hard limit on live enemies
const TELEGRAPH_WARN := 1.3      # seconds to dodge a telegraphed strike
const NET_PORT := 24565          # default co-op port

# --- difficulty climb: difficulty += dt * BASE * warmup * (1 + heat*HEAT + (level-1)*LEVEL) ---
const DIFF_BASE := 1.0 / 48.0    # base climb rate (gentler = slower ramp)
const DIFF_HEAT := 2.4           # how much clear-rate heat accelerates the climb
const DIFF_LEVEL := 0.02         # how much each player level accelerates the climb
const DIFF_LEVEL_STEP := 0.05     # flat difficulty added on each level-up
const DIFF_WARMUP_FLOOR := 0.25  # early-game climb fraction at t=0
const DIFF_WARMUP_SECS := 80.0   # seconds to ramp warmup to full

# --- spawning ---
const SPAWN_RING_MIN := 700.0         # enemies spawn this far from the anchor player...
const SPAWN_RING_MAX := 900.0         # ...up to this far (random within the ring)
const SPAWN_SAFE_RADIUS := 500.0      # never spawn an enemy within this of ANY alive player
const SPAWN_DESIRED_BASE := 6.0       # target live-enemy count at difficulty 0
const SPAWN_DESIRED_PER_DIFF := 3.0   # +this many target enemies per difficulty point
const SPAWN_INTERVAL_START := 1.4     # seconds between spawns early
const SPAWN_INTERVAL_END := 0.2       # seconds between spawns late (at ~9 min)
const SPAWN_REFILL_MULT := 0.4        # interval ×this while below the desired population

# --- time-based wave rhythm (layered on top of pace/heat in EnemySpawner.run_spawning) ---
# Per-game-minute [intensity, pop_mult], lerped between minutes for a smooth peaks/valleys
# curve. intensity divides the spawn interval (peak = faster); pop_mult scales desired_pop
# (valley = a real breather, below the normal floor). Bosses own the hard DPS-checks.
const WAVES := [
	[0.8, 0.8],   # 0 intro
	[1.0, 1.0],   # 1 build
	[1.4, 1.3],   # 2 swarm peak
	[0.6, 0.6],   # 3 valley (breather)
	[1.1, 1.1],   # 4 build + elites
	[1.3, 1.2],   # 5 pressure peak
	[1.5, 1.4],   # 6 swarm peak
	[0.65, 0.65], # 7 valley (breather)
	[1.3, 1.3],   # 8 ramp
	[1.6, 1.5],   # 9 climax
]
const WAVE_POP_FLOOR := 3.0           # valleys can thin the field to this (a genuine lull)

# --- xp gems ---
const MAX_GEMS := 500                  # hard cap on live ground gems (perf); excess XP condenses
const GEM_CONDENSED_THRESHOLD := 25    # gem value at/above which it renders as a big red gem

# --- xp level curve: three-band step curve (cost at level L to reach L+1), /cfg_xp_rate ---
# Replaces the old flat-linear curve. Steepening shape (fast early → earned late);
# absolute steps calibrated via a NICESWARM_FF run to land the 10-min win near level ~45.
const XP_BASE := 5            # cost to reach level 2
const XP_BAND_EARLY := 13     # levels 1..13 use the early step
const XP_BAND_MID := 33       # levels 14..33 use the mid step; 34+ use the late step
const XP_STEP_EARLY := 2      # +per level in the early band (fast dopamine)
const XP_STEP_MID := 4        # +per level in the mid band
const XP_STEP_LATE := 7       # +per level in the late band (aggressive; calibrated with waves on)


## Cost AT `lvl` to reach the next level — three-band step curve, divided by `rate`.
## Closed form (no loop). Pure + static so it's unit-testable without a Main instance.
static func xp_for_level(lvl: int, rate: float) -> int:
	var n := lvl - 1  # levels gained so far
	var e := mini(n, XP_BAND_EARLY - 1)
	var m := clampi(n - (XP_BAND_EARLY - 1), 0, XP_BAND_MID - XP_BAND_EARLY)
	var l := maxi(n - (XP_BAND_MID - 1), 0)
	var need := XP_BASE + XP_STEP_EARLY * e + XP_STEP_MID * m + XP_STEP_LATE * l
	return maxi(1, int(round(float(need) / maxf(rate, 0.0001))))

# --- heat exponential spike: punishes near-clearing the map once mid-game ---
const MID_GAME_TIME := 300.0     # heat_spike can only arm after this many seconds
const HEAT_SPIKE_POP_FRAC := 0.2 # live pop below this fraction of desired_pop arms the spike
const HEAT_SPIKE_GROWTH := 1.8   # exponential growth rate (/s) while armed
const HEAT_SPIKE_DECAY := 2.0    # linear decay rate (/s) once the map refills
const HEAT_SPIKE_MAX := 5.0      # cap on the spike term
const DIFF_SPIKE := 1.0          # weight of heat_spike in the difficulty climb

# --- boss spawns: a tough "boss" class enemy after enough kills ---
const BOSS_KILL_BASE := 60       # total kills before the first boss
const BOSS_KILL_INTERVAL := 90   # extra kills required for each subsequent boss

# --- bouncer: special population, separate from the normal pool/desired_pop ---
const BOUNCER_UNLOCK := 165.0       # bouncers start appearing at this elapsed time
const BOUNCER_CAP_BASE := 2.0       # bouncer population cap at pace 0
const BOUNCER_CAP_PER_PACE := 1.0   # +this many cap per pace point (keeps growing)
const BOUNCER_SPAWN_INTERVAL := 2.0 # seconds between bouncer population top-ups

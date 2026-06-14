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
const DIFF_HEAT := 1.8           # how much clear-rate heat accelerates the climb
const DIFF_LEVEL := 0.02         # how much each player level accelerates the climb
const DIFF_LEVEL_STEP := 0.3     # flat difficulty added on each level-up
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

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

# --- online lobby / relay (M7.6 — see NETWORKING.md) ---
# Defaults are placeholders; point these at your VPS deployment (or override via
# env for dev). The Lobby Registry is plain HTTP(S); Noray does hole-punch+relay.
const LOBBY_URL_DEFAULT := "http://127.0.0.1:8088"  # registry base URL
const NORAY_HOST_DEFAULT := "127.0.0.1"             # Noray server host
const NORAY_PORT_DEFAULT := 8890                     # Noray registration port

static func lobby_url() -> String:
	var e := OS.get_environment("NICESWARM_LOBBY_URL")
	return e if e != "" else LOBBY_URL_DEFAULT

static func noray_host() -> String:
	var e := OS.get_environment("NICESWARM_NORAY_HOST")
	return e if e != "" else NORAY_HOST_DEFAULT

static func noray_port() -> int:
	var e := OS.get_environment("NICESWARM_NORAY_PORT")
	return int(e) if e != "" else NORAY_PORT_DEFAULT


# --- bouncer: special population, separate from the normal pool/desired_pop ---
const BOUNCER_UNLOCK := 165.0       # bouncers start appearing at this elapsed time
const BOUNCER_CAP_BASE := 2.0       # bouncer population cap at pace 0
const BOUNCER_CAP_PER_PACE := 1.0   # +this many cap per pace point (keeps growing)
const BOUNCER_SPAWN_INTERVAL := 2.0 # seconds between bouncer population top-ups

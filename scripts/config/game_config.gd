class_name GameConfig
extends RefCounted
## Central game + difficulty tuning. main.gd aliases these (e.g. `const WIN_TIME :=
## GameConfig.WIN_TIME`), so this is the one place to tweak the knobs below.

# --- core run ---
const ARENA := Rect2(-1200, -1200, 2400, 2400)
const WIN_TIME := 600.0          # survive this long (s) to win
const MAX_WEAPONS := 5           # weapon slots per player per run
const MAX_WEAPON_LEVEL := 3      # per-weapon cap before it can be merged
const MAX_FUSION_TIER := 2       # fusion depth cap: base+base->T1, T1+T1->T2 (final, no T3)
const MAX_CHOICES := 6           # max upgrade options offered per level-up
const ENEMY_CAP := 300           # hard limit on live enemies (was 220 — denser flood)
const TELEGRAPH_WARN := 1.3      # seconds to dodge a telegraphed strike
const MAX_TELEGRAPHS := 9        # cap simultaneous danger zones (was 6 — more caster area-denial late)
const NET_PORT := 24565          # default co-op port

# --- weapon progression ---
# Every weapon's base damage is multiplied by (1 + WEAPON_LEVEL_POWER * (party_level - 1)),
# on top of its own Lv1->3 growth and the player's Power picks. Lets weapons you never
# pour level-ups into still keep pace as the run (and enemy HP) scales. Tunable via FF.
const WEAPON_LEVEL_POWER := 0.025   # was 0.04 — dialed back to shrink the late-game DPS snowball

# --- difficulty climb: difficulty += dt * BASE * warmup * (1 + heat*HEAT + (level-1)*LEVEL) ---
const DIFF_BASE := 1.0 / 45.0    # base climb rate (was 1/62 — faster ramp, toward the old 1/34)
# Late-game lethality: enemies scale fast/tanky enough with difficulty to catch and survive
# against a high-DPS kiter (breaks the zero-damage snowball). Applied in spawner.make_enemy.
const ENEMY_SPEED_DIFF_SCALE := 0.025  # enemy speed ×(1 + diff·this) — late enemies ~match player move speed
const ENEMY_HP_DIFF_SCALE := 0.04      # enemy hp ×(1 + diff·this) — survive the alpha strike to reach you
const ENEMY_HP_PER_LEVEL := 0.05       # base enemy hp ×(1 + this·(party_level-1)) — tankier as the party levels
const CC_IMMUNE_TIER := 2              # enemies at this tier index+ (the 3rd tier) + bosses resist knockback & suck-in
const DIFF_HEAT := 3.12          # how much clear-rate heat accelerates the climb (was 2.4, +30%)
const DIFF_LEVEL := 0.02         # how much each player level accelerates the climb
const DIFF_LEVEL_STEP := 0.05     # flat difficulty added on each level-up
const DIFF_WARMUP_FLOOR := 0.25  # early-game climb fraction at t=0
const DIFF_WARMUP_SECS := 130.0  # seconds to ramp warmup to full (was 80 — longer ramp softens the
                                 # difficulty/spawn-rate cliff now that the late game floods to 300)

# --- spawning ---
const SPAWN_RING_MIN := 300.0         # enemies spawn this far from the anchor player... (was 700; note SPAWN_SAFE_RADIUS still clamps the effective min)
const SPAWN_RING_MAX := 1200.0        # ...up to this far (random within the ring; was 900 — wider band)
const SPAWN_SAFE_RADIUS := 250.0      # never spawn an enemy within this of ANY alive player (was 500 — closer spawns allowed)
const SPAWN_DESIRED_BASE := 8.0       # target live-enemy count at difficulty 0 (was 6.0 — denser swarm)
const SPAWN_DESIRED_PER_DIFF := 3.5   # +this many target enemies per difficulty point (was 2.5 — denser late game)
const SPAWN_INTERVAL_START := 0.2     # seconds between spawns early (5x faster than the prior 1.0)
const SPAWN_INTERVAL_END := 0.024     # seconds between spawns late (5x faster than the prior 0.12)
const SPAWN_REFILL_MULT := 0.4        # interval ×this while below the desired population

# --- co-op party scaling (host-authoritative; N = peer_ids.size()) ---
# Two independent levers make a bigger party harder: tougher enemies (more hp to
# chew through with more guns on the field) and a denser swarm (more bodies). They
# scale per EXTRA player: at N=1 both terms are 1.0, so solo is untouched. Eased
# from the original 0.5/0.6 — at those rates a 4-player field was ~2.5× hp and
# ~2.8× spawn density, which over-punished co-op (sim 2-4p sat at ~27-33% win vs
# the 50-60% target). See docs/balance/MULTIPLAYER_BALANCE_SIM.md.
const PARTY_HP_PER := 0.3             # enemy hp ×(1 + this·(N-1))
const PARTY_RATE_PER := 0.4           # spawn density ×(1 + this·(N-1))

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
# Base XP-gain multiplier — effective xp rate = cfg_xp_rate (menu, 0.5-2x) * this. 0.5 halves
# leveling speed (player is weaker for longer, killing the late-game snowball). Tunable balance knob.
const XP_GAIN_MULT := 0.5
const XP_BASE := 5            # cost to reach level 2
const XP_GROWTH := 1.12       # exponential per-level growth: each level costs XP_GROWTH× the last


## Cost AT `lvl` to reach the next level — an EXPONENTIAL (geometric) curve, divided by `rate`:
## need(lvl) = XP_BASE * XP_GROWTH^(lvl-1). The requirement compounds — gentle early (build comes
## online fast), then steepens sharply late so high levels are genuinely earned. Pure + static so
## it's unit-testable without a Main instance.
static func xp_for_level(lvl: int, rate: float) -> int:
	var need := XP_BASE * pow(XP_GROWTH, lvl - 1)
	return maxi(1, int(round(need / maxf(rate, 0.0001))))

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
# Boss HP is DPS-responsive so a boss is always a real fight, never melted by a snowball
# build. It scales with: the party's recent damage output, party level, and player count.
const BOSS_DPS_WINDOW := 15.0    # seconds of party damage averaged into "recent dps"
const BOSS_FIGHT_SECONDS := 8.0  # boss hp ~= recent_dps * this (target single-boss fight length)
const BOSS_HP_PER_LEVEL := 0.015 # boss hp x(1 + this*(party_level-1))
const BOSS_HP_PER_PLAYER := 0.5  # boss hp x(1 + this*(player_count-1))


## Boss HP from the three factors the design calls for: the party's recent DPS (so the
## fight scales to the party's actual output), party level, and player count. `tier_floor`
## is the boss tier's static/difficulty base — a floor so a boss is never trivial when
## recent DPS is momentarily low. Pure + static, so it's unit-testable without a Main.
static func boss_hp(tier_floor: float, recent_dps: float, level: int, players: int) -> float:
	var base := maxf(tier_floor, recent_dps * BOSS_FIGHT_SECONDS)
	return base * (1.0 + BOSS_HP_PER_LEVEL * (level - 1)) * (1.0 + BOSS_HP_PER_PLAYER * (players - 1))

# --- bouncer: special population, separate from the normal pool/desired_pop ---
const BOUNCER_UNLOCK := 165.0       # bouncers start appearing at this elapsed time
const BOUNCER_CAP_BASE := 2.0       # bouncer population cap at pace 0
const BOUNCER_CAP_PER_PACE := 1.0   # +this many cap per pace point (keeps growing)
const BOUNCER_SPAWN_INTERVAL := 2.0 # seconds between bouncer population top-ups

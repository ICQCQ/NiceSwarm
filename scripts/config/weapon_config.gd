class_name WeaponConfig
extends RefCounted
## Base tuning for the 13 base weapons. Each weapon reads its `WeaponConfig.BASE[weapon_id]`
## entry (cached as `cfg` in WeaponBase._ready) for ALL its numbers — damage, cadence, AND
## spatial sizes / projectile counts / ranges. Tune everything here.
##   dmg    = base damage at level 1
##   growth = per-level damage bonus (damage = dmg * (1 + growth*(level-1)))
##   cd     = recurring cooldown / tick / re-hit interval (×Haste at runtime)
##   range/speed/radius/life/spread_deg/*_base/*_per_level/... = spatial & projectile tuning,
##     read via cfg.<key> (multiplied by player.area_mult / duration_mult / rate_mult at use).
## Only initial-cooldown state vars + no-target retry delays + cosmetic _draw() numbers stay
## inline in each weapon_*.gd (same as the fusions).

const BASE := {
	"bolt":      {"dmg": 2.5, "growth": 0.345, "cd": 0.8, "range": 650.0, "speed": 520.0, "radius": 5.0, "life": 1.6, "burst_gap": 0.07},
	"orbit":     {"dmg": 2.0, "growth": 0.46, "cd": 0.45, "orbit_r": 75.0, "blade_r": 10.0, "spin": 3.2},  # cd = per-enemy re-hit
	"nova":      {"dmg": 2.5, "growth": 0.25, "cd": 3.5, "radius_base": 130.0, "radius_per_level": 10.0, "echo_gap": 0.22},
	"glaive":    {"dmg": 2.5, "growth": 0.345, "cd": 1.6, "range": 650.0, "spread_deg": 25.0, "speed": 430.0, "speed_growth": 0.10, "hit_radius": 14.0},
	"lightning": {"dmg": 2.0, "growth": 0.46, "cd": 2.2, "range": 520.0, "chain_base": 2, "jump": 200.0},
	"flame":     {"dmg": 0.75, "growth": 0.46, "cd": 0.15, "reach_base": 150.0, "reach_per_level": 12.0, "half_angle": 0.61, "widen_per_level": 0.12, "burn_stack": 1.6},  # cd = tick interval
	"mines":     {"dmg": 6.0, "growth": 0.575, "cd": 2.0, "cap_base": 3, "blast_radius_base": 100.0, "blast_radius_per_level": 15.0, "trigger_radius": 55.0, "life": 12.0},
	"missiles":  {"dmg": 3.0, "growth": 0.345, "cd": 2.4, "range": 800.0, "count_base": 1, "splash": 70.0, "life": 4.0, "speed": 300.0},
	"laser":     {"dmg": 1.2, "growth": 0.46, "cd": 0.3, "length_base": 240.0, "length_per_level": 30.0, "spin": 1.4, "beam_width": 6.0},   # cd = per-enemy re-hit
	"frost":     {"dmg": 1.5, "growth": 0.345, "cd": 1.8, "range": 650.0, "count_base": 2, "spread_deg": 8.0, "speed": 480.0, "hit_radius": 7.0, "life": 1.4, "slow_dur": 1.5},
	"gravity":   {"dmg": 4, "growth": 0.575, "cd": 6.0, "range": 700.0, "radius_base": 120.0, "radius_per_level": 10.0, "pull_base": 170.0, "pull_per_level": 15.0, "life": 2.5},
	"turret":    {"dmg": 2.2, "growth": 0.46, "cd": 6.5, "life_base": 5.0, "life_per_level": 0.5, "target_range": 480.0, "proj_radius": 5.0},
	"venom":     {"dmg": 1.4, "growth": 0.46, "cd": 0.8, "radius_base": 45.0, "radius_per_level": 5.0, "life": 3.0, "lane_gap": 36.0},  # cd = puddle drop interval
	# Deployed turret fusions (turret + X, see Fusions._Sentry). Lv1 dmg ==
	# a Lv3 base "turret"'s damage, so fusing doesn't feel like a downgrade.
	# life_base/life_per_level/target_range/proj_radius are the shared deployment
	# mechanics for ALL turret fusions; per-mode dmg/growth/life_scale/cooldown_scale/
	# deploy_cap_bonus live in each fusion's own entry below (FusSentryBase reads both).
	"sentry":    {"dmg": 2.16, "growth": 0.46, "cd": 4.5, "life_base": 6.0, "life_per_level": 0.5,
		"target_range": 480.0, "proj_radius": 5.0},
	# Redesigned fusions — all tuning lives here.
	# fus_charge_round (bolt+laser): charge_time=cd, bolt_range=range, bolt_radius=radius
	"fus_charge_round": {"dmg": 38.0, "growth": 0.08, "cd": 2.5, "range": 500.0, "radius": 8.0},

	# --- Mine-fusion base stats (FusMineBase, read dynamically by weapon_id) plus each
	# subclass's bonus-payload numbers (added by its own _load() override). ---
	# Beam Mine doesn't explode on contact: it links a sustained damaging laser
	# to every other Beam Mine in range (Area widens link_range). Enemy contact
	# arms a delayed fuse (`inert_dur`, scales with Duration) instead of an
	# instant blast -- the baseline runs longer than a normal mine's whole life
	# (mines.life = 12.0) since it keeps beaming the whole time it's fused. The
	# fuse then detonates a normal mine-style blast. `life` only matters if a
	# mine is never triggered (it just fizzles out).
	"fus_beammine": {
		"cd": 1.9, "cap_base": 3, "trigger_radius": 50.0, "life": 20.0, "inert_dur": 10.0,
		"dmg": 17.8, "growth": 0.08, "blast_radius": 154.0, "blast_radius_per_count": 6.0,
		"link_dmg": 2.0, "link_growth": 0.08, "link_range": 220.0, "link_range_per_count": 20.0,
		"beam_width": 6.0,
	},
	"fus_novamine": {
		"dmg": 17.8, "growth": 0.08, "cd": 1.9, "blast_radius": 154.0, "blast_radius_per_count": 6.0,
		"trigger_radius": 50.0, "life": 11.0, "cap_base": 3,
		"nova_radius": 180.0, "nova_radius_per_count": 25.0, "nova_dmg": 5.0, "nova_growth": 0.08, "nova_push": 80.0,
	},
	"fus_shrapnelmine": {
		"dmg": 17.8, "growth": 0.08, "cd": 1.9, "blast_radius": 154.0, "blast_radius_per_count": 6.0,
		"trigger_radius": 50.0, "life": 11.0, "cap_base": 3,
		"shrapnel_count_base": 3, "shrapnel_dmg": 2.0, "shrapnel_growth": 0.08, "shrapnel_radius": 12.0,
		"shrapnel_life": 3.0,  # Duration: how long each shard shuttles before fading
	},
	"fus_teslamine": {
		"dmg": 17.8, "growth": 0.08, "cd": 1.9, "blast_radius": 154.0, "blast_radius_per_count": 6.0,
		"trigger_radius": 50.0, "life": 11.0, "cap_base": 3,
		"chain_count_base": 2, "chain_dmg": 5.0, "chain_growth": 0.08, "chain_range": 220.0,
	},
	"fus_toxicmine": {
		"dmg": 17.8, "growth": 0.08, "cd": 1.9, "blast_radius": 154.0, "blast_radius_per_count": 6.0,
		"trigger_radius": 50.0, "life": 11.0, "cap_base": 3,
		"venom_radius": 80.0, "venom_radius_per_count": 10.0, "venom_dps": 1.0, "venom_growth": 0.4, "venom_dur": 3.0,
	},

	# --- Turret-fusion (FusSentryBase) per-mode overrides ---
	"fus_beamsentry":    {"dmg": 1.2, "growth": 0.08, "life_scale": 1.0, "cooldown_scale": 1.0, "deploy_cap_bonus": 2},
	"fus_cryosentry":    {"dmg": 1.8, "growth": 0.08, "life_scale": 1.0, "cooldown_scale": 1.0, "deploy_cap_bonus": 2},
	"fus_flameturret":   {"dmg": 0.8, "growth": 0.08, "life_scale": 1.0, "cooldown_scale": 1.0, "deploy_cap_bonus": 2},
	"fus_glaiveturret":  {"dmg": 2.5, "growth": 0.08, "life_scale": 1.0, "cooldown_scale": 1.0, "deploy_cap_bonus": 2},
	"fus_gunturret":     {"dmg": 1.5, "growth": 0.08, "life_scale": 0.4, "cooldown_scale": 0.3, "deploy_cap_bonus": 4},
	"fus_haloturret":    {"dmg": 2.0, "growth": 0.08, "life_scale": 1.0, "cooldown_scale": 1.0, "deploy_cap_bonus": 2},
	"fus_minelayer":     {"dmg": 3.0, "growth": 0.08, "life_scale": 1.0, "cooldown_scale": 1.0, "deploy_cap_bonus": 2},
	"fus_missilebattery":{"dmg": 3.0, "growth": 0.08, "life_scale": 1.0, "cooldown_scale": 1.0, "deploy_cap_bonus": 2},
	"fus_pulseturret":   {"dmg": 2.5, "growth": 0.08, "life_scale": 1.0, "cooldown_scale": 1.0, "deploy_cap_bonus": 2},
	"fus_singturret":    {"dmg": 1.2, "growth": 0.08, "life_scale": 1.0, "cooldown_scale": 1.0, "deploy_cap_bonus": 2},
	"fus_teslaturret":   {"dmg": 2.0, "growth": 0.08, "life_scale": 1.0, "cooldown_scale": 1.0, "deploy_cap_bonus": 2},
	"fus_toxturret":     {"dmg": 1.0, "growth": 0.08, "life_scale": 1.0, "cooldown_scale": 1.0, "deploy_cap_bonus": 2, "puddle_cd": 1.2},

	# --- Standalone fusions (extends WeaponBase directly) ---
	"fus_plasma": {  # bolt+nova
		"dmg": 4.1, "growth": 0.08, "cd": 0.9, "range": 650.0, "count_base": 1,
		"spread_deg": 8.0, "speed": 480.0, "radius": 7.0, "life": 1.6,
		"explode_radius": 100.0, "explode_dmg_ratio": 0.32, "push": 70.0,
	},
	"fus_napalm": {  # flame+mines
		"dmg": 6.0, "growth": 0.5, "cd": 2.0, "cap_base": 3,
		"blast_radius": 154.0, "blast_radius_per_count": 6.0, "trigger_radius": 55.0, "life": 12.0,
		"fire_dps_ratio": 0.25, "fire_radius": 90.0, "fire_dur": 2.0,
	},

	# --- batch 1 ---
	"fus_abszero": {"dmg": 8.9, "growth": 0.08, "cd": 2.4, "radius_base": 270.0, "radius_per_count": 10.0, "slow_mult": 0.5, "slow_dur": 2.0},
	"fus_accretion": {"dmg": 3.0, "growth": 0.08, "cd": 5.5, "range": 700.0, "radius_base": 150.0, "radius_per_level": 14.0, "pull": 190.0, "life": 3.0, "spokes_base": 1, "beam_dmg": 3.0, "beam_spin": 2.0},
	"fus_acidray": {"dmg": 3.0, "growth": 0.08, "spin": 2.4, "beams_base": 1, "length_base": 244.0, "length_per_count": 8.0, "burn_dmg_ratio": 0.5, "burn_dur": 1.5, "pool_radius_base": 45.0, "pool_radius_per_level": 6.0, "pool_dmg": 0.7, "pool_growth": 0.4, "pool_life": 2.0, "pool_cd": 2.5},
	"fus_barrage": {"dmg": 1.5, "growth": 0.08, "cd": 0.5, "range": 700.0, "count_base": 1, "splash_base": 44.0, "splash_per_level": 6.0, "spread_deg": 14.0, "speed": 480.0, "direct_dmg_ratio": 0.4, "radius": 4.0, "life": 1.8, "homing_turn": 5.0, "homing_range": 260.0},
	"fus_beambattery": {"dmg": 6.1, "growth": 0.08, "cd": 1.8, "spin": 1.6, "beams_base": 1, "length_base": 244.0, "length_per_count": 8.0, "splash_base": 65.0, "splash_per_level": 8.0, "life": 4.0, "speed": 280.0, "fire_dps_base": 0.7, "fire_dps_growth": 0.35, "fire_radius_base": 55.0, "fire_radius_per_level": 8.0, "fire_dur": 1.6},
	"fus_blackbog": {"dmg": 3.0, "growth": 0.08, "cd": 4.5, "range": 700.0, "radius_base": 212.0, "radius_per_count": 8.0, "life": 3.0, "pull": 160.0, "well_dmg_ratio": 1.5, "pool_radius_ratio": 0.9, "pool_dmg_ratio": 1.6},
	"fus_halocomet": {"dmg": 5.0, "growth": 0.08, "spin": 3.2, "count_base": 2, "orbit_radius": 75.0, "blade_radius": 11.0, "spurt_cd": 2.4, "spurt_range": 160.0, "spurt_dmg_bonus": 2.5, "spurt_size_bonus": 1.8},
	"fus_blazehalo": {"dmg": 5.0, "growth": 0.08, "spin": 2.8, "count_base": 2, "orbit_radius": 80.0, "blade_radius": 11.0, "pulse_radius_base": 182.0, "pulse_radius_per_count": 8.0, "pulse_dmg": 1.5, "pulse_cd": 3.0},
	"fus_cindervortex": {"dmg": 3.0, "growth": 0.08, "cd": 4.5, "range": 700.0, "radius_base": 202.0, "radius_per_count": 8.0, "life": 2.8, "pull": 180.0, "well_dmg_ratio": 0.9, "pool_radius_ratio": 0.85, "pool_dmg_ratio": 0.9, "burn_dps_ratio": 0.9, "burn_dur": 1.4},
	"fus_cluster": {"dmg": 17.8, "growth": 0.08, "cd": 2.0, "cap_base": 3, "blast_radius_base": 110.0, "blast_radius_per_level": 15.0, "trigger_radius": 60.0, "life": 12.0, "spawn_missiles_base": 2},
	"fus_warhead": {"dmg": 4.0, "growth": 0.08, "cd": 2.6, "range": 800.0, "count_base": 1, "radius": 6.0, "speed": 340.0, "life": 2.0, "splash": 165.0, "explode_dmg": 6.0, "push_dist": 140.0},
	"fus_corrosive": {"dmg": 4.1, "growth": 0.08, "cd": 0.9, "range": 650.0, "spread_deg": 9.0, "speed": 510.0, "radius": 5.5, "life": 1.6, "burn_dmg": 1.2, "burn_growth": 0.3, "burn_dur": 2.5, "pool_radius_base": 45.0, "pool_radius_per_level": 7.0, "pool_dmg": 0.5, "pool_growth": 0.3, "pool_life": 2.0},
	"fus_cryobeam": {"dmg": 3.0, "growth": 0.08, "spin": 2.4, "beams_base": 1, "length_base": 260.0, "length_per_count": 10.0, "slow_mult": 0.5, "slow_dur": 1.0},
	"fus_cryomissile": {"dmg": 6.1, "growth": 0.08, "cd": 2.5, "range": 800.0, "count_base": 1, "splash_base": 116.0, "splash_per_count": 6.0, "life": 4.0, "speed": 280.0, "freeze_slow": 0.5, "freeze_dur_ratio": 0.35},
	"fus_cryoshock": {"dmg": 5.0, "growth": 0.08, "cd": 1.8, "range": 520.0, "chains_base": 3, "jump": 210.0, "slow_mult": 0.45, "slow_dur": 1.6},
	"fus_cyclone": {"growth": 0.08, "cd": 1.5, "range": 650.0, "count_base": 2, "glaive_speed": 380.0, "glaive_hit_radius": 14.0, "nova_radius_base": 236.0, "nova_radius_per_count": 10.0, "nova_dmg": 8.9, "nova_cd": 2.8, "burst_radius": 80.0, "burst_dmg": 1.0},
	"fus_empmissile": {"dmg": 6.1, "growth": 0.08, "cd": 2.6, "range": 800.0, "count_base": 1, "splash_base": 65.0, "splash_per_level": 8.0, "life": 4.0, "speed": 280.0, "chain_count_base": 2, "chain_dmg": 1.0, "chain_range": 200.0},
	"fus_eventhorizon": {"dmg": 5.0, "growth": 0.08, "spin": 3.2, "count_base": 2, "orbit_radius": 88.0, "blade_radius": 12.0, "pull_radius_ratio": 2.4, "pull_speed": 90.0},
	"fus_frosthalo": {"dmg": 5.0, "growth": 0.08, "spin": 2.8, "count_base": 2, "orbit_radius": 78.0, "blade_radius": 11.0, "slow_mult": 0.5, "slow_dur": 1.2},
	"fus_frostlance": {"dmg": 4.1, "growth": 0.08, "cd": 1.0, "range": 700.0, "count_base": 2, "spread_deg": 6.0, "speed": 620.0, "hit_radius": 8.0, "life": 1.6, "slow_dur": 1.4, "pierce": 4, "shatter_dmg": 4.6, "shatter_radius_base": 60.0, "shatter_radius_per_level": 12.0},

	# --- batch 2 ---
	"fus_frostbite": {"dmg": 3.0, "growth": 0.08, "cd": 2.8, "range": 600.0, "radius": 84.0, "radius_per_count": 4.0, "life": 3.5, "freeze_slow": 0.5, "freeze_dur_ratio": 0.4},
	"fus_glacial": {"dmg": 5.1, "growth": 0.08, "cd": 1.5, "range": 650.0, "count_base": 2, "spread_deg": 22.0, "speed": 430.0, "dmg_ratio": 0.6, "burn_dps_ratio": 0.3, "hit_radius": 15.0, "slow_factor": 0.5},
	"fus_glacmine": {"dmg": 17.8, "growth": 0.08, "cd": 2.2, "cap_base": 3, "blast_radius": 154.0, "blast_radius_per_count": 6.0, "trigger_radius": 55.0, "life": 12.0, "freeze_dur_base": 1.0},
	"fus_glacier": {"dmg": 3.0, "growth": 0.08, "cd": 5.0, "range": 700.0, "radius": 260.0, "radius_per_count": 10.0, "pull": 120.0, "life": 3.0},
	"fus_gravround": {"dmg": 4.1, "growth": 0.08, "cd": 1.1, "range": 650.0, "spread_deg": 9.0, "speed": 500.0, "radius": 5.5, "life": 1.6, "well_radius": 80.0, "well_radius_per_level": 10.0, "well_dmg": 0.5, "well_growth": 0.3, "well_pull": 220.0, "well_life": 1.5},
	"fus_implosionmine": {"dmg": 17.8, "growth": 0.08, "cd": 5.5, "range": 700.0, "well_radius": 150.0, "well_radius_per_level": 14.0, "well_dmg": 3.0, "well_pull": 200.0, "well_life": 2.6, "count_base": 1, "blast_radius": 90.0, "blast_radius_per_level": 12.0, "trigger_radius": 45.0, "life": 6.0, "arm": 0.2, "spawn_r_ratio": 0.6},
	"fus_carpetbombing": {"dmg": 5.0, "growth": 0.08, "cd": 4.0, "range": 750.0, "field_max_dist": 380.0, "cap_base": 2, "field_radius": 140.0, "field_radius_per_level": 8.0, "field_life": 4.0, "missile_cd": 0.85, "missile_count_base": 0, "missile_splash": 55.0, "missile_splash_per_level": 4.0, "missile_life": 3.0},
	"fus_incendiary": {"dmg": 4.1, "growth": 0.08, "cd": 0.85, "range": 650.0, "count_base": 1, "spread_deg": 9.0, "speed": 500.0, "radius": 6.0, "life": 1.6, "puddle_radius": 50.0, "puddle_radius_per_level": 8.0, "puddle_life": 2.5, "puddle_dmg": 0.6, "secondary_growth": 0.3, "burn_dps": 0.9, "burn_dur": 1.5},
	"fus_infernoblade": {"dmg": 5.1, "growth": 0.08, "cd": 1.4, "range": 650.0, "count_base": 1, "spread_deg": 20.0, "speed": 430.0, "burn_dps_ratio": 0.35, "hit_radius": 14.0, "puddle_radius": 28.0, "puddle_radius_per_level": 4.0, "puddle_dmg": 0.4, "secondary_growth": 0.3, "puddle_life": 1.5, "puddle_burn_dps": 0.5, "puddle_burn_dur": 1.0},
	"fus_ionstorm": {"dmg": 3.0, "growth": 0.08, "spin": 2.8, "beam_base": 1, "length": 260.0, "length_per_count": 10.0, "beam_width": 9.0, "hit_cd": 0.4, "zap_range": 170.0, "zap_dmg_ratio": 0.7},
	"fus_minehalo": {"dmg": 5.0, "growth": 0.08, "spin": 3.0, "hit_cd": 0.5, "blade_count_base": 2, "orbit_r": 80.0, "blade_r": 11.0, "mine_cap_base": 4, "drop_r_ratio": 1.4, "drop_cd": 1.3, "mine_dmg": 17.8, "mine_blast_radius": 90.0, "mine_trigger_radius": 50.0, "mine_life": 10.0},
	"fus_plasmapulse": {"dmg": 4.0, "growth": 0.08, "cap_base": 2, "pulse_cd": 0.9, "hit_cd": 0.45, "grow_time": 2.4, "grow_frac_half": 0.12, "max_radius": 220.0, "thickness": 14.0},
	"fus_phoenixrocket": {"dmg": 6.1, "growth": 0.08, "cd": 2.6, "range": 800.0, "count_base": 1, "splash": 75.0, "splash_per_level": 10.0, "life": 4.0, "speed": 280.0, "fire_dps": 0.8, "secondary_growth": 0.35, "fire_radius": 60.0, "fire_radius_per_level": 8.0, "fire_dur": 2.0},
	"fus_photondisc": {"dmg": 5.1, "growth": 0.08, "cd": 1.1, "range": 650.0, "count_base": 1, "spread_deg": 20.0, "speed": 430.0, "speed_growth": 0.10, "hit_radius": 13.0, "beam_length": 300.0, "beam_length_per_level": 40.0, "beam_dmg": 3.0, "beam_width": 8.0},
	"fus_groundcurrent": {"dmg": 2.2, "growth": 0.08, "cap_base": 2, "spawn_cd": 2.2, "range": 600.0, "radius": 110.0, "life": 3.5, "tick_cd": 0.65, "chain_base": 2, "chain_range": 170.0, "poison_dps_ratio": 0.35, "poison_dur": 1.3},
	"fus_plagueblade": {"dmg": 5.1, "growth": 0.08, "cd": 1.4, "range": 650.0, "count_base": 1, "spread_deg": 20.0, "speed": 430.0, "burn_dps_ratio": 0.4, "hit_radius": 14.0, "puddle_radius": 26.0, "puddle_radius_per_level": 4.0, "puddle_dmg": 0.5, "secondary_growth": 0.3, "puddle_life": 1.6},
	"fus_plaguerocket": {"dmg": 6.1, "growth": 0.08, "cd": 2.6, "range": 800.0, "count_base": 1, "splash": 70.0, "splash_per_level": 10.0, "life": 4.0, "speed": 280.0, "venom_dps": 0.8, "secondary_growth": 0.35, "venom_radius": 65.0, "venom_radius_per_level": 9.0, "venom_dur": 2.5},
	"fus_plasmastorm": {"dmg": 2.0, "growth": 0.08, "cap_base": 2, "spawn_cd": 1.8, "speed": 70.0, "aim_range": 700.0, "radius": 65.0, "max_dist": 260.0, "life": 5.0, "lightning_cd": 0.9, "lightning_dmg": 4.5, "chain_base": 2, "chain_range": 190.0},

	# --- batch 3 ---
	"fus_prism": {"dmg": 3.0, "growth": 0.08, "count_base": 1, "spawn_cd": 1.6, "lifetime": 5.0, "place_dist": 220.0, "hit_radius": 10.0, "tick_cd": 0.35},
	"fus_pulsar": {"dmg": 4.0, "growth": 0.4, "count_base": 2, "orbit_r": 75.0, "ball_r": 11.0, "orbit_dmg": 2.0, "seek_range": 380.0, "b_range": 220.0, "explode_radius": 85.0, "explode_dmg": 9.0, "period": 3.2},
	"fus_railgun": {"dmg": 5.0, "growth": 0.4, "cd": 0.9, "length": 999.0, "zap_r_min": 42.0, "zap_r_max": 80.0, "bounce_dmg_ratio": 0.6, "hops_min": 1, "hops_max": 2, "bounce_reach_min": 90.0, "bounce_reach_max": 170.0, "bounce_decay": 0.7},
	"fus_ricochet": {"dmg": 4.1, "growth": 0.08, "cd": 0.8, "range": 650.0, "speed": 540.0, "radius": 6.0, "life": 2.0, "chain_decay": 0.7, "chain_range": 220.0},
	"fus_concorde": {"dmg": 3.0, "growth": 0.08, "cd": 8.0, "range": 700.0, "speed": 240.0, "speed_ramp": 18.0, "dmg_ramp": 0.1, "max_size": 24.0, "life": 10.0},
	"fus_rotormissile": {"dmg": 6.1, "growth": 0.08, "cd": 2.6, "range": 800.0, "count_base": 1, "splash": 60.0, "splash_per_level": 8.0, "life": 4.0, "speed": 280.0, "shrapnel_count_base": 2, "shrapnel_dmg": 1.0, "shrapnel_radius": 12.0},
	"fus_sapper": {"dmg": 4.1, "growth": 0.08, "cd": 0.9, "range": 650.0, "spread_deg": 10.0, "speed": 500.0, "radius": 5.0, "life": 1.6, "mine_dmg": 17.8, "blast_radius": 90.0, "blast_radius_per_level": 12.0, "trigger_radius": 50.0, "mine_life": 8.0},
	"fus_scatter": {"dmg": 4.1, "growth": 0.08, "cd": 2.2, "count_base": 6, "count_per_level": 2, "speed": 480.0, "radius": 5.5, "life": 1.5},
	"fus_singularity": {"dmg": 3.0, "growth": 0.08, "cd": 5.5, "range": 700.0, "radius": 212.0, "radius_per_count": 8.0, "pull": 210.0, "life": 2.5, "detonate_dmg": 8.9, "push": 70.0},
	"fus_solarlance": {"dmg": 3.0, "growth": 0.08, "length": 380.0, "length_per_count": 10.0, "width": 16.0, "burn_dps_ratio": 0.6, "burn_dur": 1.2},
	"fus_storm": {"dmg": 5.1, "growth": 0.08, "cd": 1.6, "range": 650.0, "count_base": 1, "spread_deg": 24.0, "speed": 430.0, "dmg_ratio": 0.6, "burn_dps_ratio": 0.3, "hit_radius": 14.0, "arc_dmg_ratio": 0.6, "arc_range": 150.0},
	"fus_stormvortex": {"dmg": 3.0, "growth": 0.08, "cd": 5.5, "range": 700.0, "radius": 202.0, "radius_per_count": 8.0, "pull": 190.0, "life": 2.8, "chain_dmg": 5.0},
	"fus_supernova": {"dmg": 8.9, "growth": 0.08, "cd": 2.8, "radius": 270.0, "radius_per_count": 10.0, "puddle_radius_ratio": 0.7, "puddle_dmg_ratio": 0.2, "puddle_life": 2.0, "burn_dps_ratio": 0.2, "burn_dur": 1.0},
	"fus_teslahalo": {"dmg": 5.0, "growth": 0.08, "count_base": 2, "orbit_r": 80.0, "blade_r": 11.0, "zap_range": 170.0, "zap_dmg_ratio": 0.7},
	"fus_thermal": {"dmg": 1.5, "growth": 0.08, "cd": 0.15, "reach": 150.0, "reach_per_level": 12.0, "half_angle": 0.6, "slow_mult": 0.6, "slow_dur": 0.8},
	"fus_thunderclap": {"dmg": 8.9, "growth": 0.08, "cd": 2.2, "radius": 170.0, "radius_per_count": 28.0, "fork_count_base": 3, "fork_range_ratio": 1.6, "fork_dmg_ratio": 0.6},
	"fus_toxhalo": {"dmg": 5.0, "growth": 0.08, "count_base": 2, "orbit_r": 80.0, "blade_r": 11.0, "poison_dps_ratio": 0.35, "poison_dur": 1.5, "trail_cd": 0.16, "puddle_radius": 16.0, "puddle_radius_per_level": 2.0, "puddle_dmg": 0.5, "puddle_dmg_growth": 0.3, "puddle_life": 1.4},
	"fus_toxicnova": {"dmg": 8.9, "growth": 0.08, "cd": 1.8, "radius": 130.0, "radius_per_count": 10.0, "poison_dps_ratio": 0.3, "poison_dur": 1.5, "puddle_radius_ratio": 0.7, "puddle_dmg_ratio": 0.25, "puddle_life": 3.5, "echo_gap": 0.22, "echo_count_threshold": 4},
	"fus_purgatory": {"dmg": 3.0, "growth": 0.08, "cd": 2.0, "radius": 155.0, "radius_per_level": 6.0, "life": 3.0, "burn_dps_ratio": 0.8, "burn_dur": 1.2, "vuln_dmg_bonus": 0.2, "vuln_dur": 2.5},
	"fus_vortexblade": {"dmg": 5.1, "growth": 0.08, "cd": 1.8, "range": 650.0, "count_base": 2, "spread_deg": 22.0, "speed": 430.0, "hit_radius": 14.0, "well_radius": 50.0, "well_radius_per_level": 6.0, "well_dmg": 0.35, "well_growth": 0.3, "well_pull": 120.0, "well_life": 1.0},
}

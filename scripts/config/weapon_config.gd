class_name WeaponConfig
extends RefCounted
## Base tuning for the 13 base weapons. Each weapon reads `WeaponConfig.BASE[weapon_id]`
## for its core numbers — tune damage / growth / cadence here.
##   dmg    = base damage at level 1
##   growth = per-level damage bonus (damage = dmg * (1 + growth*(level-1)))
##   cd     = recurring cooldown / tick / re-hit interval (×Haste at runtime)
## Spatial sizes, projectile counts, and per-weapon extras stay in each weapon_*.gd.

const BASE := {
	"bolt":      {"dmg": 2.5, "growth": 0.345, "cd": 0.8},
	"orbit":     {"dmg": 2.0, "growth": 0.46, "cd": 0.45},  # cd = per-enemy re-hit
	"nova":      {"dmg": 2.5, "growth": 0.575, "cd": 3.5},
	"glaive":    {"dmg": 2.5, "growth": 0.345, "cd": 1.6},
	"lightning": {"dmg": 2.0, "growth": 0.46, "cd": 2.2},
	"flame":     {"dmg": 0.75, "growth": 0.46, "cd": 0.15},  # cd = tick interval
	"mines":     {"dmg": 6.0, "growth": 0.575, "cd": 2.0},
	"missiles":  {"dmg": 3.0, "growth": 0.345, "cd": 2.4},
	"laser":     {"dmg": 1.2, "growth": 0.46, "cd": 0.3},   # cd = per-enemy re-hit
	"frost":     {"dmg": 1.5, "growth": 0.345, "cd": 1.8},
	"gravity":   {"dmg": 4, "growth": 0.575, "cd": 6.0},
	"turret":    {"dmg": 2.2, "growth": 0.46, "cd": 6.5},
	"venom":     {"dmg": 1.4, "growth": 0.46, "cd": 0.35},  # cd = puddle drop interval
	# Deployed turret fusions (turret + X, see Fusions._Sentry). Lv1 dmg ==
	# a Lv3 base "turret"'s damage, so fusing doesn't feel like a downgrade.
	# life_base/life_per_level/target_range/proj_radius are the shared deployment
	# mechanics for ALL turret fusions; per-mode dmg/growth/life_scale/cooldown_scale/
	# deploy_cap_bonus live in each fusion's own entry below (FusSentryBase reads both).
	"sentry":    {"dmg": 2.16, "growth": 0.46, "cd": 4.5, "life_base": 6.0, "life_per_level": 0.5,
		"target_range": 480.0, "proj_radius": 5.0},
	# Redesigned fusions — all tuning lives here.
	# fus_charge_round (bolt+laser): charge_time=cd, bolt_range=range, bolt_radius=radius
	"fus_charge_round": {"dmg": 18.0, "growth": 0.08, "cd": 2.5, "range": 500.0, "radius": 8.0},

	# --- Mine-fusion base stats (FusMineBase, read dynamically by weapon_id) plus each
	# subclass's bonus-payload numbers (added by its own _load() override). ---
	"fus_beammine": {
		"dmg": 17.8, "growth": 0.08, "cd": 1.9, "blast_radius": 154.0, "blast_radius_per_count": 6.0,
		"trigger_radius": 50.0, "life": 11.0, "cap_base": 3,
		"beam_dmg": 2.4, "beam_growth": 0.08, "beam_len": 170.0, "beam_len_per_count": 16.0,
		"beam_spin": 2.4, "beam_spin_life": 1.4, "beam_burn_dur": 1.0,
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
	"fus_toxturret":     {"dmg": 1.0, "growth": 0.08, "life_scale": 1.0, "cooldown_scale": 1.0, "deploy_cap_bonus": 2},

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
	"fus_bladetempest": {"dmg": 5.0, "growth": 0.08, "spin": 3.2, "count_base": 2, "orbit_radius": 75.0, "blade_radius": 11.0, "launch_range": 600.0, "launch_speed": 460.0, "launch_dmg": 5.1, "launch_hit_radius": 14.0, "launch_cd": 1.8},
	"fus_blazehalo": {"dmg": 5.0, "growth": 0.08, "spin": 2.8, "count_base": 2, "orbit_radius": 80.0, "blade_radius": 11.0, "pulse_radius_base": 182.0, "pulse_radius_per_count": 8.0, "pulse_dmg": 1.5, "pulse_cd": 3.0},
	"fus_cindervortex": {"dmg": 3.0, "growth": 0.08, "cd": 4.5, "range": 700.0, "radius_base": 202.0, "radius_per_count": 8.0, "life": 2.8, "pull": 180.0, "well_dmg_ratio": 0.9, "pool_radius_ratio": 0.85, "pool_dmg_ratio": 0.9, "burn_dps_ratio": 0.9, "burn_dur": 1.4},
	"fus_cluster": {"dmg": 17.8, "growth": 0.08, "cd": 2.0, "cap_base": 3, "blast_radius_base": 110.0, "blast_radius_per_level": 15.0, "trigger_radius": 60.0, "life": 12.0, "spawn_missiles_base": 2},
	"fus_warhead": {"dmg": 3.8, "growth": 0.08, "cd": 2.6, "range": 800.0, "count_base": 1, "splash": 165.0, "push": 65.0, "life": 4.0, "speed": 300.0},
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
	"fus_glacmine": {"dmg": 17.8, "growth": 0.08, "cd": 2.2, "cap_base": 3, "blast_radius": 154.0, "blast_radius_per_count": 6.0, "trigger_radius": 55.0, "life": 12.0, "freeze_slow": 0.5, "freeze_dur_ratio": 0.4},
	"fus_glacier": {"dmg": 3.0, "growth": 0.08, "cd": 5.0, "range": 700.0, "radius": 260.0, "radius_per_count": 10.0, "pull": 120.0, "life": 3.0},
	"fus_gravround": {"dmg": 4.1, "growth": 0.08, "cd": 1.1, "range": 650.0, "spread_deg": 9.0, "speed": 500.0, "radius": 5.5, "life": 1.6, "well_radius": 80.0, "well_radius_per_level": 10.0, "well_dmg": 0.5, "well_growth": 0.3, "well_pull": 220.0, "well_life": 1.5},
	"fus_implosionmine": {"dmg": 17.8, "growth": 0.08, "cd": 5.5, "range": 700.0, "well_radius": 150.0, "well_radius_per_level": 14.0, "well_dmg": 3.0, "well_pull": 200.0, "well_life": 2.6, "count_base": 1, "blast_radius": 90.0, "blast_radius_per_level": 12.0, "trigger_radius": 45.0, "life": 6.0, "arm": 0.2, "spawn_r_ratio": 0.6},
	"fus_implosionsalvo": {"dmg": 6.1, "growth": 0.08, "cd": 4.5, "range": 750.0, "well_radius": 160.0, "well_radius_per_level": 15.0, "well_dmg": 3.0, "well_pull": 210.0, "well_life": 3.0, "count_base": 1, "splash": 70.0, "splash_per_level": 10.0, "life": 4.0, "speed": 280.0},
	"fus_incendiary": {"dmg": 4.1, "growth": 0.08, "cd": 0.85, "range": 650.0, "count_base": 1, "spread_deg": 9.0, "speed": 500.0, "radius": 6.0, "life": 1.6, "puddle_radius": 50.0, "puddle_radius_per_level": 8.0, "puddle_life": 2.5, "puddle_dmg": 0.6, "secondary_growth": 0.3, "burn_dps": 0.9, "burn_dur": 1.5},
	"fus_infernoblade": {"dmg": 5.1, "growth": 0.08, "cd": 1.4, "range": 650.0, "count_base": 1, "spread_deg": 20.0, "speed": 430.0, "burn_dps_ratio": 0.35, "hit_radius": 14.0, "puddle_radius": 28.0, "puddle_radius_per_level": 4.0, "puddle_dmg": 0.4, "secondary_growth": 0.3, "puddle_life": 1.5, "puddle_burn_dps": 0.5, "puddle_burn_dur": 1.0},
	"fus_ionstorm": {"dmg": 3.0, "growth": 0.08, "spin": 2.8, "beam_base": 1, "length": 260.0, "length_per_count": 10.0, "beam_width": 9.0, "hit_cd": 0.4, "zap_range": 170.0, "zap_dmg_ratio": 0.7},
	"fus_minehalo": {"dmg": 5.0, "growth": 0.08, "spin": 3.0, "hit_cd": 0.5, "blade_count_base": 2, "orbit_r": 80.0, "blade_r": 11.0, "mine_cap_base": 4, "drop_r_ratio": 1.4, "drop_cd": 1.3, "mine_dmg": 17.8, "mine_blast_radius": 90.0, "mine_trigger_radius": 50.0, "mine_life": 10.0},
	"fus_novabeam": {"dmg": 3.0, "growth": 0.08, "spin": 1.4, "beam_base": 1, "length": 360.0, "length_per_count": 10.0, "beam_width": 6.0, "hit_cd": 0.3, "nova_radius": 226.0, "nova_radius_per_count": 10.0, "nova_dmg": 8.9, "nova_cd": 2.6},
	"fus_phoenixrocket": {"dmg": 6.1, "growth": 0.08, "cd": 2.6, "range": 800.0, "count_base": 1, "splash": 75.0, "splash_per_level": 10.0, "life": 4.0, "speed": 280.0, "fire_dps": 0.8, "secondary_growth": 0.35, "fire_radius": 60.0, "fire_radius_per_level": 8.0, "fire_dur": 2.0},
	"fus_photondisc": {"dmg": 5.1, "growth": 0.08, "cd": 1.1, "range": 650.0, "count_base": 1, "spread_deg": 20.0, "speed": 430.0, "speed_growth": 0.10, "hit_radius": 13.0, "beam_length": 300.0, "beam_length_per_level": 40.0, "beam_dmg": 3.0, "beam_width": 8.0},
	"fus_plague": {"dmg": 5.0, "growth": 0.08, "cd": 1.9, "range": 520.0, "chain_base": 3, "poison_dps_ratio": 0.4, "poison_dur": 2.0, "chain_range": 210.0},
	"fus_plagueblade": {"dmg": 5.1, "growth": 0.08, "cd": 1.4, "range": 650.0, "count_base": 1, "spread_deg": 20.0, "speed": 430.0, "burn_dps_ratio": 0.4, "hit_radius": 14.0, "puddle_radius": 26.0, "puddle_radius_per_level": 4.0, "puddle_dmg": 0.5, "secondary_growth": 0.3, "puddle_life": 1.6},
	"fus_plaguerocket": {"dmg": 6.1, "growth": 0.08, "cd": 2.6, "range": 800.0, "count_base": 1, "splash": 70.0, "splash_per_level": 10.0, "life": 4.0, "speed": 280.0, "venom_dps": 0.8, "secondary_growth": 0.35, "venom_radius": 65.0, "venom_radius_per_level": 9.0, "venom_dur": 2.5},
	"fus_plasmastorm": {"dmg": 1.5, "growth": 0.08, "tick": 0.14, "half_angle": 0.62, "reach": 160.0, "reach_per_level": 12.0, "bolt_dmg": 5.0, "bolt_cd": 1.4, "chain_base": 2, "chain_range": 200.0},

	# --- batch 3 ---
	"fus_prism": {"dmg": 3.0, "growth": 0.08, "count_base": 1, "length": 222.0, "length_per_count": 8.0, "hit_radius": 7.0},
	"fus_pulsar": {"dmg": 5.0, "growth": 0.08, "count_base": 2, "orbit_r": 80.0, "blade_r": 11.0, "pulse_radius": 90.0, "pulse_radius_per_level": 20.0, "pulse_dmg": 8.9},
	"fus_railgun": {"dmg": 5.0, "growth": 0.4, "cd": 0.9, "length": 999.0, "zap_r_min": 42.0, "zap_r_max": 80.0, "bounce_dmg_ratio": 0.6, "hops_min": 1, "hops_max": 2, "bounce_reach_min": 90.0, "bounce_reach_max": 170.0, "bounce_decay": 0.7},
	"fus_ricochet": {"dmg": 4.1, "growth": 0.08, "cd": 0.8, "range": 650.0, "speed": 540.0, "radius": 6.0, "life": 2.0, "chain_decay": 0.7, "chain_range": 220.0},
	"fus_rockethalo": {"dmg": 5.0, "growth": 0.08, "count_base": 2, "orbit_r": 78.0, "blade_r": 11.0, "missile_dmg": 6.1, "splash": 75.0, "splash_per_level": 10.0, "missile_life": 4.0, "missile_speed": 280.0, "missile_cd": 1.6},
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
	"fus_toxicnova": {"dmg": 8.9, "growth": 0.08, "cd": 1.3, "radius": 238.0, "radius_per_count": 10.0, "poison_dps_ratio": 0.3, "poison_dur": 1.5, "puddle_radius_ratio": 0.7, "puddle_dmg_ratio": 0.25, "puddle_life": 2.5, "echo_gap": 0.22, "echo_count_threshold": 4},
	"fus_pyre": {"dmg": 3.0, "growth": 0.08, "cd": 0.3, "radius": 55.0, "radius_per_level": 6.0, "life": 3.0, "burn_dps_ratio": 0.8, "burn_dur": 1.2},
	"fus_vortexblade": {"dmg": 5.1, "growth": 0.08, "cd": 1.8, "range": 650.0, "count_base": 2, "spread_deg": 22.0, "speed": 430.0, "hit_radius": 14.0, "well_radius": 50.0, "well_radius_per_level": 6.0, "well_dmg": 0.35, "well_growth": 0.3, "well_pull": 120.0, "well_life": 1.0},
}

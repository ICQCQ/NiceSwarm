# --- nova + venom ------------------------------------------------------------
class_name FusToxicNova
extends WeaponBase
## Toxic Nova: a Nova-style shockwave that poisons + leaves a puddle. Like base Nova,
## each cooldown fires one blast plus level-scaled echo pulses (count_level()-4 extra
## shockwaves), so high levels pulse several times per cycle instead of only widening.

var cooldown := 1.6
var echoes_left := 0
var echo_cd := 0.0


func _init() -> void:
	weapon_id = "fus_toxicnova"
	display_name = "Toxic Nova"


func _physics_process(delta: float) -> void:
	if player == null or player.downed:
		return
	# High-level kicker: drain queued echo pulses so it hits several times per cooldown
	# (the "pulsing attack" — mirrors base Nova's echoes).
	if echoes_left > 0:
		echo_cd -= delta
		if echo_cd <= 0.0:
			echoes_left -= 1
			echo_cd = cfg.echo_gap * player.rate_mult
			_blast(false)
	cooldown -= delta
	if cooldown > 0.0:
		return
	if _blast(true):
		cooldown = cfg.cd * fuse_rate()             # halved (was 2.6)
		echoes_left = maxi(0, count_level() - cfg.echo_count_threshold)  # pulses scale with level, like Nova (born floor 6 -> 2-3)
		echo_cd = cfg.echo_gap * player.rate_mult
	else:
		cooldown = 0.25  # nothing in range, retry soon


## One toxic shockwave: damages + poisons everything in radius. `with_puddle` drops the
## ground puddle (only the main pulse does, not every echo). Returns whether it hit.
func _blast(with_puddle: bool) -> bool:
	var radius: float = (cfg.radius + cfg.radius_per_count * (count_level() - 1)) * fuse_area()
	var dmg: float = cfg.dmg * fuse_damage() * (1.0 + cfg.growth * (level - 1))  # ring = nova @L7 (13.35 eff)
	var any := false
	for e in Main.instance.enemies_in_radius(global_position, radius + 64.0):
		if global_position.distance_to(e.global_position) <= radius + e.radius:
			damage_dealt += dmg
			e.take_hit(dmg, global_position, Enemy.DMG_PHYS, player.peer_id)
			e.apply_burn(dmg * cfg.poison_dps_ratio, cfg.poison_dur * fuse_duration(), 1.0, player.peer_id)
			push(e, global_position)
			any = true
	if not any:
		return false
	var fx := RingFx.new()
	fx.position = global_position
	fx.radius = 25.0
	fx.max_radius = radius
	fx.life = 0.4
	fx.color = Color(0.5, 0.9, 0.4)
	player.get_parent().add_child(fx)
	if with_puddle:
		var pud := VenomPuddle.new()
		pud.source_pid = player.peer_id
		pud.source_weapon = self
		pud.radius = radius * cfg.puddle_radius_ratio
		pud.damage = dmg * cfg.puddle_dmg_ratio
		pud.max_life = cfg.puddle_life * fuse_duration()
		pud.life = pud.max_life
		pud.position = global_position
		player.get_parent().add_child(pud)
	Sfx.play("nova", global_position)
	return true

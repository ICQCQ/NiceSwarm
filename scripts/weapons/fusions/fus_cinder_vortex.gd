# --- flame + gravity: a vortex with a burning pool at its core ---------------
class_name FusCinderVortex
extends WeaponBase

var cooldown := 2.8
func _init() -> void:
	weapon_id = "fus_cindervortex"
	display_name = "Cinder Vortex"
func _physics_process(delta: float) -> void:
	if player == null or player.downed:
		return
	cooldown -= delta
	if cooldown > 0.0:
		return
	var target := player.nearest_enemy(700.0)
	if target == null:
		cooldown = 0.2
		return
	var r := (202.0 + 8.0 * (count_level() - 1)) * fuse_area()
	var life := 2.8 * fuse_duration()
	var dmg := fuse_damage() * (1.0 + 0.5 * (level - 1))
	var w := GravityWell.new()
	w.source_pid = player.peer_id
	w.source_weapon = self
	w.radius = r
	w.damage = 0.9 * dmg
	w.pull = 180.0
	w.life = life
	w.position = target.global_position
	player.get_parent().add_child(w)
	var pud := VenomPuddle.new()
	pud.source_pid = player.peer_id
	pud.source_weapon = self
	pud.radius = r * 0.85
	pud.damage = 0.9 * dmg
	pud.max_life = life
	pud.life = life
	pud.fiery = true
	pud.burn_dps = 0.9 * dmg
	pud.burn_dur = 1.4 * fuse_duration()
	pud.position = target.global_position
	player.get_parent().add_child(pud)
	Sfx.play("flame", target.global_position)
	cooldown = 4.5 * fuse_rate()

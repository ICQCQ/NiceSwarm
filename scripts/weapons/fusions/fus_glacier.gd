# --- frost + gravity ---------------------------------------------------------
class_name FusGlacier
extends WeaponBase

var cooldown := 2.8
func _init() -> void:
	weapon_id = "fus_glacier"
	display_name = "Glacier"
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
	var w := GravityWell.new()
	w.source_pid = player.peer_id
	w.source_weapon = self
	w.radius = (200.0 + 20.0 * (level - 1)) * fuse_area()
	w.damage = 2.5 * fuse_damage() * (1.0 + 0.5 * (level - 1))  # +20%: single-well fusion, 75%-of-combined floor
	w.pull = 120.0
	w.life = 3.0 * fuse_duration()
	w.freeze = true
	w.position = target.global_position
	player.get_parent().add_child(w)
	Sfx.play("frost", target.global_position)
	cooldown = 5.0 * fuse_rate()

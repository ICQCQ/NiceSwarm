# --- gravity + lightning: a vortex that arcs lightning between its captives --
class_name FusStormVortex
extends WeaponBase

var cooldown := 2.6
func _init() -> void:
	weapon_id = "fus_stormvortex"
	display_name = "Storm Vortex"
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
	var w := GravityWell.new()
	w.source_pid = player.peer_id
	w.source_weapon = self
	w.radius = r
	w.damage = 3.0 * fuse_damage() * (1.0 + GameConfig.FUSION_LEVEL_GROWTH * (level - 1))
	w.pull = 190.0
	w.life = 2.8 * fuse_duration()
	w.chain_dmg = 5.0 * fuse_damage() * (1.0 + GameConfig.FUSION_LEVEL_GROWTH * (level - 1))
	w.position = target.global_position
	player.get_parent().add_child(w)
	Sfx.play("lightning", target.global_position)
	cooldown = 5.5 * fuse_rate()

# --- gravity + missiles: marks a random enemy's spot, then calls in a missile -----
# barrage onto random points inside that zone for a few seconds ------------------
class_name FusCarpetBombing
extends WeaponBase

var cooldown := 4.0
func _init() -> void:
	weapon_id = "fus_carpetbombing"
	display_name = "Carpet Bombing"
func _physics_process(delta: float) -> void:
	if player == null or player.downed:
		return
	cooldown -= delta
	if cooldown > 0.0:
		return
	if get_tree().get_nodes_in_group("bombing_fields").size() >= cfg.cap_base + count_level():
		cooldown = 0.2
		return
	var candidates := Main.instance.enemies_in_radius(player.global_position, cfg.range * fuse_area())
	if candidates.is_empty():
		cooldown = 0.2
		return
	var picked: Node2D = candidates[randi() % candidates.size()]
	# Pick from anywhere in range, but the zone itself drops no further than
	# field_max_dist from the player — it never lands somewhere off-screen.
	var to_picked := picked.global_position - player.global_position
	var place_dist: float = cfg.field_max_dist * fuse_area()
	var field := BombingField.new()
	field.source_pid = player.peer_id
	field.source_weapon = self
	field.player_ref = player
	field.radius = (cfg.field_radius + cfg.field_radius_per_level * (level - 1)) * fuse_area()
	field.life = cfg.field_life * fuse_duration()
	field.missile_interval = cfg.missile_cd * fuse_rate()
	field.missile_count = cfg.missile_count_base + count_level()
	field.missile_dmg = cfg.dmg * fuse_damage() * (1.0 + cfg.growth * (level - 1))
	field.missile_splash = (cfg.missile_splash + cfg.missile_splash_per_level * (level - 1)) * fuse_area()
	field.missile_life = cfg.missile_life * fuse_duration()
	field.position = player.global_position + to_picked.limit_length(place_dist)
	player.get_parent().add_child(field)
	Sfx.play("missile", player.global_position, -4.0)
	cooldown = cfg.cd * fuse_rate()

# --- gravity + mines: a vortex that seeds mines around its core --------------
class_name FusImplosionMine
extends WeaponBase

var cooldown := 3.0
func _init() -> void:
	weapon_id = "fus_implosionmine"
	display_name = "Implosion Mine"
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
	var r := (150.0 + 14.0 * (level - 1)) * fuse_area()
	var w := GravityWell.new()
	w.source_pid = player.peer_id
	w.source_weapon = self
	w.radius = r
	w.damage = 3.0 * fuse_damage() * (1.0 + GameConfig.FUSION_LEVEL_GROWTH * (level - 1))
	w.pull = 200.0
	w.life = 2.6 * fuse_duration()
	w.position = target.global_position
	player.get_parent().add_child(w)
	var dmg := 17.8 * fuse_damage() * (1.0 + GameConfig.FUSION_LEVEL_GROWTH * (level - 1))
	var count := 1 + count_level()
	for i in count:
		var m := MineNode.new()
		m.source_pid = player.peer_id
		m.source_weapon = self
		m.damage = dmg
		m.blast_radius = (90.0 + 12.0 * (level - 1)) * fuse_area()
		m.trigger_radius = 45.0 * fuse_area()
		m.life = 6.0 * fuse_duration()
		m.arm = 0.2
		m.position = target.global_position + Vector2.from_angle(TAU * float(i) / count) * r * 0.6
		player.get_parent().add_child(m)
	Sfx.play("mine", target.global_position)
	cooldown = 5.5 * fuse_rate()

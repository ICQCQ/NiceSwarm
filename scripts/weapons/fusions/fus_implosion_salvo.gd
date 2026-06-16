# --- gravity + missiles: a vortex that launches a homing missile salvo -------
class_name FusImplosionSalvo
extends WeaponBase

var cooldown := 3.2
func _init() -> void:
	weapon_id = "fus_implosionsalvo"
	display_name = "Implosion Salvo"
func _physics_process(delta: float) -> void:
	if player == null or player.downed:
		return
	cooldown -= delta
	if cooldown > 0.0:
		return
	var target := player.nearest_enemy(750.0)
	if target == null:
		cooldown = 0.2
		return
	var r := (160.0 + 15.0 * (level - 1)) * fuse_area()
	var w := GravityWell.new()
	w.source_pid = player.peer_id
	w.source_weapon = self
	w.radius = r
	w.damage = 0.5 * fuse_damage() * (1.0 + 0.4 * (level - 1))
	w.pull = 210.0
	w.life = 3.0 * fuse_duration()
	w.position = target.global_position
	player.get_parent().add_child(w)
	var dmg := 2.6 * fuse_damage() * (1.0 + 0.35 * (level - 1))
	var count := 1 + count_level()
	for i in count:
		var m := MissileProj.new()
		m.source_pid = player.peer_id
		m.source_weapon = self
		m.damage = dmg
		m.splash = (70.0 + 10.0 * (level - 1)) * fuse_area()
		m.life = 4.0 * fuse_duration()
		m.velocity = Vector2.from_angle(TAU * float(i) / count) * 280.0
		m.position = player.global_position
		player.get_parent().add_child(m)
	Sfx.play("missile", player.global_position)
	cooldown = 5.8 * fuse_rate()

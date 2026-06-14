class_name WeaponBolt
extends WeaponBase
## Auto-targeting bolt launcher. Level = number of projectiles, plus bonus damage.

var cooldown := 0.4


func _init() -> void:
	weapon_id = "bolt"
	display_name = "Bolt"


func _physics_process(delta: float) -> void:
	if player == null or player.downed:
		return
	cooldown -= delta
	if cooldown > 0.0:
		return
	if _fire():
		cooldown = WeaponConfig.BASE.bolt.cd * player.rate_mult
	else:
		cooldown = 0.1  # no target yet, retry soon


func _fire() -> bool:
	var target := player.nearest_enemy(650.0)
	if target == null:
		return false
	var base_dir := (target.global_position - player.global_position).normalized()
	var dmg := WeaponConfig.BASE.bolt.dmg * player.damage_mult * (1.0 + WeaponConfig.BASE.bolt.growth * (level - 1))
	for i in level:
		var spread := deg_to_rad(10.0) * (i - (level - 1) / 2.0)
		var p := Projectile.new()
		p.source_pid = player.peer_id
		p.velocity = base_dir.rotated(spread) * 520.0
		p.damage = dmg
		p.radius = 5.0 * player.area_mult
		p.life = 1.6 * player.duration_mult
		p.position = player.global_position
		player.get_parent().add_child(p)
	Sfx.play("bolt", player.global_position)
	return true

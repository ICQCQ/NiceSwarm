# --- bolt + venom: bolt poisons target + leaves a venom pool -----------------
class_name FusCorrosiveRound
extends WeaponBase

var cooldown := 0.5
func _init() -> void:
	weapon_id = "fus_corrosive"
	display_name = "Corrosive Round"
func _physics_process(delta: float) -> void:
	if player == null or player.downed:
		return
	cooldown -= delta
	if cooldown > 0.0:
		return
	var target := player.nearest_enemy(650.0)
	if target == null:
		cooldown = 0.1
		return
	var dir := (target.global_position - player.global_position).normalized()
	var dmg := 1.8 * fuse_damage() * (1.0 + 0.35 * (level - 1))
	for i in level:
		var spread := deg_to_rad(9.0) * (i - (level - 1) / 2.0)
		var p := Projectile.new()
		p.source_pid = player.peer_id
		p.source_weapon = self
		p.velocity = dir.rotated(spread) * 510.0
		p.damage = dmg
		p.radius = 5.5 * fuse_area()
		p.life = 1.6 * fuse_duration()
		p.color = Color(0.45, 0.9, 0.35)
		p.on_hit = Callable(self, "_corrode")
		p.position = player.global_position
		player.get_parent().add_child(p)
	Sfx.play("bolt", player.global_position)
	cooldown = 0.9 * fuse_rate()
func _corrode(enemy: Node2D, hit_pos: Vector2, world: Node) -> void:
	if player == null:
		return
	enemy.apply_burn(1.2 * fuse_damage() * (1.0 + 0.3 * (level - 1)), 2.5 * fuse_duration(), 1.0, player.peer_id)
	var pud := VenomPuddle.new()
	pud.source_pid = player.peer_id
	pud.source_weapon = self
	pud.radius = (45.0 + 7.0 * (level - 1)) * fuse_area()
	pud.damage = 0.5 * fuse_damage() * (1.0 + 0.3 * (level - 1))
	pud.max_life = 2.0 * fuse_duration()
	pud.life = pud.max_life
	pud.position = hit_pos
	world.add_child(pud)
	Sfx.play("venom", hit_pos, -6.0)

# --- flame + glaive: boomerangs that ignite and leave fire pools -------------
class_name FusInfernoBlade
extends WeaponBase

var cooldown := 1.0
func _init() -> void:
	weapon_id = "fus_infernoblade"
	display_name = "Inferno Blade"
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
	var count := 1 + count_level()
	var base := (target.global_position - player.global_position).normalized()
	var dmg := 2.4 * fuse_damage() * (1.0 + 0.35 * (level - 1))
	for i in count:
		var g := GlaiveProj.new()
		g.source_pid = player.peer_id
		g.source_weapon = self
		g.player = player
		g.velocity = base.rotated(deg_to_rad(20.0) * (i - (count - 1) / 2.0)) * 430.0
		g.damage = dmg
		g.burn_dps = dmg * 0.35
		g.hit_radius = 14.0 * fuse_area()
		g.on_hit = Callable(self, "_on_hit")
		g.position = player.global_position
		player.get_parent().add_child(g)
	Sfx.play("flame", player.global_position)
	cooldown = 1.4 * fuse_rate()

## Each glaive hit leaves a small burning pool behind it.
func _on_hit(_e: Node2D, pos: Vector2) -> void:
	var pud := VenomPuddle.new()
	pud.source_pid = player.peer_id
	pud.source_weapon = self
	pud.radius = (28.0 + 4.0 * (level - 1)) * fuse_area()
	pud.damage = 0.4 * fuse_damage() * (1.0 + 0.3 * (level - 1))
	pud.max_life = 1.5 * fuse_duration()
	pud.life = pud.max_life
	pud.fiery = true
	pud.burn_dps = 0.5 * fuse_damage()
	pud.burn_dur = 1.0 * fuse_duration()
	pud.position = pos
	player.get_parent().add_child(pud)

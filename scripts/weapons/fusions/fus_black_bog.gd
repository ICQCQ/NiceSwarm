# --- gravity + venom ---------------------------------------------------------
class_name FusBlackBog
extends WeaponBase

var cooldown := 2.6
func _init() -> void:
	weapon_id = "fus_blackbog"
	display_name = "Black Bog"
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
	var r := (170.0 + 15.0 * (level - 1)) * fuse_area()
	var life := 3.0 * fuse_duration()
	var dmg := fuse_damage() * (1.0 + 0.4 * (level - 1))
	var w := GravityWell.new()
	w.source_pid = player.peer_id
	w.source_weapon = self
	w.radius = r
	w.damage = 0.96 * dmg  # +20%: single-well fusion, 75%-of-combined floor
	w.pull = 160.0
	w.life = life
	w.position = target.global_position
	player.get_parent().add_child(w)
	var pud := VenomPuddle.new()
	pud.source_pid = player.peer_id
	pud.source_weapon = self
	pud.radius = r * 0.9
	pud.damage = 1.2 * dmg  # +20%: single-well fusion, 75%-of-combined floor
	pud.max_life = life
	pud.life = life
	pud.position = target.global_position
	player.get_parent().add_child(pud)
	Sfx.play("gravity", target.global_position)
	cooldown = 5.5 * fuse_rate()

# --- frost + venom: a pool that chills and poisons ---------------------------
class_name FusFrostbite
extends WeaponBase

var cooldown := 1.5
func _init() -> void:
	weapon_id = "fus_frostbite"
	display_name = "Frostbite"
func _physics_process(delta: float) -> void:
	if player == null or player.downed:
		return
	cooldown -= delta
	if cooldown > 0.0:
		return
	var target := player.nearest_enemy(600.0)
	if target == null:
		cooldown = 0.2
		return
	var dmg := 0.8 * fuse_damage() * (1.0 + 0.35 * (level - 1))
	var pud := VenomPuddle.new()
	pud.source_pid = player.peer_id
	pud.source_weapon = self
	pud.radius = (60.0 + 8.0 * (level - 1)) * fuse_area()
	pud.damage = dmg
	pud.max_life = 3.5 * fuse_duration()
	pud.life = pud.max_life
	pud.icy = true
	pud.freeze_slow = 0.5
	pud.freeze_dur = dmg * 0.4 * fuse_duration()
	pud.position = target.global_position
	player.get_parent().add_child(pud)
	Sfx.play("frost", target.global_position)
	cooldown = 2.8 * fuse_rate()

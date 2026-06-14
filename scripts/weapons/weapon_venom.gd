class_name WeaponVenom
extends WeaponBase
## Leaves toxic puddles behind the player while they move.

const DROP_TIME := 0.35

var drop_timer := 0.0


func _init() -> void:
	weapon_id = "venom"
	display_name = "Venom Trail"


func _physics_process(delta: float) -> void:
	if player == null or player.downed:
		return
	drop_timer -= delta
	if drop_timer > 0.0 or player.velocity.length() < 10.0:
		return
	drop_timer = DROP_TIME * player.rate_mult
	var p := VenomPuddle.new()
	p.source_pid = player.peer_id
	p.radius = (45.0 + 5.0 * (level - 1)) * player.area_mult
	p.damage = WeaponConfig.BASE.venom.dmg * player.damage_mult * (1.0 + WeaponConfig.BASE.venom.growth * (level - 1))
	p.max_life = 3.0 * player.duration_mult
	p.life = p.max_life
	p.position = player.global_position
	player.get_parent().add_child(p)
	Sfx.play("venom", player.global_position)

class_name WeaponBolt
extends WeaponBase
## Auto-targeting bolt launcher: fires a rapid multi-shot burst straight at the nearest
## enemy (Level = shots per burst), plus bonus damage.

const BURST_GAP := 0.07  # seconds between shots within a burst (machine-gun cadence)
var cooldown := 0.4
var burst_left := 0      # shots remaining in the current multi-shot burst
var burst_cd := 0.0


func _init() -> void:
	weapon_id = "bolt"
	display_name = "Bolt"


func _physics_process(delta: float) -> void:
	if player == null or player.downed:
		return
	if cooldown > 0.0:
		cooldown -= delta
	# Mid-burst: fire the remaining shots one after another (multi-shot, not a spread).
	if burst_left > 0:
		burst_cd -= delta
		if burst_cd <= 0.0:
			if _shoot():
				burst_left -= 1
				burst_cd = BURST_GAP * player.rate_mult
			else:
				burst_left = 0  # target gone — end the burst
		return
	if cooldown > 0.0:
		return
	# Start a new burst of count_level() shots, fired in quick succession.
	if _shoot():
		burst_left = count_level() - 1
		burst_cd = BURST_GAP * player.rate_mult
		cooldown = WeaponConfig.BASE.bolt.cd * player.rate_mult
	else:
		cooldown = 0.1  # no target yet, retry soon


## Fire a single bolt straight at the nearest enemy, with a tiny aim jitter so a stream
## of shots doesn't perfectly overlap. Returns false if there's no target.
func _shoot() -> bool:
	var target := player.nearest_enemy(650.0)
	if target == null:
		return false
	var dir := (target.global_position - player.global_position).normalized().rotated(deg_to_rad(randf_range(-3.0, 3.0)))
	var dmg := WeaponConfig.BASE.bolt.dmg * player.damage_mult * (1.0 + WeaponConfig.BASE.bolt.growth * (level - 1))
	var p := Projectile.new()
	p.source_pid = player.peer_id
	p.source_weapon = self
	p.velocity = dir * 520.0
	p.damage = dmg
	p.radius = 5.0 * player.area_mult
	p.life = 1.6 * player.duration_mult
	p.position = player.global_position
	player.get_parent().add_child(p)
	Sfx.play("bolt", player.global_position)
	return true

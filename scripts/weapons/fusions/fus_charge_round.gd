# --- bolt + laser: charge-up railgun — long charge, piercing round, high dmg --
# All tuning lives in WeaponConfig.BASE["fus_charge_round"]: dmg/growth/cd/range/radius
class_name FusChargeRound
extends WeaponBase

const BOLT_SPEED := 1200.0

var charge    := 0.0
var aim_angle := 0.0   # radians; tracks nearest enemy, persists between frames
var _sfx_played := false


func _init() -> void:
	weapon_id    = "fus_charge_round"
	display_name = "Charge Round"


func _physics_process(delta: float) -> void:
	if player == null or player.downed:
		queue_redraw()
		return

	var range: float  = cfg.range * fuse_duration()
	var target := player.nearest_enemy(range * 1.4)
	if target != null:
		aim_angle = (target.global_position - player.global_position).angle()

	var cd: float = cfg.cd * fuse_rate()

	if not _sfx_played:
		Sfx.play("chaingun_charge", player.global_position, -2.0)
		_sfx_played = true

	charge += delta
	queue_redraw()

	if charge >= cd:
		_fire(range)
		charge      = 0.0
		_sfx_played = false


func _fire(range: float) -> void:
	var dmg: float    = cfg.dmg * fuse_damage() * (1.0 + cfg.growth * (level - 1))
	var radius: float = cfg.radius * fuse_area()
	var dir    := Vector2.from_angle(aim_angle)

	Sfx.play("chaingun_fire", player.global_position, 0.0)

	var p := Projectile.new()
	p.source_pid    = player.peer_id
	p.source_weapon = self
	p.velocity      = dir * BOLT_SPEED
	p.damage        = dmg
	p.radius        = radius
	p.color         = Color(1.0, 0.1, 0.08)
	p.pierce        = true
	p.max_dist      = range
	p.life          = (range / BOLT_SPEED) + 0.2
	p.position      = player.global_position
	player.get_parent().add_child(p)


func _draw() -> void:
	if player == null or player.downed:
		return
	var range: float = cfg.range * fuse_duration()
	var dir          := Vector2.from_angle(aim_angle)
	var cd: float    = cfg.cd * fuse_rate()
	var t     := clampf(charge / cd, 0.0, 1.0)

	# Dim guide line — full range, always visible
	draw_line(Vector2.ZERO, dir * range, Color(0.85, 0.0, 0.0, 0.12 + 0.08 * t), 2.0)

	# Charged segment growing from player as t increases
	var charged_end := dir * (range * t)
	draw_line(Vector2.ZERO, charged_end, Color(1.0, 0.08, 0.04, 0.55 + 0.3 * t), 2.5 + t * 2.0)

	# Pulsing tip dot when nearly ready (last 25% of charge)
	if t > 0.75:
		var pulse := absf(sin(charge * 18.0))
		draw_circle(charged_end, 3.5 + 3.0 * pulse * (t - 0.75) / 0.25,
				Color(1.0, 0.35, 0.2, 0.8 * t))

# --- lightning + venom: drops a crackling field; every enemy caught in it ----
# becomes its own lightning source, chaining out to nearby foes ------------------
class_name FusGroundCurrent
extends WeaponBase

var spawn_timer := 0.0
func _init() -> void:
	weapon_id = "fus_groundcurrent"
	display_name = "Ground Current"
func _physics_process(delta: float) -> void:
	if player == null or player.downed:
		return
	spawn_timer -= delta
	if spawn_timer > 0.0:
		return
	if get_tree().get_nodes_in_group("ground_current_fields").size() >= cfg.cap_base + count_level():
		spawn_timer = 0.2
		return
	# Only drop within the player's screen — Duration stretches that leash, so
	# investing in it lets fields land farther beyond what's currently visible.
	var range: float = _screen_range() * fuse_duration()
	var candidates := Main.instance.enemies_in_radius(player.global_position, range)
	if candidates.is_empty():
		spawn_timer = 0.2
		return
	var picked: Node2D = candidates[randi() % candidates.size()]
	var field := GroundCurrentField.new()
	field.source_pid = player.peer_id
	field.source_weapon = self
	field.radius = cfg.radius * fuse_area()                  # Area: field size
	field.life = cfg.life * fuse_duration()                  # Duration: how long the field lingers
	field.max_life = field.life
	field.tick_interval = cfg.tick_cd * fuse_rate()          # Haste: re-zap cadence
	field.dmg = cfg.dmg * fuse_damage() * (1.0 + cfg.growth * (level - 1))
	# Hops per source enemy: weapon level + every Duration power-up picked so far.
	field.chain_count = cfg.chain_base + count_level() + player.stat_levels.get("st_duration", 0)
	field.chain_range = cfg.chain_range * fuse_area()
	field.poison_ratio = cfg.poison_dps_ratio
	field.poison_dur = cfg.poison_dur * fuse_duration()
	field.position = picked.global_position
	player.get_parent().add_child(field)
	Sfx.play("lightning", player.global_position, -4.0)
	spawn_timer = cfg.spawn_cd * fuse_rate()  # Haste: time between new fields
func _screen_range() -> float:
	var vp := get_viewport()
	if vp == null:
		return cfg.range  # headless/no-display fallback
	var half: Vector2 = vp.get_visible_rect().size * 0.5
	var r: float = minf(half.x, half.y)
	return r if r > 0.0 else cfg.range

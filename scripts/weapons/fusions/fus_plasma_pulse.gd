# --- laser + nova: drops a ring of light where it's emitted, growing outward ---
class_name FusPlasmaPulse
extends WeaponBase

var spawn_timer := 0.0
func _init() -> void:
	weapon_id = "fus_plasmapulse"
	display_name = "Plasma Pulse"
func _physics_process(delta: float) -> void:
	if player == null or player.downed:
		return
	spawn_timer -= delta
	if spawn_timer > 0.0:
		return
	if get_tree().get_nodes_in_group("plasma_rings").size() >= cfg.cap_base + count_level():
		spawn_timer = 0.2
		return
	var ring := PlasmaRing.new()
	ring.source_pid = player.peer_id
	ring.source_weapon = self
	ring.base_max_radius = cfg.max_radius
	ring.max_radius = cfg.max_radius * fuse_area()      # Area: how far a ring can grow
	ring.thickness = cfg.thickness * fuse_area()        # Area: ring stroke thickness
	ring.grow_time = cfg.grow_time * fuse_duration()    # Duration: how long a ring takes to fully grow
	ring.grow_frac_half = cfg.grow_frac_half
	ring.dmg = cfg.dmg * fuse_damage() * (1.0 + cfg.growth * (level - 1))
	ring.rehit = cfg.hit_cd * fuse_rate()               # Haste: re-hit cadence for foes loitering in the ring
	ring.position = player.global_position
	player.get_parent().add_child(ring)
	Sfx.play("plasma_pulse", player.global_position)
	spawn_timer = cfg.pulse_cd * fuse_rate()            # Haste: time between pulses

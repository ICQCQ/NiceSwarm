class_name WeaponBase
extends Node2D
## Base for all weapons: id, level, display name, and player resolution.
## Weapons can be nested inside a WeaponFused container, so the owning
## player is found by walking up the tree rather than get_parent().

var weapon_id := ""
var display_name := ""
var level := 1
var _damage_dealt: float = 0.0
var damage_dealt: float:
	get: return _damage_dealt
	set(value):
		_dps_bucket += value - _damage_dealt
		_damage_dealt = value
var dps: float = 0.0
var _dps_bucket: float = 0.0
var _dps_timer: float = 1.0
var tier := 0   # fusion depth: 0 = base weapon, 1 = base+base fusion, 2 = deep (final). See GameConfig.MAX_FUSION_TIER.
var player: Player


## Node-count level: spawn COUNTS (projectiles/blades/turrets/chains/beams)
## freeze at the MAX_WEAPON_LEVEL value (7) so unbounded fusion leveling can't
## explode the live entity count. Damage / area / cadence keep scaling with the
## real `level` past the cap (fused parts level on).
func count_level() -> int:
	return mini(level, GameConfig.MAX_WEAPON_LEVEL)


func _ready() -> void:
	var n := get_parent()
	while n != null and not (n is Player):
		n = n.get_parent()
	player = n as Player


func _process(delta: float) -> void:
	_dps_timer -= delta
	if _dps_timer <= 0.0:
		dps = _dps_bucket
		_dps_bucket = 0.0
		_dps_timer = 1.0


## Universal Duration hook for instant/continuous weapons: leave a burn whose
## length scales with the player's Duration stat and dps with the hit damage
## (which already includes Power). Lets every weapon benefit from Duration.
## Re-igniting an already-burning enemy stacks (Enemy.apply_burn): repeat hits
## compound into a hotter, longer-lasting burn. `stack_mult` > 1 makes those
## repeat stacks pile on faster -- Flame Cone's signature.
func ignite(e: Node, dmg: float, stack_mult: float = 1.0) -> void:
	e.apply_burn(dmg * 0.3, 1.2 * player.duration_mult, stack_mult, player.peer_id)


## Count nodes in `group_name` that THIS weapon instance deployed (their
## `owner_weapon_id` equals our instance id). Lets deployable weapons (turrets,
## mines) cap their spawns PER WEAPON instead of sharing one global group count —
## so two mine/turret weapons (including one per player in co-op) don't split a
## single cap. Each spawner must stamp `owner_weapon_id = get_instance_id()`.
func owned_in_group(group_name: String) -> int:
	var my_id := get_instance_id()
	var n := 0
	for node in get_tree().get_nodes_in_group(group_name):
		if node.owner_weapon_id == my_id:
			n += 1
	return n


## Nova-family "shockwave" push: a mild extra knockback impulse on top of
## take_hit's normal hit knockback, so nova-style blasts visibly shove enemies
## outward. Push distance is spatial, so it scales with Area.
func push(e: Node, from_pos: Vector2, strength: float = 50.0) -> void:
	e.apply_push(from_pos, strength * player.area_mult)

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
const DPS_WINDOW := 30   # `dps` is averaged over a rolling 30-second window
var dps: float = 0.0
var _dps_bucket: float = 0.0
var _dps_timer: float = 1.0
var _dps_history: Array[float] = []   # last up-to-DPS_WINDOW one-second damage totals
var tier := 0   # 0 = base weapon, 1 = base+base signature fusion, 2 = amalgam (terminal). See Fusions.can_merge.
# Fusion stat scaling (1.0 = no effect, so standalone/base weapons are untouched):
#  - fuse_pow: an AMALGAM (WeaponFused) sets this on its components to buff ALL stats by
#    GameConfig.AMALGAM_STAT_PER_LEVEL per amalgam level; applied via the fuse_* helpers.
#  - born_dmg: a fresh SIGNATURE fusion is born with a flat damage boost so it isn't a
#    downgrade from the two maxed weapons it consumed (GameConfig.FUSION_BORN_DMG).
var fuse_pow := 1.0
var born_dmg := 1.0
var player: Player


## Fusion-aware stat accessors. Fused weapons read these instead of player.* so an
## amalgam can scale its components (fuse_pow) and a fresh fusion can carry a base-damage
## boost (born_dmg). Haste DIVIDES by fuse_pow (lower rate = faster). At the 1.0 defaults
## these return the raw player stat, so behavior is unchanged for non-fused weapons.
func fuse_damage() -> float: return player.damage_mult * fuse_pow * born_dmg
func fuse_area() -> float: return player.area_mult * fuse_pow
func fuse_duration() -> float: return player.duration_mult * fuse_pow
func fuse_rate() -> float: return player.rate_mult / fuse_pow


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
	if _dps_timer > 0.0:
		return
	_dps_timer = 1.0
	_dps_history.append(_dps_bucket)
	_dps_bucket = 0.0
	if _dps_history.size() > DPS_WINDOW:
		_dps_history.pop_front()
	var total := 0.0
	for v in _dps_history:
		total += v
	dps = total / _dps_history.size()  # rolling average over the last up-to-30 s


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

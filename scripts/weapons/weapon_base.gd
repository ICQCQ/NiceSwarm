class_name WeaponBase
extends Node2D
## Base for all weapons: id, level, display name, and player resolution.
## Weapons can be nested inside a WeaponFused container, so the owning
## player is found by walking up the tree rather than get_parent().

var weapon_id := ""
var display_name := ""
var level := 1
var player: Player


func _ready() -> void:
	var n := get_parent()
	while n != null and not (n is Player):
		n = n.get_parent()
	player = n as Player


## Universal Duration hook for instant/continuous weapons: leave a burn whose
## length scales with the player's Duration stat and dps with the hit damage
## (which already includes Power). Lets every weapon benefit from Duration.
## Re-igniting an already-burning enemy stacks (Enemy.apply_burn): repeat hits
## compound into a hotter, longer-lasting burn. `stack_mult` > 1 makes those
## repeat stacks pile on faster -- Flame Cone's signature.
func ignite(e: Node, dmg: float, stack_mult: float = 1.0) -> void:
	e.apply_burn(dmg * 0.3, 1.2 * player.duration_mult, stack_mult)


## Nova-family "shockwave" push: a mild extra knockback impulse on top of
## take_hit's normal hit knockback, so nova-style blasts visibly shove enemies
## outward. Push distance is spatial, so it scales with Area.
func push(e: Node, from_pos: Vector2, strength: float = 50.0) -> void:
	e.apply_push(from_pos, strength * player.area_mult)

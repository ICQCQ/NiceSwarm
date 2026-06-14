class_name EnemyGrid
extends RefCounted
## Spatial index over the "enemies" group, rebuilt lazily once per physics frame.
## Every weapon/projectile/turret used to do its own `get_tree().get_nodes_in_group
## ("enemies")` scan each frame — late-game that's dozens of objects x hundreds of
## enemies. `near(pos, radius)` instead buckets enemies into a grid and returns only
## the cells overlapping `pos` +/- radius: a strict superset of "within radius of pos"
## (callers keep their own precise `distance <= radius + e.radius` check).

const CELL := 150.0
const MARGIN := 40.0  # >= largest enemy radius, so "near" stays a superset of
                       # `distance <= radius + e.radius` checks

static var _cells: Dictionary = {}
static var _frame: int = -1


static func _ensure_fresh() -> void:
	var f := Engine.get_physics_frames()
	if f == _frame:
		return
	_frame = f
	_cells.clear()
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	for n in tree.get_nodes_in_group("enemies"):
		var e := n as Enemy
		var key := Vector2i(floori(e.global_position.x / CELL), floori(e.global_position.y / CELL))
		if not _cells.has(key):
			_cells[key] = [] as Array[Enemy]
		(_cells[key] as Array[Enemy]).append(e)


## Enemies in cells overlapping the box [pos-radius, pos+radius]. Pass the same
## radius used in your `distance <= radius + e.radius` check — the cell padding
## already covers enemy size, so this never excludes a true hit.
static func near(pos: Vector2, radius: float) -> Array[Enemy]:
	_ensure_fresh()
	var result: Array[Enemy] = []
	var r := radius + MARGIN
	var min_c := Vector2i(floori((pos.x - r) / CELL), floori((pos.y - r) / CELL))
	var max_c := Vector2i(floori((pos.x + r) / CELL), floori((pos.y + r) / CELL))
	for cx in range(min_c.x, max_c.x + 1):
		for cy in range(min_c.y, max_c.y + 1):
			var key := Vector2i(cx, cy)
			if _cells.has(key):
				result.append_array(_cells[key])
	return result


## All live enemies — fallback for unbounded queries (still O(1) extra cost
## thanks to the per-frame cache).
static func all() -> Array[Enemy]:
	_ensure_fresh()
	var result: Array[Enemy] = []
	for bucket in _cells.values():
		result.append_array(bucket)
	return result
